#!/usr/bin/env bash
set -e

ratioBucketsAggregateJson="ratio-buckets.aggregate.json"

read -d '' getOriginRedirectAggregates <<-'EOF' || true
{
	path: $path,
	domainCount,
	nonFailedDomainCount,
	requestCount,
	# Lowercase to allow simple file name generation.
	"is-same-domain": .ratios.isSameDomain.normalized.cumulative,
	"is-subdomain": .ratios.isSubdomain.normalized.cumulative,
	"is-superdomain": .ratios.isSuperdomain.normalized.cumulative,
	"is-same-primary-domain": .ratios.isSamePrimaryDomain.normalized.cumulative,
	"is-internal-domain": .ratios.isInternalDomain.normalized.cumulative,
	"is-external-domain": .ratios.isExternalDomain.normalized.cumulative,
	"is-insecure": .ratios.isInsecure.normalized.cumulative,
	"is-secure": .ratios.isSecure.normalized.cumulative,
}
EOF

read -d '' selectBucket <<-'EOF' || true
{
	path,
	bucketValues: .[$bucketName]
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	bucketValues
}
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
def padToThreeDigits:
	(("000" + (. | tostring)) | .[-3:]);

def padToTwoDecimals:
	tostring
	| split(".")
	| .[0] |= (
		(. // "")
		| ltrimstr("00")
		| ltrimstr("0")
		| if length == 0 then
			"0"
		else
			.
		end
	)
	| .[1] |= (
		(. // "")
		| (. + "00")
		| .[0:2]
	)
	| join(".");

def getColumnName(columnNumber; bucketIndex):
	columnNumber as $columnNumber
	| bucketIndex as $bucketIndex
	| ($columnNumber | padToThreeDigits) as $prefix
	| ($bucketIndex | tonumber | (. / 100) | padToTwoDecimals) as $suffix
	| ($prefix + "--" + $suffix);

map(
	.bucketValues as $bucketValues
	| {
		"001--Dataset": .dataset,
		# "002--Domains": .nonFailedDomainCount,
		# "003--Requests": .requestCount,
	}
	+ (
		# 101 buckets because it's [0,100].
		reduce range(0; 101) as $bucketIndex (
			{
				values: {},
				columnNumber: 2,
			};
			.values[getColumnName(.columnNumber; $bucketIndex)] = $bucketValues[$bucketIndex]
			| .columnNumber += 1
		)
		| .values
	)
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.dataset)
EOF

splitIntoFilePerBucket() {
	local bucketName="$1"

	<"datasets.non-failed.ratio-buckets.normalized.cumulative.json" jq --arg "bucketName" "$bucketName" "$selectBucket" >"datasets.non-failed.ratio-buckets.$bucketName.normalized.cumulative.json"

	<"datasets.non-failed.ratio-buckets.$bucketName.normalized.cumulative.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$sortObjects" >"datasets.non-failed.ratio-buckets.$bucketName.normalized.cumulative.sorted.json"

	<"datasets.non-failed.ratio-buckets.$bucketName.normalized.cumulative.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.non-failed.ratio-buckets.$bucketName.normalized.cumulative.sorted.tsv"

}

splitIntoFilesPerBucket() {
	for bucketName in "$@";
	do
		splitIntoFilePerBucket "$bucketName"
	done
}

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$ratioBucketsAggregateJson" '&&' cat "$ratioBucketsAggregateJson" '|' jq --arg path '"$PWD"' "'$getOriginRedirectAggregates'" >"datasets.non-failed.ratio-buckets.normalized.cumulative.json"

splitIntoFilesPerBucket "is-secure"
