#!/usr/bin/env bash
set -e

read -d '' getAlexaRankStats <<-'EOF' || true
.successfulOrigin
| select(
	.origin.rank.alexa.highest > 0
)
| {
	domain: .origin.url.domain.value,
	domainAlexaRank: .origin.rank.alexa.domain,
	primaryDomain: .origin.url.domain."primary-domain",
	primaryDomainAlexaRank: .origin.rank.alexa."primary-domain",
	highestAlexaRank: .origin.rank.alexa.highest,
	organizationCount: (.externalUrls.requestedUrlsDistinct.blocks.disconnect.organizations | length),
}
EOF

cat | jq "$getAlexaRankStats"
