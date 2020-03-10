#!/usr/bin/env bash

# Only bash >= 4
if ((${BASH_VERSION%%.*} <= 3)); then
    printf "Only bash >= 4 supported" >&2
    exit 1
fi

# --- Command Interpreter Configuration ---------------------------------------\
set -e          # exit immediate if an error occurs in a pipeline
set -u          # don't allow not set variables to be utilized
set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions
# set -x # Debug this shell script
# set -n # Check script syntax, without execution.

# ----- Special properties ----------------------------------------------------\
readonly __pwd="$(pwd)"
readonly __dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
readonly __file="${__dir}/$(basename -- "$0")"
readonly __base="$(basename ${__file} .sh)"
readonly __root="$(cd "$(dirname "${__dir}")" && pwd)"

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

if ! [ -f "${__dir}/assets/token.key" ]; then
    printf "Couldn't find token.key file in assets folder" >&2
    exit 1
fi

# Initialize vendor
. vendor.sh

# Make global runtime folder
mkdir -p /usr/local/bot

# Copy runtime
cp -r $__dir/{src,vendor,assets} /usr/local/bot/
[ -f "/usr/local/bot/assets/db.json" ] || { printf "{}" >"/usr/local/bot/assets/db.json"; }

# Set permissions
chown -R 65534:65534 /usr/local/bot/
find /usr/local/bot -type d | xargs -r chmod 550
find /usr/local/bot -type f | xargs -r chmod 440
chmod 550 /usr/local/bot/src/bot.sh
chmod 660 /usr/local/bot/assets/*

# Copy service
cp "${__dir}/bot.service" /etc/systemd/system/

# Start service
systemctl daemon-reload
systemctl stop bot
systemctl start bot
systemctl enable bot
journalctl -f -u bot.service
