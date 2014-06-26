 #!/usr/bin/env bash
set -e

cat "services.json" | "${BASH_SOURCE%/*}/../classification/disconnect/prepare-service-list.sh" > "prepared.disconnect.services.json"
