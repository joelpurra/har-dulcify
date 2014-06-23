#!/bin/bash
set -e

disconnectClassificationFile="$1"

read -d '' classifyExpandedParts <<-'EOF' || true
def map_keep_nonnull(mapper):
	map(mapper
		| select(
			(. | type) != "null"
		)
	);

def deleteEmtpyArray:
	if (. | length) != 0 then . else empty end;

def map_keep_noempty_nonulls_array(mapper):
	map_keep_nonnull(mapper)
	| deleteEmtpyArray;

def map_keep_noempty_array(mapper):
	map(mapper)
	| deleteEmtpyArray;

def with_entries_keep_nonnull(mapper):
	to_entries
	| map(mapper)
	| map(
		select(
			(.value | type) != "null"
		)
	)
	| from_entries;

def deleteNullKey(key):
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

def deleteNullKeys:
	with_entries(
		select(
			(.value | type) != "null"
		)
	);

def isSameDomain(domain):
	domain as $domain
	| . == $domain;

def isSubdomain(domain):
	domain as $domain
	| endswith("." + $domain);

def isSameOrSubdomain(domain):
	domain as $domain
	| (isSameDomain($domain)
			or isSubdomain($domain));

def matchDisconnect:
	. as $domain
	| $disconnect.categories
	| with_entries_keep_nonnull(
		.value |= map_keep_noempty_nonulls_array(
			with_entries_keep_nonnull(
				.value |= with_entries_keep_nonnull(
					.value |= map_keep_noempty_array(
						select(
							. as $inDisconnect
							| ($domain | isSameOrSubdomain($inDisconnect))
						)
					)
				)
			)
		)
	);

def mangle(origin):
	origin as $origin
	| .url as $urlParts
	| . + {
		blocks: ({
					disconnect: $urlParts.domain | matchDisconnect
				}
				| deleteNullKeys)
	}
	| deleteNullKey("blocks");

.origin.url as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle(($origin)))
}
EOF

cat | jq "$classifyExpandedParts" --argfile "disconnect" "$disconnectClassificationFile"
