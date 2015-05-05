#!/usr/bin/env bash
set -e

domainroot="${1%/}"
domainroot="${domainroot:-$PWD}"
domainroot=$(cd -- "$domainroot"; echo "$PWD")

# Get a list of the most recently downloaded domains
"${BASH_SOURCE%/*}/../domains/latest/all.sh" "$domainroot" > "domains.latest.txt"

# Concatenate all of them to a single file with a lot of HARs
# Not sure if parallelizing concatenation actually helps, since disk access is limiting
#<"domains.latest.txt" parallel --pipe --max-replace-args=10 --group "tr '\n' '\0' | \"${BASH_SOURCE%/*}/../util/cat-path.sh\"" > "domains.latest.har"
#<"domains.latest.txt" parallel --max-args=10 --group cat > "domains.latest.har"
<"domains.latest.txt" "${BASH_SOURCE%/*}/../util/cat-path.sh" > "domains.latest.har"

# Extract the most interesting parts
<"domains.latest.har" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../extract/request/parts.sh" > "domains.parts.json"

# Expand parts by splitting them up to parts
<"domains.parts.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../extract/request/expand-parts.sh" > "domains.parts.expanded.json"

# Add public suffix domain grouping
<"domains.parts.expanded.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../classification/public-suffix/add.sh" "prepared.public-suffix.json" > "domains.parts.expanded.public-suffix.json"

# Add basic classifications
<"domains.parts.expanded.public-suffix.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../classification/basic.sh" > "domains.parts.expanded.public-suffix.classified.json"

# Add disconnect's block matching
<"domains.parts.expanded.public-suffix.classified.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../classification/disconnect/add.sh" "prepared.disconnect.services.json" > "domains.parts.expanded.public-suffix.classified.disconnect.json"

# Add Alexa's Top 1.000.000 rank, if any.
<"domains.parts.expanded.public-suffix.classified.disconnect.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../classification/alexa/add.sh" "prepared.alexa.rank.json" > "domains.parts.expanded.public-suffix.classified.disconnect.alexa.json"
