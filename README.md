# OpenTubeX RPM repository

This repository publishes signed OpenTubeX packages for Fedora, compatible
Enterprise Linux distributions, and openSUSE at
[rpm.opentubex.org](https://rpm.opentubex.org) and through
[Fedora COPR](https://copr.fedorainfracloud.org/coprs/d3sox/opentubex/).
The hosted repository supports `x86_64` and `aarch64` systems.

Development snapshots are available through separate nightly repositories at
`/nightly/` for Fedora-compatible systems and `/opensuse/nightly/` for
openSUSE. Stable metadata never includes nightly packages.

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
sudo rpm --import \
  https://rpm.opentubex.org/opensuse/repodata/repomd.xml.key
sudo zypper addrepo --refresh \
  https://rpm.opentubex.org/opensuse/ \
  opentubex
sudo zypper install opentubex
```

## How publishing works

After an OpenTubeX stable or nightly release finishes uploading its packages,
the application repository sends a repository dispatch containing the exact
release tag. The publish workflow then:

1. downloads the latest stable and nightly `x86_64` and `aarch64` RPM assets;
2. repackages them with Fedora-compatible and openSUSE dependency names;
3. validates and signs the Fedora-compatible and openSUSE packages;
4. creates signed stable and nightly RPM-MD repositories;
5. sends the completed release tag to the COPR custom-package webhook;
6. deploys the static repositories to GitHub Pages.

COPR then downloads the release RPMs, generates its source package, and builds
and signs packages for the configured Fedora, EPEL, and openSUSE chroots. The
openSUSE chroots use distribution-specific dependency names from the same spec.
COPR currently offers Leap 15.6 and Tumbleweed chroots; the hosted repository
supports the current Leap 16.0 release as well.

The workflow can also be run manually with a release tag. If no tag is given,
it publishes the latest release.

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
6. Run the **Publish RPM repository** workflow once with a release tag.

The OpenTubeX application repository uses its existing `PUSH_TOKEN` secret to
send the cross-repository dispatch. That token needs write access to this
repository.

To rotate the signing key, publish the new public key out-of-band before
replacing the secrets. Existing installations trust only the key they already
downloaded.
