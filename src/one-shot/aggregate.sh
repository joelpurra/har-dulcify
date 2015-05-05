#!/usr/bin/env bash
set -e

# Prepare aggregates base
<"domains.parts.expanded.public-suffix.classified.disconnect.alexa.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../aggregate/prepare.sh" > "aggregates.base.json"
<"aggregates.base.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../aggregate/prepare2.sh" > "aggregates.base.2.json"

# Aggregates
<"aggregates.base.2.json" "${BASH_SOURCE%/*}/../aggregate/all.sh" > "aggregates.json"

# Analysis
<"aggregates.json" "${BASH_SOURCE%/*}/../aggregate/analysis.sh" > "aggregates.analysis.json"
