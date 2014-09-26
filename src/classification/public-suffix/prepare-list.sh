#!/usr/bin/env bash
set -e

# https://publicsuffix.org/list/
# https://publicsuffix.org/list/effective_tld_names.dat

[[ ! `which idn` ]] && { echo "idn is required"; exit 1; }

read -d '' cleanUpEffectiveTldNamesDat <<-'EOF' || true
\\_// ===BEGIN ICANN DOMAINS===_,\\_// ===END ICANN DOMAINS===_ {
	\\_//_ d
	/^[[:space:]]*$/ d
	p
}
EOF

read -d '' createJsonObject <<-'EOF' || true
	s/^(.+)[[:space:]]+(.+)$/{ "original": "\\1", "idn": "\\2" }/
	p
EOF

read -d '' expandToObject <<-'EOF' || true
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

def cleanRuleToLookupValue:
	# Keeps only the right hand part of any rules for faster, strictly defined lookups.
	split("*")[-1:][0]
	| split("!")[-1:][0]
	| split(".")
	| if .[0] == "" then .[1:] else . end
	| join(".");

def isWildcardRule:
	contains("*");

def isExceptionRule:
	startswith("!");

# DEBUG: let through only rules with wildcards or exceptions
#map(select((.idn | isWildcardRule) or (.idn | isExceptionRule))) |

. as $all
| length as $length
| [ range(0; $length) ]
| map(
	. as $num
	| $all[$num] as $rule
	| {
		original: $rule.original,
		idn: $rule.idn,
		isWildcardRule: ($rule.idn | isWildcardRule),
		isExceptionRule: ($rule.idn | isExceptionRule),
		lookup: ($rule.idn | cleanRuleToLookupValue),
		sort: ($rule.idn | split(".") | reverse | join("."))
	}
)
| map(
	{
		(.lookup): .
	}
)
# Duplicates exist: .engineering
# https://bugzilla.mozilla.org/show_bug.cgi?id=1024740
| mergeArrayOfObjectsToObjectWithDuplicatesAsArray
| with_entries(
	.value |= toNullOrSingleValueOrArray
)
EOF

cleanList=$(cat | sed -n "$cleanUpEffectiveTldNamesDat")
cleanIdnList=$(echo "$cleanList" | idn)
paste <(echo "$cleanList") <(echo "$cleanIdnList") | sed -n -E "$createJsonObject" | "${BASH_SOURCE%/*}/../../util/to-array.sh" | jq "$expandToObject"
