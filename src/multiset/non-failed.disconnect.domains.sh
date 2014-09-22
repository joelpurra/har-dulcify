#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	domains: .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.domains
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	"www.google.com": (.domains."www.google.com" // 0),
	"doubleclick.net": (.domains."doubleclick.net" // 0),
	"google-analytics.com": (.domains."google-analytics.com" // 0),
	"googleapis.com": (.domains."googleapis.com" // 0),
	"maps.google.com": (.domains."maps.google.com" // 0),
	"youtube.com": (.domains."youtube.com" // 0),
	"facebook.com": (.domains."facebook.com" // 0),
	"twitter.com": (.domains."twitter.com" // 0),
	"scorecardresearch.com": (.domains."scorecardresearch.com" // 0),
	"comScore": (.domains."comScore" // 0),
	"addthis.com": (.domains."addthis.com" // 0),
	"newrelic.com": (.domains."newrelic.com" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (.domains."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--www.google.com": ."www.google.com",
		"04--doubleclick.net": ."doubleclick.net",
		"05--google-analytics.com": ."google-analytics.com",
		"06--googleapis.com": ."googleapis.com",
		"07--maps.google.com": ."maps.google.com",
		"08--youtube.com": ."youtube.com",
		"09--facebook.com": ."facebook.com",
		"10--twitter.com": ."twitter.com",
		"11--scorecardresearch.com": ."scorecardresearch.com",
		"12--comScore": ."comScore",
		"13--addthis.com": ."addthis.com",
		"14--newrelic.com": ."newrelic.com",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.domains.json"

<"datasets.non-failed.disconnect.domains.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.domains.sorted.json"

<"datasets.non-failed.disconnect.domains.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.domains.sorted.tsv"
