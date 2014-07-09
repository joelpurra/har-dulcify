#!/usr/bin/env bash
set -e

read -d '' getAggregateBase <<-'EOF' || true
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

def mangleUrl:
	{
		domain: (
			.domain | {
					original: .original,
					groups: (if .groups then (.groups | map(.original)) else null end)
			}
		)
	};

def mangleMimeType:
	{
		type: ."mime-type".type,
		group: ."mime-type".group
	};

def mangle:
	{
		classification,
		"mime-type": mangleMimeType,
		status,
		url: (.url | mangleUrl),
		referer: (if .referer then (.referer | mangleUrl) else null end),
		blocks: {
			disconnect: .blocks.disconnect
		}
		| deleteNullKey("disconnect")
	}
	| deleteNullKey("referer")
	| deleteNullKey("blocks");

def distinctMangleDomain(domain):
	domain as $domain
	| .original |= setKeyCounterObjectCount($domain.original | fallbackString; 1)
	| .groups |= setArrayToKeyCounterObject(($domain.groups // []) | map(fallbackString); 1);

def distinctMangleUrl(url):
	. as $aggregatedUrl
	| url as $url
	| .domain |= distinctMangleDomain($url.domain);

def distinctMangleDisconnect(disconnect):
	disconnect as $disconnect
	| if $disconnect then
		.domains |= setArrayToKeyCounterObject($disconnect | map(.domain); 1)
		| .organizations |= setArrayToKeyCounterObject($disconnect | map(.organizations); 1)
		| .categories |= setArrayToKeyCounterObject($disconnect | map(.categories); 1)
		| .raw |= setCounterArray($disconnect; 1)
	 else
		.
	end;

def distinctMangleBlocks(request):
	request as $request
	| .blocks.disconnect |= distinctMangleDisconnect($request.blocks.disconnect);

def distinctMangleMimeType(mimeType):
	mimeType as $mimeType
	| .types |= setKeyCounterObjectCount($mimeType.type | fallbackString; 1)
	| .groups |= setKeyCounterObjectCount($mimeType.group | fallbackString; 1);

def distinctMangleStatus(status):
	status as $status
	| .codes |= setKeyCounterObjectCount($status.code | toStringOrFallbackString; 1)
	| .groups |= setKeyCounterObjectCount($status.group | fallbackString; 1);

def distinctMangle:
	reduce .[] as $request
	(
		{
			classification: {
				isSameDomain: (.[0].classification.isSameDomain // false),
				isSubdomain: (.[0].classification.isSubdomain // false),
				isSecure: (.[0].classification.isSecure // false)
			},
			"mime-type": {
				types: {},
				groups: {}
			},
			status: {
				codes: {},
				groups: {}
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
		| ."mime-type" |= distinctMangleMimeType($request."mime-type")
		| .status |= distinctMangleStatus($request.status)
		| .url |= distinctMangleUrl($request.url)
		| .referer |= (if $request.referer then distinctMangleUrl($request.referer) else . end)
		| deleteNullKey("referer")
		| distinctMangleBlocks($request)
		| .count += 1
	) 
	| .blocks.disconnect |= (
		deleteEmptyObjectKey("domains")
		| deleteEmptyObjectKey("organizations")
		| deleteEmptyObjectKey("categories")
		| deleteEmptyArrayKey("raw"))
	| .blocks |= deleteEmptyObjectKey("disconnect")
	| deleteEmptyObjectKey("blocks");

.origin |= mangle
| .requestedUrls[] |= mangle
| .requestedUrlsDistinct = (.requestedUrls | distinctMangle)
EOF

cat | jq "$getAggregateBase"