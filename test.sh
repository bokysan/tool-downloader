#!/bin/sh
set -e

docker build -t boky/tool-downloader .

for i in tests/*.env; do
	echo "**** $i ****"
	docker run --env-file $i --rm -t boky/tool-downloader tool-downloader
done

