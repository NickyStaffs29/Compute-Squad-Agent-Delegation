#!/usr/bin/env bash
# Installs or refreshes Compute Squad for Codex from this checkout. It renders
# one effective build (this checkout plus the Codex model choices saved in
# $CODEX_HOME/compute-squad/choices.conf) into $CODEX_HOME/compute-squad/build,
# installs the plugin from that local marketplace, and copies the agents and
# profiles from the same build. --review-models asks for the choices again.
set -euo pipefail

usage="usage: codex/update.sh [--review-models]"
review=0
case "$#:${1:-}" in
  0:) ;;
  1:--review-models) review=1 ;;
  *)
    echo "$usage" >&2
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
git_bin="${GIT_BIN:-$(command -v git || true)}"
codex_bin="${CODEX_BIN:-$(command -v codex || true)}"
python_bin="$(command -v python3 || true)"

if [[ -z "$git_bin" || ! -x "$git_bin" ]]; then
  echo "update: set GIT_BIN to the absolute path of git" >&2
  exit 1
fi
if [[ -z "$codex_bin" || ! -x "$codex_bin" ]]; then
  echo "update: set CODEX_BIN to the absolute path of codex" >&2
  exit 1
fi
if [[ -z "$python_bin" ]]; then
  echo "update: python3 is required; put it on PATH" >&2
  exit 1
fi
export GIT_BIN="$git_bin"

build_agents="$repo_root/codex/build-agents.py"
state="$codex_home/compute-squad"
choices="$state/choices.conf"
build="$state/build"
review_command="bash $(printf '%q' "$repo_root/codex/update.sh") --review-models"
unchanged="$codex_home is unchanged"

if [[ $review -eq 1 && ! -t 0 ]]; then
  echo "update: --review-models needs a terminal; $unchanged" >&2
  exit 2
fi

"$git_bin" -C "$repo_root" pull --ff-only
if ! dirty="$("$git_bin" -C "$repo_root" status --porcelain --untracked-files=no)"; then
  echo "update: git status failed in $repo_root; $unchanged" >&2
  exit 1
fi
if [[ -n "$dirty" ]]; then
  echo "update: $repo_root has uncommitted changes, and the plugin installs from this checkout; commit or stash them. $unchanged" >&2
  exit 1
fi

# One read of the installed plugins decides everything below: another
# enabled copy of this plugin would load a second skill, so it stops the
# update; the GitHub copy earlier releases installed is removed after the
# local build is installed.
if ! listed="$("$codex_bin" plugin list --json)"; then
  echo "update: codex plugin list --json failed (see above); fix what it names, then rerun. $unchanged" >&2
  exit 1
fi
if ! installed="$(printf '%s' "$listed" | "$python_bin" -c '
import json, sys
try:
    installed = json.load(sys.stdin)["installed"]
    if not isinstance(installed, list) or not all(isinstance(p, dict) for p in installed):
        raise ValueError
    ids = [p["pluginId"] for p in installed
           if p.get("name") == "compute-squad" and p.get("enabled", True) is not False]
except Exception:
    sys.exit(2)
print(" ".join(ids))
')"; then
  echo "update: could not read codex plugin list --json; $unchanged" >&2
  exit 1
fi
remote=0
for id in $installed; do
  case "$id" in
    compute-squad@compute-squad-local) ;;
    compute-squad@compute-squad) remote=1 ;;
    *)
      echo "update: another copy of Compute Squad is installed: $id. Two copies of the skill would load; remove it first with: codex plugin remove $id. $unchanged" >&2
      exit 1
      ;;
  esac
done

catalog="$(mktemp)"
trap 'rm -f "$catalog"' EXIT
have_catalog=1
if ! "$codex_bin" debug models > "$catalog" 2>/dev/null; then
  have_catalog=0
fi

