# nanobot-recamera

Pre-built [nanobot](https://github.com/HKUDS/nanobot) wheels for the Seeed reCamera V2 (ARMv7).

## Quick Install

Run on your reCamera:

```bash
curl -fsSL https://raw.githubusercontent.com/iChizer0/nanobot-recamera/main/install.sh | bash
```

The script auto-detects your Python version, downloads the matching wheelhouse from the latest release, and installs it offline via pip.

## Manual Install

1. Download the wheelhouse tarball for your Python version from the [Releases](https://github.com/iChizer0/nanobot-recamera/releases) page, e.g.:

   ```
   nanobot-armv7-py311-wheelhouse.tar.gz # Python 3.11
   ```

2. Copy it to the device and extract:

   ```bash
   tar -xzf nanobot-armv7-py311-wheelhouse.tar.gz # Python 3.11
   ```

3. Install:

   ```bash
   python3 -m pip install --no-index --find-links wheelhouse nanobot-ai
   ```

## Building Locally

Requirements: Docker with BuildKit and QEMU (for ARM cross-compilation).

```bash
./build-release.sh armv7 3.11
```

This fetches the latest nanobot release, cross-compiles all wheels for ARMv7, and produces a tarball in `dist/`.

## License

See [LICENSE](LICENSE).
