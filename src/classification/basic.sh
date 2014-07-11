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
	| {
		# TODO: work on .domain.parts, not .domain.original?
		isSameDomain: (.domain.original | isSameDomain($origin.domain.original)),
		isSubdomain: (.domain.original | isSubdomain($origin.domain.original)),
		isSecure: (.protocol | isSecure)
		# TODO: add isInternal, isExternal since they might be inaccurate to infer later.
	};

# TODO: classify an entire HAR as succesful or not.
# TODO: classify HTTP response status.
# def statusIsSuccesful:
# 	((. >= 200 and . < 300) or (. == 301 or . == 302));
# "is-successful": statusIsSuccesful

def mangle(origin):
	origin as $origin
	| . + {
		classification : .url | classifyUrl($origin)
	};

.origin.url as $origin
| .origin |= mangle($origin)
| .requestedUrls[] |= mangle($origin)
EOF

cat | jq "$classifyExpandedParts"
