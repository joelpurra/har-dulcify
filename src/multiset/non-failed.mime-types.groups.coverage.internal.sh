#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedMimeTypes <<-'EOF' || true
{
	path: $path,
	"non-failed-domains-with-internal-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	"kinds-resource-groups": .successfulOrigin.internalUrls.requestedUrlsDistinct.coverage."kinds-resource".groups
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains-with-internal-requests",
	"html": (."kinds-resource-groups"."html" // 0),
	"script": (."kinds-resource-groups"."script" // 0),
	"style": (."kinds-resource-groups"."style" // 0),
	"image": (."kinds-resource-groups"."image" // 0),
	"data": (."kinds-resource-groups"."data" // 0),
	"text": (."kinds-resource-groups"."text" // 0),
	"font": (."kinds-resource-groups"."font" // 0),
	"object": (."kinds-resource-groups"."object" // 0),
	"document": (."kinds-resource-groups"."document" // 0),
	"(null)": (."kinds-resource-groups"."(null)" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (."kinds-resource-groups"."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains w/ int": ."non-failed-domains-with-internal-requests",
		"03--html": ."html",
		"04--script": ."script",
		"05--style": ."style",
		"06--image": ."image",
		"07--data": ."data",
		"08--text": ."text",
		"09--font": ."font",
		"10--object": ."object",
		"11--document": ."document",
		"12--(null)": ."(null)",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedMimeTypes'" >"datasets.non-failed.mime-types.groups.coverage.internal.json"

<"datasets.non-failed.mime-types.groups.coverage.internal.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.mime-types.groups.coverage.internal.sorted.json"

<"datasets.non-failed.mime-types.groups.coverage.internal.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.mime-types.groups.coverage.internal.sorted.tsv"
