#!/usr/bin/env bash
set -e

(( "$#" == 0 )) && { echo "Usage: "$(basename "$BASH_SOURCE")" <dataset folder path>[ <dataset folder path>[ <dataset folder path>]]" 1>&2; exit 1; }

"${BASH_SOURCE%/*}/../multiset/download-retries.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/origin-redirects.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/ratio-buckets.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/request-status.codes.coverage.origin.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.origin.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.internal.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.classification.domain-scope.coverage.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.classification.secure.coverage.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.public-suffix.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.categories.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.domains.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.domains.coverage.external.google.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.organizations.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.requests.counts.sh" "$@"