#!/usr/bin/env bash
set -e

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getNonFailedClassificationDomainScope <<-'EOF' || true
{
	path: $path,
	"non-failed-domains": .successfulOrigin.origin.counts.count,
	"is-same-domain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-same-domain",
	"is-subdomain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-subdomain",
	"is-superdomain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-superdomain",
	"is-same-primary-domain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-same-primary-domain",
	"is-internal-domain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-internal-domain",
	"is-external-domain": .successfulOrigin.unfilteredUrls.requestedUrlsDistinct.coverage.classification."is-external-domain",
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	"non-failed-domains",
	requests,
	"is-same-domain",
	"is-subdomain",
	"is-superdomain",
	"is-same-primary-domain",
	"is-internal-domain",
	"is-external-domain",
	"is-mixed-domain": (1 - ."is-internal-domain" - ."is-external-domain"),
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": ."non-failed-domains",
		"03--Same domain": ."is-same-domain",
		"04--Subdomain": ."is-subdomain",
		"05--Superdomain": ."is-superdomain",
		"06--Same primary": ."is-same-primary-domain",
		"07--Internal": ."is-internal-domain",
		"08--Mixed": ."is-mixed-domain",
		"09--External": ."is-external-domain",
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getNonFailedClassificationDomainScope'" >"datasets.non-failed.classification.domain-scope.coverage.json"

<"datasets.non-failed.classification.domain-scope.coverage.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.classification.domain-scope.coverage.sorted.json"

<"datasets.non-failed.classification.domain-scope.coverage.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.classification.domain-scope.coverage.sorted.tsv"
