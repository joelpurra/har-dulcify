#!/usr/bin/env bash
set -e

while read harpath;
do
	# Let jq parse the entire file, but discard output
	set +e
	cat "$harpath" | jq '.' >/dev/null
	jqExitCode=$?
	set -e

	if [[ $jqExitCode != 0 ]]; then
		echo "$harpath"
	fi
done
