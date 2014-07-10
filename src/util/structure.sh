#!/usr/bin/env bash
set -e

read -d '' getStructure <<-'EOF' || true
def safeLookupValue:
	if type != "string" then
		tostring
	else
		.
	end;

def arrayToLookup:
	map(safeLookupValue)
	| reduce .[] as $exists (
		{};
		. + {
			($exists): null
		}
	);

def lookup(value):
	(value | safeLookupValue) as $value
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

def isNumeric:
	("0123456789" | explode | arrayToLookup) as $digits
	| isWhitelisted($digits);

def isAlpha:
	("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" | explode | arrayToLookup) as $letters
	| isWhitelisted($letters);

def isAlphanumeric:
	("0123456789" | explode | arrayToLookup) as $digits
	| ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" | explode | arrayToLookup) as $letters
	| ("_" | explode | arrayToLookup) as $special
	| ($digits + $letters + $special) as $alphanumeric
	| isWhitelisted($alphanumeric);

def isValidJsonShorthandPropertyName:
	(.[0:1] | isAlpha | not) or (isAlphanumeric | not);

[
	path(..)
	| map(
		if type == "number" then
			"[]"
		else
			tostring
			| if isValidJsonShorthandPropertyName then
				"[\\"\\(.)\\"]"
			else
				.
			end
		end
	)
	| join(".")
	| split("." + "[")
	| join("[")
]
| unique
| map("." + .)
| .[]
EOF

cat | jq --raw-output "$getStructure"
