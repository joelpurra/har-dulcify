#!/usr/bin/env bash
set -e

read -d '' getAnalysis <<-'EOF' || true
def keyCounterObjectMinimum(n):
	n as $n
	| with_entries(
		select(.value >= $n)
	);

def keyCounterObjectMinimumTwo:
	keyCounterObjectMinimum(2);

def keyCounterObjectTop(n):
	n as $n
	| to_entries
	| sort_by(.value)
	| reverse
	| .[0:$n]
	| from_entries;

def keyCounterObjectTopTen:
	keyCounterObjectTop(10);

def keyCounterObjectTopOneHundred:
	keyCounterObjectTop(100);

def keyCounterObjectSortByKeyAsc:
	to_entries
	| sort_by(.key)
	| from_entries;

def keyCounterObjectSortByValueDesc:
	to_entries
	| sort_by(.value)
	| reverse
	| from_entries;

def operateOnValues(f):
	with_entries(.value |= f);

def unlessNull(f):
	if . then
		f
	else
		.
	end;

def mangleUrl:
	{
		domains: .domain.original | keyCounterObjectTopOneHundred | (keyCounterObjectMinimumTwo // {}) | keyCounterObjectSortByValueDesc,
		groups: .domain.groups | keyCounterObjectTopTen,
	};

def mangleBlocks:
	{
		disconnect: (.blocks.disconnect | {
					domains: .domains | keyCounterObjectTopOneHundred,
					organizations: .organizations | keyCounterObjectTopOneHundred,
					categories: .categories | keyCounterObjectTopOneHundred,
				})
	};

def coverageKeyCounterObject(countDistinct):
	countDistinct as $countDistinct
	| unlessNull(operateOnValues(. / $countDistinct) | keyCounterObjectSortByValueDesc);

def coverageUrl(countDistinct):
	countDistinct as $countDistinct
	| .domains |= coverageKeyCounterObject($countDistinct)
	| .groups |= coverageKeyCounterObject($countDistinct);

def coverage:
	.countDistinct as $countDistinct
	| {
		"kinds-resource": {
			types: ."kinds-resource".types | coverageKeyCounterObject($countDistinct),
			groups: ."kinds-resource".groups | coverageKeyCounterObject($countDistinct)
		},
		classification: .classification | coverageKeyCounterObject($countDistinct) | keyCounterObjectSortByKeyAsc,
		urls: .urls | coverageUrl($countDistinct),
		blocks: {
			domains: .blocks.disconnect.domains | coverageKeyCounterObject($countDistinct),
			organizations: .blocks.disconnect.organizations | coverageKeyCounterObject($countDistinct),
			categories: .blocks.disconnect.categories | coverageKeyCounterObject($countDistinct)
		},
		count,
		countDistinct
	};

def mangleShared(root):
	root as $root
	| {
		counts: {
			"kinds-resource": {
				types: ."mime-type".types | keyCounterObjectTopTen,
				groups: ."mime-type".groups | keyCounterObjectTopTen
			},
			classification: {
				"is-internal": (.classification.isSameDomain + .classification.isSubdomain),
				"is-external": (.countDistinct - .classification.isSameDomain - .classification.isSubdomain),
				"is-secure": .classification.isSecure,
				"is-insecure": (.countDistinct - .classification.isSecure),
			},
			urls: .url | mangleUrl,
			blocks: mangleBlocks,
			count,
			countDistinct
		}
	}
	| .coverage = (.counts | coverage);

. as $root
| {
	origin: {},
	requestedUrls: {},
	requestedUrlsDistinct: {}
}

| .origin |= (. + ($root.origin | mangleShared($root)))
| .requestedUrls |= (. + ($root.requestedUrls | mangleShared($root)))
| .requestedUrlsDistinct |= (. + ($root.requestedUrlsDistinct | mangleShared($root)))
EOF

cat | jq "$getAnalysis"
