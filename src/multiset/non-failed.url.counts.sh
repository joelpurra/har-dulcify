#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedUrlCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	requests: .successfulOrigin.unfilteredUrls.requestedUrls.counts.count,
	"internal-requests": .successfulOrigin.internalUrls.requestedUrls.counts.count,
	"external-requests": .successfulOrigin.externalUrls.requestedUrls.counts.count,
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-2:] | join("/")),
	"non-failed-domains",
	requests,
	"internal-requests",
	"external-requests",
	#"internal-requests-ratio": (."internal-requests" / .requests),
	"external-requests-ratio": (."external-requests" / .requests),
	"requests-per-domain": (.requests / ."non-failed-domains"),
	#"internal-requests-per-domain": (."internal-requests" / ."non-failed-domains"),
	"external-requests-per-domain": (."external-requests" / ."non-failed-domains"),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Non-failed domains": ."non-failed-domains",
		"03--Requests": .requests,
		"04--Internal requests": ."internal-requests",
		"05--External requests": ."external-requests",
		#"06--Internal ratio": ."internal-requests-ratio",
		"07--External ratio": ."external-requests-ratio",
		"08--Requests per domain": ."requests-per-domain",
		#"09--Internal requests per domain": ."internal-requests-per-domain",
		"10--External requests per domain": ."external-requests-per-domain",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedUrlCounts'" >"datasets.non-failed.url.counts.json"

<"datasets.non-failed.url.counts.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.url.counts.sorted.json"

<"datasets.non-failed.url.counts.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.url.counts.sorted.tsv"
