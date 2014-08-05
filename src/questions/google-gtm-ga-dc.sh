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
					.original
					and (
						.original
						| contains("googletagmanager.com/gtm.js")
					)
				)
			)
		)
	)
)
| {
	origin: .origin.url.domain.original,
	requests: (
		.requestedUrls
		| map(
			select(
				.url
				and
				.url.original
				and
				.url.domain
				and
				.url.domain.original
			)
			| select(
				.url.domain.original
				| (
					contains("doubleclick")
					or
					contains("google")
				)
			)
			| .url.original
		)
	)
}
| .count = (.requests | length)
| .ga = (.requests | map(select(contains("analytics"))) | length)
| .dc = (.requests | map(select(contains("doubleclick"))) | length)
EOF

cat | jq "$getGoogleTagManagerDomainsAndRelatedUrls"
