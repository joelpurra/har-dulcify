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

def mangle:
	(.url | splitUrlToParts) as $urlParts
	| {
		url: $urlParts,
		status: .status,
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
