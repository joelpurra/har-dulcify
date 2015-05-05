#!/usr/bin/env bash
set -e

read -d '' mapData <<-'EOF' || true
{
	domain,
	domainAlexaRank,
	primaryDomain,
	primaryDomainAlexaRank,
	highestAlexaRank,
	organizationCount,
}
EOF

read -d '' toBuckets <<-'EOF' || true
# HACK TODO: Don't drop unranked primary domains -- try to look at other domain elements.
# TODO: update the public suffix list?

# def pow(n):
# 	. as $x
# 	| n as $n
# 	| reduce range(0; $n) as $i (
# 		1;
# 		. * $x
# 	);

# def simpleLog(base; maxSteps):
# 	. as $x
# 	| base as $base
# 	| maxSteps as $maxSteps
# 	| reduce range(0; $maxSteps) as $i (
# 		{
# 			x: $x,
# 			base: $base,
# 			exponent: 0,
# 			left: $x
# 		};
# 		if .left >= $base then
# 			.left /= $base
# 			| .exponent += 1
# 		else
# 			.
# 		end
# 	);

# def simpleLogExponent(base; maxSteps):
# 	simpleLog(base; maxSteps)
# 	| .exponent;

# def rankToIndex:
# 	simpleLogExponent(10; 7);

# def indexToBucket:
# 	. as $index
# 	| 10
# 	| pow($index);

def rankToIndex:
	if . < 10 then
		0
	elif . < 100 then
		1
	elif . < 1000 then
		2
	elif . < 10000 then
		3
	elif . < 20000 then
		4
	elif . < 30000 then
		5
	elif . < 40000 then
		6
	elif . < 50000 then
		7
	elif . < 60000 then
		8
	elif . < 70000 then
		9
	elif . < 80000 then
		10
	elif . < 90000 then
		11
	elif . < 100000 then
		12
	elif . < 200000 then
		13
	elif . < 300000 then
		14
	elif . < 400000 then
		15
	elif . < 500000 then
		16
	elif . < 600000 then
		17
	elif . < 700000 then
		18
	elif . < 800000 then
		19
	elif . < 900000 then
		20
	elif . < 1000000 then
		21
	else
		22
	end;

def indexToBucket:
	if . == 0 then
		0
	elif . == 1 then
		10
	elif . == 2 then
		100
	elif . == 3 then
		1000
	elif . == 4 then
		10000
	elif . == 5 then
		20000
	elif . == 6 then
		30000
	elif . == 7 then
		40000
	elif . == 8 then
		50000
	elif . == 9 then
		60000
	elif . == 10 then
		70000
	elif . == 11 then
		80000
	elif . == 12 then
		90000
	elif . == 13 then
		100000
	elif . == 14 then
		200000
	elif . == 15 then
		300000
	elif . == 16 then
		400000
	elif . == 17 then
		500000
	elif . == 18 then
		600000
	elif . == 19 then
		700000
	elif . == 20 then
		800000
	elif . == 21 then
		900000
	else
		1000000
	end;


map(
	select(
		(.primaryDomainAlexaRank | type) != "null"
	)
)
| map({
	rank: .primaryDomainAlexaRank,
	value: .organizationCount,
})
| reduce .[] as $drop (
	reduce range(0; 23) as $index ([]; .[$index] = { bucket: ($index | indexToBucket), drops: [] });
	($drop.rank | rankToIndex) as $index
	| .[$index] |= (.drops += [ $drop ])
)
| map(
	.average = (
		.drops
		| if length > 0 then
			(
				map(.value)
				| add
			)
			/
			length
		else
			0
		end
	)
)
| map(
	{
		rank: .bucket,
		value: .average,
	}
)
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Rank": .rank,
		"02--Value": .value,
	}
)
EOF

read -d '' sortObjects <<-'EOF' || true
sort_by(.rank)
EOF

<"alexa-rank.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$toBuckets" >"alexa-rank.buckets.json"

<"alexa-rank.buckets.json" jq "$sortObjects" >"alexa-rank.buckets.sorted.json"

<"alexa-rank.buckets.sorted.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"alexa-rank.buckets.sorted.tsv"
