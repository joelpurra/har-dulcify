#!/usr/bin/env bash
set -e

disconnectClassificationFile="$1"

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

def singleOrFirst:
	if type == "array" then
		sort
		| .[0]
	else
		.
	end;

def matchDisconnect:
	# Match the domain to disconnect's list.
	# If the domain is a subdomain of a domain in disconnect's list, include it too.
	map(
		# has($subdomain) is more effective than $disconnect[$subdomain]
		. as $subdomain
		| if $disconnect | has($subdomain) then
			(
				# Inject the matched service domain into the returned object.
				{
					domain: $subdomain
				}
				+ $disconnect[$subdomain]
			)
		else
			empty
		end
	)
	# In case a subdomain matches more than once, keep only one of each match.
	| unique
	# Fix multiple urls and organizations by picking the first one.
	# Should not be a problem when disconnect fixes their datafile, but fixing here rather than in the preparation to retain blocking list aggregate analysis warning signs.
	| map(
		.urls |= singleOrFirst
		| .organizations |= singleOrFirst
	);

def mangle:
	if .url and .url.domain and .url.domain.components then
		.blocks += ({
				disconnect: (.url.domain.components | matchDisconnect)
			}
			| deleteEmptyArrayKey("disconnect"))
		| deleteNullKey("blocks")
	else
		.
	end
	| .classification.isDisconnectMatch = (.blocks and .blocks.disconnect and ((.blocks.disconnect | length) > 0))
	| .classification.isNotDisconnectMatch = (.classification.isDisconnectMatch | not);

.origin |= mangle
| .requestedUrls |= map(mangle)
EOF

cat | jq "$classifyExpandedParts" --argfile "disconnect" "$disconnectClassificationFile"
