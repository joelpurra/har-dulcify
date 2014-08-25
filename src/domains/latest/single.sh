#!/usr/bin/env bash
set -e

domainpath="${1%/}"
domainpath="${domainpath:-$PWD}"
domainpath=$(cd -- "$domainpath"; echo "$PWD")

# https://unix.stackexchange.com/questions/75186/how-to-do-head-and-tail-on-null-delimited-input-in-bash
# https://unix.stackexchange.com/a/75206
nul_terminated() {
  tr '\0\n' '\n\0' | "$@" | tr '\0\n' '\n\0'
}

newest=$(find "$domainpath" -type f -name '*.har' -print0 | sort -z | nul_terminated tail -1)

if [[ -e "$newest" ]]; then
	echo "$newest"
fi
