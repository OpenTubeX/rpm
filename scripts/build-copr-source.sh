#!/usr/bin/env bash

set -euo pipefail

rpm_directory=${1:-release-files}
output_directory=${2:-copr-source}
version=${3:-}

if [[ ! -d "$rpm_directory" ]]; then
  printf 'Package directory does not exist: %s\n' "$rpm_directory" >&2
  exit 1
fi

if [[ -z "$output_directory" || "$output_directory" == '/' || "$output_directory" == '.' ]]; then
  printf 'Unsafe output directory: %s\n' "$output_directory" >&2
  exit 1
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Expected a version like 0.29.0, got: %s\n' "$version" >&2
  exit 1
fi

x86_64_payload="opentubex-${version}-beta.amd64.rpm"
aarch64_payload="opentubex-${version}-beta.arm64.rpm"

declare -A expected_architectures=(
  ["$x86_64_payload"]='x86_64'
  ["$aarch64_payload"]='aarch64'
)

for payload in "$x86_64_payload" "$aarch64_payload"; do
  package="$rpm_directory/$payload"

  if [[ ! -f "$package" ]]; then
    printf 'Required package does not exist: %s\n' "$package" >&2
    exit 1
  fi

  package_name=$(rpm --query --package --queryformat '%{NAME}' "$package")
  package_version=$(rpm --query --package --queryformat '%{VERSION}' "$package")
  package_architecture=$(rpm --query --package --queryformat '%{ARCH}' "$package")

  if [[ "$package_name" != 'opentubex' || "$package_version" != "$version" ]]; then
    printf 'Unexpected package identity in %s: %s %s\n' \
      "$package" "$package_name" "$package_version" >&2
    exit 1
  fi

  if [[ "$package_architecture" != "${expected_architectures[$payload]}" ]]; then
    printf 'Unexpected architecture in %s: %s\n' "$package" "$package_architecture" >&2
    exit 1
  fi
done

rm -rf -- "$output_directory"
top_directory="$output_directory/.rpmbuild"
mkdir -p "$top_directory/SOURCES" "$top_directory/SPECS"

cp "$rpm_directory/$x86_64_payload" "$top_directory/SOURCES/"
cp "$rpm_directory/$aarch64_payload" "$top_directory/SOURCES/"
sed "s/@VERSION@/$version/g" \
  packaging/copr/opentubex.spec > "$top_directory/SPECS/opentubex.spec"

top_directory=$(realpath "$top_directory")

rpmbuild -bs \
  --define "_topdir $top_directory" \
  "$top_directory/SPECS/opentubex.spec"

mapfile -t source_packages < <(find "$top_directory/SRPMS" -maxdepth 1 -type f -name '*.src.rpm' -print)

if (( ${#source_packages[@]} != 1 )); then
  printf 'Expected one source RPM, found %d\n' "${#source_packages[@]}" >&2
  exit 1
fi

cp "${source_packages[0]}" "$output_directory/"
rm -rf -- "$top_directory"
