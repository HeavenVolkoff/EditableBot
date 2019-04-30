#!/usr/bin/env bash

# --- Command Interpreter Configuration ---------------------------------------\
set -e # exit immediate if an error occurs in a pipeline
set -u # don't allow not set variables to be utilized
set +o posix # Allow some bash features
set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions
# set -x # Debug this shell script
# set -n # Check script syntax, without execution.

# --- Language Configuration --------------------------------------------------\
export 'LANG=C.UTF-8'
export 'LC_ALL=C.UTF-8'
export 'LANGUAGE=C.UTF-8'

# ----- Special properties ----------------------------------------------------\
readonly __pwd="$(pwd)"
readonly __dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
readonly __file="${__dir}/$(basename -- "$0")"
readonly __base="$(basename ${__file} .sh)"
readonly __root="$(cd "$(dirname "${__dir}")" && pwd)"
__result=""

# ----- global properties -----------------------------------------------------\
IFS=$'\n'

# Support files
TOKEN_FILE="${TOKEN_FILE:-"${__dir}/token.key"}"
OFFSET_FILE=${OFFSET_FILE:-"${__dir}/offset.txt"}

# Token validation
TOKEN="${TOKEN:-"$(cat $TOKEN_FILE)"}"
if [ -z "$TOKEN" ]; then
    echo "Invalid token" >&2
    exit 1
fi

# Method urls
URL="https://api.telegram.org/bot${TOKEN}"
UPD_URL="${URL}/getUpdates"
MSG_URL="${URL}/sendMessage"
GET_ME_URL="${URL}/getMe"
EDIT_MSG_URL="${URL}/editMessageText"

# getUpdates options
OFFSET="${OFFSET:-"$(cat "$OFFSET_FILE" 2>/dev/null || echo "")"}"
OFFSET=${OFFSET:-1}
TIMEOUT=${TIMEOUT:-60}

# ----- Support functions -----------------------------------------------------\
. "$__dir/function.sh"

# ----- Main ------------------------------------------------------------------\
if ! { request "$GET_ME_URL" && to_dict "$__result"; }; then
    echo "Failed to connect to Telegram" >&2
    exit 1
fi

BOT_ID="${DATA["id"]}"
BOT_USERNAME="${DATA["username"]}"

echo "Bot<name=${BOT_USERNAME}, id=${BOT_ID}>"

process_message()  {
    local cmd
    local text
    local orig_cmd
    local bot_target

    orig_cmd=($( echo "${DATA["text"]:-""}" | tr " " "\n"))
    orig_cmd="${orig_cmd[0]:-""}"
    if [ ${orig_cmd:0:1} == "/" ]; then
        cmd=($( echo "$orig_cmd" | tr "@" "\n"))
        bot_target="${cmd[1]:-"$BOT_USERNAME"}"
        cmd="${cmd[0]:-""}"

        [ "$bot_target" != "$BOT_USERNAME" ] && return 0
    else
        cmd=""
        orig_cmd=""
        bot_target=""
    fi

    text="${DATA["text"]:${#orig_cmd}}"

    case "$cmd" in
        /start)
            request "$MSG_URL" \
                -d "chat_id=${DATA["chat/id"]}" \
                -d "parse_mode=Markdown" \
                --data-urlencode 'text=*Available commands*:
• /start  `- Start bot and get this message.`
• /say    `- Tell me something to say.`
Written by Vitor Vasconcellos (@hvolkoff).' \
                || true
            ;;
        /say)
            [ -z "$text" ] && continue
            request "$MSG_URL" \
                -d "chat_id=${DATA["chat/id"]}" \
                --data-urlencode "text=${text:0:4096}" \
                || true
            ;;
        *)
            if [ -n "${DATA["reply_to_message/message_id"]:-""}" ]; then
                request "$EDIT_MSG_URL" \
                    -d "chat_id=${DATA["chat/id"]}" \
                    -d "message_id=${DATA["reply_to_message/message_id"]}" \
                    --data-urlencode "text=${text:0:4096}" \
                    || true
            else
                echo "Unrecognized command: ${cmd[0]}" >&2
            fi
            ;;
    esac
}

while request "$UPD_URL" -d "offset=${OFFSET}" -d "timeout=${TIMEOUT}"; do
    UPDATE="$__result"
    OFFSET="$(echo "$UPDATE" | jq '. | max_by(.update_id) .update_id // 0')"
    OFFSET="$((OFFSET + 1))"

    echo "$OFFSET" >"$OFFSET_FILE"

    [ "$OFFSET" -eq 1 ] && continue

    messages=($( echo "$UPDATE" | jq -c '(. | map(.message) | .[]) // empty'))
    for message in "${messages[@]}"; do
        ( to_dict "$message" && process_message ) &
    done
    wait

    unset DATA
done

exit 1
