dev_command() {
    [ "$text" != "$TOKEN" ] && return 1

    db_write "$(printf '.developer.chat_id = %s' "${DATA["chat/id"]}")"

    request "$MSG_URL" \
        -d "chat_id=${DATA["chat/id"]}" \
        --data-urlencode "text=You are now a developer"
}

say_command() {
    local text="$1"

    if [ -z "$text" ]; then
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode 'text=You gotta tell me what to say'
    else
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode "text=${text}"
    fi
}

start_command() {
    request "$MSG_URL" \
        -d "chat_id=${DATA["chat/id"]}" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text@${ASSETS}/start.md"
}

debug_command() {
    db_read '.developer.chat_id'

    local dev_id="$__result"

    if [ -n "$dev_id" ]; then
        text="$(eval "$text")"
        request "$MSG_URL" \
            -d "chat_id=${dev_id}" \
            --data-urlencode "text=${text::4096}"
    fi
}

edit_command() {
    local text="$1"

    if [ -z "$text" ]; then
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode 'text=You gotta tell me what to say'
    elif [ -z "${DATA["reply_to_message/message_id"]:-""}" ]; then
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode 'text=You gotta reply to which message you want me to edit'
    elif [ "${DATA["reply_to_message/from/id"]}" != "$BOT_ID" ]; then
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode "text=I can't edit someone else's message"
    else
        request "$EDIT_MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            -d "message_id=${DATA["reply_to_message/message_id"]}" \
            --data-urlencode "text=${text}"
    fi
}

nocommand() {
    true
}
