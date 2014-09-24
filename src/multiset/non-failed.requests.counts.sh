#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedUrlCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	unfilteredRequests: .successfulOrigin.unfilteredUrls.requestedUrls.counts.count,
	internalRequests: .successfulOrigin.internalUrls.requestedUrls.counts.count,
	externalRequests: .successfulOrigin.externalUrls.requestedUrls.counts.count,
	externalRequestsDisconnectMatches: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.domains | add),
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	unfilteredRequests,
	internalRequests,
	externalRequests,
	externalRequestsDisconnectMatches,
	unfilteredRequestsPerDomain: (.unfilteredRequests / ."non-failed-domains"),
	internalRequestsPerDomain: (.internalRequests / ."non-failed-domains"),
	externalRequestsPerDomain: (.externalRequests / ."non-failed-domains"),
	externalRequestsDisconnectMatchesPerDomain: (.externalRequestsDisconnectMatches / ."non-failed-domains"),
	internalRequestsRatio: (.internalRequests / .unfilteredRequests),
	externalRequestsRatio: (.externalRequests / .unfilteredRequests),
	externalRequestsDisconnectMatchesRatio: (.externalRequestsDisconnectMatches / .unfilteredRequests),
	externalRequestsDisconnectMatchesPerExternalRequests: (.externalRequestsDisconnectMatches / .externalRequests),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--All": ."unfilteredRequests",
		"04--Ext": ."externalRequests",
		"05--Int": ."internalRequests",
		"06--Disco.": ."externalRequestsDisconnectMatches",
		"07--A/d": ."unfilteredRequestsPerDomain",
		"08--I/d": ."internalRequestsPerDomain",
		"09--E/d": ."externalRequestsPerDomain",
		"10--D/d": ."externalRequestsDisconnectMatchesPerDomain",
		"11--I/A": ."internalRequestsRatio",
		"12--E/A": ."externalRequestsRatio",
		"13--D/A": ."externalRequestsDisconnectMatchesRatio",
		"14--D/E": ."externalRequestsDisconnectMatchesPerExternalRequests",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedUrlCounts'" >"datasets.non-failed.requests.counts.json"

<"datasets.non-failed.requests.counts.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.requests.counts.sorted.json"

<"datasets.non-failed.requests.counts.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.requests.counts.sorted.tsv"
