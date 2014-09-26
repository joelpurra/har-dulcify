#!/usr/bin/env bash
set -e

read -d '' getOriginWithRedirectsAggregate <<-'EOF' || true
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
		hasMissingClassification: 0,
		isSameDomain: 0,
		isSubdomain: 0,
		isSuperdomain: 0,
		isSamePrimaryDomain: 0,
		isInternalDomain: 0,
		isExternalDomain: 0,
		isSecure: 0,
		isInsecure: 0,
	};

def addRatio(count; coverage):
	count as $count
	| coverage as $coverage
	| {
		values: .,
		"total-ratio": deepRatio($count),
		"coverage-ratio": deepRatio($coverage),
	};

reduce .[] as $item (
	{
		domainCount: 0,
		redirectCount: 0,
		counts: countsBase,
		coverage: (
			countsBase +
			{
				internalAndExternal: 0,
			}
		)
	};
	.domainCount += 1
	| .redirectCount += $item.count
	| .counts |= deepAdd($item.counts)
	| .coverage |= deepAdd($item.coverage)
)
| . as $aggregated
| .counts |= addRatio($aggregated.redirectCount; $aggregated.domainCount)
| .coverage |= addRatio($aggregated.redirectCount; $aggregated.domainCount)
EOF

jq --slurp "$getOriginWithRedirectsAggregate"
