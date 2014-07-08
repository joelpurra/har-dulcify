 #!/usr/bin/env bash
set -e

# Prepare aggregates base
<"domains.parts.expanded.classified.disconnect.effective-tld.json" "${BASH_SOURCE%/*}/../aggregate/prepare.sh" > "aggregates.base.json"

# Aggregates, reduced to unique values per domain
<"aggregates.base.json" "${BASH_SOURCE%/*}/../aggregate/prepare-per-domain.sh" > "aggregates.base.per-domain.json"

# Aggregates per domain
<"aggregates.base.per-domain.json" "${BASH_SOURCE%/*}/../aggregate/per-domain.sh" > "aggregates.per-domain.json"

# Aggregates
<"aggregates.base.json" "${BASH_SOURCE%/*}/../aggregate/all.sh" > "aggregates.json"
