#!/bin/bash
set -e

read -d '' splitUrlToParts <<-'EOF' || true
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
