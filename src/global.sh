# Only split on newlines, retain spaces
IFS=$'\n'

# Support files
ASSETS="$(realpath -e "${__dir}/../assets")"
DB_FILE="${ASSETS}/db.json"
TOKEN_FILE="${ASSETS}/token.key"

# Verify if database exists and that it is a valid json file
if ! cat "$DB_FILE" | jq "." >/dev/null 2>/dev/null; then
    printf "Invalid Database, reseting...\n" >&2
    printf "{}" >"$DB_FILE"
fi

# Open file
exec 200<>"$DB_FILE"

# Token validation
TOKEN="$(cat $TOKEN_FILE)"
if [ -z "$TOKEN" ]; then
    printf "Invalid token" >&2
    exit 1
fi

# Method urls
URL="https://api.telegram.org/bot${TOKEN}"
UPD_URL="${URL}/getUpdates"
MSG_URL="${URL}/sendMessage"
GET_ME_URL="${URL}/getMe"
EDIT_MSG_URL="${URL}/editMessageText"

# getUpdates options
OFFSET="1"
TIMEOUT="60"

# Bot info (to be filled later)
BOT_ID=""
BOT_USERNAME=""

# Placeholder for message data
DATA=""

# Reference to command functions
declare -A COMMANDS
