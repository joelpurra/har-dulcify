#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedClassificationDisconnect <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	"non-failed-domains-with-internal-requests": .successfulOrigin.internalUrls.requestedUrlsDistinct.counts.countDistinct,
	"non-failed-domains-with-external-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	"all-disconnect-coverage": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-disconnect-match",
	"all-not-disconnect-coverage": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-not-disconnect-match",
	"internal-disconnect-coverage": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage.classification."is-disconnect-match",
	"internal-not-disconnect-coverage": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage.classification."is-not-disconnect-match",
	"external-disconnect-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-disconnect-match",
	"external-not-disconnect-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-not-disconnect-match",
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	"non-failed-domains-with-internal-requests",
	"non-failed-domains-with-external-requests",
	"all-disconnect-coverage",
	"all-not-disconnect-coverage",
	"internal-disconnect-coverage",
	"internal-not-disconnect-coverage",
	"external-disconnect-coverage",
	"external-not-disconnect-coverage",
	"all-mixed-coverage": (1 - ."all-disconnect-coverage" - ."all-not-disconnect-coverage"),
	"internal-mixed-coverage": (1 - ."internal-disconnect-coverage" - ."internal-not-disconnect-coverage"),
	"external-mixed-coverage": (1 - ."external-disconnect-coverage" - ."external-not-disconnect-coverage"),
	"all-some-coverage": (1 - ."all-not-disconnect-coverage"),
	"internal-some-coverage": (1 - ."internal-not-disconnect-coverage"),
	"external-some-coverage": (1 - ."external-not-disconnect-coverage"),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--Dom w/ int": ."non-failed-domains-with-internal-requests",
		"04--Int non-D": ."internal-not-disconnect-coverage",
		# "xxxxxxxxx--Mix int D": ."internal-mixed-coverage",
		# "xxxxxxxxx--Int D": ."internal-disconnect-coverage",
		"05--Some int D": ."internal-some-coverage",
		"06--Dom w/ ext": ."non-failed-domains-with-external-requests",
		"07--Ext non-D": ."external-not-disconnect-coverage",
		# "xxxxxxxxx--Mix ext D": ."external-mixed-coverage",
		# "xxxxxxxxx--Ext D": ."external-disconnect-coverage",
		"08--Some ext D": ."external-some-coverage",
		"09--All non-D": ."all-not-disconnect-coverage",
		# "xxxxxxxxx--Mix D": ."all-mixed-coverage",
		# "xxxxxxxxx--All D": ."all-disconnect-coverage",
		"10--Some D": ."all-some-coverage",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedClassificationDisconnect'" >"datasets.non-failed.classification.disconnect.coverage.json"

<"datasets.non-failed.classification.disconnect.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.classification.disconnect.coverage.sorted.json"

<"datasets.non-failed.classification.disconnect.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.classification.disconnect.coverage.sorted.tsv"
