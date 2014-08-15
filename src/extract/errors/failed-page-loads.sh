#!/usr/bin/env bash
set -e

read -d '' selectFailedPageLoad <<-'EOF' || true
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
				.[0].response
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

select(isFailedPageLoad)
EOF

cat | jq "$selectFailedPageLoad"