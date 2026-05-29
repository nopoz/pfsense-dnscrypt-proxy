# Security Policy

## Supported versions

Only the [latest release](https://github.com/nopoz/pfsense-dnscrypt-proxy/releases/latest)
is supported. Fixes are shipped as new releases rather than backported.

## Reporting a vulnerability

Please report security issues privately through GitHub's
[**Report a vulnerability**](https://github.com/nopoz/pfsense-dnscrypt-proxy/security/advisories/new)
flow (Security tab > Advisories) rather than opening a public issue.

Expect an initial response within a few days. If a fix is warranted, it is
released and the advisory is published once users have had time to update.

## Supply-chain controls

This package ships a third-party binary (`dnscrypt-proxy`) inside a `.pkg`, so
the release pipeline is built to make that chain auditable:

- **Upstream binary verification.** New upstream binaries are pulled and their
  [minisign](https://jedisct1.github.io/minisign/) signatures verified against
  the official DNSCrypt release key before they are ever committed. The update
  is then proposed as a pull request for review, never auto-merged.
  (`.github/workflows/upstream-update.yml`)
- **Build provenance (SLSA).** Every release artifact is attested with
  [`actions/attest-build-provenance`](https://github.com/actions/attest-build-provenance),
  cryptographically binding each `.pkg` to the workflow, commit, and runner that
  produced it. A `SHA256SUMS` file is published alongside the artifacts.
- **Pinned Actions.** All GitHub Actions are pinned to a full commit SHA, with
  [Dependabot](.github/dependabot.yml) keeping the pins current.
- **Least-privilege tokens.** Workflows default to no permissions and grant the
  minimum scope each job needs.
- **CI gates.** Pull requests run ShellCheck, `php -l`, actionlint, and
  [zizmor](https://github.com/zizmorcore/zizmor) (GitHub Actions static
  analysis) before merge. (`.github/workflows/ci.yml`)

## Verifying a download

Verify build provenance with the GitHub CLI:

```bash
gh attestation verify pfSense-pkg-dnscrypt-proxy-<version>.pkg \
  --repo nopoz/pfsense-dnscrypt-proxy
```

Or check the published checksums:

```bash
# Download the package and SHA256SUMS from the same release, then:
sha256sum -c SHA256SUMS
```
