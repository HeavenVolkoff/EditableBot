dev_command() {
    [ "$text" != "$TOKEN" ] && return 1

    db_write "$(printf '.developer.chat_id = %s' "${DATA["chat/id"]}")"

    request "$MSG_URL" \
        -d "chat_id=${DATA["chat/id"]}" \
        --data-urlencode "text=You are now a developer"
}

say_command() {
    # Normalize text
    local text="$(perl -e "$PERL_VENDOR; use Text::Unidecode; print unidecode('$1')" \
                    | sed -e 's/[^A-Za-z _.,!?:'"'"']/ /g' \
                    | tr "\n" " " \
                    | xargs)"
    if [ -z "$text" ]; then
        # TODO: Improve error for message with only deleted characters
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode 'text=You gotta tell me what to say'

        return

        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode "text=${text}"
    fi

    case "${text:(-1)}" in
        "." | "!" | "?")
            ;;
        "," | ":" | "_")
            text="${text::-1}."
            ;;
        *)
            text="${text}."
            ;;
    esac

    local tempfile="$(mktemp -uq)"
    if curl -sfL 'https://api.fifteen.ai/app/getAudioFile' \
            -H 'Content-Type: application/json' \
            --data "$(printf '{"text":"%s","character":"GLaDOS"}' "$text")" \
            | ffmpeg -hide_banner -loglevel panic -f wav -i pipe:0 -f ogg "$tempfile"; then
        request "$VOICE_URL" -F "chat_id=${DATA["chat/id"]}" -F "voice=@${tempfile};filename=voice.ogg" \
            ; rm "$tempfile"
    else
        request "$MSG_URL" \
            -d "chat_id=${DATA["chat/id"]}" \
            --data-urlencode "text=Failed to execute say"
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

    if [ "$dev_id" = "${DATA["chat/id"]}" ]; then
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
