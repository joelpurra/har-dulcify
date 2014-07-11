#!/usr/bin/env bash
set -e

"${BASH_SOURCE%/*}/preparations.sh"
"${BASH_SOURCE%/*}/data.sh" "$1"
"${BASH_SOURCE%/*}/aggregate.sh"
