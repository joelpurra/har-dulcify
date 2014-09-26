#!/usr/bin/env bash
set -e

# Google Tag Manager
<"domains.parts.expanded.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../questions/google-gtm-ga-dc.sh" > "google-gtm-ga-dc.json"
# TODO: parallelize question aggregation?
<"google-gtm-ga-dc.json" "${BASH_SOURCE%/*}/../questions/google-gtm-ga-dc.aggregate.sh" > "google-gtm-ga-dc.aggregate.json"

# Origin redirects
<"domains.parts.expanded.public-suffix.classified.json" "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/../questions/origin-redirects.sh" > "origin-redirects.json"
# TODO: parallelize question aggregation?
<"origin-redirects.json" "${BASH_SOURCE%/*}/../questions/origin-redirects.aggregate.sh" > "origin-redirects.aggregate.json"

# Regroup disconnect's categories and organizations
<"aggregates.analysis.json" "${BASH_SOURCE%/*}/../questions/disconnect.categories.organizations.sh" "prepared.disconnect.services.json" > "aggregate.disconnect.categories.organizations.json"