#!/bin/bash
set -e

while read harpath;
do
	cat "$harpath" | jq '[ .log.entries[].request.url ]'
done
