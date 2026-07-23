#!/usr/bin/env bash

set -euo pipefail

rpm_directory=${1:-release-files}
repository_directory=${2:-repository}
opensuse_rpm_directory=${3:-}
nightly_rpm_directory=${4:-}
nightly_opensuse_rpm_directory=${5:-}

if [[ ! -d "$rpm_directory" ]]; then
  printf 'Package directory does not exist: %s\n' "$rpm_directory" >&2
  exit 1
fi

if [[ -z "$repository_directory" || "$repository_directory" == '/' || "$repository_directory" == '.' ]]; then
  printf 'Unsafe repository directory: %s\n' "$repository_directory" >&2
  exit 1
fi

: "${RPM_GPG_KEY_ID:?RPM_GPG_KEY_ID is required to sign packages and metadata}"
: "${RPM_GPG_PASSPHRASE_FILE:?RPM_GPG_PASSPHRASE_FILE is required to sign packages and metadata}"

if [[ ! -f "$RPM_GPG_PASSPHRASE_FILE" ]]; then
  printf 'GPG passphrase file does not exist: %s\n' "$RPM_GPG_PASSPHRASE_FILE" >&2
  exit 1
fi

passphrase_file=$(realpath "$RPM_GPG_PASSPHRASE_FILE")

rm -rf -- "$repository_directory"
mkdir -p "$repository_directory"

publish_packages() {
  local source_directory=$1
  local target_directory=$2
  local package_directory="$target_directory/packages"
  local package package_name architecture destination
  local -a packages

  mapfile -t packages < <(find "$source_directory" -maxdepth 1 -type f -name '*.rpm' -print | sort)
  if (( ${#packages[@]} == 0 )); then
    printf 'No RPM packages found in %s\n' "$source_directory" >&2
    exit 1
  fi

  mkdir -p "$package_directory"

  for package in "${packages[@]}"; do
    package_name=$(rpm --query --package --queryformat '%{NAME}' "$package")
    architecture=$(rpm --query --package --queryformat '%{ARCH}' "$package")

    if [[ "$package_name" != 'opentubex' ]]; then
      printf 'Unexpected package name %s in %s\n' "$package_name" "$package" >&2
      exit 1
    fi

    case "$architecture" in
      x86_64|aarch64)
        ;;
      *)
        printf 'Unsupported RPM architecture %s in %s\n' "$architecture" "$package" >&2
        exit 1
        ;;
    esac

    destination="$package_directory/$(basename "$package")"
    cp "$package" "$destination"
    rpmsign --addsign \
      --define "_openpgp_sign gpg" \
      --define "_openpgp_sign_id $RPM_GPG_KEY_ID" \
      --define "_gpg_name $RPM_GPG_KEY_ID" \
      --define "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback --passphrase-file $passphrase_file" \
      "$destination"
  done

  createrepo_c --database "$target_directory"

  gpg --batch --yes --pinentry-mode loopback \
    --passphrase-file "$passphrase_file" \
    --local-user "$RPM_GPG_KEY_ID" \
    --armor --detach-sign \
    --output "$target_directory/repodata/repomd.xml.asc" \
    "$target_directory/repodata/repomd.xml"
}

publish_packages "$rpm_directory" "$repository_directory"

if [[ -n "$opensuse_rpm_directory" ]]; then
  if [[ ! -d "$opensuse_rpm_directory" ]]; then
    printf 'openSUSE package directory does not exist: %s\n' "$opensuse_rpm_directory" >&2
    exit 1
  fi

  publish_packages "$opensuse_rpm_directory" "$repository_directory/opensuse"
fi

if [[ -n "$nightly_rpm_directory" && -d "$nightly_rpm_directory" ]]; then
  publish_packages "$nightly_rpm_directory" "$repository_directory/nightly"
fi

if [[ -n "$nightly_opensuse_rpm_directory" && -d "$nightly_opensuse_rpm_directory" ]]; then
  publish_packages "$nightly_opensuse_rpm_directory" "$repository_directory/opensuse/nightly"
fi

gpg --batch --armor --export "$RPM_GPG_KEY_ID" > "$repository_directory/opentubex-repo-key.asc"

if [[ -n "$opensuse_rpm_directory" ]]; then
  cp "$repository_directory/opentubex-repo-key.asc" \
    "$repository_directory/opensuse/repodata/repomd.xml.key"
fi

if [[ -n "$nightly_opensuse_rpm_directory" && -d "$nightly_opensuse_rpm_directory" ]]; then
  cp "$repository_directory/opentubex-repo-key.asc" \
    "$repository_directory/opensuse/nightly/repodata/repomd.xml.key"
fi

cp \
  static/CNAME \
  static/code-blocks.js \
  static/favicon.ico \
  static/favicon.svg \
  static/index.html \
  static/opentubex-opensuse.repo \
  static/opentubex-nightly-opensuse.repo \
  static/opentubex-nightly.repo \
  static/opentubex.repo \
  static/style.css \
  "$repository_directory/"
touch "$repository_directory/.nojekyll"
