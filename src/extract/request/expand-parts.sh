#!/usr/bin/env bash
set -e

read -d '' expandParts <<-'EOF' || true
def trim(str):
	str as $str
	| ltrimstr($str) | rtrimstr($str);

def arrayToLookup:
	map(@text)
	| reduce .[] as $exists (
		{};
		. + {
			($exists): null
		}
	);

def lookup(value):
	(value | @text) as $value
	| has($value);

def isWhitelisted(whitelist):
	whitelist as $whitelist
	| explode
	| map(
		. as $charCode
		| $whitelist
		| lookup($charCode)
	)
	| all;

def digitsLookup:
	"0123456789" | explode | arrayToLookup;

def lettersLookup:
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" | explode | arrayToLookup;

def specialAlphanumericLookup:
	"_" | explode | arrayToLookup;

def alphanumericLookup:
	digitsLookup + lettersLookup + specialAlphanumericLookup;

def isNumeric:
	isWhitelisted(digitsLookup);

def isAlpha:
	isWhitelisted(lettersLookup);

def isAlphanumeric:
	isWhitelisted(alphanumericLookup);

def specialDomainCharacterLookup:
	"-." | explode | arrayToLookup;

def isSpecialDomainCharacter:
	isWhitelisted(specialDomainCharacterLookup);

def isFirstDomainCharacter:
	isWhitelisted(digitsLookup + lettersLookup);

def isSubsequentDomainCharacter:
	isWhitelisted(digitsLookup + lettersLookup + specialDomainCharacterLookup);

def isValidDomainNameComponentLookup:
	(.[0:1] | isFirstDomainCharacter) and (.[1:] | isSubsequentDomainCharacter);

def deleteNullKeys:
	with_entries(
		select(
			(.value | type) != "null"
		)
	);

def checkUrlValidity:
	type == "string"
	and
	# Very basic length check.
	length > 0
	and
	(
		index(":") as $firstColon
		| index("/") as $firstSlash
		| index("?") as $firstQuestionMark
		| index("#") as $firstHash
		| (
			($firstColon < $firstSlash)
			and
			((($firstSlash | type) == "null") or (($firstQuestionMark | type) == "null") or ($firstSlash < $firstQuestionMark))
			and
			((($firstQuestionMark | type) == "null") or (($firstHash | type) == "null") or ($firstQuestionMark < $firstHash))
		)
	);

def splitDomainToComponentsArray:
	[] as $fallback
	| if type == "string" then
		split(".") as $domainComponents
		| if length > 0 then
			# Negative range to build the domain from components from the right.
			[ range((($domainComponents | length) * -1); 0) ]
			| map(
				# Assemble the domain, longest domain combination first.
				$domainComponents[.:] | join(".")
			)
		else
			$fallback
		end
	else
		$fallback
	end;

def splitDomainToComponents:
	. as $domain
	| splitDomainToComponentsArray as $domainComponents
	| {
		value: $domain,
		components: $domainComponents,
		tld: $domainComponents[-1:][0],
		valid: ($domainComponents | map(isValidDomainNameComponentLookup) | all)
	};

def getScheme:
	{
		value: null,
		rest: null,
		valid: false
	} as $fallback
	| if type == "string" then
		split(":")
		| if length >= 2 then
			{
				value: .[0],
				rest: (.[1:] | join(":")),
				valid: true
			}
		else
			$fallback
		end
	else
		$fallback
	end;

def isWhitelistedScheme:
	. as $scheme
	| ["http", "https", "ftp"] as $whitelistedSchemes
	| $whitelistedSchemes
	| map(. == $scheme)
	| any;

def removeLeadingSlashSlash:
	"" as $fallback
	| if type == "string" then
		if startswith("//") then
			.[2:]
		else
			.
		end
	else
		$fallback
	end;

