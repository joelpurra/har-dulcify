#!/usr/bin/env bash
set -e

read -d '' getRatioBucketAggregateAnalysis <<-'EOF' || true
def averageIndices:
	. as $array
	| reduce range(0; length) as $index(
		[];
		. + [
			{
				index: $index,
				value: $array[$index]
			}
		]
	)
	| map(
		.diff = (
			.value - 0.5
			| if . < 0 then . * -1 else . end
		)
	)
	| (map(.diff) | min) as $min
	| map(select(.diff == $min))
	| map(.index);

def averageIndexMinimum:
	0 as $min
	| .[$min];

def averageIndexMiddle:
	(((length - 1) / 2) | floor) as $mid
	| .[$mid];

def averageIndexMaximum:
	(length - 1) as $max
	| .[$max];

def getAverageIndiceRange:
	averageIndices
	| {
		minimum: averageIndexMinimum,
		middle: averageIndexMiddle,
		maximum: averageIndexMaximum,
	};

def getAverageIndiceRanges:
	with_entries(
		.value.analysis = {}
		| .value.analysis.index = {}
		| .value.analysis.index.average = (.value.normalized.cumulative | getAverageIndiceRange)
	);

.ratios |= getAverageIndiceRanges
| .occurrences |=  getAverageIndiceRanges
EOF

jq "$getRatioBucketAggregateAnalysis"
