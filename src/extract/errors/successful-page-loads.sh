#!/usr/bin/env bash
set -e

read -d '' selectSuccessfulPageLoad <<-'EOF' || true
def isFailedPageLoad:
	.log
	| (
		type != "object"
		or
		(
			.entries
			| type != "array"
			or
			length == 0
			or
			(
				.entries[0].response
				| (
					type != "object"
					or
					(
						.status
						| (
							type != "number"
							or
							. < 100
							or
							. > 999
						)
					)
				)
			)
		)
	);

select(!isFailedPageLoad)
EOF

cat | jq "$selectSuccessfulPageLoad"