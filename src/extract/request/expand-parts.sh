#!/usr/bin/env bash
set -e

read -d '' expandParts <<-'EOF' || true
def splitDomainToPartsArray:
	split(".") as $domainParts
	# Negative range to build the domain from parts from the right.
	| [ range((($domainParts | length) * -1); 0) ]
	| map(
		# Assemble the domain, longest domain combination first.
		$domainParts[.:] | join(".")
	);

def splitDomainToParts:
	. as $domain
	| splitDomainToPartsArray as $domainParts
	| {
		original: $domain,
		parts: $domainParts,
		tld: $domainParts[-1:][0]
	};

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
			domain: ($protocolParts[1] | split("/")[0] | splitDomainToParts)
		}
	end;

def trim(str):
	str as $str
	| ltrimstr($str) | rtrimstr($str);

def deleteNullKeys:
	with_entries(
		select(
			(.value | type) != "null"
		)
	);

# http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.17
# http://www.w3.org/Protocols/rfc1341/4_Content-Type.html
def mimeParameter(name):
	name as $name
	| map(
		trim(" ") | split("=") as $parameterParts
		| select($parameterParts[0] == $name) | $parameterParts[1] | trim("\\"")
		)
	| .[0];

def mimeTypeGrouping:
	{
		"application/javascript": "script",
		"application/x-javascript": "script",
		"text/javascript": "script",

		"application/font-woff": "font",
		"font/ttf": "font",

		"application/json": "data",
		"application/octet-stream": "data",

		"image/gif": "image",
		"image/jpeg": "image",
		"image/png": "image",
		"image/svg+xml": "image",

		"text/css": "style",
		"text/html": "html",
		"text/plain": "text",
	} as $typeLookup
	| $typeLookup[.];

def splitMime:
	(split(";") | map(trim(" "))) as $mimeParts
	| {
		original: .,
		type: $mimeParts[0],
		charset: $mimeParts[1:] | mimeParameter("charset"),
		group: ($mimeParts[0] | mimeTypeGrouping)
	}
	| deleteNullKeys;

def statusGroup:
	if . >= 100 and . < 200 then
		"1xx"
	elif . >= 200 and . < 300 then
		"2xx"
	elif . >= 300 and . < 400 then
		"3xx"
	elif . >= 400 and . < 500 then
		"4xx"
	elif . >= 500 and . < 600 then
		"5xx"
	else
		null
	end;

def expandStatus:
	{
		code: .,
		group: statusGroup
	};

def mangle:
	(.url | splitUrlToParts) as $urlParts
	| {
		url: $urlParts,
		status: (.status | expandStatus),
		"mime-type": (if ."mime-type" then (."mime-type" | splitMime) else null end),
		referer: (if .referer then (.referer | splitUrlToParts) else null end),
		redirect: (if .redirect then (.redirect | splitUrlToParts) else null end)
	}
	| deleteNullKeys;

{
	origin: .origin | mangle,
	requestedUrls: .requestedUrls | map(mangle)
}
EOF

cat | jq "$expandParts"
