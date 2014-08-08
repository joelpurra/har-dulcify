#!/usr/bin/env bash
set -e

read -d '' getAggregates <<-'EOF' || true
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

def boolToInt:
	if . == true then
		1
	elif . == false then
		0
	else
		null
	end;

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
		domain: {
			value: {},
			"public-suffices": {}
		}
	};

def base:
	{
		classification: {
			isSameDomain: 0,
			isSubdomain: 0,
			isInternalDomain: 0,
			isExternalDomain: 0,
			isSuccessful: 0,
			isSecure: 0
		},
		"mime-type": {
			types: {},
			groups: {}
		},
		status: {
			codes: {},
			groups: {}
		},
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
	| .value |= addToKeyCounterObject($domain.value | fallbackString)
	| ."public-suffices" |= addArrayToKeyCounterObject(($domain."public-suffices" // []) | map(fallbackString));

def mangleUrl(url):
	. as $aggregatedUrl
	| url as $url
	| .domain |= mangleDomain($url.domain);

def mangleClassification(request):
	request as $request
	| .classification.isSameDomain += ($request.classification.isSameDomain | boolToInt)
	| .classification.isSubdomain += ($request.classification.isSubdomain | boolToInt)
	| .classification.isInternalDomain += ($request.classification.isInternalDomain | boolToInt)
	| .classification.isExternalDomain += ($request.classification.isExternalDomain | boolToInt)
	| .classification.isSuccessful += ($request.classification.isSuccessful | boolToInt)
	| .classification.isSecure += ($request.classification.isSecure | boolToInt);

def mangleDisconnect(disconnect):
	disconnect as $disconnect
	| if $disconnect then
		.domains |= addArrayToKeyCounterObject($disconnect | map(.domain))
		| .organizations |= addArrayToKeyCounterObject($disconnect | map(.organizations))
		| .categories |= addArrayToKeyCounterObject($disconnect | map(.categories))
		| .raw |= addToCounterArray($disconnect)
	 else
		.
	end;

def mangleBlocks(request):
	request as $request
	| .blocks.disconnect |= mangleDisconnect($request.blocks.disconnect);

def mangleMimeType(mimeType):
	mimeType as $mimeType
	| .types |= addToKeyCounterObject($mimeType.type | fallbackString)
	| .groups |= addToKeyCounterObject($mimeType.group | fallbackString);

def mangleStatus(status):
	status as $status
	| .codes |= addToKeyCounterObject($status.code | toStringOrFallbackString)
	| .groups |= addToKeyCounterObject($status.group | fallbackString);

def mangle(request):
	request as $request
	| mangleClassification($request)
	| ."mime-type" |= mangleMimeType($request."mime-type")
	| .status |= mangleStatus($request.status)
	| .url |= mangleUrl($request.url | fallbackString)
	| .referer |= (if $request.referer then mangleUrl($request.referer) else . end)
	| mangleBlocks($request)
	| .count += 1;

def distinctBaseUrl:
	{
		domain: {
			value: {},
			"public-suffices": {}
		}
	};

def distinctBase:
	{
		classification: {
			isSameDomain: 0,
			isSubdomain: 0,
			isInternalDomain: 0,
			isExternalDomain: 0,
			isSuccessful: 0,
			isSecure: 0
		},
		"mime-type": {
			types: {},
			groups: {}
		},
		status: {
			codes: {},
			groups: {}
		},
		url: distinctBaseUrl,
		referer: distinctBaseUrl,
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

def distinctMangleDomain(domain):
	domain as $domain
	| .value |= mergeKeyCounterObjects($domain.value // {})
	| ."public-suffices" |= mergeKeyCounterObjects($domain."public-suffices" // {});

def distinctMangleUrl(url):
	. as $aggregatedUrl
	| url as $url
	| .domain |= distinctMangleDomain($url.domain);

def distinctMangleClassification(request):
	request as $request
	| .classification.isSameDomain += ($request.classification.isSameDomain | boolToInt)
	| .classification.isSubdomain += ($request.classification.isSubdomain | boolToInt)
	| .classification.isInternalDomain += ($request.classification.isInternalDomain | boolToInt)
	| .classification.isExternalDomain += ($request.classification.isExternalDomain | boolToInt)
	| .classification.isSuccessful += ($request.classification.isSuccessful | boolToInt)
	| .classification.isSecure += ($request.classification.isSecure | boolToInt);

def distinctMangleDisconnect(disconnect):
	disconnect as $disconnect
	| if $disconnect then
		.domains |= mergeKeyCounterObjects($disconnect.domains)
		| .organizations |= mergeKeyCounterObjects($disconnect.organizations)
		| .categories |= mergeKeyCounterObjects($disconnect.categories)
		| .raw |= mergeArrayToCounterArray($disconnect.raw)
	 else
		.
	end;

def distinctMangleBlocks(request):
	request as $request
	| .blocks.disconnect |= distinctMangleDisconnect($request.blocks.disconnect);

def distinctMangleOrigin(request):
	request as $request
	| .count += $request.count;

def distinctMangleMimeType(mimeType):
	mimeType as $mimeType
	| .types |= mergeKeyCounterObjects($mimeType.types)
	| .groups |= mergeKeyCounterObjects($mimeType.groups);

def distinctMangleStatus(status):
	status as $status
	| .codes |= mergeKeyCounterObjects($status.codes)
	| .groups |= mergeKeyCounterObjects($status.groups);

def distinctMangle(request):
	request as $request
	| if $request.count > 0 then
		distinctMangleClassification($request)
		| ."mime-type" |= distinctMangleMimeType($request."mime-type")
		| .status |= distinctMangleStatus($request.status)
		| .url |= distinctMangleUrl($request.url)
		| .referer |= (if $request.referer then distinctMangleUrl($request.referer) else . end)
		| distinctMangleBlocks($request)
	else
		.
	end
	| .count += $request.count;

reduce .[] as $request
(
	{
		origin: base,
		requestedUrls: base,
		requestedUrlsDistinct: distinctBase
	};
	. as $aggregated
	| .origin |= mangle($request.origin)
	| .requestedUrls = (
		reduce $request.requestedUrls[] as $requestedUrl
		(
			$aggregated.requestedUrls;
			mangle($requestedUrl)
		)
	)
	| .requestedUrlsDistinct |= distinctMangle($request.requestedUrlsDistinct)
)

| .origin.countDistinct = .origin.count
| .requestedUrls.countDistinct = .requestedUrls.count
| .requestedUrlsDistinct.countDistinct = .origin.count
EOF

cat | jq --slurp "$getAggregates"
