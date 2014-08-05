#!/usr/bin/env bash
set -e

# See if domains with requests to google tag manager also have other google requests, and analytics in particular.
read -d '' getGoogleTagManagerDomainsAndRelatedUrls <<-'EOF' || true
select(
	.requestedUrls[].url.original
	| contains("googletagmanager.com/gtm.js")
)
| {
	origin: .origin.url.domain.original,
	requests: (
		.requestedUrls
		| map(.url.original)
		| map(select(contains("doubleclick") or contains("google")))
	)
}
| .count = (.requests | length)
| .ga = (.requests | map(select(contains("analytics"))) | length)
| .dc = (.requests | map(select(contains("doubleclick"))) | length)
EOF

read -d '' getGoogleTagManagerCoverage <<-'EOF' || true
def over0:
	if . > 0 then
		1
	else
		0
	end;

def over(n):
	(. - n) | over0;

def over1:
	over(1);

reduce .[] as $item
(
	{
		domains: 0,
		requests: 0,
		ga: 0,
		dc: 0,
		coverage: {
			ga: 0,
			dc: 0,
			both: 0
		}
	};
	.domains += 1
	| .requests += $item.count
	| .ga += $item.ga
	| .dc += $item.dc
	| .coverage.ga += ($item.ga | over0)
	| .coverage.dc += ($item.dc | over0)
	| .coverage.both += ((.coverage.ga + .coverage.dc) | over1)
)
EOF

# TODO: don't write to named files from this script.
cat | jq "$getGoogleTagManagerDomainsAndRelatedUrls" > "google-gtm-ga-dc.json"
<"google-gtm-ga-dc.json" jq --slurp "$getGoogleTagManagerCoverage" > "google-gtm-ga-dc.aggregate.json"
