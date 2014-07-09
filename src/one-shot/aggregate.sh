 #!/usr/bin/env bash
set -e

# Prepare aggregates base
<"domains.parts.expanded.classified.disconnect.effective-tld.json" "${BASH_SOURCE%/*}/../aggregate/prepare.sh" > "aggregates.base.json"

# Aggregates
<"aggregates.base.json" "${BASH_SOURCE%/*}/../aggregate/all.sh" > "aggregates.json"

# Analysis
<"aggregates.json" "${BASH_SOURCE%/*}/../aggregate/analysis.sh" > "aggregates.analysis.json"
