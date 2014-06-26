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

def matchDisconnect:
	# Match the domain to disconnect's list.
	# If the domain is a subdomain of a domain in disconnect's list, include it too.
	. as $domain
	| ($domain | split(".")) as $domainParts
	# Negative range to build the domain from parts from the right.
	| [ range((($domainParts | length) * -1); -1) ]
	| map(
		# Assemble the domain, longest domain combination first.
		($domainParts[.:] | join(".")) as $subdomain
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
	| unique;

def mangle:
	.blocks += ({
			disconnect: .url.domain | matchDisconnect
		}
		| deleteEmptyArrayKey("disconnect"))
	| deleteNullKey("blocks");

{
	origin: .origin | mangle,
	requestedUrls: .requestedUrls | map(mangle)
}
EOF

cat | jq "$classifyExpandedParts" --argfile "disconnect" "$disconnectClassificationFile"
