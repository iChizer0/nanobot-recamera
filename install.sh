#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPO="Seeed-Projects/nanobot-recamera"
PLATFORM="armv7"

# Detect Python version
if command -v python3 >/dev/null 2>&1; then
  PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON="python"
else
  echo "Error: python3 is not installed." >&2
  exit 1
fi

PY_FULL="$("$PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PY_NODOT="${PY_FULL//./}"

echo "==> Detected Python ${PY_FULL} (${PYTHON})"

# Fetch latest release info
echo "==> Fetching latest release from github.com/${GITHUB_REPO} ..."

CURL_OPTS=(-fsSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_OPTS+=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

RELEASE_JSON="$(curl "${CURL_OPTS[@]}" "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")"

TAG="$(echo "$RELEASE_JSON" | grep '"tag_name"' | sed -E 's/.*"tag_name":[ \t]*"([^"]+)".*/\1/')"

if [ -z "$TAG" ]; then
  echo "Error: could not determine the latest release tag." >&2
  exit 1
fi

echo "    Latest release: ${TAG}"

# Find the matching wheelhouse asset
ASSET_NAME="nanobot-${PLATFORM}-py${PY_NODOT}-wheelhouse.tar.gz"
ASSET_URL="$(
  echo "$RELEASE_JSON" \
    | grep -o "\"browser_download_url\":[ ]*\"[^\"]*${ASSET_NAME}\"" \
    | sed -E 's/.*"browser_download_url":[ ]*"([^"]+)".*/\1/' \
  || true
)"

if [ -z "$ASSET_URL" ]; then
  echo "Error: no asset found for Python ${PY_FULL} (${ASSET_NAME})." >&2
  echo "Available assets:" >&2
  echo "$RELEASE_JSON" | grep '"browser_download_url"' | sed -E 's/.*"([^"]+\.tar\.gz)".*/  \1/' >&2
  exit 1
fi

echo "    Asset: ${ASSET_NAME}"

# Download and extract
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Downloading ${ASSET_URL} ..."
curl -fSL -o "${WORK_DIR}/${ASSET_NAME}" "$ASSET_URL"

echo "==> Extracting wheelhouse ..."
tar -xzf "${WORK_DIR}/${ASSET_NAME}" -C "$WORK_DIR"

# Install
WHEEL_DIR="${WORK_DIR}/wheelhouse"
if [ ! -d "$WHEEL_DIR" ]; then
  echo "Error: wheelhouse directory not found in archive." >&2
  exit 1
fi

PIP_ARGS=(--no-index --find-links "$WHEEL_DIR")
if "$PYTHON" -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then
  PIP_ARGS+=(--break-system-packages)
fi

echo "==> Installing nanobot-ai from wheelhouse ..."
"$PYTHON" -m pip install "${PIP_ARGS[@]}" nanobot-ai

echo ""
echo "==> Done!  nanobot ${TAG} installed for Python ${PY_FULL}."
echo "    Run:  ${PYTHON} -m nanobot"
