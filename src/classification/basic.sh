#!/usr/bin/env bash
set -e

read -d '' classifyExpandedParts <<-'EOF' || true
def isSameDomain(domain):
	domain as $domain
	| . == $domain;

def isSubdomain(domain):
	domain as $domain
	| endswith("." + $domain);

def isSecure:
	. == "https";

def classifyUrl(origin):
	origin as $origin
	# TODO: work on .domain.components, not .domain.value?
	| (if (.domain.value and $origin.domain.value) then (.domain.value | isSameDomain($origin.domain.value)) else false end) as $isSameDomain
	| (if (.domain.value and $origin.domain.value) then (.domain.value | isSubdomain($origin.domain.value)) else false end) as $isSubdomain
	| {
		isSameDomain: $isSameDomain,
		isSubdomain: $isSubdomain,
		isInternalDomain: ($isSameDomain or $isSubdomain),
		isExternalDomain: (($isSameDomain or $isSubdomain) | not),
		isSecure: (if (.scheme and .scheme.valid and .scheme.value) then (.scheme.value | isSecure) else false end)
	};

def statusIsSuccessful:
	type == "object"
	and
	(
		.code
		| (
			type == "number"
			and
			(
				(. >= 200 and . < 300)
				or
				(. == 304)
			)
		)
	);

def statusIsUnsuccessful:
	type == "object"
	and
	(
		.code
		| (
			type == "number"
			and
			(
				(. >= 100 and . < 200)
				or
				(. >= 300 and . < 304)
				or
				(. >= 305 and . < 600)
			)
		)
	);

def statusIsFailed:
	type != "object"
	or
	(
		.code
		| (
			type != "number"
			or
			(
				(. < 100)
				or
				(. >= 600)
			)
		)
	);

def classifyStatus:
	{
		isSuccessful: statusIsSuccessful,
		isUnsuccessful: statusIsUnsuccessful,
		# TODO: distinguish between software and network/external errors?
		# Would require checking the HAR data for .log.creator.name == "heedless"?
		isFailed: statusIsFailed
	};

def classify(origin):
	origin as $origin
	| {}
	+
	(.url | classifyUrl($origin))
	+
	(.status | classifyStatus);

def mangle(origin):
	origin as $origin
	| . + {
		classification: classify($origin)
	};

.origin.url as $origin
| .origin |= mangle($origin)
| .requestedUrls |= map(mangle($origin))
EOF

cat | jq "$classifyExpandedParts"
