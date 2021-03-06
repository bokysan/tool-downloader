#!/usr/bin/env bash
set -e

declare SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source $SCRIPTPATH/functions.sh

# Do a multistage build
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

if [[ "$*" == *--push* ]]; then
	docker_login
fi

setup_default_platforms
docker buildx build --platform $PLATFORMS . $*
