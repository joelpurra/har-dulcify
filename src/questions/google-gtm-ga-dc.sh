#!/usr/bin/env bash
set -e

# See if domains with requests to google tag manager also have other google requests, and analytics in particular.
read -d '' getGoogleTagManagerDomainsAndRelatedUrls <<-'EOF' || true
select(
	.requestedUrls
	and
	reduce .requestedUrls[] as $item
	(
		false;
		.
		or
		(
			$item
			| .url
			and (
				.url
				| (
					.valid
					and
					.value
					and (
						.value
						| contains("googletagmanager.com/gtm.js")
					)
				)
			)
		)
	)
)
| {
	origin: .origin.url.domain.value,
	requests: (
		.requestedUrls
		| map(
			select(
				.url
				and
				.url.value
				and
				.url.domain
				and
				.url.domain.value
			)
			| select(
				.url.domain.value
				| (
					contains("doubleclick")
					or
					contains("google")
				)
			)
			| .url.value
		)
	)
}
| .count = (.requests | length)
| .ga = (.requests | map(select(contains("analytics"))) | length)
| .dc = (.requests | map(select(contains("doubleclick"))) | length)
EOF

cat | jq "$getGoogleTagManagerDomainsAndRelatedUrls"
