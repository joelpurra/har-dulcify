#!/usr/bin/env bash
set -e

read -d '' selectFailedPageLoad <<-'EOF' || true
def isFailedPageLoad:
	.log
	| (
		(
			.entries
			| (
				type == "null"
				or
				length == 0
			)
		)
		or
		(
			.entries[0]
			| (
				(
					.response
					| type == "null"
				)
				or
				(
					.response.status
					| (
						type == "null"
						or
						. <= 0
					)
				)
			)
		)
	);

select(isFailedPageLoad)
EOF

cat | jq "$selectFailedPageLoad"