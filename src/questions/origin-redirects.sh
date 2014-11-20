#!/usr/bin/env bash
set -e

# See if domains with requests to google tag manager also have other google requests, and analytics in particular.
read -d '' getOriginWithRedirects <<-'EOF' || true
def over0:
	if . > 0 then
		1
	else
		0
	end;

def over(n):
	(. - n) | over0;

def over1:
	over(1);

def boolToInt:
	if . == true then
		1
	elif . == false then
		0
	else
		null
	end;

def deepCoverage:
	with_entries(
		if (.value | type) == "number" then
			.value |= over0
		else
			.value |= deepCoverage
		end
	);

def changeAt(index; f):
	index as $index
	| reduce .[] as $item (
		{
			currentIndex: 0,
			result: []
		};
		if .currentIndex == $index then
			.result += [ $item | f ]
		else
			.result += [ $item ]
		end
		| .currentIndex += 1
	)
	| .result;

def requestHasRedirect:
	.status
	and .status.group == "3xx"
	# The 304 status isn't a redirect
	and .status.code != 304;

def urlsAreFairlyEqualInnerComparison(right):
	. as $left
	| right as $right
	| (
		($left + "/") == $right
		or
		(
			(
				$left
				| split("?")
				| .[0] + "/?" + (.[1:] | join("?"))
			) == $right
		)
	);

def urlsAreFairlyEqual(right):
	. as $left
	| right as $right
	| (
		($left | type) == "string"
		and
		($right | type) == "string"
		and
		(
			$left == $right
			or
			($left | urlsAreFairlyEqualInnerComparison($right))
			or
			# The other way around
			($right | urlsAreFairlyEqualInnerComparison($left))
		)
	);

def redirectClassificationCount(prop):
	.originRedirectChain
	| map(
		select(
			.classification
			and (
				.classification
				| (prop == true)
			)
		)
	)
	| length;

def redirectClassificationCoverage(prop):
	.originRedirectChain
	| map(
		.classification
		and (
			.classification
			| (prop == true)
		)
	)
	| (length > 0) and all
	| boolToInt;

def addRedirectStuff(request):
	request as $request
	| if (.previousRedirect | urlsAreFairlyEqual($request.url.value)) then
		.previousRedirect = $request.redirect.value
		| .collected |= changeAt(
			length - 1;
			. + {
				classification: $request.classification
			}
		)
	else
		.
	end
	| if (.collect == true) and ($request | requestHasRedirect) then
		.collected += [
			{
				redirect: $request.redirect
			}
		]
	else
		# TODO: is there a way to stop the reduction?
		.collect = false
	end;

def getFinalIsSecure:
	.originRedirectChain
	and (
		.originRedirectChain
		| length > 0
		and (
			.[-1:][0]
			| (
				.classification
				and .classification.isSecure
			)
		)
	);

(.origin and .origin.classification and .origin.classification.isFailed == false) as $isNonFailedDomain
| if (.origin and (.origin | requestHasRedirect)) then
	.origin as $origin
	| {
		origin: (
			$origin
			| {
				url,
				classification
			}
		),
		originRedirectChain: (
			.requestedUrls
			| reduce .[] as $request (
				{
					collect: true,
					collected: [
						{
							redirect: $origin.redirect
						}
					],
					previousRedirect: $origin.redirect.value
				};
				addRedirectStuff($request)
			)
			| .collected
		)
	}
	| .count = (.originRedirectChain | length)

	# TODO: avoid having to explicitly list these classification properties?
	| .counts.isSameDomain = redirectClassificationCount(.isSameDomain)
	| .counts.isSubdomain = redirectClassificationCount(.isSubdomain)
	| .counts.isSuperdomain = redirectClassificationCount(.isSuperdomain)
	| .counts.isSamePrimaryDomain = redirectClassificationCount(.isSamePrimaryDomain)
	| .counts.isInternalDomain = redirectClassificationCount(.isInternalDomain)
	| .counts.isExternalDomain = redirectClassificationCount(.isExternalDomain)
	| .counts.isDisconnectMatch = redirectClassificationCount(.isDisconnectMatch)
	| .counts.isSecure = redirectClassificationCount(.isSecure)
	| .counts.isInsecure = redirectClassificationCount(.isInsecure)
	# hasMissingClassification is a debugging counter, to check if any redirects didn't have a matching subsequent request.
	| .counts.hasMissingClassification = (.originRedirectChain | map(select(has("classification") | not)) | length)

	| .coverage = (.counts | deepCoverage)
	| .coverage.mixedInternalAndExternal = ((.coverage.isInternalDomain + .coverage.isExternalDomain) | over1)
	| .coverage.mixedSecurity = ((.coverage.isSecure + .coverage.isInsecure) | over1)
	| .coverage.finalIsSecure = (getFinalIsSecure | boolToInt)

	| .all.isSameDomain = redirectClassificationCoverage(.isSameDomain)
	| .all.isSubdomain = redirectClassificationCoverage(.isSubdomain)
	| .all.isSuperdomain = redirectClassificationCoverage(.isSuperdomain)
	| .all.isSamePrimaryDomain = redirectClassificationCoverage(.isSamePrimaryDomain)
	| .all.isInternalDomain = redirectClassificationCoverage(.isInternalDomain)
	| .all.isExternalDomain = redirectClassificationCoverage(.isExternalDomain)
	| .all.isDisconnectMatch = redirectClassificationCoverage(.isDisconnectMatch)
	| .all.isSecure = redirectClassificationCoverage(.isSecure)
	| .all.isInsecure = redirectClassificationCoverage(.isInsecure)
	| .all.hasMissingClassification = ((.counts.hasMissingClassification == .count) | boolToInt)
else
	{
		count: 0
	}
end
| .isNonFailedDomain = $isNonFailedDomain
EOF

cat | jq "$getOriginWithRedirects"
