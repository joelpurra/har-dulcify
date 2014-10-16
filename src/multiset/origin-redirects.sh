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
	redirectCount,
	"redirects-per-domain": (.redirectCount / .domainWithRedirectCount),
	isSameDomain,
	isSubdomain,
	isSuperdomain,
	isSamePrimaryDomain,
	isInternalDomain,
	isExternalDomain,
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
		"03--With R": .domainWithRedirectCount,
		# "xxxxxxx--Redirects": .redirectCount,
		"04--R/dwr": ."redirects-per-domain",
		# "xxxxxxx--isSameDomain": .isSameDomain,
		# "xxxxxxx--isSubdomain": .isSubdomain,
		# "xxxxxxx--isSuperdomain": .isSuperdomain,
		# "xxxxxxx--isSamePrimaryDomain": .isSamePrimaryDomain,
		"05--I": .isInternalDomain,
		"06--E": .isExternalDomain,
		"07--Mix I+E": .mixedInternalAndExternal,
		"08--Insec": .isInsecure,
		"09--Sec": .isSecure,
		"10--Mix sec": .mixedSecurity,
		"11--Final sec": .finalIsSecure,
		"12--Mism": .hasMissingClassification,
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$originRedirectsAggregateJson" '&&' cat "$originRedirectsAggregateJson" '|' jq --arg path '"$PWD"' "'$getOriginRedirectAggregates'" >"datasets.non-failed.origin-redirects.coverage.json"

<"datasets.non-failed.origin-redirects.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.origin-redirects.coverage.sorted.json"

<"datasets.non-failed.origin-redirects.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.origin-redirects.coverage.sorted.tsv"
