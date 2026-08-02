#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
git_bin="${GIT_BIN:-$(command -v git || true)}"
codex_bin="${CODEX_BIN:-$(command -v codex || true)}"

if [[ -z "$git_bin" || ! -x "$git_bin" ]]; then
  echo "update: set GIT_BIN to the absolute path of git" >&2
  exit 1
fi
if [[ -z "$codex_bin" || ! -x "$codex_bin" ]]; then
  echo "update: set CODEX_BIN to the absolute path of codex" >&2
  exit 1
fi

"$git_bin" -C "$repo_root" pull --ff-only
"$codex_bin" plugin marketplace upgrade compute-squad
"$codex_bin" plugin add compute-squad@compute-squad

mkdir -p "$codex_home/agents"
cp "$repo_root"/codex/agents/*.toml "$codex_home/agents/"

sync_profile() {
  local profile="$1"
  local values

  values="$(awk -v section="[profiles.${profile}]" '
    $0 == section { found = 1; next }
    found && /^\[/ { exit }
    found && /^(model|model_reasoning_effort)[[:space:]]*=/ { print }
  ' "$repo_root/codex/profiles.toml")"

  if [[ -z "$values" ]]; then
    echo "update: profile not found in codex/profiles.toml: $profile" >&2
    exit 1
  fi
  printf '%s\n' "$values" > "$codex_home/$profile.config.toml"
}

for profile in compute-squad compute-squad-pm compute-squad-execution compute-squad-mechanical; do
  sync_profile "$profile"
done

echo "update: Codex plugin, agents, and profiles refreshed"
