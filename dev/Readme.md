# Update the Compose release

Run `dev/update-release.sh VERSION` from this repository to update the image pin,
README, three installation guides, test expectation, and English/Korean/Chinese
PDFs together. The version must already be published to Docker Hub with both
`linux/amd64` and `linux/arm64` images. The script fetches the shared index digest;
you do not copy or guess a digest.

## Setup once

Install Python 3.10+ with venv support, Docker with Buildx and Compose v2,
Google Chrome or Chromium, and Noto CJK fonts. On Ubuntu, Python's venv package
and fonts are available as `python3-venv` and `fonts-noto-cjk`.

```bash
python3 -m venv dev/.venv
dev/.venv/bin/pip install Markdown==3.10.2
```

## Update

From the repository root:

```bash
./dev/update-release.sh 0.0.11
git diff --stat
git diff
```

The script works from any directory when called by its path. It runs Compose
configuration/script checks and `git diff --check` after updating the files.
Open all three PDFs and review page breaks, code wrapping, and translated text
before committing. These checks do not start containers or test ARM execution.

`PYTHON` can select another Python executable with Markdown installed.
`CHROME_BIN` can select a Chrome/Chromium executable. Chrome's sandbox is enabled
by default; `CHROME_NO_SANDBOX=1` is available for restricted build environments.
Authenticate with `docker login` if needed. If using a custom `DOCKER_CONFIG`,
export that variable so the script uses the same Docker credentials and plugins.
Run this script as your normal user so generated repository files stay writable.

The script stages every PDF before replacing the release files. Missing images,
platforms, dependencies, or a PDF rendering failure stop the update. It updates
repository defaults only: the private `.env.docker`, database, running stack,
PostgreSQL version, Helm repository, and published images are not modified.
For an existing installation, follow the root README's backup and upgrade steps.

The root `.gitignore` ignores local files under `dev/`, including `.venv/` and
temporary browser/rendering files, while keeping this README and script trackable.
