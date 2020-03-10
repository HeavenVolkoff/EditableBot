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

# Make vendor
mkdir -p vendor

# Retrieve libs
curl -L# https://cpan.metacpan.org/authors/id/S/SB/SBURKE/Text-Unidecode-1.30.tar.gz \
    | tar -xzf - --strip-components=2 -C vendor Text-Unidecode-1.30/lib/Text