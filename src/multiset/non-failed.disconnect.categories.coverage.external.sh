#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains-with-external-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	"external-not-disconnect-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-not-disconnect-match",
	categories: .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.categories,
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains-with-external-requests",
	"external-some-coverage": (1 - ."external-not-disconnect-coverage"),
	"Disconnect": (.categories.Disconnect // 0),
	"Content": (.categories.Content // 0),
	"Advertising": (.categories.Advertising // 0),
	"Analytics": (.categories.Analytics // 0),
	"Social": (.categories.Social // 0)
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains-with-external-requests",
		"03--Any": ."external-some-coverage",
		"04--Disconnect": .Disconnect,
		"05--Content": .Content,
		"06--Advertising": .Advertising,
		"07--Analytics": .Analytics,
		"08--Social": .Social
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.categories.coverage.external.json"

<"datasets.non-failed.disconnect.categories.coverage.external.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.categories.coverage.external.sorted.json"

<"datasets.non-failed.disconnect.categories.coverage.external.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.categories.coverage.external.sorted.tsv"
