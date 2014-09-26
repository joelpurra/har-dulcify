#!/usr/bin/env bash
set -e

# Fallback to wget, which is chattier or doesn't display a progress bar?
[[ -z "$(which curl)" ]] && { echo "curl is required" >&2; exit 1; }

download() {
	echo "Downloading $1" >&2
	curl --progress-bar -O "$1"
}

# services.json (also known as disconnect-plaintext.json) from disconnect.me
# Alternative URL: https://github.com/disconnectme/disconnect/raw/master/firefox/content/disconnect.safariextension/opera/chrome/data/services.json
download "https://services.disconnect.me/disconnect-plaintext.json"
<"disconnect-plaintext.json" "${BASH_SOURCE%/*}/../classification/disconnect/prepare-service-list.sh" > "prepared.disconnect.services.json"
<"prepared.disconnect.services.json" "${BASH_SOURCE%/*}/../classification/disconnect/analysis.sh" > "prepared.disconnect.services.analysis.json"


download "https://publicsuffix.org/list/effective_tld_names.dat"
<"effective_tld_names.dat" "${BASH_SOURCE%/*}/../classification/public-suffix/prepare-list.sh" > "prepared.public-suffix.json"

