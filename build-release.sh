#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/nanobot"
GITHUB_REPO="HKUDS/nanobot"

# Parse target platform and python version arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <platform> <python-version>" >&2
  echo "  e.g. $0 armv7 3.11" >&2
  exit 1
fi

PLATFORM="$1"
PY_VERSION="$2"
PY_VERSION_NODOT="${PY_VERSION//./}"

# Pre-flight checks
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "Error: docker buildx is required." >&2
  exit 1
fi

# Ensure a buildx builder with cross-platform support exists
BUILDER_NAME="nanobot-multiarch"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "==> Creating buildx builder '${BUILDER_NAME}' with QEMU support ..."
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER_NAME"

# Find latest release version from GitHub
echo "==> Fetching latest release from github.com/${GITHUB_REPO} ..."

CURL_OPTS=(-fsSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_OPTS+=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

LATEST_VERSION="$(
  curl "${CURL_OPTS[@]}" "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name":[ \t]*"([^"]+)".*/\1/'
)"

if [ -z "$LATEST_VERSION" ]; then
  echo "Error: failed to determine the latest release version." >&2
  exit 1
fi

echo "    Latest release : $LATEST_VERSION"

# Compare with current version
CURRENT_VERSION="${NANOBOT_VERSION_CURRENT:-}"
echo "    Current version: ${CURRENT_VERSION:-<not set>}"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "==> Already up-to-date ($CURRENT_VERSION). Nothing to do."
  exit 0
fi

echo "==> Version differs - proceeding with download and build."

# Download and extract the latest release
TARBALL_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${LATEST_VERSION}.tar.gz"
DOWNLOAD_DIR="${SCRIPT_DIR}/downloads"
TARBALL_PATH="${DOWNLOAD_DIR}/${LATEST_VERSION}.tar.gz"

mkdir -p "$DOWNLOAD_DIR"

echo "==> Downloading ${TARBALL_URL} ..."
curl -fsSL -o "$TARBALL_PATH" "$TARBALL_URL"

echo "==> Extracting to ${REPO_DIR} ..."
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
tar -xzf "$TARBALL_PATH" -C "$REPO_DIR" --strip-components=1

# Build the Python wheelhouse for the specified platform
EXTRAS="${EXTRAS:-}"
OUT_DIR="${SCRIPT_DIR}/dist/${PLATFORM}-py${PY_VERSION_NODOT}-wheelhouse"

DOCKERFILE="${SCRIPT_DIR}/Dockerfile.py-wheelhouse"
if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

# Map platform shorthand to docker platform
case "$PLATFORM" in
  armv7)
    DOCKER_PLATFORM="linux/arm/v7"
    ;;
  *)
    echo "Error: unsupported platform '$PLATFORM'." >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"

echo "==> Building ${PLATFORM} (${DOCKER_PLATFORM}) wheelhouse for Python ${PY_VERSION}"
if [ -n "$EXTRAS" ]; then
  echo "==> Including optional extras: $EXTRAS"
fi

docker buildx build \
  --platform "$DOCKER_PLATFORM" \
  --file "$DOCKERFILE" \
  --build-arg "PY_VERSION=$PY_VERSION" \
  --build-arg "EXTRAS=$EXTRAS" \
  --target export \
  --output "type=local,dest=$OUT_DIR" \
  "$REPO_DIR"

# Check if wheelhouse was generated
WHEEL_DIR="$OUT_DIR/wheelhouse"
if [ ! -d "$WHEEL_DIR" ]; then
  echo "Error: wheelhouse output not found at $WHEEL_DIR" >&2
  exit 1
fi

TARBALL="$SCRIPT_DIR/dist/nanobot-${PLATFORM}-py${PY_VERSION_NODOT}-wheelhouse.tar.gz"
mkdir -p "$SCRIPT_DIR/dist"
tar -C "$OUT_DIR" -czf "$TARBALL" wheelhouse

echo ""
echo "==> Done"
echo "    Release version : $LATEST_VERSION"
echo "    Wheel directory : $WHEEL_DIR"
echo "    Packed bundle   : $TARBALL"
echo ""
echo "Install on target (offline):"
echo "  python${PY_VERSION} -m pip install --no-index --find-links \"$WHEEL_DIR\" nanobot-ai"
