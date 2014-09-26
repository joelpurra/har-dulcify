#!/usr/bin/env bash
set -e

read -d '' classifyExpandedParts <<-'EOF' || true
def isSameDomain(domain):
	domain as $domain
	| . == $domain;

# TODO: compare subdomain with Public Suffix List for verification?
def isSubdomain(domain):
	domain as $domain
	| endswith("." + $domain);

# TODO: compare superdomain with Public Suffix List for verification?
def isSuperdomain(domain):
	. as $original
	| domain as $domain
	| $domain
	| isSubdomain($original);

def isSamePrimaryDomain(originDomain):
	originDomain as $originDomain
	| ."primary-domain" == $originDomain."primary-domain";

def isSecure:
	. == "https";

def classifyUrl(origin):
	origin as $origin
	# TODO: work on .domain.components, not .domain.value?
	| (.domain.value and $origin.domain.value) as $hasDomainValue
	| (if $hasDomainValue then (.domain.value | isSameDomain($origin.domain.value)) else false end) as $isSameDomain
	| (if $hasDomainValue then (.domain.value | isSubdomain($origin.domain.value)) else false end) as $isSubdomain
	| (if $hasDomainValue then (.domain.value | isSuperdomain($origin.domain.value)) else false end) as $isSuperdomain
	| (if $hasDomainValue then (.domain | isSamePrimaryDomain($origin.domain)) else false end) as $isSamePrimaryDomain
	| ($isSameDomain or $isSubdomain or $isSuperdomain or $isSamePrimaryDomain) as $isInternalDomain
	| (if (.scheme and .scheme.valid and .scheme.value) then (.scheme.value | isSecure) else false end) as $isSecure
	| {
		isSameDomain: $isSameDomain,
		isSubdomain: $isSubdomain,
		isSuperdomain: $isSuperdomain,
		isSamePrimaryDomain: $isSamePrimaryDomain,
		isInternalDomain: $isInternalDomain,
		isExternalDomain: ($isInternalDomain | not),
		isSecure: $isSecure,
		isInsecure: ($isSecure | not)
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
