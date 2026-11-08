# OpenTubeX RPM repository

This repository publishes signed OpenTubeX packages for Fedora, compatible
Enterprise Linux distributions, and openSUSE at
[rpm.opentubex.org](https://rpm.opentubex.org) and through
[Fedora COPR](https://copr.fedorainfracloud.org/coprs/d3sox/opentubex/).
The hosted repository supports `x86_64` and `aarch64` systems.

Development snapshots are available through a separate nightly repository at
`/nightly/`. Stable metadata never includes nightly packages. All distributions
share the same packages.

## Install OpenTubeX

With Fedora COPR:

```sh
sudo dnf copr enable d3sox/opentubex
sudo dnf install opentubex
```

Or with the OpenTubeX-hosted repository:

```sh
sudo curl --fail --location \
  --output /etc/yum.repos.d/opentubex.repo \
  https://rpm.opentubex.org/opentubex.repo
sudo dnf install opentubex
```

On openSUSE Leap 16.0 or Tumbleweed, use the OpenTubeX-hosted repository:

```sh
sudo zypper addrepo https://rpm.opentubex.org/opentubex.repo
sudo zypper install opentubex
```

For nightly builds, use `opentubex-nightly.repo` instead of `opentubex.repo`.

## How publishing works

After an OpenTubeX stable or nightly release finishes uploading its packages,
the application repository sends a repository dispatch containing the exact
release tag. The publish workflow then:

1. resolves the latest stable release and the latest nightly; the nightly
   repository follows whichever of the two was published last;
2. repackages their `x86_64` and `aarch64` RPM assets with dependencies that
   resolve on Fedora, Enterprise Linux, and openSUSE;
3. signs the packages and the stable and nightly RPM-MD repositories;
4. sends stable release tags to the COPR custom-package webhook;
5. deploys the static repositories to GitHub Pages.

A channel whose release, packaging files, and signing key are unchanged reuses
its published packages instead of rebuilding them. The `/opensuse/` and
`/opensuse/nightly/` paths keep working for older openSUSE installations and
serve the same packages.

COPR then downloads the release RPMs, generates its source package, and builds
and signs packages for the configured Fedora and EPEL chroots.

The workflow can also be run manually. It then publishes the latest stable
release and nightly.

## Maintainer setup

1. Create a dedicated, passphrase-protected GPG key for this repository.
2. Add its ASCII-armored private key as the `RPM_GPG_PRIVATE_KEY` repository
   secret and its passphrase as `RPM_GPG_PASSPHRASE`.
3. Configure the `opentubex` COPR custom package to run
   `scripts/copr-webhook-source.sh`, then add its package-specific custom
   webhook URL as the `COPR_WEBHOOK_URL` repository secret.
4. In **Settings → Pages**, select **GitHub Actions** as the source and configure
   `rpm.opentubex.org` as the custom domain.
5. Add a DNS `CNAME` record from `rpm.opentubex.org` to
   `opentubex.github.io`.
6. Run the **Publish RPM repository** workflow once.

The OpenTubeX application repository uses its existing `PUSH_TOKEN` secret to
send the cross-repository dispatch. That token needs write access to this
repository.

To rotate the signing key, publish the new public key out-of-band before
replacing the secrets. Existing installations trust only the key they already
downloaded.
