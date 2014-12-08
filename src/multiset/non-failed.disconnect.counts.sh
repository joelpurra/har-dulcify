#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"
disconnectAnalysisFile="prepared.disconnect.services.analysis.json"

read -d '' getNonFailedDisconnectCount <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,

	disconnectRequests: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.domains | add),

	disconnectDomainCount: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.domains | length),
	disconnectOrganizationCount: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.organizations | length),
	disconnectCategoryCount: (.successfulOrigin.externalUrls.requestedUrls.counts.blocks.disconnect.categories | length),

	disconnectTotalDomainCount: $disconnectAnalysis.distinct.domains,
	disconnectTotalOrganizationCount: $disconnectAnalysis.distinct.organizations,
	disconnectTotalCategoriesCount: $disconnectAnalysis.distinct.categories,
}
EOF

read -d '' mapData <<-'EOF' || true
(.disconnectRequests / ."non-failed-domains") as $disconnectRequestsPerDomain
| {
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",

	disconnectRequests,
	disconnectDomainCount,
	disconnectOrganizationCount,
	disconnectCategoryCount,

	# disconnectDomainCountPerDisconnectOrganizationCount: (.disconnectDomainCount / .disconnectOrganizationCount),

	disconnectDomainCountOfTotal: (.disconnectDomainCount / .disconnectTotalDomainCount),
	disconnectOrganizationCountOfTotal: (.disconnectOrganizationCount / .disconnectTotalOrganizationCount),
	# disconnectCategoriesCountOfTotal: (.disconnectCategoryCount / .disconnectTotalCategoriesCount),

	disconnectRequestsPerDomain: $disconnectRequestsPerDomain,
	# disconnectRequestsPerDomainAndDisconnectDomainCount: ($disconnectRequestsPerDomain / .disconnectDomainCount),
	disconnectRequestsPerDomainAndDisconnectOrganizationCount: ($disconnectRequestsPerDomain / .disconnectOrganizationCount),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",

		"03--D Requests": .disconnectRequests,
		"04--D Domains": .disconnectDomainCount,
		"05--D Orgs": .disconnectOrganizationCount,
		"06--D Cats": .disconnectCategoryCount,

		"07--DR/d": .disconnectRequestsPerDomain,
		# "xx--(DR/d)/DD": .disconnectRequestsPerDomainAndDisconnectDomainCount,
		"08--(DR/d)/DO": .disconnectRequestsPerDomainAndDisconnectOrganizationCount,

		# "xx--DD/DO": .disconnectDomainCountPerDisconnectOrganizationCount,
		"09--DD/T": .disconnectDomainCountOfTotal,
		"10--DO/T": .disconnectOrganizationCountOfTotal,
		# "xx--DC/T": .disconnectCategoriesCountOfTotal,
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' --argfile "disconnectAnalysis" "$disconnectAnalysisFile" "'$getNonFailedDisconnectCount'" >"datasets.non-failed.disconnect.counts.json"

<"datasets.non-failed.disconnect.counts.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.disconnect.counts.sorted.json"

<"datasets.non-failed.disconnect.counts.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.disconnect.counts.sorted.tsv"
