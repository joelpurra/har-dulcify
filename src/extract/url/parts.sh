#!/bin/bash
set -e

read -d '' splitUrlToParts <<-'EOF' || true
def splitUrlToParts:
	split("://") as $protocolParts
	| {
		url: .,
		protocol: $protocolParts[0],
		domain: ($protocolParts[1] | split("/")[0])
	};

[
	.[]
	| if (. | type) == "string" then
		splitUrlToParts
	else
		empty
	end
]
EOF

cat | jq "$splitUrlToParts"
