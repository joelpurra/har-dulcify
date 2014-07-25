#!/usr/bin/env bash
set -e

domainroot="${1%/}"
domainroot="${domainroot:-$PWD}"
domainroot=$(cd -- "$domainroot"; echo "$PWD")

# Get a list of the most recently downloaded domains
"${BASH_SOURCE%/*}/../domains/latest/all.sh" "$domainroot" > "domains.latest.txt"

# Concatenate all of them to a single file with a lot of HARs
<"domains.latest.txt" "${BASH_SOURCE%/*}/../util/cat-path.sh" > "domains.latest.har"

# Extract the most interesting parts
<"domains.latest.har" "${BASH_SOURCE%/*}/../extract/request/parts.sh" > "domains.parts.json"

# Expand parts by splitting them up to parts
<"domains.parts.json" "${BASH_SOURCE%/*}/../extract/request/expand-parts.sh" > "domains.parts.expanded.json"

# Add basic classifications
<"domains.parts.expanded.json" "${BASH_SOURCE%/*}/../classification/basic.sh" > "domains.parts.expanded.classified.json"

# Add disconnect's block matching
<"domains.parts.expanded.classified.json" "${BASH_SOURCE%/*}/../classification/disconnect/add.sh" "prepared.disconnect.services.json" > "domains.parts.expanded.classified.disconnect.json"

# Add effective tld domain grouping
<"domains.parts.expanded.classified.disconnect.json" "${BASH_SOURCE%/*}/../classification/effective-tld/add.sh" "prepared.effective-tld.json" > "domains.parts.expanded.classified.disconnect.effective-tld.json"
