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
catalog="$(mktemp)"
trap 'rm -f "$catalog"' EXIT
if ! "$codex_bin" debug models > "$catalog" 2>/dev/null; then
  echo "update: WARN: codex debug models failed; model IDs were not validated" >&2
elif command -v python3 >/dev/null 2>&1; then
  if ! python3 "$repo_root/codex/build-agents.py" --validate-catalog "$catalog"; then
    echo "update: stopped before installing; $codex_home is unchanged" >&2
    exit 1
  fi
else
  for id in $(awk -F'"' '/^model[[:space:]]*=/ { print $2 }' \
      "$repo_root"/codex/agents/*.toml "$repo_root/codex/profiles.toml" | sort -u); do
    if ! grep -Eq "\"slug\": *\"$id\"" "$catalog"; then
      echo "update: $id is not in the model catalog; $codex_home is unchanged" >&2
      exit 1
    fi
  done
  echo "update: WARN: python3 not found; reasoning efforts were not validated" >&2
fi
"$codex_bin" plugin marketplace upgrade compute-squad
"$codex_bin" plugin add compute-squad@compute-squad

mkdir -p "$codex_home/agents"
cp "$repo_root"/codex/agents/*.toml "$codex_home/agents/"

retired_agents=(squad-design.toml squad-manager.toml squad-verifier.toml squad-executor-haiku.toml squad-executor-opus.toml)
for name in "${retired_agents[@]}"; do
  rm -f "$codex_home/agents/$name"
done

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
