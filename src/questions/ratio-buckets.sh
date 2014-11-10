#!/usr/bin/env bash
set -e

read -d '' getRatioBuckets <<-'EOF' || true
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
	}
else
	{
		requestCount: 0
	}
end
| .isNonFailedDomain = $isNonFailedDomain
EOF

cat | jq "$getRatioBuckets"
