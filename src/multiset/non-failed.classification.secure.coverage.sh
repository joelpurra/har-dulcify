#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedClassificationSecure <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	requests: .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
	"internal-secure-coverage": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
	"external-secure-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	requests,
	"internal-secure-coverage",
	"external-secure-coverage",
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--All secure": .requests,
		"04--Internal secure": ."internal-secure-coverage",
		"05--External secure": ."external-secure-coverage",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedClassificationSecure'" >"datasets.non-failed.classification.secure.coverage.json"

<"datasets.non-failed.classification.secure.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.classification.secure.coverage.sorted.json"

<"datasets.non-failed.classification.secure.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.classification.secure.coverage.sorted.tsv"
