#!/usr/bin/env bash
set -e

originRedirectsAggregateJson="origin-redirects.aggregate.json"

read -d '' getOriginRedirectAggregates <<-'EOF' || true
{
	path: $path,
	domainCount,
	nonFailedDomainCount,
	domainWithRedirectCount,
	redirectCount,
	isSameDomain: .all."per-domain-with-redirect-coverage".isSameDomain,
	isSubdomain: .all."per-domain-with-redirect-coverage".isSubdomain,
	isSuperdomain: .all."per-domain-with-redirect-coverage".isSuperdomain,
	isSamePrimaryDomain: .all."per-domain-with-redirect-coverage".isSamePrimaryDomain,
	isInternalDomain: .all."per-domain-with-redirect-coverage".isInternalDomain,
	isExternalDomain: .all."per-domain-with-redirect-coverage".isExternalDomain,
	isDisconnectMatch: .all."per-domain-with-redirect-coverage".isDisconnectMatch,
	isNotDisconnectMatch: .all."per-domain-with-redirect-coverage".isNotDisconnectMatch,
	isInsecure: .all."per-domain-with-redirect-coverage".isInsecure,
	isSecure: .all."per-domain-with-redirect-coverage".isSecure,
	hasMissingClassification: .coverage."per-domain-with-redirect-coverage".hasMissingClassification,
	mixedInternalAndExternal: .coverage."per-domain-with-redirect-coverage".mixedInternalAndExternal,
	mixedSecurity: .coverage."per-domain-with-redirect-coverage".mixedSecurity,
	finalIsSecure: .coverage."per-domain-with-redirect-coverage".finalIsSecure,
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	domainCount,
	nonFailedDomainCount,
	domainWithRedirectCount,
	"domains-with-redirect-ratio": (.domainWithRedirectCount / .nonFailedDomainCount),
	redirectCount,
	"redirects-per-domain": (.redirectCount / .domainWithRedirectCount),
	isSameDomain,
	isSubdomain,
	isSuperdomain,
	isSamePrimaryDomain,
	isInternalDomain,
	isExternalDomain,
	isDisconnectMatch,
	isNotDisconnectMatch,
	isInsecure,
	isSecure,
	hasMissingClassification,
	mixedInternalAndExternal,
	mixedSecurity,
	finalIsSecure,
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": .nonFailedDomainCount,
		"03--w/ R": .domainWithRedirectCount,
		"04--DWR/D": ."domains-with-redirect-ratio",
		# "xxxxxxx--Redirects": .redirectCount,
		"05--R/DWR": ."redirects-per-domain",
		# "xxxxxxx--isSameDomain": .isSameDomain,
		# "xxxxxxx--isSubdomain": .isSubdomain,
		# "xxxxxxx--isSuperdomain": .isSuperdomain,
		# "xxxxxxx--isSamePrimaryDomain": .isSamePrimaryDomain,
		"06--I": .isInternalDomain,
		"07--Mix I+E": .mixedInternalAndExternal,
		"08--E": .isExternalDomain,
		# "xxxxxxx--D": .isDisconnectMatch,
		# "xxxxxxx--NotD": .isNotDisconnectMatch,
		"09--Insec": .isInsecure,
		"10--Mix sec": .mixedSecurity,
		"11--Sec": .isSecure,
		"12--Final sec": .finalIsSecure,
		"13--Mism": .hasMissingClassification,
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$originRedirectsAggregateJson" '&&' cat "$originRedirectsAggregateJson" '|' jq --arg path '"$PWD"' "'$getOriginRedirectAggregates'" >"datasets.non-failed.origin-redirects.coverage.json"

<"datasets.non-failed.origin-redirects.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.origin-redirects.coverage.sorted.json"

<"datasets.non-failed.origin-redirects.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.origin-redirects.coverage.sorted.tsv"
