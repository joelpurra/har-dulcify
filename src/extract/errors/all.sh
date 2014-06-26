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

while read harpath;
do
	cat "$harpath" | jq "$allWithComments" || (echo "ERROR: $harpath" >/dev/stderr)
done
