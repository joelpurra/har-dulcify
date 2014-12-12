#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedDisconnectCategoryCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains-with-external-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	"public-suffixes": .successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.urls."public-suffixes"
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains-with-external-requests",
	"se": (."public-suffixes"."se" // 0),
	"dk": (."public-suffixes"."dk" // 0),
	"com": (."public-suffixes"."com" // 0),
	"net": (."public-suffixes"."net" // 0),
	"org": (."public-suffixes"."org" // 0),
	"nu": (."public-suffixes"."nu" // 0),
	"uk": (."public-suffixes"."uk" // 0),
	"de": (."public-suffixes"."de" // 0),
	"ru": (."public-suffixes"."ru" // 0),
	"jp": (."public-suffixes"."jp" // 0),
	"cn": (."public-suffixes"."cn" // 0),
	"br": (."public-suffixes"."br" // 0),
	"fr": (."public-suffixes"."fr" // 0),
	# "xxxxxxxxxxxxxxxxxxxxxxxxx": (."public-suffixes"."xxxxxxxxxxxxxxxxxxxxxxxxx" // 0),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains w/ ext": ."non-failed-domains-with-external-requests",
		"03--se": ."se",
		"04--dk": ."dk",
		"05--com": ."com",
		"06--net": ."net",
		"07--org": ."org",
		"08--nu": ."nu",
		"09--uk": ."uk",
		"10--de": ."de",
		"11--ru": ."ru",
		"12--jp": ."jp",
		"13--cn": ."cn",
		"14--br": ."br",
		"15--fr": ."fr",
		# "0c--yyyyyyyyyyyyyyyy": ."yyyyyyyyyyyyyyyy",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedDisconnectCategoryCounts'" >"datasets.non-failed.public-suffix.coverage.external.json"

<"datasets.non-failed.public-suffix.coverage.external.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.public-suffix.coverage.external.sorted.json"

<"datasets.non-failed.public-suffix.coverage.external.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.public-suffix.coverage.external.sorted.tsv"
