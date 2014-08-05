#!/usr/bin/env bash
set -e

<"domains.parts.expanded.classified.disconnect.effective-tld.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../questions/google-gtm-ga-dc.sh"
