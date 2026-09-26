#!/usr/bin/env bash
# Installs or refreshes Compute Squad for Codex from this checkout. It renders
# one effective build (this checkout plus the Codex model choices saved in
# $CODEX_HOME/compute-squad/choices.conf) into $CODEX_HOME/compute-squad/build,
# installs the plugin from that local marketplace, and copies the agents and
# profiles from the same build. --review-models asks for the choices again.
# The source is this checkout on main, fast-forwarded to origin/main, or with
# --source-sha exactly that commit, not pulled. Whichever commit that is, the
# build is rendered from an export of the commit itself, by that commit's own
# renderer, never from the working tree. --check changes nothing: it reports
# every difference between that source (with the saved choices) and what
# Codex runs.
set -euo pipefail

usage="usage: codex/update.sh [--review-models | --check] [--source-sha <40-hex commit>]"
review=0
check=0
source_sha=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --review-models | --check)
      if [[ $review -eq 1 || $check -eq 1 ]]; then
        echo "$usage" >&2
        exit 2
      fi
      if [[ "$1" == --check ]]; then check=1; else review=1; fi
      ;;
    --source-sha)
      if [[ $# -lt 2 || -n "$source_sha" || ! "$2" =~ ^[0-9a-f]{40}$ ]]; then
        echo "$usage" >&2
        exit 2
      fi
      source_sha="$2"
      shift
      ;;
    *)
      echo "$usage" >&2
      exit 2
      ;;
  esac
  shift
done

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
state="$codex_home/compute-squad"
choices="$state/choices.conf"
build="$state/build"
review_command="bash $(printf '%q' "$repo_root/codex/update.sh") --review-models"
if [[ -n "$source_sha" ]]; then
  review_command="$review_command --source-sha $source_sha"
fi
unchanged="$codex_home is unchanged"
lock="$codex_home/compute-squad.lock"

if [[ $review -eq 1 && ! -t 0 ]]; then
  echo "update: --review-models needs a terminal; $unchanged" >&2
  exit 2
fi

# Git reads that never write, not even the index git status may refresh.
git_read() {
  "$git_bin" -C "$repo_root" --no-optional-locks "$@"
}

# Writes the files of commit $1, from git's objects and with their recorded
# modes, into the new directory $2. Untracked files, uncommitted edits, and
# edits git status cannot see (skip-worktree, assume-unchanged) never reach
# it. Every python call below runs $2's codex/build-agents.py, so the renderer
# and every file it reads come from that commit.
export_commit() {
  "$python_bin" - "$git_bin" "$repo_root" "$1" "$2" <<'PY'
import os, subprocess, sys
git, repo, commit, out = sys.argv[1:]
def run(args, data=None):
    return subprocess.run([git, "-C", repo, "--no-optional-locks", *args], input=data,
                          stdout=subprocess.PIPE, check=True).stdout
try:
    entries = []
    for record in run(["ls-tree", "-r", "-z", "--full-tree", commit]).split(b"\0"):
        if record:
            meta, path = record.split(b"\t", 1)
            mode, kind, oid = meta.decode().split()
            if kind != "blob":
                sys.exit(f"export: {os.fsdecode(path)} in {commit} is a {kind}, not a file")
            entries.append((mode, oid, os.fsdecode(path)))
    data = run(["cat-file", "--batch"], "".join(oid + "\n" for _, oid, _ in entries).encode())
except (OSError, subprocess.CalledProcessError) as error:
    sys.exit(f"export: cannot read {commit}: {error}")
at = 0
for mode, oid, path in entries:
    end = data.index(b"\n", at)
    got, kind, size = data[at:end].decode().split()
    if got != oid or kind != "blob":
        sys.exit(f"export: git cat-file gave {got} {kind} for {oid}")
    content, at = data[end + 1:end + 1 + int(size)], end + 2 + int(size)
    dest = os.path.join(out, path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if mode == "120000":
        os.symlink(os.fsdecode(content), dest)
    else:
        with open(dest, "wb") as handle:
            handle.write(content)
        os.chmod(dest, 0o755 if mode == "100755" else 0o644)
PY
}

# check_install TREE PRIOR compares what Codex runs with a fresh render of
# TREE (an export of the selected commit) and the saved choices: the plugin
# state, every file of the cached plugin (manifest, skill, references, hooks),
# the seven agents, and the four profiles. PRIOR is 1 when the caller already
# reported a mismatch. It writes only a temporary directory outside
# $codex_home, prints one MISMATCH line per difference and a final verdict,
# and returns 1 on any mismatch.
expected=""
source_tree=""
have_lock=0
check_install() {
  local tree="$1" mismatch="$2" listed
  if [[ $have_lock -eq 0 && -d "$lock" ]]; then
    echo "check: MISMATCH $lock exists: an update is running, or one was killed"
    mismatch=1
  fi
  if [[ ! -f "$choices" ]]; then
    echo "check: MISMATCH choices: none saved in $choices, so there is nothing to compare"
    mismatch=1
  else
    expected="$(mktemp -d)"
    if ! "$python_bin" "$tree/codex/build-agents.py" --render-codex "$expected/build" "$choices" > /dev/null; then
      echo "check: MISMATCH source: rendering it with your choices failed"
      mismatch=1
    else
      if ! listed="$("$codex_bin" plugin list --json)"; then
        listed=""
      fi
      if ! printf '%s' "$listed" | "$python_bin" "$tree/codex/build-agents.py" --compare-install "$expected/build" "$codex_home"; then
        mismatch=1
      fi
    fi
    rm -rf "$expected"
    expected=""
  fi
  if [[ $mismatch -eq 0 ]]; then
    echo "check: OK"
  else
    echo "check: FAILED: each MISMATCH line above is a difference; rerun codex/update.sh to install the source"
  fi
  return $mismatch
}

if [[ $check -eq 1 ]]; then
  trap 'rm -rf ${expected:+"$expected"} ${source_tree:+"$source_tree"}' EXIT
  mismatch=0
  if ! head="$(git_read rev-parse HEAD)" || ! branch="$(git_read rev-parse --abbrev-ref HEAD)" \
      || ! dirty="$(git_read status --porcelain --untracked-files=no)"; then
    echo "check: MISMATCH source: git cannot read $repo_root"
    echo "check: FAILED: each MISMATCH line above is a difference; rerun codex/update.sh to install the source"
    exit 1
  fi
  commit="${source_sha:-$head}"
  echo "check: source $commit ($repo_root, $branch at $head)"
  if [[ "$head" != "$commit" ]]; then
    echo "check: MISMATCH source: HEAD is $head, not the approved $commit"
    mismatch=1
  fi
  if [[ -n "$dirty" ]]; then
    echo "check: MISMATCH source: $repo_root has uncommitted changes"
    mismatch=1
  fi
  source_tree="$(mktemp -d)"
  if ! export_commit "$commit" "$source_tree"; then
    echo "check: MISMATCH source: commit $commit cannot be read from $repo_root"
    echo "check: FAILED: each MISMATCH line above is a difference; rerun codex/update.sh to install the source"
    exit 1
  fi
  if check_install "$source_tree" "$mismatch"; then
    exit 0
  fi
  exit 1
fi

# One update at a time. The lock is taken before anything below reads the
# checkout, the installed plugins, the catalog, or the saved choices, and held
# until the install ends, so a review can never save choices while another
# update validates, renders, or installs a build from the old ones. An update
# that cannot take it stops here with nothing saved or installed. It sits
# beside $state, not in it, so a refusal never creates or removes $state.
catalog=""
cleanup() {
  if [[ -n "$catalog" ]]; then
    rm -f "$catalog"
  fi
  if [[ -n "$expected" ]]; then
    rm -rf "$expected"
  fi
  if [[ -n "$source_tree" ]]; then
    rm -rf "$source_tree"
  fi
  if [[ $have_lock -eq 1 ]]; then
    rmdir "$lock" 2>/dev/null || true
  fi
}
trap cleanup EXIT
if ! mkdir "$lock" 2>/dev/null; then
  if [[ -d "$lock" ]]; then
    echo "update: another update is running (or one was killed: then remove $lock); nothing was saved or installed" >&2
  else
    echo "update: cannot create $lock; nothing was saved or installed" >&2
  fi
  exit 1
fi
have_lock=1

# Select the source before anything is installed. An approved commit is never
# pulled: the checkout must already be exactly that commit. Otherwise the
# checkout must be main tracking origin/main with no uncommitted changes to
# tracked files before the fast-forward, and exactly origin/main after it, so
# no local commit rides along. Tracked files are checked again at the end.
if [[ -n "$source_sha" ]]; then
  if ! head="$(git_read rev-parse HEAD)" || [[ "$head" != "$source_sha" ]]; then
    echo "update: $repo_root is at ${head:-an unknown commit}, not the approved $source_sha; check out that commit or drop --source-sha. $unchanged" >&2
    exit 1
  fi
else
  branch="$(git_read rev-parse --abbrev-ref HEAD || true)"
  upstream="$(git_read rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ "$branch" != main || "$upstream" != origin/main ]]; then
    echo "update: $repo_root is on ${branch:-no branch} tracking ${upstream:-nothing}; updates install main tracking origin/main. To install an approved commit instead, use --source-sha <commit>. $unchanged" >&2
    exit 1
  fi
  if ! dirty="$(git_read status --porcelain --untracked-files=no)" || [[ -n "$dirty" ]]; then
    echo "update: $repo_root has uncommitted changes (or git status failed); commit or stash them before the update pulls. $unchanged" >&2
    exit 1
  fi
  if ! "$git_bin" -C "$repo_root" pull --ff-only; then
    echo "update: git pull --ff-only failed in $repo_root; $unchanged" >&2
    exit 1
  fi
  head="$(git_read rev-parse HEAD)"
  if [[ "$head" != "$(git_read rev-parse '@{upstream}')" ]]; then
    echo "update: $repo_root is at $head, not origin/main, after the pull (a local commit?); updates install origin/main exactly. $unchanged" >&2
    exit 1
  fi
fi
if ! dirty="$(git_read status --porcelain --untracked-files=no)"; then
  echo "update: git status failed in $repo_root; $unchanged" >&2
  exit 1
fi
if [[ -n "$dirty" ]]; then
  echo "update: $repo_root has uncommitted changes, and the plugin installs from this checkout; commit or stash them. $unchanged" >&2
  exit 1
fi
source_tree="$(mktemp -d)"
if ! export_commit "$head" "$source_tree"; then
  echo "update: cannot read commit $head from $repo_root; $unchanged" >&2
  exit 1
fi
build_agents="$source_tree/codex/build-agents.py"

# One read of the installed plugins decides everything below: another
# enabled copy of this plugin would load a second skill, so it stops the
# update; the GitHub copy earlier releases installed is removed after the
# local build is installed.
if ! listed="$("$codex_bin" plugin list --json)"; then
  echo "update: codex plugin list --json failed (see above); fix what it names, then rerun. $unchanged" >&2
  exit 1
fi
# Each enabled copy prints as its ID, then "local" when it is installed from
# this updater's build directory, else the path it is installed from.
if ! installed="$(printf '%s' "$listed" | "$python_bin" -c '
import json, os, sys
try:
    installed = json.load(sys.stdin)["installed"]
    if not isinstance(installed, list) or not all(isinstance(p, dict) for p in installed):
        raise ValueError
    for plugin in installed:
        if plugin.get("name") == "compute-squad" and plugin.get("enabled", True) is not False:
            path = (plugin.get("source") or {}).get("path") or ""
            same = path and os.path.realpath(path) == os.path.realpath(sys.argv[1])
            print(plugin["pluginId"], "local" if same else path or "an unknown source", sep="\t")
except Exception:
    sys.exit(2)
' "$build/plugins/compute-squad")"; then
  echo "update: could not read codex plugin list --json; $unchanged" >&2
  exit 1
fi
remote=0
while IFS=$'\t' read -r id installed_from; do
  case "$id" in
    "") ;;
    compute-squad@compute-squad-local)
      if [[ "$installed_from" != local ]]; then
        echo "update: compute-squad@compute-squad-local is installed from $installed_from, not $build/plugins/compute-squad; remove that registration first with: codex plugin marketplace remove compute-squad-local. $unchanged" >&2
        exit 1
      fi
      ;;
    compute-squad@compute-squad) remote=1 ;;
    *)
      echo "update: another copy of Compute Squad is installed: $id. Two copies of the skill would load; remove it first with: codex plugin remove $id. $unchanged" >&2
      exit 1
      ;;
  esac
done <<< "$installed"

catalog="$(mktemp)"
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

if ! check_install "$source_tree" 0; then
  echo "update: the installed setup does not match the source (see the mismatches above); rerun the updater. Codex may load a mix of old and new files until it matches." >&2
  exit 1
fi
echo "update: Codex plugin, agents, and profiles installed from $build"
echo "update: tiers: $tiers"
echo "Start a new Codex session. Running sessions keep the skill and agents they loaded; a run resumed in a new session uses these models from its next stage."
