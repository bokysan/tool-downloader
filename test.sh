#!/bin/sh
set -e

docker build -t boky/tool-downloader .

if [ "$#" -gt 0 ]; then
	while [ "$1" != "" ]; do
		docker run --env-file "$1" --rm -t boky/tool-downloader tool-downloader
		shift
	done
else
	for i in tests/*.env; do
		echo "**** $i ****"
		docker run --env-file "$i" --rm -t boky/tool-downloader tool-downloader
	done
fi
