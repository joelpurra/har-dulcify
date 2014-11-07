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

def keyCounterObjectSortByValueDescOrEmptyObject:
	keyCounterObjectSortByValueDesc
	| nullFalllbackEmptyObject;

def keyCounterObjectMinimumTwoOrEmptyObject:
	keyCounterObjectMinimumTwo
	| nullFalllbackEmptyObject;

def mangleUrl:
	{
		domains: .domain.value | keyCounterObjectSortByValueDescOrEmptyObject,
		"public-suffixes": .domain."public-suffixes" | keyCounterObjectSortByValueDescOrEmptyObject,
		"primary-domain": .domain."primary-domain" | keyCounterObjectSortByValueDescOrEmptyObject,
	};

def mangleBlocks:
	{
		disconnect: (.blocks.disconnect | {
					domains: .domains | keyCounterObjectSortByValueDescOrEmptyObject,
					organizations: .organizations | keyCounterObjectSortByValueDescOrEmptyObject,
					categories: .categories | keyCounterObjectSortByValueDescOrEmptyObject,
				})
	};

def coverageKeyCounterObject(countDistinct):
	countDistinct as $countDistinct
	| unlessNullFallback(
		operateOnValues(
			. / $countDistinct
		)
		| nullFalllbackEmptyObject
		| keyCounterObjectSortByValueDescOrEmptyObject;
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
				types: (."mime-type".types | keyCounterObjectSortByValueDescOrEmptyObject),
				groups: (."mime-type".groups | keyCounterObjectSortByValueDescOrEmptyObject)
			},
			"request-status": {
				codes: (.status.codes | keyCounterObjectSortByValueDescOrEmptyObject),
				groups: (.status.groups | keyCounterObjectSortByValueDescOrEmptyObject)
			},
			classification: {
				"is-same-domain": .classification.isSameDomain,
				"is-subdomain": .classification.isSubdomain,
				"is-superdomain": .classification.isSuperdomain,
				"is-same-primary-domain": .classification.isSamePrimaryDomain,
				"is-internal-domain": .classification.isInternalDomain,
				"is-external-domain": .classification.isExternalDomain,
				"is-successful-request": .classification.isSuccessful,
				"is-unsuccessful-request": .classification.isUnsuccessful,
				"is-failed-request": .classification.isFailed,
				"is-secure-request": .classification.isSecure,
				"is-insecure-request": .classification.isInsecure,
			},
			urls: .url | mangleUrl,
			blocks: mangleBlocks,
			count,
			countDistinct
		}
	};

def mangleSharedAddCoverage:
	.coverage = (.counts | coverage);

def mangleUrlGroup:
	if . then
		{
			requestedUrls: (.requestedUrls | mangleShared | mangleSharedAddCoverage),
			requestedUrlsDistinct: (.requestedUrlsDistinct | mangleShared | mangleSharedAddCoverage),
		}
	else
		null
	end;

def mangleGroup:
	if . then
		{
			origin: (
				.origin
				| mangleShared
				# Don't keep full lists of input domains.
				| .counts.urls |= (
					.domains |= (keyCounterObjectMinimumTwoOrEmptyObject | keyCounterObjectSortByValueDescOrEmptyObject)
					| ."primary-domain" |= (keyCounterObjectMinimumTwoOrEmptyObject | keyCounterObjectSortByValueDescOrEmptyObject)
				)
				| mangleSharedAddCoverage
			),
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
