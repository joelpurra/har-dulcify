#!/bin/bash
set -e

read -d '' getParts <<-'EOF' || true
def splitUrlToParts:
	split("://") as $protocolParts
		| {
			url: .,
			protocol: $protocolParts[0],
			domain: ($protocolParts[1] | split("/")[0])
		};

def header(name):
	name as $name
	| map(select(.name == $name) | .value) | .[0];

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

(.log.pages[0].id | splitUrlToParts | .domain) as $domain
| {
	url: .log.pages[0].id,
	requestedUrls: .log.entries
		| map({
			url: .request.url,
			"mime-type": .response.content.mimeType,
			referer: .request.headers | header("Referer")
		})
	| map(deleteNullKeys)
}
EOF

while read harpath;
do
	cat "$harpath" | jq "$getParts"
done
