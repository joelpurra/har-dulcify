#!/usr/bin/env bash
set -e

declare -a tlds=("se" "dk")
input="top-1m.csv"
timestamp=$(date -u +%FT%TZ | tr -d ':')
outputDir="$timestamp"
outputPrefix="$outputDir/alexa."
outputSuffix=".$timestamp.txt"

# TODO: check for shuf, use gshuf as a fallback.
[[ -z $(which gshuf) ]] && { echo "gshuf is required" 1>&2; exit 1; }

filename(){
	echo "$outputPrefix$1$outputSuffix"
}

write(){
	cat > "$(filename "$1")"
}

clean(){
	sed -e 's/.*,//' -e 's_/.*__' "$(filename "$1")" | awk '!_[$0]++'
}

mkdir "$timestamp"

head -n 10000 "$input" | write "top.10000"
gshuf "$input" | head -n 10000 | write "random.10000"

clean "top.10000" | write "top.10000.clean"
clean "random.10000" | write "random.10000.clean"

for tld in "${tlds[@]}"
do
	grep "\\.$tld\$" "$input" | head -n 10000 | write "top.10000.$tld"
	clean "top.10000.$tld" | write "top.10000.$tld.clean"
done
