#!/usr/bin/env bash
set -e

# Domain list preparation script, developed for ".se health status" domain lists.
# https://iis.se/
# This could be done by hand, but now that it's scripted, why not go all the way and create about 20x the number of files in different variations.
# Enjoy!
#
# Copyright 2014 Joel Purra, http://joelpurra.com/
# Released under the GPL3.0 license.
#
# Usage: "$0" in a folder containing .txt files.
# Input: Text files containing one domain per line. Extended characters allowed; they will be idn encoded.
# Output: text files and json files.
#  clean/	Whitespace trimmed and empty lines stripped.
#  clean/idn/	IDN encoded domain names.
#  clean/idn/no-idn-duplicates/	All idn encoded names removed. (They all turned out to be duplicates/redirects in my data.)
#  */unique-per-group/	Unique names per text file.
#  */unique/	Unique name for all text files in the folder.
#  */json/	A JSON object with the file name as property name, and an array of all values.
#  */json/merged/	All JSON files/objects in the folder merged into one.
#  */stats/	Line counts, total counts.

[[ ! `which idn` ]] && { echo "idn is required"; exit 1; }
[[ ! `which jq` ]] && { echo "jq is required"; exit 1; }

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

removeWhitespaceAndEmptyLines() {
	sedExtRegexp -e 's/[[:space:]]//g' -e '/^$/d'
}

createJsonVersions() {
	mkdir -p "json"

	while IFS= read -r -d '' file;
	do
		name=$(basename -a -s ".txt" "$file")
		cat "$file" | jq --raw-input --slurp --arg name "$name" '{ ($name): split("\n") }' > "json/$name.json"
	done < <(find '.' -depth 1 -type f -name '*.txt' -print0)

	cd "json"
	mkdir -p "merged"
	# mergeArrayOfObjectsToObject
	cat *.json | jq --slurp 'reduce .[] as $obj ({}; . + $obj)' > "merged/merged.json"
	cd ..
}

createUniqueVersions() {
	mkdir -p "unique-per-group"

	# Remove duplicates per group
	ls *.txt | xargs -I '{}' -- sh -c "cat {} | sort | uniq > unique-per-group/{}"

	cd "unique-per-group"
	createJsonVersions
	createStats
	cd ..

	mkdir -p "unique"

	# Create a single file with unique entries
	cat *.txt | sort | uniq > "unique/unique.txt"

	cd "unique"
	createJsonVersions
	createStats
	cd ..
}

createStats(){
	mkdir -p "stats"

	ls *.txt | xargs -I '{}' -n 1 -- sh -c "cat {} | sort | uniq -c | sort -n > stats/{}.counts.txt"
	ls *.txt | xargs -I '{}' -n 1 -- sh -c "cat {} | wc >> stats/{}.counts.txt"

	# Simplified second level grouping/sort - should be split(".") | reverse | join(".") | sort | split(".") | reverse | join(".").
	ls *.txt | xargs -I '{}' -n 1 -- sh -c "cat {} | grep --extended-regex '\..+\.[a-z]+$' | rev | sort | rev > stats/{}.secondlevel.txt"
	ls *.txt | xargs -I '{}' -n 1 -- sh -c "cat {} | grep --extended-regex --only-matching '\..+\.[a-z]+$' | rev | sort | rev | uniq -c | sort -n > stats/{}.secondlevel.counts.txt"
}

processFolder() {
	createJsonVersions
	createStats
	createUniqueVersions
}

mkdir -p "clean"

while IFS= read -r -d '' file;
do
	name=$(basename -a -s ".txt" "$file")
	cat "$file" | removeWhitespaceAndEmptyLines > "clean/$name.txt"
done < <(find '.' -depth 1 -type f -name '*.txt' -print0)

cd "clean"
processFolder

mkdir -p "idn"

# Convert domains to idn
ls *.txt | xargs -I '{}' -n 1 -- sh -c "cat {} | idn > idn/{}"

cd "idn"
processFolder

mkdir -p "no-idn-duplicates"

# Filter out idn domains as duplicates
ls *.txt | xargs -I '{}' -- sh -c "cat {} | grep -v 'xn--' > no-idn-duplicates/{}"

cd "no-idn-duplicates"
processFolder

