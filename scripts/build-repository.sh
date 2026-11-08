#!/usr/bin/env bash
# Builds the signed stable and nightly RPM repositories.
# Usage: build-repository.sh STABLE_TAG NIGHTLY_TAG REPOSITORY_DIRECTORY
# NIGHTLY_TAG may equal STABLE_TAG when the latest release is newer than the
# latest nightly.

set -euo pipefail

stable_tag=$1
nightly_tag=$2
repository_directory=$3
site_url=https://rpm.opentubex.org
release_url=https://github.com/OpenTubeX/OpenTubeX/releases/download

: "${RPM_GPG_KEY_ID:?RPM_GPG_KEY_ID is required to sign packages and metadata}"
: "${RPM_GPG_PASSPHRASE_FILE:?RPM_GPG_PASSPHRASE_FILE is required to sign packages and metadata}"
passphrase_file=$(realpath "$RPM_GPG_PASSPHRASE_FILE")

if [[ -z "$repository_directory" || "$repository_directory" == '/' || "$repository_directory" == '.' ]]; then
  printf 'Unsafe repository directory: %s\n' "$repository_directory" >&2
  exit 1
fi

work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT

# Rebuilding an unchanged release would publish the same package names with new
# checksums, which breaks downloads for clients with cached metadata. Reuse the
# published packages while the release, packaging, and signing key stay the same.
# The query string bypasses the CDN cache, which may still hold an older build-info.
publish_packages() {
  local tag=$1 channel=$2
  local asset_version=${tag#v}
  local package_directory="$work_directory/$channel/packages"
  local published_url="$site_url/packages"
  local fingerprint build_info package_name

  fingerprint=$(cat <(printf '%s\n' "$asset_version" "$RPM_GPG_KEY_ID") \
    packaging/copr/opentubex.spec scripts/build-packages.sh | sha256sum | cut -d ' ' -f 1)
  if [[ "$channel" == nightly ]]; then
    published_url="$site_url/nightly/packages"
  fi
  mkdir -p "$package_directory"

  if build_info=$(wget --quiet --output-document=- "$published_url/build-info?$(date +%s)") \
    && [[ "$(head -n 1 <<< "$build_info")" == "$fingerprint" ]]; then
    printf 'Reusing the published %s packages\n' "$asset_version"
    while read -r _ package_name; do
      wget --quiet --output-document="$package_directory/$package_name" "$published_url/$package_name"
    done < <(tail -n +2 <<< "$build_info")
    (cd "$package_directory" && tail -n +2 <<< "$build_info" | sha256sum --check --quiet)
  else
    printf 'Building the %s packages\n' "$asset_version"
    mkdir -p "$work_directory/sources"
    for architecture in amd64 arm64; do
      wget --quiet --tries=3 \
        --output-document="$work_directory/sources/opentubex-${asset_version}.${architecture}.rpm" \
        "$release_url/$tag/opentubex-${asset_version}.${architecture}.rpm"
    done
    ./scripts/build-packages.sh "$work_directory/sources" "$package_directory" "$asset_version"
    rm -rf -- "$work_directory/sources"
    rpmsign --addsign \
      --define "_openpgp_sign gpg" \
      --define "_openpgp_sign_id $RPM_GPG_KEY_ID" \
      --define "_gpg_name $RPM_GPG_KEY_ID" \
      --define "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback --passphrase-file $passphrase_file" \
      "$package_directory"/*.rpm
  fi

  {
    printf '%s\n' "$fingerprint"
    (cd "$package_directory" && sha256sum -- *.rpm)
  } > "$package_directory/build-info"
}

# Writes signed metadata for a package directory. The location prefix lets the
# metadata live in another directory, as the openSUSE paths require.
index_packages() {
  local package_directory=$1 output_directory=$2 location_prefix=$3
  mkdir -p "$output_directory"
  createrepo_c --location-prefix "$location_prefix" \
    --outputdir "$output_directory" "$package_directory"
  gpg --batch --yes --pinentry-mode loopback \
    --passphrase-file "$passphrase_file" \
    --local-user "$RPM_GPG_KEY_ID" \
    --armor --detach-sign \
    --output "$output_directory/repodata/repomd.xml.asc" \
    "$output_directory/repodata/repomd.xml"
}

publish_packages "$stable_tag" stable
if [[ "$nightly_tag" == "$stable_tag" ]]; then
  mkdir -p "$work_directory/nightly"
  cp -r "$work_directory/stable/packages" "$work_directory/nightly/"
else
  publish_packages "$nightly_tag" nightly
fi

rm -rf -- "$repository_directory"
mkdir -p "$repository_directory"
index_packages "$work_directory/stable/packages" "$work_directory/stable" packages/
index_packages "$work_directory/nightly/packages" "$work_directory/nightly" packages/
# openSUSE installs from before both distributions shared one package set use
# these paths. Zypper ignores xml:base, so point them at the packages relatively.
index_packages "$work_directory/stable/packages" "$work_directory/opensuse" ../packages/
index_packages "$work_directory/nightly/packages" "$work_directory/opensuse/nightly" ../../nightly/packages/

cp -r "$work_directory/stable/." "$repository_directory/"
cp -r "$work_directory/nightly" "$work_directory/opensuse" "$repository_directory/"

gpg --batch --armor --export "$RPM_GPG_KEY_ID" > "$repository_directory/opentubex-repo-key.asc"
for directory in opensuse opensuse/nightly; do
  cp "$repository_directory/opentubex-repo-key.asc" "$repository_directory/$directory/repodata/repomd.xml.key"
done

cp \
  static/CNAME \
  static/code-blocks.js \
  static/favicon.ico \
  static/favicon.svg \
  static/index.html \
  static/og.png \
  static/opentubex-nightly.repo \
  static/opentubex.repo \
  static/style.css \
  "$repository_directory/"
touch "$repository_directory/.nojekyll"
