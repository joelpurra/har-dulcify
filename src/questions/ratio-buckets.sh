#!/usr/bin/env bash
set -e

read -d '' getRatioBuckets <<-'EOF' || true
# def over0:
# 	if . > 0 then
# 		1
# 	else
# 		0
# 	end;

# def over(n):
# 	(. - n) | over0;

# def over1:
# 	over(1);

# def boolToInt:
# 	if . == true then
# 		1
# 	elif . == false then
# 		0
# 	else
# 		null
# 	end;

# def deepCoverage:
# 	with_entries(
# 		if (.value | type) == "number" then
# 			.value |= over0
# 		else
# 			.value |= deepCoverage
# 		end
# 	);

def requestClassificationCount(prop):
	.requestedUrls
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

# def requestClassificationCoverage(prop):
# 	.requestedUrls
# 	| map(
# 		.classification
# 		and (
# 			.classification
# 			| (prop == true)
# 		)
# 	)
# 	| (length > 0) and all
# 	| boolToInt;

(.origin and .origin.classification and .origin.classification.isFailed == false) as $isNonFailedDomain
| if $isNonFailedDomain then
	. as $root
	| {
		requestCount: (.requestedUrls | length),
		counts: {
			# TODO: avoid having to explicitly list these classification properties?
			isSameDomain: requestClassificationCount(.isSameDomain),
			isSubdomain: requestClassificationCount(.isSubdomain),
			isSuperdomain: requestClassificationCount(.isSuperdomain),
			isSamePrimaryDomain: requestClassificationCount(.isSamePrimaryDomain),
			isInternalDomain: requestClassificationCount(.isInternalDomain),
			isExternalDomain: requestClassificationCount(.isExternalDomain),
			isSecure: requestClassificationCount(.isSecure),
			isInsecure: requestClassificationCount(.isInsecure),
		},
		# all: {
		# 	# TODO: avoid having to explicitly list these classification properties?
		# 	isSameDomain: requestClassificationCoverage(.isSameDomain),
		# 	isSubdomain: requestClassificationCoverage(.isSubdomain),
		# 	isSuperdomain: requestClassificationCoverage(.isSuperdomain),
		# 	isSamePrimaryDomain: requestClassificationCoverage(.isSamePrimaryDomain),
		# 	isInternalDomain: requestClassificationCoverage(.isInternalDomain),
		# 	isExternalDomain: requestClassificationCoverage(.isExternalDomain),
		# 	isSecure: requestClassificationCoverage(.isSecure),
		# 	isInsecure: requestClassificationCoverage(.isInsecure),
		# },
	}
	# | .coverage = (.counts | deepCoverage)
else
	{
		requestCount: 0
	}
end
| .isNonFailedDomain = $isNonFailedDomain
EOF

cat | jq "$getRatioBuckets"
