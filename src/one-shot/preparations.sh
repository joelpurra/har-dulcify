#!/usr/bin/env bash
set -e

# services.json (also known as disconnect-plaintext.json) from disconnect.me
# Alternative URL: https://github.com/disconnectme/disconnect/raw/master/firefox/content/disconnect.safariextension/opera/chrome/data/services.json
wget "https://services.disconnect.me/disconnect-plaintext.json"
<"disconnect-plaintext.json" "${BASH_SOURCE%/*}/../classification/disconnect/prepare-service-list.sh" > "prepared.disconnect.services.json"
<"prepared.disconnect.services.json" "${BASH_SOURCE%/*}/../classification/disconnect/analysis.sh" > "prepared.disconnect.services.analysis.json"


wget "https://publicsuffix.org/list/effective_tld_names.dat"
<"effective_tld_names.dat" "${BASH_SOURCE%/*}/../classification/effective-tld/prepare-list.sh" > "prepared.effective-tld.json"

