#!/usr/bin/env bash
# vim: ts=2:sw=2:noexpandtab:nosmarttab
set -e

declare GOARCH
declare GOARM
declare GOOS
declare GOEXT
declare GOBITS
declare GOPROC
declare GOOS_ARCHIVE_STYLE
declare IS_ONLY_VERSION
declare IS_ONLY_DOWNLOAD_URL

semversort() {
	cat | \
		sed -E 's/^(.*)$/\1~~~~~~~~~~/' | \
		sort --version-sort | \
		sed -E 's/~~~~~~~~~~$//'
}

error() {
	printf "ERROR " >&2
	echo "$@" >&2
}

die() {
	local _ret=$1
	test -n "$_ret" || _ret=1
	shift
	error $@
	exit ${_ret}
}

parse_arguments() {
	while (( "$#" )); do
		_key="$1"
		case "$_key" in
			--)
				# Stop processsing more arguments
				shift
				break
				;;
			-e|--echo-version)
				IS_ONLY_VERSION="1"
				;;
			-E|--echo-download-url)
				IS_ONLY_DOWNLOAD_URL="1"
				;;
			-p|--project)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				PROJECT="$2"
				shift
				;;
			--project=*)
				PROJECT="${_key##--project=}"
				shift
				;;
			-D|--download-template)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				DOWNLOAD_TEMPLATE="$2"
				shift
				;;
			--download-template=*)
				DOWNLOAD_TEMPLATE="${_key##--download-template=}"
				shift
				;;
			-n|--name)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				NAME="$2"
				shift
				;;
			--name=*)
				NAME="${_key##--name=}"
				shift
				;;
			-c|--curl-opts)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				CURL_OPTS="$2"
				shift
				;;
			--curl-opts=*)
				CURL_OPTS="${_key##--curl-opts=}"
				shift
				;;
			-v|--version)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				VERSION="$2"
				shift
				;;
			--version=*)
				VERSION="${_key##--version=}"
				shift
				;;
			-V|--version-template)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				VERSION_TEMPLATE="$2"
				shift
				;;
			--version-template=*)
				VERSION_TEMPLATE="${_key##--version-template=}"
				shift
				;;
			-E|--verify-command)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				VERIFY_COMMAND="$2"
				shift
				;;
			--verify-command=*)
				VERIFY_COMMAND="${_key##--verify-command=}"
				shift
				;;
			-i|--pre-install)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				PRE_INSTALL="$2"
				shift
				;;
			--pre-install=*)
				PRE_INSTALL="${_key##--pre-install=}"
				shift
				;;
			-I|--post-install)
				test $# -lt 2 && die 1 "Missing value for argument '$_key'."
				POST_INSTALL="$2"
				shift
				;;
			--post-install=*)
				POST_INSTALL="${_key##--post-install=}"
				shift
				;;
			*)
				die 2 "Invalid argument: $_key"
		esac
		shift
	done
}

setup_initial_variables() {
	if [[ -z "${PROJECT}" ]]; then
		echo "Please define at least the GitHub project name, e.g. xetys/hetzner-kube"
		exit 1
	fi

	if [[ -z "${DOWNLOAD_TEMPLATE}" ]]; then
		DOWNLOAD_TEMPLATE='https://github.com/${PROJECT}/releases/download/${VERSION}/${NAME}-${VERSION}-${GOOS}-${GOARCH}${GOEXT}'
	fi

	if [[ -z "${NAME}" ]]; then
		NAME="$(echo "${PROJECT}" | cut -f2- -d/)"
	fi

	if [[ -z "${CURL_OPTS}" ]]; then
		CURL_OPTS="--retry 5 --retry-connrefused --max-time 300 --connect-timeout 10 -fsSL"
		if curl --help | fgrep -q -- --retry-all-errors; then
			CURL_OPTS="${CURL_OPTS} --retry-all-errors"
		fi
	fi

	if [[ -z "${VERSION_TEMPLATE}" ]]; then
		VERSION_TEMPLATE='https://api.github.com/repos/${PROJECT}/releases'
	fi
}

