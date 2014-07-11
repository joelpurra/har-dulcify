#!/usr/bin/env bash
set -e

domainroot="${1%/}"
domainroot="${domainroot:-$PWD}"
domainroot=$(cd "$domainroot"; echo "$PWD")

domainpaths=$(find "$domainroot" -type d ! -path "$domainroot")

for domainpath in $domainpaths;
do
	newest=$("${BASH_SOURCE%/*}/single.sh" "$domainpath")

	if [[ -e "$newest" ]]; then
		echo "$newest"
	fi
done
