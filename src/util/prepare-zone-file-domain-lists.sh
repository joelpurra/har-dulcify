#!/usr/bin/env bash
set -e

zoneSuffix="$1"
input="$2"

TEMPORARY=$(mktemp -d "$(basename "${BASH_SOURCE}").XXXXXXXX")
trap 'rm -rf "$TEMPORARY"' EXIT

ZONESUFFIX="$(echo "$zoneSuffix" | tr '[:lower:]' '[:upper:]')"

timestamp=$(date -u +%FT%TZ | tr -d ':')
outputDir="$timestamp"
outputPrefix="$outputDir/zone.$zoneSuffix."
outputSuffix=".$timestamp.txt"

# TODO: check for shuf, use gshuf as a fallback.
shuffler="$(which shuf || which gshuf || "" 2>/dev/null)"
[[ -z shuffler ]] && { echo "shuf/gshuf is required" 1>&2; exit 1; }


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


filename(){
	echo "$outputPrefix$1$outputSuffix"
}

write(){
	cat > "$(filename "$1")"
}

T(){
	tee "$(filename "$1")"
}

top10k(){
	head -n 10000 "$@"
}

shuffle(){
	"$shuffler" "$@"
}

extractDomains(){
	sedExtRegexp -e "1,/^${ZONESUFFIX}\./ d" -e '/^[^ ]+ NS / ! d' -e 's/^([^ ]+) .*$/\1/' -e 's/./\L&/g' -e "s/\$/.${zoneSuffix}/" "$@"
}

unique(){
	# Using `uniq` instead of  `sort -u` as indata is already grouped by domain.
	uniq
}

mkdir "$timestamp"

extractDomains | unique | T "unique" | shuffle | top10k | write "random.10000"