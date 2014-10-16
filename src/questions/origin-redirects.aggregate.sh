#!/usr/bin/env bash
set -e

read -d '' getOriginWithRedirectsAggregate <<-'EOF' || true
def boolToInt:
	if . == true then
		1
	elif . == false then
		0
	else
		null
	end;

def deepAdd(item):
	item as $item
	| with_entries(
		($item[.key]) as $other
		| if (.value | type) == "number" and ($other | type) == "number" then
			.value += $other
		else
			.value |= deepAdd($other)
		end
	);

def deepRatio(denominator):
	denominator as $denominator
	| with_entries(
		if (.value | type) == "number" then
			.value /= $denominator
		else
			.value |= deepRatio($denominator)
		end
	);

# TODO: avoid having to explicitly list these classification properties?
def countsBase:
	{
		isSameDomain: 0,
		isSubdomain: 0,
		isSuperdomain: 0,
		isSamePrimaryDomain: 0,
		isInternalDomain: 0,
		isExternalDomain: 0,
		isSecure: 0,
		isInsecure: 0,
		hasMissingClassification: 0,
	};

def addRatio(count; coverage):
	count as $count
	| coverage as $coverage
	| {
		values: .,
		"per-redirect-request-ratio": deepRatio($count),
		"per-domain-with-redirect-coverage": deepRatio($coverage),
	};

reduce .[] as $item (
	{
		domainCount: 0,
		nonFailedDomainCount: 0,
		domainWithRedirectCount: 0,
		redirectCount: 0,
		counts: countsBase,
		coverage: (
			countsBase +
			{
				mixedInternalAndExternal: 0,
				mixedSecurity: 0,
				finalIsSecure: 0,
			}
		),
		all: countsBase
	};
	.domainCount += 1
	| .nonFailedDomainCount += ($item.isNonFailedDomain | boolToInt)
	| if ($item.count > 0) then
		.domainWithRedirectCount += 1
		| .redirectCount += $item.count
		| .counts |= deepAdd($item.counts)
		| .coverage |= deepAdd($item.coverage)
		| .all |= deepAdd($item.all)
	else
		.
	end
)
| . as $aggregated
| .counts |= addRatio($aggregated.redirectCount; $aggregated.domainWithRedirectCount)
| .coverage |= addRatio($aggregated.redirectCount; $aggregated.domainWithRedirectCount)
| .all |= addRatio($aggregated.redirectCount; $aggregated.domainWithRedirectCount)
EOF

jq --slurp "$getOriginWithRedirectsAggregate"
