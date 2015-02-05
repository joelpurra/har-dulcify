#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedUrlCounts <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	"non-failed-domains-with-internal-requests": .successfulOrigin.internalUrls.requestedUrlsDistinct.counts.countDistinct,
	"non-failed-domains-with-external-requests": .successfulOrigin.externalUrls.requestedUrlsDistinct.counts.countDistinct,
	# TODO: use a proper count instead of primary domain counter object lengths.
	externalDomains: (.successfulOrigin.externalUrls.requestedUrls.counts.urls.domains | length),
	externalPrimaryDomains: (.successfulOrigin.externalUrls.requestedUrls.counts.urls."primary-domain" | length),
	unfilteredRequests: .successfulOrigin.unfilteredUrls.requestedUrls.counts.count,
	internalRequests: .successfulOrigin.internalUrls.requestedUrls.counts.count,
	externalRequests: .successfulOrigin.externalUrls.requestedUrls.counts.count,
	# TODO: use a proper count instead of adding domain counts.
	externalRequestsDisconnectDomains: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.domains | length),
	externalRequestsDisconnectMatches: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.domains | add),
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	"non-failed-domains-with-internal-requests",
	"non-failed-domains-with-external-requests",
	externalDomains,
	externalPrimaryDomains,
	externalRequestsDisconnectDomains,
	externalDisconnectDomainsDiffExternalDomains: (.externalDomains - .externalRequestsDisconnectDomains),
	externalDisconnectDomainsDiffExternalPrimaryDomains: (.externalPrimaryDomains - .externalRequestsDisconnectDomains),
	externalDisconnectDomainsPerExternalDomains: (.externalRequestsDisconnectDomains / .externalDomains),
	externalDisconnectDomainsPerExternalPrimaryDomains: (.externalRequestsDisconnectDomains / .externalPrimaryDomains),
	externalDisconnectDomainsMismatchPerExternalDomains: (1 - (.externalRequestsDisconnectDomains / .externalDomains)),
	externalDisconnectDomainsMismatchPerExternalPrimaryDomains: (1 - (.externalRequestsDisconnectDomains / .externalPrimaryDomains)),
	withInternalRatio: (."non-failed-domains-with-internal-requests" / ."non-failed-domains"),
	withExternalRatio: (."non-failed-domains-with-external-requests" / ."non-failed-domains"),
	unfilteredRequests,
	internalRequests,
	externalRequests,
	externalRequestsDisconnectMatches,
	unfilteredRequestsPerDomain: (.unfilteredRequests / ."non-failed-domains"),
	internalRequestsPerDomain: (.internalRequests / ."non-failed-domains-with-internal-requests"),
	externalRequestsPerDomain: (.externalRequests / ."non-failed-domains-with-external-requests"),
	externalRequestsDisconnectMatchesPerDomain: (.externalRequestsDisconnectMatches / ."non-failed-domains-with-external-requests"),
	internalRequestsRatio: (.internalRequests / .unfilteredRequests),
	externalRequestsRatio: (.externalRequests / .unfilteredRequests),
	externalRequestsDisconnectMatchesRatio: (.externalRequestsDisconnectMatches / .unfilteredRequests),
	internalRequestsPerInternalRequests: (.externalRequests / .internalRequests),
	externalRequestsDisconnectMatchesPerExternalRequests: (.externalRequestsDisconnectMatches / .externalRequests),
}
EOF

read -d '' renameForTsvColumnOrderingCounts <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--w/ int": ."non-failed-domains-with-internal-requests",
		"04--w/ ext": ."non-failed-domains-with-external-requests",
		"05--Ext dom.": .externalDomains,
		"06--Ext prim.": .externalPrimaryDomains,
		"07--Ext D dom.": .externalRequestsDisconnectDomains,
		"08--All requests": .unfilteredRequests,
		"09--Int": .internalRequests,
		"10--Ext": .externalRequests,
		"11--Disco.": .externalRequestsDisconnectMatches,
	}
)
EOF

read -d '' renameForTsvColumnOrderingRatios <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--w/ int": .withInternalRatio,
		"04--w/ ext": .withExternalRatio,
		"05--A/d": .unfilteredRequestsPerDomain,
		"06--I/di": .internalRequestsPerDomain,
		"07--E/de": .externalRequestsPerDomain,
		"08--D/de": .externalRequestsDisconnectMatchesPerDomain,
		"09--I/A": .internalRequestsRatio,
		"10--E/A": .externalRequestsRatio,
		"11--D/A": .externalRequestsDisconnectMatchesRatio,
		"12--E/I": .internalRequestsPerInternalRequests,
		"13--D/E": .externalRequestsDisconnectMatchesPerExternalRequests,
	}
)
EOF

read -d '' renameForTsvColumnOrderingDomainRatios <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--Ext dom.": .externalDomains,
		"04--Prim.": .externalPrimaryDomains,
		"05--D dom.": .externalRequestsDisconnectDomains,
		"06--D diff ext.": .externalDisconnectDomainsDiffExternalDomains,
		"07--D diff prim.": .externalDisconnectDomainsDiffExternalPrimaryDomains,
		"08--D/ext.": .externalDisconnectDomainsPerExternalDomains,
		"09--Prim. det.": .externalDisconnectDomainsPerExternalPrimaryDomains,
		# "1xxx--D/ext.": .externalDisconnectDomainsMismatchPerExternalDomains,
		"10--Undet.": .externalDisconnectDomainsMismatchPerExternalPrimaryDomains,
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedUrlCounts'" >"datasets.non-failed.requests.counts.json"

<"datasets.non-failed.requests.counts.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.requests.counts.sorted.json"

# Two output files.
<"datasets.non-failed.requests.counts.sorted.json" jq "$renameForTsvColumnOrderingCounts" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.requests.counts.sorted.tsv"
<"datasets.non-failed.requests.counts.sorted.json" jq "$renameForTsvColumnOrderingRatios" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.requests.ratios.sorted.tsv"
<"datasets.non-failed.requests.counts.sorted.json" jq "$renameForTsvColumnOrderingDomainRatios" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.domains.ratios.sorted.tsv"
