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
# 	"datasets.retries.rates.csv"	CSV version.

aggregatesAnalysisJson="aggregates.analysis.json"

read -d '' getRetriesCountsQueries <<-'EOF' || true
{
	path: $path,
	domains: {
		counts: {
			all: .unfiltered.origin.counts.count,
			failed: .unfiltered.origin.counts.classification."is-failed-request",
			"not-failed": .successfulOrigin.origin.counts.count
		}
	}
}
| .domains.coverage = {
	all: 1,
	failed: (.domains.counts.failed / .domains.counts.all),
	"not-failed": (.domains.counts."not-failed" / .domains.counts.all)
}
EOF

read -d '' mapData <<-'EOF' || true
{
	dataset: (.path | split("/")[-2:] | join("/")),
	domains: .domains.counts.all,
	failed: .domains.counts.failed,
	rate: .domains.coverage.failed
}
EOF

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
	| $current[-1:][0].rate as $prevRate
	| $current
	+ [
		$item
		+ {
			rateOfChange: (
				if $prevRate == 0 then
					"-"
				else
					rateOfChange($prevRate; $item.rate)
				end
			)
		}
	]
)
EOF

read -d '' renameForCsvColumnOrdering <<-'EOF' || true
map(
	{
		"01--Dataset": .dataset,
		"02--Domains": .domains,
		"03--Failed": .failed,
		"04--Failure Rate": .rate,
		"05--Rate of Change": .rateOfChange
	}
)
EOF

"${BASH_SOURCE%/*}/../util/dataset-query.sh" "$@" -- test -e "$aggregatesAnalysisJson" '&&' cat "$aggregatesAnalysisJson" '|' jq --arg path '"$PWD"' "'$getRetriesCountsQueries'" >"datasets.retries.json"

<"datasets.retries.json" jq "$mapData" | "${BASH_SOURCE%/*}/../util/to-array.sh" | jq "$calculateRate" >"datasets.retries.rates.json"

<"datasets.retries.rates.json" jq "$renameForCsvColumnOrdering" | "${BASH_SOURCE%/*}/../util/array-of-objects-to-csv.sh" | "${BASH_SOURCE%/*}/../util/clean-csv-sorted-header.sh" >"datasets.retries.rates.csv"