setup_environment_variables () {
	if [[ -z "${GOOS}" ]]; then
		GOOS="$(uname -s | tr '[:upper:]' '[:lower:]')"
	fi
	GOEXT=""
	if [[ -n "${TARGETPLATFORM}" ]]; then
		GOARM=$(echo "${TARGETPLATFORM}" | cut -f3 -d/ | cut -c2-)
		GOARCH=$(echo "${TARGETPLATFORM}" | cut -f2 -d/)
	fi

	if [[ -z "${GOARCH}" ]]; then
		GOARCH="$(uname -m)"
	fi

	if command -v getconf >/dev/null 2>&1; then
		GOBITS="$(getconf LONG_BIT)"
	fi

	if [[ -z "${GOBITS}" ]]; then
		if [[ "${GOARCH}" == *64 ]]; then
			GOBITS=64
		elif [[ "${GOARCH}" == *32 ]]; then
			GOBITS=32
		elif [[ -n "${GOARM}" ]] && [[ "${GOARM}" -gt 7 ]]; then
			GOBITS=64
		elif [[ -n "${GOARM}" ]] && [[ "${GOARM}" -lt 8 ]]; then
			GOBITS=32
		elif [[ "${GOARCH}" == "arm5" ]] || [[ "${GOARCH}" == "arm6" ]] || [[ "${GOARCH}" == "arm7" ]]; then
			GOBITS=32
		elif [[ "${GOARCH}" == "armv5" ]] || [[ "${GOARCH}" == "armv6" ]] || [[ "${GOARCH}" == "armv7" ]] || [[ "${GOARCH}" == "armv7l" ]]; then
			GOBITS=32
		elif [[ "${GOARCH}" == arm* ]]; then
			GOBITS=64
		fi
	fi

	if [[ "${GOARCH}" == "x86_64" ]]; then
		# Docker will not emulate 32-bit architecture
		# and will show x86_64 even when running a 32-bit OS.
		# Hence we need additional checks here to make sure
		# we're really running on 32-bit OS.

		if [[ -n "${GOBITS}" ]]; then
			if [[ "${GOBITS}" == "32" ]]; then
				GOARCH="386"
			fi
		elif command -v dpkg >/dev/null 2>&1; then
			GOARCH="$(dpkg --print-architecture)"
		fi
	fi

	if [[ "${GOARCH}" == "x86_64" ]] || [[ "${GOARCH}" == "aarch64" ]]; then
		GOARCH="amd64"
	elif [[ "${GOARCH}" == "i386" ]] || [[ "${GOARCH}" == "i486" ]] || [[ "${GOARCH}" == "i586" ]] || [[ "${GOARCH}" == "i686" ]]; then
		GOARCH="386"
	fi

	if [[ "${GOARCH}" == "arm64" ]]; then
		GOPROC="${GOARCH}"
	elif [[ "${GOARCH}" == arm* ]]; then
		GOPROC="arm"
	else
		GOPROC="${GOARCH}"
	fi

	GOOS_ARCHIVE_STYLE=".tar.gz"
	if [[ "${GOOS}" == "windows" ]]; then
		GOEXT=".exe"
		GOOS_ARCHIVE_STYLE=".zip"
	fi
}


get_version() {
	if [[ -z "${VERSION}" ]]; then
		# Get the latest version
		VERSION_URL="$(eval echo "${VERSION_TEMPLATE}")"
		VERSIONS="$(curl ${CURL_OPTS} ${VERSION_URL} | jq -r -c '.[] | select( .prerelease == false and .draft == false ) | .tag_name')"
		VERSIONS="$(echo "$VERSIONS" | semversort | tac)"
		VERSION="$(echo "$VERSIONS" | head -n1)"
	fi
}

get_download_url() {
	if [[ -z "${DOWNLOAD_URL}" ]]; then
		DOWNLOAD_URL="$(eval echo "${DOWNLOAD_TEMPLATE}")"
	fi
}

download() {
	cd /tmp
	if echo "${DOWNLOAD_URL}" | egrep -iq '.*\.(tar\.gz|tgz)$'; then
		echo "Extracting ${PROJECT} from ${DOWNLOAD_URL}..."
		curl ${CURL_OPTS} ${DOWNLOAD_URL} | tar xz
	elif echo "${DOWNLOAD_URL}" | egrep -iq '.*\.(zip)$'; then
		echo "Extracting ${PROJECT} from ${DOWNLOAD_URL}..."
		curl ${CURL_OPTS} ${DOWNLOAD_URL} -o /tmp/${NAME}.zip
		unzip /tmp/${NAME}.zip
		rm /tmp/${NAME}.zip
	else
		echo "Downloading ${PROJECT} from ${DOWNLOAD_URL}..."
		curl ${CURL_OPTS} ${DOWNLOAD_URL} -o /tmp/${NAME}
	fi
}

install() {
	if [[ -n "${PRE_INSTALL}" ]]; then
		eval "${PRE_INSTALL}"
	fi

	if [[ -f /tmp/${NAME} ]]; then
		mv /tmp/${NAME} /usr/local/bin
		chmod +x /usr/local/bin/${NAME}
		chown root:root /usr/local/bin/${NAME}
		echo "Installed into /usr/local/bin/${NAME}"
	else
		echo "Don't know how to install. Please install manually."
		ls -la /tmp
	fi

	if [[ -n "${POST_INSTALL}" ]]; then
		eval "${POST_INSTALL}"
	fi
}

verify() {
	if [[ -n "${VERIFY_COMMAND}" ]]; then
		eval "${VERIFY_COMMAND}"
	fi
}

parse_arguments $@
setup_initial_variables
setup_environment_variables
get_version

if [[ -n "${IS_ONLY_VERSION}" ]]; then
	echo "$VERSION"
	exit 0
fi

get_download_url

if [[ -n "${IS_ONLY_DOWNLOAD_URL}" ]]; then
	echo "$DOWNLOAD_URL"
	exit 0
fi

download
install
verify
