#!/usr/bin/env bash
set -e

domainroot="${1%/}"
domainroot="${domainroot:-$PWD}"
domainroot=$(cd -- "$domainroot"; echo "$PWD")

# http://mywiki.wooledge.org/BashFAQ/020
# Bash
unset a i
while IFS= read -r -d '' domainpath; do
	newest=$("${BASH_SOURCE%/*}/single.sh" "$domainpath")

	if [[ -e "$newest" ]]; then
		echo "$newest"
	fi
done < <(find "$domainroot" -type d -print0 ! -path "$domainroot")
