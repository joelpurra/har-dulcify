#!/bin/bash
set -e

read -d '' getParts <<-'EOF' || true
def httpHeader(name):
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

def getEntryDetails:
	{
		url: .request.url,
		status: .response.status,
		"mime-type": .response.content.mimeType,
		referer: .request.headers | httpHeader("Referer"),
		redirect: (
			if (.response.redirectURL | length) == 0 then
				null
			else
				.response.redirectURL
			end
		)
	};

{
	origin: .log.entries[0] | getEntryDetails | deleteNullKeys,
	requestedUrls: (
		.log.entries[1:]
		| map(getEntryDetails | deleteNullKeys)
	)
}
EOF

while read harpath;
do
	cat "$harpath" | jq "$getParts"
done
