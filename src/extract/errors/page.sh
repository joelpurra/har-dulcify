#!/usr/bin/env bash
set -e

cat | jq 'select(.log.comment | length > 0)'
