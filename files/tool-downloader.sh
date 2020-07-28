#!/bin/sh
set -e

if [ -z "${PROJECT}" ]; then
	echo "Please define at least the GitHub project name, e.g. xetys/hetzner-kube"
	exit 1
fi

if [ -z "${DOWNLOAD_TEMPLATE}" ]; then
	DOWNLOAD_TEMPLATE='https://github.com/${PROJECT}/releases/download/${VERSION}/${NAME}-${VERSION}-${GOOS}-${GOARCH}${GOEXT}'
fi

if [ -z "${NAME}" ]; then
	NAME="$(echo "${PROJECT}" | cut -f2- -d/)"
fi

if [ -z "${CURL_OPTS}" ]; then
	CURL_OPTS="--retry 5 --retry-connrefused --max-time 300 --connect-timeout 10 -fsSL"
fi

if [ -z "${VERSION}" ]; then
	if [ -z "${VERSION_TEMPLATE}" ]; then
		VERSION_TEMPLATE='https://api.github.com/repos/${PROJECT}/releases/latest'
	fi
	VERSION_URL="$(eval echo "${VERSION_TEMPLATE}")"
	VERSION=$(curl ${CURL_OPTS} ${VERSION_URL} | jq -r '.tag_name')
fi

GOOS="$(uname -s | tr '[:upper:]' '[:lower:]')"
GOEXT=""
if [ -n "${TARGETPLATFORM}" ]; then
	GOARM=$(echo "${TARGETPLATFORM}" | cut -f3 -d/ | cut -c2-)
	GOARCH=$(echo "${TARGETPLATFORM}" | cut -f2 -d/)
fi

if [ -z "${GOARCH}" ]; then
	GOARCH="$(uname -m)"
fi

if [ "${GOARCH}" == "x86_64" ]; then
	GOARCH="amd64"
elif [ "${GOARCH}" == "i386" ]; then
	GOARCH="386"
fi

if [ "${GOARCH}" = "*64" ]; then
	GOBITS=64
elif [ "${GOARCH}" = "*32" ]; then
	GOBITS=32
elif [ -n "${GOARM}" ] && [ "${GOARM}" -gt 7 ]; then
	GOBITS=64
elif [ -n "${GOARM}" ] && [ "${GOARM}" -lt 8 ]; then
	GOBITS=32
elif [ "${GOARCH}" == "arm5" ] || [ "${GOARCH}" == "arm6" ] || [ "${GOARCH}" == "arm7" ]; then
	GOBITS=32
elif [ "${GOARCH}" == arm* ]; then
	GOBITS=64
fi


OSARCHIVE=".tar.gz"
if [ "${GOOS}" == "windows" ]; then
	GOEXT=".exe"
	OSARCHIVE=".zip"
fi

DOWNLOAD_URL="$(eval echo "${DOWNLOAD_TEMPLATE}")"
echo "Downloading ${PROJECT} from ${DOWNLOAD_URL}..."

cd /tmp
if [ "${DOWNLOAD_URL}" == *.tar.gz ] || [ "${DOWNLOAD_URL}" == *.tgz ]; then
	curl ${CURL_OPTS} ${DOWNLOAD_URL} | tar xz
elif [ "${DOWNLOAD_URL}" == *.zip ]; then
	curl ${CURL_OPTS} ${DOWNLOAD_URL} | -o /tmp/${NAME}.zip
	unzip /tmp/${NAME}.zip
	rm /tmp/${NAME}.zip
else
	curl ${CURL_OPTS} ${DOWNLOAD_URL} -o /tmp/${NAME}
fi

if [ -f /tmp/${NAME} ]; then
	mv /tmp/${NAME} /usr/bin
	chmod +x /usr/bin/${NAME}
	chown root:root /usr/bin/${NAME}
	echo "Installed into /usr/bin/${NAME}"
else
	echo "Don't know how to install. Please install manually."
	ls -la /tmp
fi
