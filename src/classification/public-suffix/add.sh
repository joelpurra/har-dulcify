#!/usr/bin/env bash
set -e

preparedPublicSuffixFile="$1"

read -d '' addPublicSuffixes <<-'EOF' || true
def deleteNullKey(key):
	# Delete a property if it is null.
	key as $key
	| with_entries(
		select(
			.key != $key
			or (
				.key == $key
				and
				(.value | type) != "null"
			)
		)
	);

def deleteEmptyArrayKey(key):
	# Delete a property if it is an empty array.
	key as $key
	| with_entries(
		select(
			.key != $key
			or (
				.key == $key
				and
				(.value | length) != 0
			)
		)
	);

def matchPublicSuffix:
	# Match the domain to all possible rules/groups/public-suffixes in the public suffix list.
	map(
		# has($subdomain) is more effective than $publicSuffixLookup[.] // empty
		. as $subdomain
		| if $publicSuffixLookup | has($subdomain) then
			$publicSuffixLookup[$subdomain]
		else
			empty
		end
	);

def getPrivatePrefix(publicSuffixes):
	publicSuffixes as $publicSuffixes
	| ($publicSuffixes | length) as $publicSuffixesLength
	| .[0:(length - $publicSuffixesLength)];

def getPrimaryDomain:
	.[-1:][0];

def mangle:
	if . and .domain and .domain.components and (.domain.components | type) == "array" and (.domain.components | length) > 0 then
		(.domain.components | matchPublicSuffix) as $currentSuffixes
		| (.domain.components | getPrivatePrefix($currentSuffixes)) as $currentPrefixes
		| .domain."public-suffixes" = $currentSuffixes
		| .domain."private-prefixes" = $currentPrefixes
		| .domain."primary-domain" = ($currentPrefixes | getPrimaryDomain)
	else
		.
	end;

.origin.url |= mangle
| .requestedUrls[].url |= mangle
EOF

cat | jq "$addPublicSuffixes" --argfile "publicSuffixLookup" "$preparedPublicSuffixFile"
