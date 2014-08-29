#!/usr/bin/env bash
set -e

declare -a tlds=("se" "dk")
input="top-1m.csv"
timestamp=$(date -u +%FT%TZ | tr -d ':')
outputDir="$timestamp"
outputPrefix="$outputDir/alexa."
outputSuffix=".$timestamp.txt"

shuffler="$(which shuf || which gshuf || "" 2>/dev/null)"
[[ -z shuffler ]] && { echo "shuf/gshuf is required" 1>&2; exit 1; }

filename(){
	echo "$outputPrefix$1$outputSuffix"
}

write(){
	cat > "$(filename "$1")"
}

T(){
	tee "$(filename "$1")"
}

clean(){
	sed -e 's/.*,//' -e 's_/.*__' | awk '!_[$0]++' | write "$1"
}

top10k(){
	head -n 10000 "$@"
}

shuffle(){
	"$shuffler" "$@"
}

mkdir "$timestamp"

top10k "$input" | T "top.10000" | clean "top.10000.clean"
shuffle "$input" | top10k | T "random.10000" | clean "random.10000.clean"

for tld in "${tlds[@]}"
do
	grep "\\.$tld\$" "$input" | top10k | T "top.10000.$tld" | clean "top.10000.$tld.clean"
done
