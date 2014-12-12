#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains-with-external-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	domains: .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.domains
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains-with-external-requests",
	"www.google.com": (.domains."www.google.com" // 0),
	"doubleclick.net": (.domains."doubleclick.net" // 0),
	"google-analytics.com": (.domains."google-analytics.com" // 0),
	"googleapis.com": (.domains."googleapis.com" // 0),
	"maps.google.com": (.domains."maps.google.com" // 0),
	"youtube.com": (.domains."youtube.com" // 0),
	"google.se": (.domains."google.se" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (.domains."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains w/ ext": ."non-failed-domains-with-external-requests",
		"03--www.google.com": ."www.google.com",
		"04--doubleclick.net": ."doubleclick.net",
		"05--google-analytics.com": ."google-analytics.com",
		"06--googleapis.com": ."googleapis.com",
		"07--maps.google.com": ."maps.google.com",
		"08--youtube.com": ."youtube.com",
		"09--google.se": ."google.se",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.domains.coverage.external.google.json"

<"datasets.non-failed.disconnect.domains.coverage.external.google.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.domains.coverage.external.google.sorted.json"

<"datasets.non-failed.disconnect.domains.coverage.external.google.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.domains.coverage.external.google.sorted.tsv"
