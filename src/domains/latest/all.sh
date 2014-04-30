#!/bin/bash
set -e

domainroot="$PWD/${1%/}"

cd "$(dirname $0)"

domainpaths=$(find "$domainroot" ! -path "$domainroot" -type d)

for domainpath in $domainpaths;
do
	newest=$(./single.sh $domainpath)

	echo "$newest"
done

cd - > /dev/null
