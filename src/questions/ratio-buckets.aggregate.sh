#!/usr/bin/env bash
set -e

read -d '' getRatioBucketAggregates <<-'EOF' || true
def boolToInt:
	if . == true then
		1
	elif . == false then
		0
	else
		null
	end;

def pow(n):
	. as $x
	| n as $n
	| reduce range(0; $n) as $i (
		1;
		. * $x
	);

def round(decimals):
	. as $x
	| decimals as $decimals
	# Assuming decimal numbers.
	| 10 as $base
	| ($base * pow($decimals)) as $shifter
	| $x * $shifter
	| tostring
	| split(".")
	| .[0]
	| tonumber
	| . / $shifter;

def asPercentageInteger:
	. as $x
	# Assuming decimal numbers.
	| $x * 100
	| tostring
	| split(".")
	| .[0]
	| tonumber;

def counterBucket(count):
	count as $count
	| ($count - 1) as $length
	| []
	| .[$length] = 0
	| map(. + 0);

def counterBucketIncrementBy(index; count):
	index as $index
	| .[$index] += count;

def counterBucketIncrement(index):
	counterBucketIncrementBy(index; 1);

def addCounterBuckets(right):
	. as $left
	| length as $length
	| right as $right
	| reduce range(0; $length) as $index (
		[];
		.[$index] = ($left[$index] + $right[$index])
	);

def cumulativeCounterBucket:
	. as $counterBucket
	| length as $length
	| reduce range(0; $length) as $index (
		{
			counterBucket: [],
			sum: 0,
		};
		.sum += $counterBucket[$index]
		| .counterBucket[$index] = .sum
	)
	| .counterBucket;

def normalizedCounterBucket:
	add as $sum
	| map(. / $sum);

def ratioBucket:
	# 101 buckets because it's [0,100].
	counterBucket(101);

def ratioBucketIncrement(ratio):
	ratio as $ratio
	| ($ratio | asPercentageInteger) as $index
	| counterBucketIncrement($index);

def deepAddToRatioBuckets(item; denominator):
	item as $item
	| denominator as $denominator
	| with_entries(
		($item[.key]) as $other
		| if (.value | type) == "array" and ($other | type) == "number" then
			.value |= ratioBucketIncrement($other / $denominator)
		else
			.value |= deepAddToRatioBuckets($other; $denominator)
		end
	);

def maxBucket(highestCounter):
	highestCounter as $highestCounter
	| counterBucket($highestCounter);

def maxBucketIncrement(count):
	count as $count
	| ([$count, (length - 1)] | min) as $index
	| counterBucketIncrement($index);

def deepMaxBucketIncrement(item):
	item as $item
	| with_entries(
		($item[.key]) as $other
		| if (.value | type) == "array" and ($other | type) == "number" then
			.value |= maxBucketIncrement($other)
		else
			.value |= deepMaxBucketIncrement($other)
		end
	);

# TODO: avoid having to explicitly list these classification properties?
def ratioBucketsBase:
	{
		isSameDomain: ratioBucket,
		isSubdomain: ratioBucket,
		isSuperdomain: ratioBucket,
		isSamePrimaryDomain: ratioBucket,
		isInternalDomain: ratioBucket,
		isExternalDomain: ratioBucket,
		isSecure: ratioBucket,
		isInsecure: ratioBucket,

		isDisconnect: ratioBucket,
	};

def occurrencesBucketsBase:
	{
		# Use 101 to get [0,99] and "above 99".
		disonnectDomains: maxBucket(101),
		disonnectOrganizations: maxBucket(101),
		# Only 5 categories, so 7 buckets 0, 1-5, 5+ (just in case).
		disonnectCategories: maxBucket(7),
	};

def addBucketCumulative:
	{
		values: .,
		cumulative: cumulativeCounterBucket,
	};

def addBucketVariations:
	{
		values: .,
		normalized: normalizedCounterBucket,
	}
	| .values |= addBucketCumulative
	| .normalized |= addBucketCumulative;

def deepAddBucketVariations:
	with_entries(
		.value |= addBucketVariations
	);

reduce .[] as $item (
	{
		domainCount: 0,
		nonFailedDomainCount: 0,
		requestCount: 0,
		ratios: ratioBucketsBase,
		occurrences: occurrencesBucketsBase,
	};
	.domainCount += 1
	| .nonFailedDomainCount += ($item.isNonFailedDomain | boolToInt)
	| if ($item.requestCount > 0) then
		.requestCount += $item.requestCount
		| .ratios |= deepAddToRatioBuckets($item.counts; $item.requestCount)
		| .occurrences |= deepMaxBucketIncrement($item.uniqueCounts)
	else
		.
	end
)
| .ratios |= deepAddBucketVariations
| .occurrences |= deepAddBucketVariations
EOF

jq --slurp "$getRatioBucketAggregates"
