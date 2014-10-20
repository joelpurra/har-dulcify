#!/usr/bin/env bash
set -e

read -d '' analysis <<-'EOF' || true
def keyCounterObjectSortByKeyAsc:
	to_entries
	| sort_by(.key)
	| from_entries;

def keyCounterObjectSortByValueDesc:
	to_entries
	| sort_by(.value)
	| reverse
	| from_entries;

def addToKeyCounterObject(obj):
	obj as $obj
	| .[$obj] = ((.[$obj] // 0) + 1);

def addArrayToKeyCounterObject(arr):
	. as $keyCounterObject
	| arr as $arr
	| reduce $arr[] as $item
	(
		$keyCounterObject;
		addToKeyCounterObject($item)
	);

def flatten:
	reduce
		.[] as $item
		(
			[];
			if ($item | type) == "array" then
				. + $item
			else
				. + [ $item ]
			end
		);

def mergeArrayOfObjectsToObject:
	# Assumes that the array's objects have unique enough properties to be suitable for merging.
	reduce .[] as $obj ({}; . + $obj);

def keyCounterObjectMinimum(n):
	n as $n
	| with_entries(
		select(.value >= $n)
	);

def keyCounterObjectMinimumTwo:
	keyCounterObjectMinimum(2);

def augmentWithCount:
	{
		count: length,
		values: .
	};

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

def hasValue(value):
	value as $value
	| index($value)
	| type == "number";

def breakOutArrays:
	{
		# Flattening necessary since some entries have multiple categories/organizations/urls.
		categories: (map(.categories) | flatten),
		organizations: (map(.organizations) | flatten),
		urls: (map(.urls) | flatten),
		# Flattening just in case.
		domains: to_entries | (map(.key) | flatten),
		entries: length
	};

def getOrganizationsByDomainCount:
	map(.)
	| group_by(.organizations)
	| map(
		length as $count
		| .[0]
		| {
			organizations,
			urls,
			count: $count
		}
	);

def getOrganizationsWithTheMostDomains:
	getOrganizationsByDomainCount
	| sort_by(.count)
	| reverse
	| .[0:25];

def groupOrganizationsByDomainCount:
	getOrganizationsByDomainCount
	| group_by(.count);

def getOrganizationCountByDomainCount:
	getOrganizationsByDomainCount
	| group_by(.count)
	| map(
		{
			domains: .[0].count,
			organizations: length
		}
	);

def getOrganizationsByCategoryCount:
	map(.)
	| reduce .[] as $item
	(
		[];
		. + (
			if ($item.categories | type) == "array" then
				[
					$item.categories[]
					| . as $category
					| $item
					| .categories = $category
				]
			else
				[ $item ]
			end
		)
	)
	| group_by(.categories)
	| map(
		group_by(.organizations)
		| map(
			length as $count
			| .[0]
			| {
				categories,
				organizations,
				count: $count
			}
		)
	);

def getOrganizationsWithTheMostCategoriesCounts:
	getOrganizationsByCategoryCount
	| map(
		map(
			.organizations
		)
		| flatten
	) 
	| reduce .[] as $categoryWithOrganizations
	(
		{};
		addArrayToKeyCounterObject($categoryWithOrganizations)
	)
	| keyCounterObjectMinimumTwo
	| keyCounterObjectSortByValueDesc
	| augmentWithCount;

def getOrganizationsWithTheMostCategoriesNames:
	getOrganizationsByCategoryCount
	| map(
		map(
			# Skip organizations with duplicates
			select(
				(.organizations | type) == "string"
			)
			| {
				(.organizations): .categories
			}
		)
		| .[]
	)
	| mergeArrayOfObjectsToObjectWithDuplicatesAsArray
	| with_entries(
		.value |= {
			categories: {
				Advertising: hasValue("Advertising"),
				Analytics: hasValue("Analytics"),
				Content: hasValue("Content"),
				Disconnect: hasValue("Disconnect"),
				Social: hasValue("Social"),
			},
			count: length,
		}
	)
	| to_entries
	| map(select(.value.count > 1))
	| sort_by(.value.count)
	| reverse
	| from_entries;

def getOrganizationCountByCategoryCount:
	getOrganizationsByCategoryCount
	| map(
		length as $count
		| .[0]
		| {
			(.categories): $count
		}
	)
	| mergeArrayOfObjectsToObject;

. as $root
| breakOutArrays
| {
	entries,
	distinct: {
		domains: (.domains | unique | length),
		organizations: (.organizations | unique | length),
		urls: (.urls | unique | length),
		categories: (.categories | unique | length)
	},
	"domains-per-category": (
		.categories as $categories
		| {}
		| addArrayToKeyCounterObject($categories)
		| keyCounterObjectSortByKeyAsc
	)
}
| . + {
	"domains-per-organization": {
		"average": (.distinct.domains / .distinct.organizations),
		"top-twentyfive": ($root | getOrganizationsWithTheMostDomains),
		"group-by-count": ($root | getOrganizationCountByDomainCount)
	}
}
| . + {
	"organizations-per-category": {
		"more-than-one": ($root | getOrganizationsWithTheMostCategoriesCounts),
		"more-than-one-names": ($root | getOrganizationsWithTheMostCategoriesNames),
		"count": ($root | getOrganizationCountByCategoryCount)
	}
}
EOF

cat | jq "$analysis"
