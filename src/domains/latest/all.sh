#!/usr/bin/env bash
set -e

domainroot="${1%/}"
domainroot="${domainroot:-$PWD}"
domainroot=$(cd -- "$domainroot"; echo "$PWD")

# TODO: rewrite to work on strings from find -type f and split/group on directory.
find "$domainroot" -type d -print0 ! -path "$domainroot" | parallel --jobs 10 --null --line-buffer "${BASH_SOURCE%/*}/single.sh" "{}"
