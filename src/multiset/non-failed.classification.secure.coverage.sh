#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedClassificationSecure <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	"all-secure-coverage": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
	"all-insecure-coverage": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-insecure-request",
	"internal-secure-coverage": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
	"internal-insecure-coverage": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage.classification."is-insecure-request",
	"external-secure-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-secure-request",
	"external-insecure-coverage": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.classification."is-insecure-request",
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	"all-secure-coverage",
	"all-insecure-coverage",
	"internal-secure-coverage",
	"internal-insecure-coverage",
	"external-secure-coverage",
	"external-insecure-coverage",
	"all-mixed-coverage": (1 - ."all-secure-coverage" - ."all-insecure-coverage"),
	"internal-mixed-coverage": (1 - ."internal-secure-coverage" - ."internal-insecure-coverage"),
	"external-mixed-coverage": (1 - ."external-secure-coverage" - ."external-insecure-coverage"),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--Int insec": ."internal-insecure-coverage",
		"04--Mix int sec": ."internal-mixed-coverage",
		"05--Int sec": ."internal-secure-coverage",
		"06--Ext insec": ."external-insecure-coverage",
		"07--Mix ext sec": ."external-mixed-coverage",
		"08--Ext sec": ."external-secure-coverage",
		"09--All insec": ."all-insecure-coverage",
		"10--Mix sec": ."all-mixed-coverage",
		"11--All sec": ."all-secure-coverage",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedClassificationSecure'" >"datasets.non-failed.classification.secure.coverage.json"

<"datasets.non-failed.classification.secure.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.classification.secure.coverage.sorted.json"

<"datasets.non-failed.classification.secure.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.classification.secure.coverage.sorted.tsv"
