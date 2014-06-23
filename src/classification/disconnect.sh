#!/bin/bash
set -e

disconnectClassificationFile="$1"

read -d '' classifyExpandedParts <<-'EOF' || true
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
	| with_entries(
		.value |= map(
			with_entries(
				.value |= with_entries(
					.value |= map(
						select(
							. as $inDisconnect
							| ($domain | isSameOrSubdomain($inDisconnect))
						)
					)
				)
			)
		)
	)
	| with_entries(
		.value |= map(
			with_entries(
				.value |= with_entries(
					select(
						(.value | length) > 0
					)
				)
			)
		)
	)
	| with_entries(
		.value |= map(
			with_entries(
				select(
					(.value | length) > 0
				)
			)
		)
	)
	| with_entries(
		.value |= map(
			select(
				(. | length) > 0
			)
		)
	)
	| with_entries(
		select(
			(.value | length) > 0
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
	| deleteNullKeys;

.origin.url as $origin
| {
	origin: .origin | mangle($origin),
	requestedUrls: .requestedUrls | map(mangle(($origin)))
}
EOF

cat | jq "$classifyExpandedParts" --argfile "disconnect" "$disconnectClassificationFile"
