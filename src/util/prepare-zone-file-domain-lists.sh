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

read(){
	cat "$(filename "$1")"
}




tempFilename(){
	echo "$TEMPORARY/$(filename "$1")"
}

writeTemp(){
	cat > "$(tempFilename "$1")"
}

Ttemp(){
	tee "$(filename "$1")"
}

readTemp(){
	cat "$(tempFilename "$1")"
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

differ(){
	diff --unified "$(filename "$1")" "$(filename "$2")"
}

unique(){
	# Using `uniq` instead of  `sort -u` as indata is already grouped by domain.
	uniq
}

mkdir "$timestamp"

# DEBUGGING
# Used to test the difference between `uniq` and `sort -u` on this indata.
# `uniq` is a lot faster, and the indata is grouped by domain after filtering; `sort -u` isn't necessary.
# echo extract
# time extractDomains "$input" | write "t"

# echo uniq
# time read "t" | uniq | write "u"

# echo sort -u
# time read "t" | sort -u | write "su"

# echo uniq sort
# time read "u" | sort | write "us"

# echo differ
# time differ "su" "us" | write "d"

# echo done diffing

# echo extract+unique
# time extractDomains "$input" | unique | write "unique"
# echo shuffle+top10k
# time read "unique" | shuffle | top10k | write "random.10000"

# echo extract+unique+shuffle+top10k
extractDomains | unique | T "unique" | shuffle | top10k | write "random.10000"