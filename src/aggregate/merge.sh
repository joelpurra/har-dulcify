#!/usr/bin/env bash
set -e

read -d '' mergeHalfwayData <<-'EOF' || true
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

def mangle(halfway):
	halfway as $halfway
	| .classification |= mergeKeyCounterObjects($halfway.classification)
	| ."mime-type".types |= mergeKeyCounterObjects($halfway."mime-type".types)
	| ."mime-type".groups |= mergeKeyCounterObjects($halfway."mime-type".groups)
	| .status.codes |= mergeKeyCounterObjects($halfway.status.codes)
	| .status.groups |= mergeKeyCounterObjects($halfway.status.groups)
	| .url.domain.value |= mergeKeyCounterObjects($halfway.url.domain.value)
	| .url.domain."public-suffixes" |= mergeKeyCounterObjects($halfway.url.domain."public-suffixes")
	| .url.domain."primary-domain" |= mergeKeyCounterObjects($halfway.url.domain."primary-domain")
	| .referer.domain.value |= mergeKeyCounterObjects($halfway.referer.domain.value)
	| .referer.domain."public-suffixes" |= mergeKeyCounterObjects($halfway.referer.domain."public-suffixes")
	| .referer.domain."primary-domain" |= mergeKeyCounterObjects($halfway.referer.domain."primary-domain")
	| .blocks.disconnect.domains |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.domains) else . end)
	| .blocks.disconnect.organizations |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.organizations) else . end)
	| .blocks.disconnect.categories |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.categories) else . end)
	| .blocks.disconnect.raw |= (if . then mergeArrayToCounterArray($halfway.blocks.disconnect.raw) else . end)
	| .count += $halfway.count
	| .countDistinct += $halfway.countDistinct;

def mangleUrlGroup(halfwayUrls):
	halfwayUrls as $halfwayUrls
	| if . then
		if $halfwayUrls then
			.requestedUrls |= mangle($halfwayUrls.requestedUrls)
			| .requestedUrlsDistinct |= mangle($halfwayUrls.requestedUrlsDistinct)
		else
			.
		end
	else
		$halfwayUrls
	end;

def mangleGroup(halfway):
	halfway as $halfway
	| if . then
		if $halfway then
			.origin |= mangle($halfway.origin)
			| .unfilteredUrls |= mangleUrlGroup($halfway.unfilteredUrls)
			| .internalUrls |= mangleUrlGroup($halfway.internalUrls)
			| .externalUrls |= mangleUrlGroup($halfway.externalUrls)
		else
			.
		end
	else
		$halfway
	end;

reduce .[1:][] as $halfway
(
	.[0];
	.unfiltered |= mangleGroup($halfway.unfiltered)
	| .successfulOrigin |= mangleGroup($halfway.successfulOrigin)
)
EOF

cat | jq --slurp "$mergeHalfwayData"
