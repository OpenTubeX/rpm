#!/usr/bin/env bash

set -euo pipefail

source_directory=${1:-release-files}
output_directory=${2:-opensuse-files}
version=${3:-}

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Expected a version like 0.29.0, got: %s\n' "$version" >&2
  exit 1
fi

for source_name in \
  "opentubex-${version}-beta.amd64.rpm" \
  "opentubex-${version}-beta.arm64.rpm"; do
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

cp "$source_directory/opentubex-${version}-beta.amd64.rpm" \
  "$source_directory/opentubex-${version}-beta.arm64.rpm" \
  "$build_directory/SOURCES/"

sed "s/@VERSION@/$version/g" packaging/copr/opentubex.spec \
  > "$build_directory/SPECS/opentubex.spec"

for architecture in x86_64 aarch64; do
  rpmbuild -bb \
    --nodeps \
    --target "$architecture" \
    --define "_topdir $build_directory" \
    --define 'suse_version 160000' \
    --define 'dist .opensuse' \
    "$build_directory/SPECS/opentubex.spec"
done

rm -rf -- "$output_directory"
mkdir -p "$output_directory"

mapfile -t packages < <(find "$build_directory/RPMS" -type f -name '*.rpm' -print | sort)
if (( ${#packages[@]} != 2 )); then
  printf 'Expected two openSUSE packages, found %d\n' "${#packages[@]}" >&2
  exit 1
fi

cp "${packages[@]}" "$output_directory/"
