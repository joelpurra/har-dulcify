#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedMimeTypes <<-'EOF' || true
{
	path: $path,
	"domains": .unfiltered.origin.counts.count,
	"request-status-codes": .unfiltered.origin.coverage."request-status".codes,
	"request-status-groups": .unfiltered.origin.coverage."request-status".groups
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"domains",
	"1xx": (."request-status-groups"."1xx" // 0),
	"2xx": (."request-status-groups"."2xx" // 0),
	# "200": (."request-status-codes"."200" // 0),
	"3xx": (."request-status-groups"."3xx" // 0),
	"301": (."request-status-codes"."301" // 0),
	"302": (."request-status-codes"."302" // 0),
	"303": (."request-status-codes"."303" // 0),
	# "304": (."request-status-codes"."304" // 0),
	"307": (."request-status-codes"."307" // 0),
	"4xx": (."request-status-groups"."4xx" // 0),
	"5xx": (."request-status-groups"."5xx" // 0),
	"(null)": (."request-status-groups"."(null)" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (."request-status-codes"."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."domains",
		"03--1xx": ."1xx",
		"04--2xx": ."2xx",
		# "05--200": ."200",
		"06--3xx": ."3xx",
		"07--301": ."301",
		"08--302": ."302",
		"09--303": ."303",
		# "10--304": ."304",
		"11--307": ."307",
		"12--4xx": ."4xx",
		"13--5xx": ."5xx",
		"14--(null)": ."(null)",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedMimeTypes'" >"datasets.request-status.coverage.origin.json"

<"datasets.request-status.coverage.origin.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.request-status.coverage.origin.sorted.json"

<"datasets.request-status.coverage.origin.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.request-status.coverage.origin.sorted.tsv"
