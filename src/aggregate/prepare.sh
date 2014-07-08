#!/usr/bin/env bash
set -e

read -d '' getAggregateBase <<-'EOF' || true
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

def mangleUrl:
	{
		domain: (
			.domain | {
					original: .original,
					groups: (if .groups then (.groups | map(.original)) else null end)
			}
		)
	};

def mangleMimeType:
	{
		type: ."mime-type".type,
		group: ."mime-type".group
	};

def mangle:
	{
		classification,
		"mime-type": mangleMimeType,
		status,
		url: (.url | mangleUrl),
		referer: (if .referer then (.referer | mangleUrl) else null end),
		blocks: {
			disconnect: .blocks.disconnect
		}
		| deleteNullKey("disconnect")
	}
	| deleteNullKey("referer")
	| deleteNullKey("blocks");

.origin |= mangle
| .requestedUrls[] |= mangle
EOF

cat | jq "$getAggregateBase"
