#!/usr/bin/env bash
set -e

read -d '' getCSV <<-'EOF' || true
def toHeader:
	to_entries
	| map(
		.key
		| @text
	)
	| @csv;

def toLine:
	to_entries
	| map(
		.value
		| @text
	)
	| @csv;

def toLines:
	map(toLine)
	| join("\\n");

(.[0] | toHeader),
toLines
EOF

cat | jq --raw-output "$getCSV"
