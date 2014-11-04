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
	"facebook.com": (.domains."facebook.com" // 0),
	"twitter.com": (.domains."twitter.com" // 0),
	"cloudfront.net": (.domains."cloudfront.net" // 0),
	"addthis.com": (.domains."addthis.com" // 0),
	"newrelic.com": (.domains."newrelic.com" // 0),
	"optimizely.com": (.domains."optimizely.com" // 0),
	"scorecardresearch.com": (.domains."scorecardresearch.com" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (.domains."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--facebook.com": ."facebook.com",
		"04--twitter.com": ."twitter.com",
		"05--cloudfront.net": ."cloudfront.net",
		"06--addthis.com": ."addthis.com",
		"07--newrelic.com": ."newrelic.com",
		"08--optimizely.com": ."optimizely.com",
		"09--scorecardresearch.com": ."scorecardresearch.com",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.domains.coverage.external.json"

<"datasets.non-failed.disconnect.domains.coverage.external.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.domains.coverage.external.sorted.json"

<"datasets.non-failed.disconnect.domains.coverage.external.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.domains.coverage.external.sorted.tsv"
