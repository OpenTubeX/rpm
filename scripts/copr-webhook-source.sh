#!/usr/bin/env bash

set -euo pipefail

payload_file=''
for candidate in hook_payload hook_data; do
  if [[ -f "$candidate" ]]; then
    payload_file=$candidate
    break
  fi
done

if [[ -z "$payload_file" ]]; then
  echo 'The COPR webhook payload is missing.' >&2
  exit 1
fi

tag=$(tr -d '[:space:]' < "$payload_file")

if [[ ! "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)-beta$ ]]; then
  printf 'Expected a tag like v0.29.0-beta, got: %s\n' "$tag" >&2
  exit 1
fi

version=${BASH_REMATCH[1]}
result_directory=${COPR_RESULTDIR:-.}
release_url="https://github.com/OpenTubeX/OpenTubeX/releases/download/$tag"

mkdir -p "$result_directory"

wget --quiet \
  "$release_url/opentubex-${version}-beta.amd64.rpm" \
  --output-document="$result_directory/opentubex-${version}-beta.amd64.rpm"
wget --quiet \
  "$release_url/opentubex-${version}-beta.arm64.rpm" \
  --output-document="$result_directory/opentubex-${version}-beta.arm64.rpm"
wget --quiet \
  https://raw.githubusercontent.com/OpenTubeX/rpm/main/packaging/copr/opentubex.spec \
  --output-document="$result_directory/opentubex.spec.in"

sed "s/@VERSION@/$version/g" \
  "$result_directory/opentubex.spec.in" > "$result_directory/opentubex.spec"
rm "$result_directory/opentubex.spec.in"
