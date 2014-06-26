 #!/usr/bin/env bash
set -e

while read harpath;
do
	cat "$harpath" | jq 'select(.log.comment | length > 0)' || (echo "ERROR: $harpath" >/dev/stderr)
done
