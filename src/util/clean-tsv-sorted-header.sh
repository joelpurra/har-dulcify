#!/usr/bin/env bash
set -e

cat | sed -e '1s/^[[:digit:]][[:digit:]]--//g' -e '1s/	[[:digit:]][[:digit:]]--/	/g'
