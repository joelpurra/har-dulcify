#!/usr/bin/env bash
set -e

read -d '' allWithComments <<-'EOF' || true
select(
	(.log.comment | length > 0)
	or (
		reduce .log.entries[] as $entry
			(
				false;
				. or ($entry | (.response.comment | length) > 0)
			)
	)
)
EOF

cat | jq "$allWithComments"