def getAuthority:
	{
			value: "",
			valid: false
	} as $fallback
	| if type == "string" then
		split("?")
		| .[0]
		| split("#")
		| .[0]
		| removeLeadingSlashSlash
		| split("/")
		| {
			value: .[0],
			valid: true
		}
	else
		$fallback
	end;

def getPort:
	{
		value: null,
		separator: false,
		valid: false
	} as $fallback
	| if type == "string" then
		split(":")
		| if length == 1 then
			{
				value: null,
				separator: false,
				valid: true
			}
		elif length == 2 then
			.[1]
			| if isNumeric then
				{
					value: (. | tonumber),
					separator: true,
					valid: true
				}
			else
				{
					value: null,
					separator: true,
					valid: false
				}
			end
		else
			$fallback
		end
	else
		$fallback
	end;

def getDomain:
	{
		value: .,
		components: [],
		tld: null,
		valid: false
	} as $fallback
	| if type == "string" then
		split(":")
		| .[0]
		| splitDomainToComponents
	else
		$fallback
	end;

def getAfterAuthority:
	removeLeadingSlashSlash
	| length as $length
	| (
		[
			index("/"),
			index("?"),
			index("#"),
			$length
		]
		| map(select((type != "null") and (. >= 0)))
		| min
		| [., 0]
		| max
	) as $firstAfter
	| .[$firstAfter:$length];

def getPathComponents:
	[] as $fallback
	| if type == "string" then
		split("/")
		| (
			if length > 0 then
				.[1:]
			else
				$fallback
			end
		)
	else
		$fallback
	end;

