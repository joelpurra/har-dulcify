#!/usr/bin/env bash
set -e

# Google Tag Manager
<"domains.parts.expanded.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../questions/google-gtm-ga-dc.sh" > "google-gtm-ga-dc.json"
# TODO: parallelize question aggregation?
<"google-gtm-ga-dc.json" "${BASH_SOURCE%/*}/../questions/google-gtm-ga-dc.aggregate.sh" > "google-gtm-ga-dc.aggregate.json"
