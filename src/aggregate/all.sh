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

def addToCounterArray(value):
	value as $value
	| if map(.value == $value) | any then
		map(
			if .value == $value then
				.count += 1
			else
				.
			end
		)
	else
		. + [
			{
				count: 1,
				value: $value
			}
		]
	end;

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
	| .original |= addToKeyCounterObject($domain.original | fallbackString)
	| .groups |= addArrayToKeyCounterObject(($domain.groups // []) | map(fallbackString));

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

def mangle(request):
	request as $request
	| mangleClassification($request)
	| ."mime-type" |= mangleMimeType($request."mime-type")
	| .status |= addToKeyCounterObject($request.status | toStringOrFallbackString)
	| .url |= mangleUrl($request.url | fallbackString)
	| .referer |= (if $request.referer then mangleUrl($request.referer) else . end)
	| mangleBlocks($request)
	| .count += 1;

reduce .[] as $request
(
	{
		origin: base,
		requestedUrls: base
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
)
EOF

cat | jq --slurp "$getAggregates"
