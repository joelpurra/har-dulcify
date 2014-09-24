#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	organizations: .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.organizations
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	"Google": (.organizations."Google" // 0),
	"Facebook": (.organizations."Facebook" // 0),
	"Twitter": (.organizations."Twitter" // 0),
	"Microsoft": (.organizations."Microsoft" // 0),
	"Amazon.com": (.organizations."Amazon.com" // 0),
	"Adobe": (.organizations."Adobe" // 0),
	"Yahoo!": (.organizations."Yahoo!" // 0),
	"AddThis": (.organizations."AddThis" // 0),
	"AppNexus": (.organizations."AppNexus" // 0),
	"comScore": (.organizations."comScore" // 0),
	"Quantcast": (.organizations."Quantcast" // 0),
	"Adform": (.organizations."Adform" // 0),
	"New Relic": (.organizations."New Relic" // 0),
	"Optimizely": (.organizations."Optimizely" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (.organizations."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--Google": ."Google",
		"04--Facebook": ."Facebook",
		"05--Twitter": ."Twitter",
		"06--Microsoft": ."Microsoft",
		"07--Amazon.com": ."Amazon.com",
		"08--Adobe": ."Adobe",
		"09--Yahoo!": ."Yahoo!",
		"10--AddThis": ."AddThis",
		"11--AppNexus": ."AppNexus",
		"12--comScore": ."comScore",
		"13--Quantcast": ."Quantcast",
		"14--Adform": ."Adform",
		"15--New Relic": ."New Relic",
		"16--Optimizely": ."Optimizely",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.disconnect.organizations.coverage.external.json"

<"datasets.non-failed.disconnect.organizations.coverage.external.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.organizations.coverage.external.sorted.json"

<"datasets.non-failed.disconnect.organizations.coverage.external.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.organizations.coverage.external.sorted.tsv"
