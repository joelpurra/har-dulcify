#!/usr/bin/env bash
set -e

domainpath="${1%/}"
domainpath="${domainpath:-$PWD}"
domainpath=$(cd -- "$domainpath"; echo "$PWD")

newest=$(find "$domainpath" -type f -name '*.har' -print0 | sort -z | tail -1)

if [[ -e "$newest" ]]; then
	echo "$newest"
fi
