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
	| .url.domain.original |= mergeKeyCounterObjects($halfway.url.domain.original)
	| .url.domain.groups |= mergeKeyCounterObjects($halfway.url.domain.groups)
	| .referer.domain.original |= mergeKeyCounterObjects($halfway.referer.domain.original)
	| .referer.domain.groups |= mergeKeyCounterObjects($halfway.referer.domain.groups)
	| .blocks.disconnect.domains |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.domains) else . end)
	| .blocks.disconnect.organizations |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.organizations) else . end)
	| .blocks.disconnect.categories |= (if . then mergeKeyCounterObjects($halfway.blocks.disconnect.categories) else . end)
	| .blocks.disconnect.raw |= (if . then mergeArrayToCounterArray($halfway.blocks.disconnect.raw) else . end)
	| .count += $halfway.count
	| .countDistinct += $halfway.countDistinct;

reduce .[1:][] as $halfway
(
	.[0];
	.origin |= mangle($halfway.origin)
	| .requestedUrls |= mangle($halfway.requestedUrls)
	| .requestedUrlsDistinct |= mangle($halfway.requestedUrlsDistinct)
)
EOF

cat | jq --slurp "$mergeHalfwayData"
