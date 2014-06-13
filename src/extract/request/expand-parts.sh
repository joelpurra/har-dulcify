#!/bin/bash
set -e

read -d '' expandParts <<-'EOF' || true
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

def classifyUrl(origin):
	origin as $origin
	| {
		isSameDomain: (.domain == $origin.domain),
		isSubdomain: ((.domain // "") | endswith("." + $origin.domain)),
		isSecure: (.protocol == "https")
	};

def trim(str):
	str as $str
	| ltrimstr($str) | rtrimstr($str);

def deleteNullKeys:
	with_entries(
		select(
			(.value | type) != "null"
		)
	);

def mimeParameter(name):
	name as $name
	| map(
		trim(" ") | split("=") as $parameterParts
		| select($parameterParts[0] == $name) | $parameterParts[1] | trim("\\"")
		)
	| .[0];

def splitMime:
	split(";") as $mimeParts
	| {
		original: .,
		type: $mimeParts[0] | trim(" "),
		charset: $mimeParts[1:] | mimeParameter("charset")
	}
	| deleteNullKeys;

def mangle(origin):
	origin as $origin
	| (.url | splitUrlToParts) as $urlParts
	| {
		url: $urlParts,
		status: .status,
		"mime-type": (if ."mime-type" then (."mime-type" | splitMime) else null end),
		referer: (if .referer then (.referer | splitUrlToParts) else null end),
		redirect: (if .redirect then (.redirect | splitUrlToParts) else null end)
	}
	| deleteNullKeys;

(.origin.url | splitUrlToParts) as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle(($origin)))
}
EOF

cat | jq "$expandParts"
