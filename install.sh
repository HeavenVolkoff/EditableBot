#!/usr/bin/env bash

# --- Command Interpreter Configuration ---------------------------------------\
set -e # exit immediate if an error occurs in a pipeline
set -u # don't allow not set variables to be utilized
set +o posix # Allow some bash features
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

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

mkdir -p /usr/local/bot
cp -r $__dir/* /usr/local/bot/
cp "${__dir}/bot.service" /etc/systemd/system/
chown -R 65534:65534 /usr/local/bot/
find /usr/local/bot/ -type f -exec chmod 0770 {} \;
systemctl daemon-reload
systemctl stop bot
systemctl start bot
systemctl enable bot
journalctl -f -u  bot.service
