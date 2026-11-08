#!/usr/bin/env bash
# Repackages the amd64 and arm64 release RPMs of one OpenTubeX release.
# Usage: build-packages.sh SOURCE_DIRECTORY OUTPUT_DIRECTORY ASSET_VERSION

set -euo pipefail

source_directory=$1
output_directory=$2
asset_version=$3

if [[ ! "$asset_version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(beta|nightly-([0-9]+))$ ]]; then
  printf 'Expected a beta or nightly asset version, got: %s\n' "$asset_version" >&2
  exit 1
fi

# Nightlies are built after the release they are numbered after, so
# 0.37.0.nightly.2527 must sort between the 0.37.0 and 0.37.1 releases.
rpm_version=${BASH_REMATCH[1]}
if [[ -n "${BASH_REMATCH[3]}" ]]; then
  rpm_version+=".nightly.${BASH_REMATCH[3]}"
fi

build_directory=$(mktemp -d)
trap 'rm -rf -- "$build_directory"' EXIT
mkdir -p "$build_directory/SOURCES" "$build_directory/SPECS"

cp "$source_directory/opentubex-${asset_version}.amd64.rpm" \
  "$source_directory/opentubex-${asset_version}.arm64.rpm" \
  "$build_directory/SOURCES/"

sed -e "s/@RPM_VERSION@/$rpm_version/g" \
  -e "s/@ASSET_VERSION@/$asset_version/g" packaging/copr/opentubex.spec \
  > "$build_directory/SPECS/opentubex.spec"

# Keep the release notes that the OpenTubeX release build recorded in its RPM.
changelog=$(rpm --query --package --changelog "$source_directory/opentubex-${asset_version}.amd64.rpm")
if [[ -n "$changelog" ]]; then
  printf '\n%%changelog\n%s\n' "${changelog//%/%%}" >> "$build_directory/SPECS/opentubex.spec"
fi

# One package per architecture serves Fedora, Enterprise Linux, and openSUSE,
# so it carries no distribution tag.
for architecture in x86_64 aarch64; do
  rpmbuild -bb \
    --nodeps \
    --target "$architecture" \
    --define "_topdir $build_directory" \
    --define 'dist %{nil}' \
    "$build_directory/SPECS/opentubex.spec"
done

mkdir -p "$output_directory"
cp "$build_directory"/RPMS/*/*.rpm "$output_directory/"
