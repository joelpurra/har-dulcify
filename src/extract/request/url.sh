 #!/usr/bin/env bash
set -e

read -d '' getRequestUrls <<-'EOF' || true
.log.entries | map(.request.url)
EOF

cat | jq "$getRequestUrls"
