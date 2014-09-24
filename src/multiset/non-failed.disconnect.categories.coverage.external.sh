#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	categories: .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.categories
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
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
		"02--Domains": ."non-failed-domains",
		"03--Disconnect": .Disconnect,
		"04--Content": .Content,
		"05--Advertising": .Advertising,
		"06--Analytics": .Analytics,
		"07--Social": .Social
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.categories.coverage.external.json"

<"datasets.non-failed.disconnect.categories.coverage.external.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.categories.coverage.external.sorted.json"

<"datasets.non-failed.disconnect.categories.coverage.external.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.categories.coverage.external.sorted.tsv"
