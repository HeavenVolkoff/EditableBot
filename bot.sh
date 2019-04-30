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
# Only split on newlines, retain spaces
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

# Bot info (to be filled later)
BOT_ID=""
BOT_USERNAME=""

# Placeholder for message data
DATA=""

# ----- Support functions -----------------------------------------------------\
. "$__dir/function.sh"

process_cmd() {
    local text

    text="${2:-""}"

    case "${1:-""}" in
        /start)
            request "$MSG_URL" \
                -d "chat_id=${DATA["chat/id"]}" \
                -d "parse_mode=Markdown" \
                --data-urlencode "text@${__dir}/start.md" \
                || true
            ;;
        /say)
            [ -z "$text" ] && return 0
            request "$MSG_URL" \
                -d "chat_id=${DATA["chat/id"]}" \
                --data-urlencode "text=${text}" \
                || true
            ;;
        *)
            echo "Unrecognized command: ${cmd[0]}" >&2
            ;;
    esac
}

process_message()  {
    local cmd
    local orig_cmd
    local bot_target

    # Check if message is a command
    orig_cmd=($( tr " " "\n" <<<"${DATA["text"]:-""}"))
    orig_cmd="${orig_cmd[0]:-""}"
    if [ ${orig_cmd:0:1} == "/" ]; then
        # Message is a command
        cmd=($( tr "@" "\n" <<<"$orig_cmd"))
        bot_target="${cmd[1]:-"$BOT_USERNAME"}"
        orig_cmd="${cmd[0]:-""}${cmd[1]:+"@${cmd[1]}"}"
        cmd="${cmd[0]:-""}"

        # Not a command for this bot though
        [ "$bot_target" != "$BOT_USERNAME" ] && return 0

        process_cmd "$cmd" "${DATA["text"]:${#orig_cmd}}"
        return $?
    fi

    # Just a normal direct message

    if [ -n "${DATA["reply_to_message/message_id"]:-""}" ]; then
        request "$EDIT_MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            -d "message_id=${DATA["reply_to_message/message_id"]}" \
            --data-urlencode "text=${DATA[text]}" \
            || true
    fi
}

# ----- Main ------------------------------------------------------------------\
if ! { request "$GET_ME_URL" && to_dict "$__result"; }; then
    echo "Failed to connect to Telegram" >&2
    exit 1
fi

# Fill bot info with information collected from /getMet
BOT_ID="${DATA["id"]}"
BOT_USERNAME="${DATA["username"]}"

# Don't retain memory
unset DATA

echo "Bot<name=${BOT_USERNAME}, id=${BOT_ID}>"

# Pooling loop
while request "$UPD_URL" -d "offset=${OFFSET}" -d "timeout=${TIMEOUT}"; do
    UPDATE="$__result"

    # Offset logic
    OFFSET="$(jq '. | max_by(.update_id) .update_id // 0' <<<"$UPDATE")"
    OFFSET="$((OFFSET + 1))"
    echo "$OFFSET" >"$OFFSET_FILE"
    ((OFFSET == 1)) && continue

    # Filter messages from updates
    messages=($(jq -c '(. | map(.message) | .[]) // empty' <<<"$UPDATE"))
    for message in "${messages[@]}"; do
        ( to_dict "$message" && process_message ) &
    done

    # Don't retain memory
    unset DATA
done

# If pooling failed something went wrong
exit 1
