clear_str() {
    set -- "${1%\"}"
    printf -- "${1#\"}"
}

to_dict() {
    local i
    local key
    local value
    local lenght
    local json_cmd

    [ -z "${1:-""}" ] && return 1
    if [ -z "${2:-""}" ]; then
        unset DATA
        declare -Ag DATA
    fi

    set -- "$1" "${2:-""}"

    json_cmd='. as $parent | try ( to_entries | map(.key, .value) | .[]) catch $parent'

    while (($# > 0)); do
        key="$2"
        value=($( jq -c "$json_cmd" <<<"$1"))
        lenght="${#value[@]}"

        shift 2

        if ((lenght == 0)); then
            continue
        elif ((lenght < 2)); then
            value="$(clear_str $value)"

            if [ -z "$key" ]; then
                DATA="$value"
            else
                DATA["$key"]="$value"
            fi
        else
            # TODO: escape possible `\` characters in key
            for ((i = 0; i < lenght; i += 2)); do
                set -- \
                    "${value[$((i + 1))]}" \
                    "${key:+"$key/"}$(clear_str "${value[$i]}")" \
                    $@
            done
        fi
    done
}

request() {
    local url
    local data

    url="${1:-""}"

    [ -z "$url" ] && return 1

    shift

    __result="$(jq -c 'if .ok then .result else error(.description) end' <<<"$( curl -s "$url" "$@")")"
}
