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
#  */json-inverted/	Domain names as properties, groups (text file names) as values.
#  */json-inverted/merged/	Merged inverted, with domain names as properties and groups/arrays of groups as values.
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

read -d '' invertedObject <<-'EOF' || true
def toNullOrSingleValueOrArray:
	if length == 0 then
		# Replace an empty array with null.
		null
	elif length == 1 then
		# Replace an array with a single element with that element.
		.[0]
	else
		# Return an array with more than one element as is.
		.
	end;

def mergeArrayOfObjectsToObjectWithDuplicatesAsArray:
	reduce .[] as $obj (
		{};
		. as $big
		| $obj
		| to_entries
		| .[]
		| .key as $key
		| .value as $value
		| $big
		| if $big | has($key) then
			$big[$key] += [ $value ]
		else
			$big[$key] = [ $value ]
		end
	);

def flattenObject:
	[
		to_entries
		| .[]
		| .key as $category
		| .value[]
		| . as $domain
		| {
			domain: $domain,
			category: $category,
		}
	];

def groupDomains:
	group_by(.domain)
	| map(
		{
			# Create a property out of the domain.
			(.[0].domain):
				# Merge deeper properties to (arrays of) unique values.
				[ .[].category ] | unique | toNullOrSingleValueOrArray
		}
	);

def transformRawDomainList:
	flattenObject
	| groupDomains
	| mergeArrayOfObjectsToObjectWithDuplicatesAsArray;

transformRawDomainList
| with_entries(
	.value |= toNullOrSingleValueOrArray
)
EOF

read -d '' mergeToObject <<-'EOF' || true
def toNullOrSingleValueOrArray:
	if length == 0 then
		# Replace an empty array with null.
		null
	elif length == 1 then
		# Replace an array with a single element with that element.
		.[0]
	else
		# Return an array with more than one element as is.
		.
	end;

def mergeArrayOfObjectsToObject:
	# Assumes that the array's objects have unique enough properties to be suitable for merging.
	reduce .[] as $obj ({}; . + $obj);

mergeArrayOfObjectsToObject
| with_entries(
	.value |= toNullOrSingleValueOrArray
)
EOF

read -d '' mergeToObjectWithDuplicatesAsArray <<-'EOF' || true
def toNullOrSingleValueOrArray:
	if length == 0 then
		# Replace an empty array with null.
		null
	elif length == 1 then
		# Replace an array with a single element with that element.
		.[0]
	else
		# Return an array with more than one element as is.
		.
	end;

def splitObjectToObjects:
	to_entries
	| .[]
	| {
		(.key): .value
	};

# TODO: mention that this function only merges a single object property (the last .key, alphabetically).
# Why? Because ". as $big" creates a reference to a point in time. Only the last modified version will be returned.
def mergeArrayOfObjectsToObjectWithDuplicatesAsArray:
	reduce .[] as $obj (
		{};
		. as $big
		| $obj
		| to_entries
		| .[]
		| .key as $key
		| .value as $value
		| $big
		| if $big | has($key) then
			$big[$key] += [ $value ]
		else
			$big[$key] = [ $value ]
		end
	);

# HACK: splitObjectToObjects to get over mergeArrayOfObjectsToObjectWithDuplicatesAsArray limitations.
map(splitObjectToObjects)
| mergeArrayOfObjectsToObjectWithDuplicatesAsArray
| with_entries(
	.value |= toNullOrSingleValueOrArray
)
EOF

createJsonVersions() {
	mkdir -p "json"
	mkdir -p "json-inverted"

	while IFS= read -r -d '' file;
	do
		name=$(basename -a -s ".txt" "$file")
		cat "$file" | jq --raw-input --slurp --arg name "$name" '{ ($name): split("\n") }' > "json/$name.json"
		<"json/$name.json" jq "$invertedObject" > "json-inverted/$name.inverted.json"
	done < <(find '.' -depth 1 -type f -name '*.txt' -print0)

	cd "json"
	mkdir -p "merged"
	cat *.json | jq --slurp "$mergeToObject" > "merged/merged.json"
	cd ..

	cd "json-inverted"
	mkdir -p "merged"
	cat *.json | jq --slurp "$mergeToObjectWithDuplicatesAsArray" > "merged/merged.duplicates.json"
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

