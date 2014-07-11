#!/usr/bin/env bash
set -e

domainpath="${1%/}"
domainpath="${domainpath:-$PWD}"
domainpath=$(cd "$domainpath"; echo "$PWD")

newest=$(find "$domainpath" -type f | sort | tail -1)

if [[ -e "$newest" ]]; then
	echo "$newest"
fi
