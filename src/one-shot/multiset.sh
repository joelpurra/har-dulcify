#!/usr/bin/env bash
set -e

(( "$#" == 0 )) && { echo "Usage: "$(basename "$BASH_SOURCE")" <dataset folder path>[ <dataset folder path>[ <dataset folder path>]]" 1>&2; exit 1; }

"${BASH_SOURCE%/*}/../multiset/download-retries.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/request-status.codes.coverage.origin.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.origin.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.internal.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.mime-types.groups.coverage.external.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.classification.domain-scope.coverage.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.classification.secure.coverage.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.categories.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.domains.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.disconnect.organizations.sh" "$@"
"${BASH_SOURCE%/*}/../multiset/non-failed.url.counts.sh" "$@"