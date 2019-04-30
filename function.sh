to_dict() {
    local i
    local key
    local value
    local parsed_json

    [ -z "${1:-""}" ] && return 1
    [ -z "${2:-""}" ] && unset DATA

    declare -Ag DATA

    parsed_json=($(
        echo "$1" \
            | jq --compact-output '. as $parent | try ( to_entries | map(.key, .value) | .[]) catch $parent'
    ))
    parsed_json="${parsed_json:-""}"

    if [ ${#parsed_json[@]} -lt 2 ]; then
        key="${2:-""}"
        value="$(echo "$parsed_json" | sed -e 's/^"//' -e 's/"$//')"
        value="$(printf -- "$value")"

        if [ -z "$key" ]; then
            DATA="$value"
        else
            DATA["$key"]="$value"
        fi
    else
        for ((i = 0; i < ${#parsed_json[@]}; i += 2)); do
            key="$(echo "${parsed_json[$i]}" | sed -e 's/^"//' -e 's/"$//')"
            key="${2:+"$2/"}$(printf -- "$key")"

            to_dict "${parsed_json[$((i + 1))]}" "$key"
        done
    fi
}

request() {
    local url
    local data
    local form

    url="${1:-""}"

    [ -z "$url" ] && return 1

    shift

    __result="$(
        curl -s "$url" "$@" \
            | jq --compact-output 'if .ok then .result else error(.description) end'
    )"
}
