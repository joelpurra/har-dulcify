#!/bin/bash
set -e

read -d '' classifyExpandedParts <<-'EOF' || true
def splitUrlToParts:
	split("://") as $protocolParts
	| if ($protocolParts | length) == 1 then
		{
			original: .
		}
	else
		{
			original: .,
			protocol: $protocolParts[0],
			domain: ($protocolParts[1] | split("/")[0])
		}
	end;

def deleteNullKeys:
	with_entries(
		select(
			(.value | type) != "null"
		)
	);

def classifyUrl(origin):
	origin as $origin
	| {
		isSameDomain: (.domain == $origin.domain),
		isSubdomain: ((.domain // "") | endswith("." + $origin.domain)),
		isSecure: (.protocol == "https")
	};

def mangle(origin):
	origin as $origin
	| .url as $urlParts
	| . + {
		classification : $urlParts | classifyUrl($origin)
	}
	| deleteNullKeys;

.origin.url as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle(($origin)))
}
EOF

cat | jq "$classifyExpandedParts"
