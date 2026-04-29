#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: scripts/check-release.sh vX.Y.Z

Validates that a release tag matches harn.toml and CHANGELOG.md, then runs the
same Harn checks used by CI.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

tag="$1"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "expected release tag like v0.1.0, got '$tag'" >&2
  exit 1
fi

version="${tag#v}"

manifest_version="$(python3 - <<'PY'
from pathlib import Path
import re
import sys

source = Path("harn.toml").read_text(encoding="utf-8")
match = re.search(r'(?ms)^\[package\]\s+.*?^version\s*=\s*"([^"]+)"', source)
if not match:
    print("could not find [package].version in harn.toml", file=sys.stderr)
    sys.exit(1)
print(match.group(1))
PY
)"

if [ "$manifest_version" != "$version" ]; then
  echo "tag $tag does not match harn.toml package version $manifest_version" >&2
  exit 1
fi

if ! grep -Eq "^## \\[?${version}\\]?([[:space:]]+-|[[:space:]]*$)" CHANGELOG.md; then
  echo "CHANGELOG.md does not contain a release heading for $version" >&2
  exit 1
fi

if [ "${CHECK_RELEASE_REQUIRE_TAG_HEAD:-false}" = "true" ] \
  && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  tag_commit="$(git rev-list -n 1 "$tag")"
  head_commit="$(git rev-parse HEAD)"
  if [ "$tag_commit" != "$head_commit" ]; then
    echo "tag $tag points at $tag_commit, but HEAD is $head_commit" >&2
    exit 1
  fi
fi

harn check src/lib.harn
harn lint src/lib.harn
harn fmt --check src tests
harn connector check . --provider github

for test in tests/*.harn; do
  harn run "$test"
done

smoke_root="$(mktemp -d)"
trap 'rm -rf "$smoke_root"' EXIT
cat > "$smoke_root/harn.toml" <<'EOF'
[package]
name = "harn-github-connector-consumer-smoke"
version = "0.0.0"
EOF
cd "$smoke_root"
harn add "${GITHUB_WORKSPACE:-$OLDPWD}@HEAD"
printf 'import "harn-github-connector/default"\n' > smoke.harn
harn check smoke.harn
