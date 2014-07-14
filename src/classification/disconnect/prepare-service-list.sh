#!/usr/bin/env bash
set -e

read -d '' classifyExpandedParts <<-'EOF' || true
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

def flattenDisconnect:
	# services.json keeps service domains in the deepest level.
	# This flattens the hierarchy to one object per domain, but duplicates other information.
	# Done to be able to perform hash/object-has-property lookups on domains.
	[
		to_entries
		| .[]
		| .key as $category
		| .value[]
		| to_entries
		| .[]
		| .key as $organization
		| .value
		| to_entries
		| .[]
		| .key as $url
		| .value[]
		| . as $domain
		| {
			domain: $domain,
			url: $url,
			organization: $organization,
			category: $category,
		}
	];

def groupDomains:
	group_by(.domain)
	| map(
		{
			# Create a property out of the domain.
			(.[0].domain): {
				# Merge deeper properties to (arrays of) unique values.
				# NOTE: at the time of writing only four domains in services.json have more than one value for category/organization/url, but keeping them in arrays just in case.
				urls: [ .[].url ] | unique | toNullOrSingleValueOrArray,
				organizations: [ .[].organization ] | unique | toNullOrSingleValueOrArray,
				categories: [ .[].category ] | unique | toNullOrSingleValueOrArray
			}
		}
	);

def transformRawDisconnect:
	flattenDisconnect
	| groupDomains
	| mergeArrayOfObjectsToObject;

.categories
# Too many domains are duplicated in the legacy lists.
| del(."Legacy Content")
| del(."Legacy Disconnect")
| transformRawDisconnect
EOF

cat | jq "$classifyExpandedParts"
