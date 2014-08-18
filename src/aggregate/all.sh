#!/usr/bin/env bash
set -e

TEMPORARY=$(mktemp -d "$(basename "${BASH_SOURCE}").XXXXXXXX")
TEMPOUT1="$TEMPORARY/aggregate.merge.1.json"
TEMPOUT2="$TEMPORARY/aggregate.merge.2.json"
trap 'rm -rf "$TEMPORARY"' EXIT

# From https://github.com/EtiennePerot/parcimonie.sh/blob/master/parcimonie.sh
# Test for GNU `sed`, or use a `sed` fallback in sedExtRegexp
sedExec=(sed)
if [ "$(echo 'abc' | sed -r 's/abc/def/' 2> /dev/null || true)" == 'def' ]; then
	# GNU Linux sed
	sedExec+=(-r)
else
	# Mac OS X sed
	sedExec+=(-E)
fi

sedExtRegexp() {
	"${sedExec[@]}" "$@"
}

keepDigitsOnly() {
	sedExtRegexp -e 's/[^[:digit:]]//g' -e '/^$/d'
}


getJsonObjectCount() {
	jq '1' | wc -l | keepDigitsOnly
}

getMergedObjectCount() {
	mergedObjectCount=$(cat "$TEMPOUT1" | getJsonObjectCount)
}


cat | "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/prepare2.sh" > "$TEMPOUT1"

getMergedObjectCount

while (( $mergedObjectCount > 2 )); do
	cat "$TEMPOUT1" | "${BASH_SOURCE%/*}/../util/parallel-chunks.sh" "${BASH_SOURCE%/*}/merge.sh" > "$TEMPOUT2"
	mv "$TEMPOUT2" "$TEMPOUT1"
	getMergedObjectCount
done

cat "$TEMPOUT1" | "${BASH_SOURCE%/*}/merge.sh" > "$TEMPOUT2"
mv "$TEMPOUT2" "$TEMPOUT1"

cat "$TEMPOUT1"