#!/bin/bash
set -e

read -d '' getRequestUrls <<-'EOF' || true
.log.entries | map(.request.url)
EOF

while read harpath;
do
	cat "$harpath" | jq "$getRequestUrls"
done
