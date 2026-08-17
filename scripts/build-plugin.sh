#!/usr/bin/env bash
# Rebuilds dist/compute-squad.plugin, the single-file package Claude Cowork installs from.
# Run from anywhere; paths resolve against the repo root. Requires zip.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v zip >/dev/null 2>&1; then
  echo "build-plugin: zip is required but not installed" >&2
  exit 1
fi

for path in .claude-plugin/plugin.json skills agents commands README.md; do
  if [ ! -e "$path" ]; then
    echo "build-plugin: missing $path" >&2
    exit 1
  fi
done

python3 -c 'import json,sys; json.load(open(".claude-plugin/plugin.json"))'

mkdir -p dist
rm -f dist/compute-squad.plugin
git ls-files -z -- .claude-plugin/plugin.json skills agents commands README.md \
  | xargs -0 zip -q dist/compute-squad.plugin

echo "build-plugin: wrote dist/compute-squad.plugin"
zip -sf dist/compute-squad.plugin
