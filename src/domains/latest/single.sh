#!/bin/bash
set -e

domainpath="${1%/}"

newest=$(find $domainpath -type f | sort | tail -1)

echo "$newest"
