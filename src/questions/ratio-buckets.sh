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

def disconnectUrls:
	.requestedUrls
	| map(
		select(
			.blocks
			and .blocks.disconnect
			and (
				.blocks.disconnect
				| (length > 0)
			)
		)
	);

def disconnectUrlEntries:
	[ .[].blocks.disconnect[] ];

def requestDisconnectCount(prop):
	map(prop)
	| unique
	| length;

(.origin and .origin.classification and .origin.classification.isFailed == false) as $isNonFailedDomain
| if $isNonFailedDomain then
	. as $root
	| disconnectUrls as $disconnectUrls
	| ($disconnectUrls | disconnectUrlEntries) as $disconnectUrlEntries
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

			isDisconnect: ($disconnectUrls | length),
		},
		uniqueCounts: {
			disonnectDomains: ($disconnectUrlEntries | requestDisconnectCount(.domain)),
			disonnectOrganizations: ($disconnectUrlEntries | requestDisconnectCount(.organizations)),
			disonnectCategories: ($disconnectUrlEntries | requestDisconnectCount(.categories)),
		}
	}
else
	{
		requestCount: 0
	}
end
| .isNonFailedDomain = $isNonFailedDomain
EOF

cat | jq "$getRatioBuckets"
