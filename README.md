# Editable Bot

This is a simple telegram bot, written in bash, that allows multiple users to
edit the same message. I am currently using it to facilitate the mantainace of
pin messages in groups.

## Requirements

- Bash >= 4.0

- curl

- jq

- systemd (Only required if you want to use the included installation method)

## Installation

Run: `sudo ./install.sh`

Will create a systemd service called bot, and activate it.
All files will be copied to `/usr/local/bot`.

## License

See [LICENSE](./LICENSE)

## COPYRIGHT

    Copyright (c) 2018 Vítor Augusto da Silva Vasconcellos. All rights reserved.