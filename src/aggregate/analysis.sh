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

def unlessNullFallback(f; fallback):
	if type != "null" then
		f
	else
		fallback
	end;

def unlessNull(f):
	unlessNullFallback(f; .);

def nullFallback(fallback):
	if type != "null" then
		.
	else
		fallback
	end;	

def nullFalllbackEmptyObject:
	nullFallback({});

def mangleUrl:
	{
		domains: .domain.value | keyCounterObjectTopOneHundred | keyCounterObjectMinimumTwo | nullFalllbackEmptyObject | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject,
		"public-suffixes": .domain."public-suffixes" | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject,
		"primary-domain": .domain."primary-domain" | keyCounterObjectTopOneHundred | keyCounterObjectMinimumTwo | nullFalllbackEmptyObject | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject,
	};

def mangleBlocks:
	{
		disconnect: (.blocks.disconnect | {
					domains: .domains | keyCounterObjectTopOneHundred | nullFalllbackEmptyObject,
					organizations: .organizations | keyCounterObjectTopOneHundred | nullFalllbackEmptyObject,
					categories: .categories | keyCounterObjectTopOneHundred | nullFalllbackEmptyObject,
				})
	};

def coverageKeyCounterObject(countDistinct):
	countDistinct as $countDistinct
	| unlessNullFallback(
		operateOnValues(
			. / $countDistinct)
			| unlessNullFallback(
				keyCounterObjectSortByValueDesc;
				{}
		);
		{}
	);

def coverageUrl(countDistinct):
	countDistinct as $countDistinct
	| .domains |= coverageKeyCounterObject($countDistinct)
	| ."public-suffixes" |= coverageKeyCounterObject($countDistinct)
	| ."primary-domain" |= coverageKeyCounterObject($countDistinct);

def coverage:
	.countDistinct as $countDistinct
	| {
		"kinds-resource": {
			types: ."kinds-resource".types | coverageKeyCounterObject($countDistinct),
			groups: ."kinds-resource".groups | coverageKeyCounterObject($countDistinct)
		},
		"request-status": {
			codes: ."request-status".codes | coverageKeyCounterObject($countDistinct),
			groups: ."request-status".groups | coverageKeyCounterObject($countDistinct)
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

def mangleShared:
	{
		counts: {
			"kinds-resource": {
				types: (."mime-type".types | keyCounterObjectTopOneHundred | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject),
				groups: (."mime-type".groups | keyCounterObjectTopOneHundred | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject)
			},
			"request-status": {
				codes: (.status.codes | keyCounterObjectTopOneHundred | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject),
				groups: (.status.groups | keyCounterObjectTopOneHundred | keyCounterObjectSortByValueDesc | nullFalllbackEmptyObject)
			},
			classification: {
				"is-same-domain": .classification.isSameDomain,
				"is-subdomain": .classification.isSubdomain,
				"is-internal-domain": .classification.isInternalDomain,
				"is-external-domain": .classification.isExternalDomain,
				"is-successful-request": .classification.isSuccessful,
				"is-unsuccessful-request": .classification.isUnsuccessful,
				"is-failed-request": .classification.isFailed,
				"is-secure-request": .classification.isSecure,
				"is-insecure-request": (.countDistinct - .classification.isSecure),
			},
			urls: .url | mangleUrl,
			blocks: mangleBlocks,
			count,
			countDistinct
		}
	}
	| .coverage = (.counts | coverage);

def mangleUrlGroup:
	if . then
		{
			requestedUrls: (.requestedUrls | mangleShared),
			requestedUrlsDistinct: (.requestedUrlsDistinct | mangleShared),
		}
	else
		null
	end;

def mangleGroup:
	if . then
		{
			origin: (.origin | mangleShared),
			unfilteredUrls: (.unfilteredUrls | mangleUrlGroup),
			internalUrls: (.internalUrls | mangleUrlGroup),
			externalUrls: (.externalUrls | mangleUrlGroup),
		}
	else
		null
	end;

.unfiltered |= mangleGroup
| .successfulOrigin |= mangleGroup
EOF

cat | jq "$getAnalysis"
