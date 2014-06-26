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
		isSameDomain: (.domain | isSameDomain($origin.domain)),
		isSubdomain: (.domain | isSubdomain($origin.domain)),
		isSecure: (.protocol | isSecure)
	};

def mangle(origin):
	origin as $origin
	| .url as $urlParts
	| . + {
		classification : $urlParts | classifyUrl($origin)
	};

.origin.url as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle(($origin)))
}
EOF

cat | jq "$classifyExpandedParts"
