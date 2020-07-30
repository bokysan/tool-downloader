#!/usr/bin/env bash
set -e

declare SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source $SCRIPTPATH/functions.sh

# Do a multistage build
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

docker_login

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

		setup_default_platforms
		if [ -f "$build_env" ]; then
			eval "$(cat "$build_env" | egrep '^PLATFORMS=')"
		fi
		export PLATFORMS

		IMAGE_VERSION="$(echo "$VERSION" | sed -E 's/^v//' | sed -E 's/\+.*$//')"
		echo "**** $dockerfile / $IMAGE_VERSION$IS_LATEST ****"
		cmd="docker buildx build --push --platform $PLATFORMS --build-arg VERSION=$VERSION $(build_args "$build_env" "--build-arg ") -t boky/$toolname:$IMAGE_VERSION"
		if [ -n "$IS_LATEST" ]; then
			cmd="$cmd -t boky/$toolname:latest"
		fi
		cmd="$cmd -f $dockerfile $dockerdir"
		echo "$cmd"
		eval "$cmd"
#		if [ -n "$IS_LATEST" ]; then
#			docker tag boky/$toolname:$IMAGE_VERSION boky/$toolname:latest
#		fi
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