def getPath:
	{
		value: .,
		components: [],
		valid: false
	} as $fallback
	| if type == "string" then
		split("?")
		| (.[0] // "")
		| split("#")
		| (.[0] // "")
		| {
			value: .,
			components: getPathComponents,
			valid: true
		}
	else
		$fallback
	end;

def getQuerystringComponent:
	{
		key: null,
		value: null,
		separator: false,
		valid: false
	} as $fallback
	| if type == "string" then
		split("=")
		| if length == 1 then
			{
				key: .[0],
				value: null,
				separator: false,
				valid: true
			}
		elif length == 2 then
			if (.[0] | length) > 0 then
				{
					key: .[0],
					value: .[1],
					separator: true,
					valid: true
				}
			else
				{
					key: null,
					value: .[1],
					separator: true,
					valid: false
				}
			end
		else
			$fallback
		end
	else
		$fallback
	end;

def getQuerystringComponents:
	[] as $fallback
	| if type == "string" then
		split("&")
		| map(getQuerystringComponent)
	else
		$fallback
	end;

def getQuery:
	{
		value: null,
		separator: false,
		components: [],
		valid: false
	} as $fallback
	| if type == "string" then
		. as $original
		| split("?")
		| if length <= 1 then
			{
				value: null,
				separator: ($original == "?"),
				components: [],
				valid: true
			}
		elif length >= 2 then
			.[1:]
			# The RFC allows question marks in the query string.
			| join("?")
			| split("#")
			| .[0]
			| if length == 0 then
				{
					value: null,
					separator: true,
					components: [],
					valid: true
				}
			else
				{
					value: .,
					separator: true,
					components: getQuerystringComponents,
					valid: true
				}
			end
		else
			$fallback
		end
	else
		$fallback
	end;

def getFragment:
	{
		value: null,
		separator: false,
		valid: false
	} as $fallback
	| if type == "string" then
		. as $original
		| split("#")
		| if length <= 1 then
			{
				value: null,
				separator: ($original == "#"),
				valid: true
			}
		elif length == 2 then
			{
				value: .[1],
				separator: true,
				valid: true
			}
		else
			$fallback
		end
	else
		$fallback
	end;

def isValidComponent:
	. and .valid == true;

def allComponentsValid:
	map(isValidComponent)
	| all;

def deleteInvalidComponentKey(key):
	key as $key
	| with_entries(
		select(
			.key != $key
			or (
				.key == $key
				and
				(.value | isValidComponent)
			)
		)
	);

def splitUrlToComponents:
	. as $value
	| checkUrlValidity as $validity
	| if ($validity | not) then
		{
			value: $value
		}
	else
		($value | getScheme) as $scheme
		| if ($scheme.valid | not) or ($scheme.value | isWhitelistedScheme | not) then
			{
				value: $value,
				scheme: $scheme
			}
		else
			($scheme.rest | getAuthority) as $authoritySplit
			| ($authoritySplit.value | getDomain) as $domain
			| ($authoritySplit.value | getPort) as $port
			| ($scheme.rest | getAfterAuthority) as $afterAuthority
			| ($afterAuthority | getPath) as $path
			| ($afterAuthority | getQuery) as $query
			| ($afterAuthority | getFragment) as $fragment
			| {
				value: $value,
				scheme: $scheme,
				domain: $domain,
				port: $port,
				path: $path,
				query: $query,
				fragment: $fragment
			}
		end
	end
	| {
		value: .value,
		valid: ([.scheme, .domain, .port, .path, .query, .fragment] | allComponentsValid),
		scheme: (.scheme | del(.rest)),
		domain: .domain,
		port: .port,
		path: .path,
		query: .query,
		fragment: .fragment
	}
	| deleteInvalidComponentKey("scheme")
	| deleteInvalidComponentKey("domain")
	| deleteInvalidComponentKey("port")
	| deleteInvalidComponentKey("path")
	| deleteInvalidComponentKey("query")
	| deleteInvalidComponentKey("fragment")
	| deleteNullKeys;

# http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.17
# http://www.w3.org/Protocols/rfc1341/4_Content-Type.html
def mimeParameter(name):
	name as $name
	| map(
		trim(" ") | split("=") as $parameterParts
		| select(length == 2 and $parameterParts[0] == $name) | $parameterParts[1] | trim("\\"")
		)
	| .[0];

def mimeTypeGrouping:
	{
		"application/javascript": "script",
		"application/x-javascript": "script",
		"text/javascript": "script",
		"text/x-js": "script",

		"application/font-woff": "font",
		"application/x-woff": "font",
		"application/x-font-ttf": "font",
		"application/x-font-otf": "font",
		"font/ttf": "font",
		"font/opentype": "font",
		"font/woff": "font",

		"application/json": "data",
		"application/octet-stream": "data",
		"binary/octet-stream": "data",
		"application/xml": "data",
		"text/xml": "data",

		"image/gif": "image",
		"image/jpeg": "image",
		"image/jpg": "image",
		"image/pjpeg": "image",
		"image/png": "image",
		"image/x-png": "image",
		"image/bmp": "image",
		"image/svg+xml": "image",

		"text/html": "html",
		"application/xhtml+xml": "html",

		"text/css": "style",
		"text/plain": "text",

		"application/pdf": "document",

		"application/x-shockwave-flash": "object",
	} as $typeLookup
	| $typeLookup[.];

def splitMime:
	(split(";") | map(trim(" "))) as $mimeParts
	| if (($mimeParts | length) | (. != 1 and . != 2)) then
		{
			original: .
		}
	else
		{
			original: .,
			type: $mimeParts[0],
			charset: $mimeParts[1:] | mimeParameter("charset"),
			group: (if $mimeParts[0] then ($mimeParts[0] | mimeTypeGrouping) else null end)
		}
	end
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
	(.url | splitUrlToComponents) as $urlParts
	| {
		url: $urlParts,
		status: (.status | expandStatus),
		"mime-type": (if ."mime-type" then (."mime-type" | splitMime) else null end),
		referer: (if .referer then (.referer | splitUrlToComponents) else null end),
		redirect: (if .redirect then (.redirect | splitUrlToComponents) else null end)
	}
	| deleteNullKeys;

{
	origin: .origin | mangle,
	requestedUrls: .requestedUrls | map(mangle)
}
EOF

cat | jq "$expandParts"
