#!/usr/bin/env bash
set -e

preparedAlexaRankFile="$1"

read -d '' addAlexaRank <<-'EOF' || true
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

def matchAlexaRank:
	# has($subdomain) is more effective than $alexaRankLookup[.] // empty
	. as $subdomain
	| if $alexaRankLookup | has($subdomain) then
		$alexaRankLookup[$subdomain]
	else
		empty
	end;

def domainsToRank:
	{
		key: .,
		value: matchAlexaRank
	};

def mangle:
	if . and .url and .url.domain then
		(.url.domain."private-prefixes" | map(domainsToRank)) as $ranks
		| if ($ranks | length) > 0 then
			.rank = (.rank // {})
			| .rank.alexa = {}
			| .rank.alexa.all = ($ranks | from_entries)
			| .rank.alexa.highest = ($ranks | min_by(.value) | .value)
			| .rank.alexa.lowest = ($ranks | max_by(.value) | .value)
			| .rank.alexa.domain = (.url.domain.value | matchAlexaRank // null)
			| .rank.alexa."primary-domain" = (.url.domain."primary-domain" | matchAlexaRank // null)
		else
			.
		end
	else
		.
	end;

.origin |= mangle
# | .requestedUrls[] |= mangle
EOF

cat | jq "$addAlexaRank" --argfile "alexaRankLookup" "$preparedAlexaRankFile"
