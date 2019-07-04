#!/usr/bin/env bash

# Only bash >= 4 is supported
if ((${BASH_VERSINFO[0]:-0} <= 3)); then
    printf "Only bash >= 4 supported" >&2
    exit 1
fi

# --- Command Interpreter Configuration ---------------------------------------\
set -e          # exit immediate if an error occurs in a pipeline
set -E          # make commands inherit ERR trap 
set -u          # don't allow not set variables to be utilized
set +o posix    # Allow some bash features
set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions
# set -x # Debug this shell script
# set -n # Check script syntax, without execution.

# --- Language Configuration --------------------------------------------------\
# Check if current language accepts utf-8
if locale -k LC_CTYPE | egrep -qi 'charmap="utf-?8"'; then
    # If not get some language that do
    LANGUAGE=( $(locale -a | egrep -i 'utf-?8') )

    export LANG="${LANGUAGE[0]:-"C.UTF-8"}"
    export LC_ALL="${LANGUAGE[0]:-"C.UTF-8"}"
    export LANGUAGE="${LANGUAGE[0]:-"C.UTF-8"}"
fi

# ----- Special properties ----------------------------------------------------\
readonly __pwd="$(pwd)"
readonly __dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
readonly __file="${__dir}/$(basename -- "$0")"
readonly __base="$(basename ${__file} .sh)"
readonly __root="$(cd "$(dirname "${__dir}")" && pwd)"
__result=""

# --- Traps -------------------------------------------------------------------\
on_failure() {
    local retval=$?
    local err_str="$( \
        printf '%d: %b\n^ Line failed with code %d' \
        "$1" "$BASH_COMMAND" "$retval" \
    )\n"
    local stack_trace=""

    shift
    for func in $@; do
        stack_trace="${stack_trace}$(printf '  %15s()' "$func")\n"
    done

    if [ -n "$stack_trace" ]; then
        err_str="$(printf '%bCall stack:\n%b' "$err_str" "$stack_trace")"
    fi

    if declare -f db_read >/dev/null \
        && db_read '.developer.chat_id' \
        && declare -f request >/dev/null
    then
        request "$MSG_URL" \
            -d "chat_id=${__result}" \
            -d "parse_mode=Markdown" \
            --data-urlencode "$(printf 'text=`%b`' "${err_str}")" || true
    fi

    printf "$err_str\n" >&2

    exit $retval
}

trap 'on_failure $LINENO ${FUNCNAME[@]}' ERR

# ----- global properties -----------------------------------------------------\
. "$__dir/global.sh"

# ----- Support functions -----------------------------------------------------\
. "$__dir/helpers.sh"
. "$__dir/commands.sh"

process_message() {
    local cmd
    local text="${DATA["text"]:-""}"

    # Check if message is a command
    cmd=($(tr " " "\n" <<<"$text"))
    cmd="${cmd[0]:-""}"
    if [ ${cmd:0:1} = "/" ]; then # Message is a command
        # Separate command parts
        cmd=($(tr "@" "\n" <<<"$cmd"))
        # Check if it is a command for this bot
        [ "${cmd[1]:-"$BOT_USERNAME"}" != "$BOT_USERNAME" ] && return 0
        # Remove command from text
        text="$(trim "${text:$((${#cmd[0]} + 1 + ${#cmd[1]}))}")"
        # Get command name
        cmd="${cmd[0]:-""}"
    else # Just a normal message
        cmd="/"
    fi

    # Check if command is implemented
    [ -n "$cmd" ] && [ -n "${COMMANDS["$cmd"]:-""}" ]

    # Call command
    ${COMMANDS["$cmd"]} "$text"
}

# ----- Main ------------------------------------------------------------------\
# Populate commands
for func in $(declare -F | awk '{print $NF}'); do
    { [ "$func" = "nocommand" ] && COMMANDS["/"]="$func"; } \
        || { [[ "$func" =~ ^.*?_command$ ]] && COMMANDS["/${func%"_command"}"]="$func"; }
done

# Get database values
db_read $(printf '.config.offset // %d' "$OFFSET")
OFFSET="$__result"
db_read $(printf '.config.timeout // %d' "$TIMEOUT")
TIMEOUT="$__result"

# Get bot info from telegram
if ! { request "$GET_ME_URL" && to_dict "$__result"; }; then
    printf 'Failed to connect to Telegram\n' >&2
    exit 1
fi

# Fill bot info with what was collected
BOT_ID="${DATA["id"]}"
BOT_USERNAME="${DATA["username"]}"

# Don't retain memory
unset DATA

printf "Bot<name=%s, id=%b>\n" "${BOT_USERNAME}" "${BOT_ID}"

# Pooling loop
while request "$UPD_URL" -d "offset=${OFFSET}" -d "timeout=${TIMEOUT}"; do
    UPDATE="$__result"

    # Offset logic
    OFFSET="$(jq '. | max_by(.update_id) .update_id // 0' <<<"$UPDATE")"
    OFFSET="$((OFFSET + 1))"
    db_write "$(printf '.config.offset = %d' "$OFFSET")"
    ((OFFSET == 1)) && continue

    # Filter messages from updates
    messages=($(jq -c '(. | map(.message) | .[]) // empty' <<<"$UPDATE"))
    for message in "${messages[@]}"; do
        (to_dict "$message" && process_message) &
    done
done

# If pooling failed something went wrong
exit 1
