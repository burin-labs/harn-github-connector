#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 HARN_VERSION" >&2
  exit 2
fi

version="${1#v}"
tag="v${version}"
harn_root="${HOME}/.cargo-harn/${version}"
harn_bin="${harn_root}/bin/harn"

mkdir -p "${harn_root}/bin"

if [ -x "${harn_bin}" ]; then
  echo "${harn_root}/bin" >> "${GITHUB_PATH}"
  echo "Using cached harn-cli ${version} from ${harn_bin}"
  exit 0
fi

case "${RUNNER_OS:-$(uname -s)}-${RUNNER_ARCH:-$(uname -m)}" in
  Linux-X64 | Linux-x86_64)
    asset="harn-x86_64-unknown-linux-gnu.tar.gz"
    ;;
  Linux-ARM64 | Linux-aarch64 | Linux-arm64)
    asset="harn-aarch64-unknown-linux-gnu.tar.gz"
    ;;
  macOS-X64 | Darwin-x86_64)
    asset="harn-x86_64-apple-darwin.tar.gz"
    ;;
  macOS-ARM64 | Darwin-arm64)
    asset="harn-aarch64-apple-darwin.tar.gz"
    ;;
  *)
    asset=""
    ;;
esac

github_api_get() {
  local endpoint="$1"
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

  if [ -n "${token}" ]; then
    curl -fsSL -H "Authorization: Bearer ${token}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/burin-labs/harn/${endpoint}"
    return
  fi

  curl -fsSL "https://api.github.com/repos/burin-labs/harn/${endpoint}"
}

asset_digest() {
  local asset_name="$1"

  github_api_get "releases/tags/${tag}" | python3 -c '
import json
import sys

asset_name = sys.argv[1]
release = json.load(sys.stdin)
for asset in release.get("assets", []):
    if asset.get("name") == asset_name:
        print(asset.get("digest", ""))
        break
' "${asset_name}"
}

install_from_release() {
  if [ -z "${asset}" ]; then
    return 1
  fi

  local url="https://github.com/burin-labs/harn/releases/download/${tag}/${asset}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN

  echo "Downloading ${url}"
  curl -fsSL -o "${tmpdir}/${asset}" "${url}" || return 1

  local digest
  digest="$(asset_digest "${asset}" || true)"
  if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "No release digest found for ${asset}; falling back to source install." >&2
    return 1
  fi

  echo "${digest#sha256:}  ${tmpdir}/${asset}" | sha256sum -c -
  tar -xzf "${tmpdir}/${asset}" -C "${tmpdir}"

  if [ ! -x "${tmpdir}/harn" ]; then
    echo "Release asset ${asset} did not contain an executable harn binary." >&2
    return 1
  fi

  cp "${tmpdir}/harn" "${harn_bin}"
  chmod +x "${harn_bin}"
  echo "Installed harn-cli ${version} from ${tag}/${asset}"
}

if install_from_release; then
  echo "${harn_root}/bin" >> "${GITHUB_PATH}"
  exit 0
fi

echo "Falling back to cargo install harn-cli ${version}"
cargo install harn-cli --version "${version}" --locked --root "${harn_root}"
echo "${harn_root}/bin" >> "${GITHUB_PATH}"
