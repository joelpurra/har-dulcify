#!/usr/bin/env bash
set -e

effectiveTldFile="$1"

read -d '' classifyExpandedParts <<-'EOF' || true
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

def matchEffectiveTld:
	# Match the domain to all possible rules/groups int the effective tld list.
	map(
		# has($subdomain) is more effective than $effectiveTld[.] // empty
		. as $subdomain
		| if $effectiveTld | has($subdomain) then
			$effectiveTld[$subdomain]
		else
			empty
		end
	);

def mangle:
	.domain.groups = (if .domain.parts then (.domain.parts | matchEffectiveTld) else null end);

.origin.url |= mangle
| .requestedUrls[].url |= mangle
| .requestedUrls[].referer |= mangle
EOF

cat | jq "$classifyExpandedParts" --argfile "effectiveTld" "$effectiveTldFile"
