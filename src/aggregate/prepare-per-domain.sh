#!/usr/bin/env bash
set -e

read -d '' getAggregateBasePerDomain <<-'EOF' || true
def deleteNullKey(key):
	# Delete a property if it is null.
	key as $key
	| with_entries(
		select(
			.key != $key
			or (
				.key == $key
				and
				(.value | type) != "null"
			)
		)
	);

def deleteEmptyKeyType(key; valueType):
	# Delete a property if it is an empty value of type.
	key as $key
	| valueType as $valueType
	| with_entries(
		select(
			.key != $key
			or (
				.key == $key
				and
				(.value | type) == $valueType
				and
				(.value | length) != 0
			)
		)
	);

def deleteEmptyArrayKey(key):
	# Delete a property if it is an empty array.
	deleteEmptyKeyType(key; "array");

def deleteEmptyObjectKey(key):
	# Delete a property if it is an empty object.
	deleteEmptyKeyType(key; "object");

def fallbackString:
	if . then
		.
	else
		"(" + (. | type) + ")"
	end;

def toStringOrFallbackString:
	if . then
		. | tostring
	else
		fallbackString
	end;

def setKeyCounterObjectCount(obj; count):
	obj as $obj
	| count as $count
	| .[$obj] = $count;

def setArrayToKeyCounterObject(arr; count):
	. as $keyCounterObject
	| count as $count
	| arr as $arr
	| reduce $arr[] as $item
	(
		$keyCounterObject;
		setKeyCounterObjectCount($item; $count)
	);

def setCounterArray(value; count):
	value as $value
	| count as $count
	| if map(.value == $value) | any then
		map(
			if .value == $value then
				.count = $count
			else
				.
			end
		)
	else
		. + [
			{
				count: $count,
				value: $value
			}
		]
	end;

def mangleDomain(domain):
	domain as $domain
	| .original |= setKeyCounterObjectCount($domain.original | fallbackString; 1)
	| .groups |= setArrayToKeyCounterObject(($domain.groups // []) | map(fallbackString); 1);

def mangleUrl(url):
	. as $aggregatedUrl
	| url as $url
	| .domain |= mangleDomain($url.domain);

def mangleDisconnect(disconnect):
	disconnect as $disconnect
	| if $disconnect then
		.domains |= setArrayToKeyCounterObject($disconnect | map(.domain); 1)
		| .organizations |= setArrayToKeyCounterObject($disconnect | map(.organizations); 1)
		| .categories |= setArrayToKeyCounterObject($disconnect | map(.categories); 1)
		| .raw |= setCounterArray($disconnect; 1)
	 else
		.
	end;

def mangleBlocks(request):
	request as $request
	| .blocks.disconnect |= mangleDisconnect($request.blocks.disconnect);

.origin = {
	count: 1
}
| .requestedUrls |= (
	reduce .[] as $request
	(
		{
			classification: {
				isSameDomain: (.[0].classification.isSameDomain // false),
				isSubdomain: (.[0].classification.isSubdomain // false),
				isSecure: (.[0].classification.isSecure // false)
			},
			# TODO: remove empty objects after filters?
			blocks: {
				disconnect: {
					domains: {},
					organizations: {},
					categories: {},
					raw: []
				}
			},
			count: 0
		};
		.classification.isSameDomain = (.classification.isSameDomain and $request.classification.isSameDomain)
		| .classification.isSubdomain = (.classification.isSubdomain and $request.classification.isSubdomain)
		| .classification.isSecure = (.classification.isSecure and $request.classification.isSecure)
		| ."mime-type" |= setKeyCounterObjectCount($request."mime-type" | fallbackString; 1)
		| .status |= setKeyCounterObjectCount($request.status | toStringOrFallbackString; 1)
		| .url |= mangleUrl($request.url)
		| .referer |= (if $request.referer then mangleUrl($request.referer) else . end)
		| deleteNullKey("referer")
		| mangleBlocks($request)
		| .count += 1
	)
)
| .requestedUrls.blocks.disconnect |= (
	deleteEmptyObjectKey("domains")
	| deleteEmptyObjectKey("organizations")
	| deleteEmptyObjectKey("categories")
	| deleteEmptyArrayKey("raw"))
| .requestedUrls.blocks |= deleteEmptyObjectKey("disconnect")
| .requestedUrls |= deleteEmptyObjectKey("blocks")
EOF

cat | jq "$getAggregateBasePerDomain"
