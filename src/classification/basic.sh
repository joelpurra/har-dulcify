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
	};

def mangle(origin):
	origin as $origin
	| . + {
		classification : .url | classifyUrl($origin)
	};

.origin.url as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle($origin))
}
EOF

cat | jq "$classifyExpandedParts"