choose=$review
if [[ $choose -eq 0 && ! -f "$choices" ]]; then
  if [[ ! -t 0 ]]; then
    echo "update: setup gap: no Codex model choices saved in $choices; run: $review_command" >&2
    exit 3
  fi
  choose=1
fi
if [[ $choose -eq 1 && $have_catalog -eq 0 ]]; then
  echo "update: codex debug models failed, and choosing models needs your catalog; $unchanged" >&2
  exit 1
fi
if [[ $choose -eq 0 && $have_catalog -eq 1 ]]; then
  if ! status="$("$python_bin" "$build_agents" --catalog-status "$catalog" "$choices")"; then
    echo "update: stopped before installing; if $choices cannot be read, replace it with: $review_command. $unchanged" >&2
    exit 1
  fi
  case "$status" in
    changed)
      if [[ -t 0 ]]; then
        printf 'The model catalog changed since your choices were saved. Review them now? [y/N] '
        answer=""
        read -r answer || true
        if [[ "$answer" == y || "$answer" == Y ]]; then
          choose=1
        fi
      else
        echo "update: WARN: the model catalog changed since your choices were saved; keeping them. Review them with: $review_command" >&2
      fi
      ;;
    unknown)
      echo "update: WARN: codex debug models printed a catalog format this updater does not read" >&2
      have_catalog=0
      ;;
  esac
fi
if [[ $choose -eq 1 ]]; then
  if ! "$python_bin" "$build_agents" --choose "$catalog" "$choices"; then
    if [[ -f "$choices" ]]; then
      echo "update: no new choices saved; your saved choices and installed setup are unchanged" >&2
    else
      echo "update: no choices saved; nothing was installed" >&2
    fi
    exit 1
  fi
fi

if [[ $have_catalog -eq 1 ]]; then
  if ! "$python_bin" "$build_agents" --validate-catalog "$catalog" --choices "$choices"; then
    echo "update: stopped before installing; review your models with: $review_command" >&2
    exit 1
  fi
else
  echo "update: WARN: your saved models were not checked against the catalog" >&2
fi

lock="$state/update.lock"
if ! mkdir "$lock" 2>/dev/null; then
  echo "update: another update is running (or one was killed: then remove $lock); nothing was installed" >&2
  exit 1
fi
trap 'rm -f "$catalog"; rmdir "$lock" 2>/dev/null || true' EXIT

rm -rf "$build.new"
if ! tiers="$("$python_bin" "$build_agents" --render-codex "$build.new" "$choices")"; then
  echo "update: rendering the build failed; nothing was installed" >&2
  exit 1
fi

# From here each step changes the installed setup. A failure names the step;
# the choices stay saved, and rerunning the updater finishes the install.
step() {
  if ! "$@"; then
    echo "update: failed at: $*. Your choices are saved; rerun the updater to finish the install. Until then Codex may load a mix of the old and new plugin, agents, and profiles." >&2
    exit 1
  fi
}
if [[ -e "$build" || -L "$build" ]]; then
  rm -rf "$build.old"
  step mv "$build" "$build.old"
fi
step mv "$build.new" "$build"
rm -rf "$build.old"

step "$codex_bin" plugin marketplace add "$build"
step "$codex_bin" plugin add compute-squad@compute-squad-local
if [[ $remote -eq 1 ]]; then
  step "$codex_bin" plugin remove compute-squad@compute-squad
fi

step mkdir -p "$codex_home/agents"
step cp "$build"/agents/*.toml "$codex_home/agents/"

retired_agents=(squad-design.toml squad-manager.toml squad-verifier.toml squad-executor-haiku.toml squad-executor-opus.toml)
for name in "${retired_agents[@]}"; do
  rm -f "$codex_home/agents/$name"
done

step cp "$build"/profiles/*.config.toml "$codex_home/"

echo "update: Codex plugin, agents, and profiles installed from $build"
echo "update: tiers: $tiers"
echo "Start a new Codex session. Running sessions keep the skill and agents they loaded; a run resumed in a new session uses these models from its next stage."
