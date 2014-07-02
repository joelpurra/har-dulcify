 #!/usr/bin/env bash
set -e

# services.json (also known as disconnect-plaintext.json) from disconnect.me
# Alternative URL: https://github.com/disconnectme/disconnect/raw/master/firefox/content/disconnect.safariextension/opera/chrome/data/services.json
wget "https://services.disconnect.me/disconnect-plaintext.json"
cat "disconnect-plaintext.json" | "${BASH_SOURCE%/*}/../classification/disconnect/prepare-service-list.sh" > "prepared.disconnect.services.json"
