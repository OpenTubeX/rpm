#!/usr/bin/env bash

set -euo pipefail

rpm_directory=${1:-release-files}
repository_directory=${2:-repository}

if [[ ! -d "$rpm_directory" ]]; then
  printf 'Package directory does not exist: %s\n' "$rpm_directory" >&2
  exit 1
fi

if [[ -z "$repository_directory" || "$repository_directory" == '/' || "$repository_directory" == '.' ]]; then
  printf 'Unsafe repository directory: %s\n' "$repository_directory" >&2
  exit 1
fi

mapfile -t packages < <(find "$rpm_directory" -maxdepth 1 -type f -name '*.rpm' -print | sort)

if (( ${#packages[@]} == 0 )); then
  printf 'No RPM packages found in %s\n' "$rpm_directory" >&2
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
package_directory="$repository_directory/packages"
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

createrepo_c --database "$repository_directory"

gpg --batch --yes --pinentry-mode loopback \
  --passphrase-file "$passphrase_file" \
  --local-user "$RPM_GPG_KEY_ID" \
  --armor --detach-sign \
  --output "$repository_directory/repodata/repomd.xml.asc" \
  "$repository_directory/repodata/repomd.xml"
gpg --batch --armor --export "$RPM_GPG_KEY_ID" > "$repository_directory/opentubex-repo-key.asc"

cp static/CNAME static/index.html static/opentubex.repo static/style.css "$repository_directory/"
touch "$repository_directory/.nojekyll"
