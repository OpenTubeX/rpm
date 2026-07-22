# OpenTubeX RPM repository

This repository publishes signed OpenTubeX packages for Fedora and compatible
Enterprise Linux distributions at [rpm.opentubex.org](https://rpm.opentubex.org)
and through [Fedora COPR](https://copr.fedorainfracloud.org/coprs/d3sox/opentubex/).
It supports `x86_64` and `aarch64` systems.

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

## How publishing works

After an OpenTubeX release finishes uploading its packages, the application
repository sends an `opentubex-release` repository dispatch containing the
release tag. The publish workflow then:

1. downloads the `x86_64` and `aarch64` RPM assets;
2. validates their package names and RPM architectures;
3. signs each package and creates signed DNF repository metadata;
4. sends the completed release tag to the COPR custom-package webhook;
5. deploys the static repository to GitHub Pages.

COPR then downloads the release RPMs, generates its source package, and builds
and signs packages for the configured Fedora and EPEL chroots.

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
