#!/usr/bin/env bash
set -e

read -d '' getParts <<-'EOF' || true
def httpHeader(name):
	name as $name
	| map(select(.name == $name) | .value) | .[0];

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

cat | jq "$getParts"