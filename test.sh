#!/usr/bin/env bash
set -e

docker build -t boky/tool-downloader .

build_args() {
	local build_env="$1"
	local prefix="$2"
	local name
	local val

	if [ -f "$build_env" ]; then
		cat "$build_env" \
			| sed -e '/^[ \t]*#/d' \
			| sed -E "s/'/\\\\\'/g" \
			| sed -E 's/^([A-Za-z_][A-Za-z0-9_-]+)=(.+)$/\1='"'"'\2'"'"'/' \
			| sed -E "s/^/$prefix/g" \
			| sed -e ':a' -e 'N' -e '$!ba' -e "s/\n/ /g" \
			| cat
	fi
}

do_it() {
		if [ -d "$1" ]; then
			for i in $1/Dockerfile*; do
				do_it "$i"
			done
			return
		fi

		local dockerfile="$1"
		local dockerdir="$(dirname "$dockerfile")"
		local toolname="$(basename "$dockerdir")"
		local VERSION="$(echo "$dockerfile" | cut -f2- -d.)"
		local IS_LATEST
		local build_env="$dockerdir/build.env"
		local cmd
		local IMAGE_VERSION

		if [ "$dockerfile" == "$VERSION" ]; then
			IS_LATEST=" (latest)"
			cmd="env $(build_args "$build_env") ./files/tool-downloader.sh --echo-version"
			echo $cmd
			VERSION="$(eval "$cmd")"
		fi
		export VERSION

		IMAGE_VERSION="$(echo "$VERSION" | sed -E 's/^v//' | sed -E 's/\+.*$//')"
		echo "**** $dockerfile / $IMAGE_VERSION$IS_LATEST ****"
		# --env-file <( env | cut -f1 -d= )
		cmd="docker build --build-arg VERSION=$VERSION $(build_args "$build_env" "--build-arg ") -t tools/$toolname:$IMAGE_VERSION -f $dockerfile $dockerdir"
		echo "$cmd"
		eval "$cmd"
		if [ -n "$IS_LATEST" ]; then
			docker tag tools/$toolname:$IMAGE_VERSION tools/$toolname:latest
		fi
}

if [ "$#" -gt 0 ]; then
	while [ "$1" != "" ]; do
		do_it "$1"
		shift
	done
else
	for i in tests/*; do
		if [ -d "$i" ]; then
			do_it "$i"
		fi
	done
fi
