#!/usr/bin/env bash
set -e

# Calculate differences in failed versus non-failed downloads in subsequent datasets where failed domains have been retried.
#
# USAGE:
# 	"$0" <folder(s)>
#
# Each folder must contain the file "$aggregatesAnalysisJson".
#
# OUTPUT:
# 	"datasets.retries.json"			Retry counts and coverage.
# 	"datasets.retries.rates.json"	Rates and rate of change calculated.
# 	"datasets.retries.rates.tsv"	TSV version.

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getRetriesCountsQueries <<-'EOF' || true
{
	path: $path,
	domains: {
		counts: {
			all: .unfiltered.origin.counts.count,
			successful: .unfiltered.origin.counts.classification."is-successful-request",
			unsuccessful: .unfiltered.origin.counts.classification."is-unsuccessful-request",
			failed: .unfiltered.origin.counts.classification."is-failed-request",
			"non-failed": .successfulOrigin.origin.counts.count
		},
		coverage: {
			successful: .unfiltered.origin.coverage.classification."is-successful-request",
			unsuccessful: .unfiltered.origin.coverage.classification."is-unsuccessful-request",
			failed: .unfiltered.origin.coverage.classification."is-failed-request",
		}
	}
}
| .domains.coverage += {
	all: 1,
	"non-failed": (.domains.counts."non-failed" / .domains.counts.all)
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-1:][0]),
	domains: .domains.counts.all,
	successful: .domains.counts.successful,
	unsuccessful: .domains.counts.unsuccessful,
	"non-failed": .domains.counts."non-failed",
	failed: .domains.counts.failed,
	"success-rate": .domains.coverage.successful,
	"unsuccess-rate": .domains.coverage.unsuccessful,
	"non-failure-rate": .domains.coverage."non-failed",
	"failure-rate": .domains.coverage.failed,
}
EOF

# The change rate is only useful if used on subsequent download retries of the same domain list/dataset.
read -d '' calculateRate <<-'EOF' || true
def rateOfChange(previous; current):
	previous as $previous
	| current as $current
	| ($current - $previous) as $delta
	| ($delta/$previous);

sort_by(.dataset)
| .[0].rateOfChange = "-"
| reduce .[1:][] as $item (
	[
		.[0]
	];
	. as $current
	| $current[-1:][0]."failure-rate" as $prevRate
	| $current
	+ [
		$item
		+ {
			rateOfChange: (
				if $prevRate == 0 then
					"-"
				else
					rateOfChange($prevRate; $item."failure-rate")
				end
			)
		}
	]
)
EOF

read -d '' renameForTsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": .domains,
		"03--Successful": .successful,
		"04--Unsuccessful": .unsuccessful,
		"05--Non-failed": ."non-failed",
		"06--Failed": .failed,
		"07--Success rate": ."success-rate",
		"08--Unsuccess rate": ."unsuccess-rate",
		"09--Non-failure rate": ."non-failure-rate",
		"10--Failure rate": ."failure-rate",
		"11--Rate of change": .rateOfChange
	}
)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getRetriesCountsQueries'" >"datasets.retries.json"

<"datasets.retries.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$calculateRate" >"datasets.retries.rates.json"

<"datasets.retries.rates.json" jq "$renameForTsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-tsv.sh" | "${BASH_SOURCE%/*}/../util/clean-tsv-sorted-header.sh" >"datasets.retries.rates.tsv"
