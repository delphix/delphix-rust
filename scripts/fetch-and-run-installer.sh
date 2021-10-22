#!/bin/bash
#
# Copyright 2021 Delphix
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -o xtrace

BASEURL="https://artifactory.delphix.com/artifactory/linux-pkg/rust"

function die() {
	echo "$(basename "$0"): $*" >&2
	exit 1
}

function usage() {
	echo "$(basename "$0"): $*" >&2
	echo "Usage: $(basename "$0") <version> <prefix> <destdir>"
	exit 2
}

function cleanup() {
	[[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

[[ $# -gt 3 ]] && usage "too many arguments specified"
[[ $# -lt 3 ]] && usage "too few arguments specified"

VERSION="$1"
PREFIX="$2"
DESTDIR="$3"

RUST="rust-${VERSION}-x86_64-unknown-linux-gnu"

[[ -z "$VERSION" ]] && usage "version not specified."
[[ -z "$PREFIX" ]] && usage "prefix not specified."
[[ -z "$DESTDIR" ]] && usage "destdir not specified."

#
# The full path is required, so DESTDIR can be used after calling "pushd" below.
#
DESTDIR="$(readlink -f "$DESTDIR")"
mkdir -p "${DESTDIR}" || die "'mkdir -p \"${DESTDIR}\"' failed"

curl -v https://keybase.io/rust/pgp_keys.asc | gpg --import ||
	die "failed to import GPG key"

trap cleanup EXIT

TEMP_DIR="$(mktemp -d -t delphix-rust.XXXXXXX)"
[[ -d "$TEMP_DIR" ]] || die "failed to create temporary directory '$TEMP_DIR'"
pushd "$TEMP_DIR" &>/dev/null || die "'pushd $TEMP_DIR' failed"

wget -nv "${BASEURL}/${RUST}.tar.gz" || die "failed to download tarfile"
wget -nv "${BASEURL}/${RUST}.tar.gz.asc" || die "failed to download signature"
gpg --verify "${RUST}.tar.gz.asc" "${RUST}.tar.gz" ||
	die "failed to verify signature"

tar -xvf "${RUST}.tar.gz" || die "failed to extract tarfile"
"./${RUST}/install.sh" --verbose --disable-ldconfig \
	--prefix="${PREFIX}" --destdir="$DESTDIR" ||
	die "failed to install; 'prefix=${PREFIX}' and 'destdir=${DESTDIR}'"

popd &>/dev/null || die "'popd' failed"
