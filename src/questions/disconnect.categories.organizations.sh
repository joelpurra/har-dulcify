#!/usr/bin/env bash
set -e

disconnectClassificationFile="$1"

read -d '' expandDisconnectDomains <<-'EOF' || true
def matchSingleDisconnect:
	# Match the domain to disconnect's list.
	. as $domain
	| if $disconnect | has($domain) then
		$disconnect[$domain]
	else
		empty
	end;

def domainWithValue:
	{
		(.domains): .value
	};

.successfulOrigin.externalUrls.requestedUrlsDistinct.coverage.blocks.domains
| with_entries(
	. as $entry
	| .value |= (
		($entry.key | matchSingleDisconnect)
		+ {
			value: $entry.value
		}
	)
)
| with_entries(
	.value.domains = .key
)
| to_entries
| map(.value)
| group_by(.categories)
| map(
	group_by(.organizations)
	| map(
		reduce .[1:][] as $item (
			.[0]
			| .domains = domainWithValue;
			.domains += ($item | domainWithValue)
			| .value += $item.value
		)
		| .domains |= (
			to_entries
			| sort_by(.value)
			| reverse
			| from_entries
		)
	)
	| sort_by(.value)
	| reverse
)
EOF

cat | jq "$expandDisconnectDomains" --argfile "disconnect" "$disconnectClassificationFile"
