#!/usr/bin/env bash
set -e

read -d '' getAggregatesPerDomain <<-'EOF' || true
def keyCounterObject(key):
	key as $key
	| .
	+
	(
		[
			{
				key: $key,
				value: ((.[$key] // 0) + 1)
			}
		]
		| from_entries
	);

def aggregate(key):
	key as $key
	| reduce .[] as $item
	(
		{
			count: {
				($key): {}
			}
		};
		{
			count: .[$key] | keyCounterObject($item[$key])
		}
	);

def addValueToKeyCounterObject(obj; value):
	obj as $obj
	| value as $value
	| .[$obj] = ((.[$obj] // 0) + $value);

def addToKeyCounterObject(obj):
	obj as $obj
	| addValueToKeyCounterObject($obj; 1);

def addArrayToKeyCounterObject(arr):
	. as $keyCounterObject
	| arr as $arr
	| reduce $arr[] as $item
	(
		$keyCounterObject;
		addToKeyCounterObject($item)
	);

def mergeKeyCounterObjects(obj):
	. as $keyCounterObject
	| obj
	| to_entries
	| reduce .[] as $item
	(
		$keyCounterObject;
		addValueToKeyCounterObject($item.key; $item.value)
	);

def boolToInt:
	if . == true then
		1
	elif . == false then
		0
	else
		null
	end;

def addCountToCounterArray(value; count):
	value as $value
	| count as $count
	| if map(.value == $value) | any then
		map(
			if .value == $value then
				.count += $count
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

def addToCounterArray(value):
	value as $value
	| addCountToCounterArray($value; 1);

def mergeToCounterArray(item):
	item as $item
	| addCountToCounterArray($item.value; $item.count);

def mergeArrayToCounterArray(arr):
	. as $counterArray
	| arr
	| reduce .[] as $item
	(
		$counterArray;
		mergeToCounterArray($item)
	);

def baseUrl:
	{
		domain: {}
	};

def base:
	{
		classification: {
			isSameDomain: 0,
			isSubdomain: 0,
			isSecure: 0
		},
		"mime-type": {
			types: {},
			groups: {}
		},
		status: {},
		url: baseUrl,
		referer: baseUrl,
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

def mangleDomain(domain):
	domain as $domain
	| .original |= mergeKeyCounterObjects($domain.original)
	| .groups |= mergeKeyCounterObjects($domain.groups);

def mangleUrl(url):
	. as $aggregatedUrl
	| url as $url
	| .domain |= mangleDomain($url.domain);

def mangleClassification(request):
	request as $request
	| .classification.isSameDomain += ($request.classification.isSameDomain | boolToInt)
	| .classification.isSubdomain += ($request.classification.isSubdomain | boolToInt)
	| .classification.isSecure += ($request.classification.isSecure | boolToInt);

def mangleDisconnect(disconnect):
	disconnect as $disconnect
	| if $disconnect then
		.domains |= mergeKeyCounterObjects($disconnect.domains)
		| .organizations |= mergeKeyCounterObjects($disconnect.organizations)
		| .categories |= mergeKeyCounterObjects($disconnect.categories)
		| .raw |= mergeArrayToCounterArray($disconnect.raw)
	 else
		.
	end;

def mangleBlocks(request):
	request as $request
	| .blocks.disconnect |= mangleDisconnect($request.blocks.disconnect);

def mangleOrigin(request):
	request as $request
	| .count += $request.count;

def mangleMimeType(mimeType):
	mimeType as $mimeType
	| .types |= mergeKeyCounterObjects($mimeType.types)
	| .groups |= mergeKeyCounterObjects($mimeType.groups);

def mangle(request):
	request as $request
	| if $request.count > 0 then
		mangleClassification($request)
		| ."mime-type" |= mangleMimeType($request."mime-type")
		| .status |= mergeKeyCounterObjects($request.status)
		| .url |= mangleUrl($request.url)
		| .referer |= (if $request.referer then mangleUrl($request.referer) else . end)
		| mangleBlocks($request)
	else
		.
	end
	| .count += $request.count;

reduce .[] as $request
(
	{
		origin: {
			count: 0,
			"no-requestedUrls": (map(select(.requestedUrls.count == 0)) | length)
		},
		requestedUrls: base
	};
	. as $aggregated
	| .origin |= mangleOrigin($request.origin)
	| .requestedUrls |= mangle($request.requestedUrls)
)
EOF

cat | jq --slurp "$getAggregatesPerDomain"
