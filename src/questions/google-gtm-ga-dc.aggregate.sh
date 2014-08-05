#!/usr/bin/env bash
set -e

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

jq --slurp "$getGoogleTagManagerCoverage"
