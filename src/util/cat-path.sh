 #!/usr/bin/env bash
set -e

while read path;
do
	cat "$path"
done
