#!/usr/bin/env bash

set -euo pipefail

source_directory=${1:-release-files}
output_directory=${2:-distribution-files}
asset_version=${3:-}
distribution=${4:-}

if [[ ! "$asset_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-(beta|nightly-[0-9]+)$ ]]; then
  printf 'Expected a beta or nightly asset version, got: %s\n' "$asset_version" >&2
  exit 1
fi

case "$distribution" in
  fedora)
    rpm_defines=()
    ;;
  opensuse)
    rpm_defines=(--define 'suse_version 160000' --define 'dist .opensuse')
    ;;
  *)
    printf 'Expected distribution to be fedora or opensuse, got: %s\n' "$distribution" >&2
    exit 1
    ;;
esac

for source_name in \
  "opentubex-${asset_version}.amd64.rpm" \
  "opentubex-${asset_version}.arm64.rpm"; do
  if [[ ! -f "$source_directory/$source_name" ]]; then
    printf 'Source package does not exist: %s\n' "$source_directory/$source_name" >&2
    exit 1
  fi
done

if [[ -z "$output_directory" || "$output_directory" == '/' || "$output_directory" == '.' ]]; then
  printf 'Unsafe output directory: %s\n' "$output_directory" >&2
  exit 1
fi

build_directory=$(mktemp -d)
trap 'rm -rf -- "$build_directory"' EXIT

mkdir -p \
  "$build_directory/BUILD" \
  "$build_directory/BUILDROOT" \
  "$build_directory/RPMS" \
  "$build_directory/SOURCES" \
  "$build_directory/SPECS" \
  "$build_directory/SRPMS"

cp "$source_directory/opentubex-${asset_version}.amd64.rpm" \
  "$source_directory/opentubex-${asset_version}.arm64.rpm" \
  "$build_directory/SOURCES/"

mapfile -t package_versions < <(
  rpm --query --package --queryformat '%{VERSION}\n' \
    "$source_directory/opentubex-${asset_version}.amd64.rpm" \
    "$source_directory/opentubex-${asset_version}.arm64.rpm" | sort -u
)
if (( ${#package_versions[@]} != 1 )); then
  printf 'Source packages do not have one common RPM version\n' >&2
  exit 1
fi

sed -e "s/@RPM_VERSION@/${package_versions[0]}/g" \
  -e "s/@ASSET_VERSION@/$asset_version/g" packaging/copr/opentubex.spec \
  > "$build_directory/SPECS/opentubex.spec"

for architecture in x86_64 aarch64; do
  rpmbuild -bb \
    --nodeps \
    --target "$architecture" \
    --define "_topdir $build_directory" \
    "${rpm_defines[@]}" \
    "$build_directory/SPECS/opentubex.spec"
done

rm -rf -- "$output_directory"
mkdir -p "$output_directory"

mapfile -t packages < <(find "$build_directory/RPMS" -type f -name '*.rpm' -print | sort)
if (( ${#packages[@]} != 2 )); then
  printf 'Expected two %s packages, found %d\n' "$distribution" "${#packages[@]}" >&2
  exit 1
fi

cp "${packages[@]}" "$output_directory/"
