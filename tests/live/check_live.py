#!/usr/bin/env python3
"""Setup and assertions for the live tier, tests/live/run.sh (report section 6).

run.sh calls this script; it never calls a model itself.

    check_live.py seed <seed.log.md> <repo> <base>
    check_live.py collide <repo> <shim dir>
    check_live.py preflight <check> <repo>
    check_live.py snapshot <repo> <base> <state.json>
    check_live.py verify <check> <repo> <base> <state.json> <result.json> [--tools FILE] [--summary FILE --label TEXT]
    check_live.py toollog <tools.jsonl>
    check_live.py checks

seed writes a seed log from tests/fixtures/logs/ into the scenario repo as
COMPUTE_SQUAD_LOG.md. Seeds carry the placeholder base 4f2c9a1 and worktree
/home/dev/app; seed puts in the real base commit and repo path. For each
"Archive target:" line it also writes the archive copy the PM's archive
command would have made: the log up to and including that line.

collide sets up S6b: it writes a date command into the shim dir that always
reports the same second (run.sh puts that dir first on the claude call's
PATH), and writes an earlier archive of the seeded log's run at the name the
archive command will give it under that clock: the log's Goal entry alone, so
an overwrite by the full log would change its sha256.

preflight runs before a live scenario spends tokens, under the environment
the claude call gets, and exits 1 if the scenario's premise does not hold:
for S5 the browser check must run and report the fixture's overflow, for S5b
it must find no browser, and for S6b date must name the existing archive.

snapshot records what the next claude call must extend or leave alone: the
base and HEAD commits, the active log, the sha256 of every archive file, every
product path that differs from the base commit with its sha256, and the agent
IDs already in compute-squad-archive/usage.jsonl.

verify reads the claude -p result JSON (subagent_stats.by_type,
permission_denials, modelUsage), the log the call left (the active log, or the
newest new archive when the call cleared it), the product tree, and the usage
ledger, and applies one named check. Every check also requires: a successful
result, a log that starts with the log the call found (append-only), a log that
lints clean with tests/check_logs.py, every earlier archive file unchanged, no
needs-human: blocker in the new entries (finding 4: S1 and S2 log none, since
the fixture's test script works; S5 and S5b, whose premise is a criterion that
cannot be met as locked, assert their own), and ledger billed input within 1%
of modelUsage with ledger output at or below it (WO-3c acceptance). It prints
one line per assertion and exits 1 when any fails, 2 when it cannot run.

toollog is the hook log: run.sh passes the claude call a PreToolUse hook
(in --settings, with no matcher) that runs it, so every tool call the main
session or a subagent makes appends one JSON line to the file: the session,
the agent_id and agent_type of a subagent's call (a main-session call has
neither), the tool, and the inputs the checks read, each string cut to 4,000
characters (a spawn prompt keeps its full length in prompt_chars). It prints
nothing and always exits 0, so it never blocks or changes a call. verify
--tools reads the file. Two checks rest on it (work order WO-3f): S8, the
reference run, holds the main session to SKILL.md's Stage 0 bound (no Read
or Grep of tracked product source and no test or build command before the
first squad-recon spawn) and its billed input and output, from the ledger's
main-session line, to 756,000 and 12,400 tokens; S9 holds the audit to its
skeptic cap (at most 10 skeptic spawns, the other findings UNREVIEWED in
the ## Audit Findings entry). Check 8b runs the same rules over the cases in
tests/fixtures/live/.

Python 3.9 stdlib only.
"""
import argparse
import collections
import fnmatch
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO_ROOT, "tests"))
sys.dont_write_bytecode = True   # leave no tests/__pycache__ in the checkout
import check_logs  # noqa: E402  (the 8a linter: log parser, grammar, grant hook runner)

SKILL_PATH = check_logs.SKILL_PATH
LOG = "COMPUTE_SQUAD_LOG.md"
ARCHIVE_DIR = "compute-squad-archive"
ARCHIVE_PREFIX = "COMPUTE_SQUAD_LOG_"
LEDGER = os.path.join(ARCHIVE_DIR, "usage.jsonl")
SEED_BASE = "4f2c9a1"             # placeholder base commit in the seeds
SEED_WORKTREE = "/home/dev/app"   # placeholder repo path in the seeds
PLUGIN_PREFIX = "compute-squad:"
LEDGER_TOLERANCE = 0.01

# The S2 and S3 seed plans (tests/fixtures/logs/s2.log.md and s3.log.md, the
# same plan r1) list these files for WO-1; WO-2 adds the reset_cooldown_hit
# event and touches src/server/log.js.
S2_WO1_FILES = (
    "src/server/auth/reset.service.js",
    "src/server/auth/__tests__/reset.routes.test.js",
)
S2_WO2_MARK = "reset_cooldown_hit"
# S5 (tests/fixtures/logs/s5.log.md, on tests/fixtures/repo-ui/): the
# criterion the browser check covers, and that check. The fixture's check
# exits 0 with no overflow, 1 with one, and 2 when it cannot run.
S5_CRITERION = "AC2"
BROWSER_CHECK = ("node", "scripts/check-overflow.js")
BROWSER_WORDS = re.compile(r"chromium|playwright|browser|check[:-]overflow", re.IGNORECASE)
MISSING_WORDS = re.compile(r"missing|not installed|not found|no chromium|no browser|doesn't exist|does not exist|"
                           r"cannot run|can't run", re.IGNORECASE)
# S6b's clock: the second every date call reports, 2026-09-20T08:30:00Z.
S6B_EPOCH = 1789893000
# Checks whose scenario may end in a needs-human: blocker; each asserts its own.
BLOCKER_CHECKS = ("s5", "s5b")
# The hook log (toollog): the spawn tool's two names, the tool inputs kept,
# and how much of each string input is kept.
SPAWN_TOOLS = ("Agent", "Task")
TOOL_INPUT_KEYS = ("file_path", "path", "pattern", "glob", "command", "subagent_type", "model", "description", "prompt")
TOOL_TEXT_LIMIT = 4000
# S8 (WO-3f): the main-session budget on the reference run, the after model's
# estimate for the orchestrating session in the 3.9.2 analysis (section 5),
# against 877,638 billed input and 14,408 output measured on 3.9.2.
MAIN_BUDGET_INPUT = 756000
MAIN_BUDGET_OUTPUT = 12400
# What SKILL.md's Stage 0 bound lets the main session read in the repo besides
# files the user named: the README and the instruction files the host injects.
# Every other file tracked at the base commit is product source.
STAGE0_DOCS = re.compile(r"(?:^|/)(?:README(?:\.[A-Za-z]+)?|CLAUDE\.md|AGENTS\.md)$")
# A test or build command at the start of a shell command, after a ;, &, |,
# (, or $(, or after environment assignments or a timeout wrapper: a package
# manager's test, run, build, or runner command, npx and its kin, node's test
# runner, make, a test runner or compiler called directly, or go's or cargo's
# test and build.
TEST_RUN = re.compile(
    r"(?:^|[;&|(]|\$\()\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:timeout\s+\S+\s+)?"
    r"(?:(?:npm|yarn|pnpm|bun)\s+(?:test|t|run|run-script|build|ci|exec|dlx|jest|vitest|mocha|tsc)\b"
    r"|(?:npx|pnpx|bunx)\s|node\s+--test\b|make\b|(?:jest|vitest|mocha|ava|tap|pytest|tsc)\b"
    r"|python3?\s+-m\s+(?:pytest|unittest)\b|(?:go|cargo)\s+(?:test|build)\b)",
    re.MULTILINE,
)
# Shell programs that print, search, compare, or count a file's contents:
# before its first squad-recon spawn the main session runs none of them over
# product source. The search programs take a pattern first and read a
# directory recursively (grep with -r or -R; rg, ag, and ack always); the
# script programs take a script first.
READ_PROGRAMS = frozenset((
    "cat", "tac", "nl", "head", "tail", "less", "more", "sed", "awk", "gawk", "mawk", "cut", "sort", "uniq", "wc",
    "od", "xxd", "hexdump", "strings", "bat", "diff", "cmp", "grep", "egrep", "fgrep", "rg", "ag", "ack",
))
SEARCH_PROGRAMS = frozenset(("grep", "egrep", "fgrep", "rg", "ag", "ack"))
ALWAYS_RECURSIVE = frozenset(("rg", "ag", "ack"))
SCRIPT_PROGRAMS = frozenset(("sed", "awk", "gawk", "mawk"))
# The shell's operators: a redirection takes the next word as its target,
# and any other run of operator characters (; | & && || ( ) and mixes) ends
# a simple command. Descriptor duplications (2>&1) go first, and &> reads
# as >.
REDIRECTS = frozenset(("<", ">", ">>", "<<", "<<<", "<>"))
SHELL_OPERATOR = re.compile(r"[();<>|&]+")
FD_DUP = re.compile(r"[0-9]*>&[0-9-]*")
# Words a simple command's program can follow.
SHELL_PREFIXES = frozenset(("command", "exec", "nice", "do", "then", "else", "elif", "if", "while", "until", "!", "{",
                            "time"))
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
# S9 (WO-3f): tests/live/repo-reset-audit.patch plants about 30 defects on
# the WO-1 change, so the finders' candidate findings exceed the skeptic cap.
S9_PLANTED = 30


class SetupError(Exception):
    pass


def git(repo, *args):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    run = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, env=env)
    if run.returncode != 0:
        raise SetupError(f"git {' '.join(args)} in {repo} exited {run.returncode}: {run.stderr.strip()}")
    return run.stdout


def sha256_file(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def read_text(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except FileNotFoundError:
        return None


# ---- seed ------------------------------------------------------------------

def cmd_seed(seed, repo, base):
    repo = os.path.abspath(repo)
    # Run state is not product state: keep the log and the archive out of
    # git status, as a project's own .gitignore would.
    exclude = os.path.join(repo, ".git", "info", "exclude")
    os.makedirs(os.path.dirname(exclude), exist_ok=True)
    with open(exclude, "a", encoding="utf-8") as handle:
        handle.write(f"{LOG}\n{ARCHIVE_DIR}/\n")
    with open(seed, encoding="utf-8") as handle:
        text = handle.read()
    text = text.replace(SEED_BASE, base[:len(SEED_BASE)]).replace(SEED_WORKTREE, repo)
    with open(os.path.join(repo, LOG), "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"seeded {LOG} from {os.path.relpath(seed, REPO_ROOT)} ({len(text.splitlines())} lines)")
    lines = text.splitlines(keepends=True)
    for index, line in enumerate(lines):
        match = re.fullmatch(r"Archive target: (\S+)\n?", line)
        if not match:
            continue
        target = os.path.normpath(os.path.join(repo, match.group(1)))
        if not target.startswith(os.path.join(repo, ARCHIVE_DIR) + os.sep):
            raise SetupError(f"{seed}: archive target {match.group(1)!r} is outside {ARCHIVE_DIR}/")
        if os.path.exists(target):
            raise SetupError(f"{seed}: archive target {match.group(1)!r} already exists")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8") as handle:
            handle.write("".join(lines[:index + 1]))
        print(f"wrote the archive copy {match.group(1)}")
    return 0


def log_run(text):
    """The run ID the archive command reads from a log: its first Run: line."""
    return next((line[len("Run: "):] for line in text.splitlines() if line.startswith("Run: ")), "") or "norun"


def shim_date(shim, *args):
    run = subprocess.run([os.path.join(shim, "date"), *args], capture_output=True, text=True)
    if run.returncode != 0 or not run.stdout.strip():
        raise SetupError(f"{shim}/date {' '.join(args)} exited {run.returncode}: {run.stderr.strip()}")
    return run.stdout.strip()


def cmd_collide(repo, shim):
    """S6b: a fixed clock, and an archive already at the name it gives the log."""
    repo = os.path.abspath(repo)
    real = None
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(folder, "date")
        if folder and os.path.abspath(folder) != os.path.abspath(shim) and os.access(candidate, os.X_OK):
            real = candidate
            break
    if real is None:
        raise SetupError("no date command on PATH to wrap")
    os.makedirs(shim, exist_ok=True)
    path = os.path.join(shim, "date")
    with open(path, "w", encoding="utf-8") as handle:
        # GNU date takes -d @<epoch>; BSD date takes -r <epoch>.
        handle.write(
            "#!/bin/sh\n"
            f"# S6b's clock (tests/live/run.sh): every date call reports epoch {S6B_EPOCH}.\n"
            f"if '{real}' -u -d @0 +%s >/dev/null 2>&1; then exec '{real}' -d @{S6B_EPOCH} \"$@\"; fi\n"
            f"exec '{real}' -r {S6B_EPOCH} \"$@\"\n"
        )
    os.chmod(path, 0o755)
    stamp = shim_date(shim, "-u", "+%Y-%m-%d_%H%M%S")
    run_id = log_run(read_text(os.path.join(repo, LOG)) or "")
    target = os.path.join(ARCHIVE_DIR, f"{ARCHIVE_PREFIX}{stamp}_{run_id}.md")
    full = os.path.join(repo, target)
    if os.path.exists(full):
        raise SetupError(f"{target} already exists")
    lines = (read_text(os.path.join(repo, LOG)) or "").splitlines(keepends=True)
    second = next((i for i, line in enumerate(lines) if line.startswith("## ") and i > 0), len(lines))
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as handle:
        handle.write("".join(lines[:second]).rstrip("\n") + "\n")
    print(f"wrote {path}, which reports {shim_date(shim, '-u', '+%Y-%m-%dT%H:%M:%SZ')}, and the earlier archive {target}")
    return 0


def browser_check(repo):
    run = subprocess.run(list(BROWSER_CHECK), cwd=repo, capture_output=True, text=True, timeout=120)
    return run.returncode, (run.stdout + run.stderr).strip()


def cmd_preflight(check, repo):
    """Exit 1 unless the scenario's premise holds in this repo and environment."""
    repo = os.path.abspath(repo)
    if check == "s5":
        code, output = browser_check(repo)
        ok = code == 1 and "overflow" in output and "table.plans" in output
        want = "exit 1 with the plans table's overflow"
    elif check == "s5b":
        code, output = browser_check(repo)
        ok = code == 2 and "cannot run" in output
        want = "exit 2: no browser for the check"
    elif check == "s6b":
        stamp = subprocess.run(["sh", "-c", "date -u +%Y-%m-%d_%H%M%S"], cwd=repo, capture_output=True, text=True)
        run_id = log_run(read_text(os.path.join(repo, LOG)) or "")
        target = os.path.join(ARCHIVE_DIR, f"{ARCHIVE_PREFIX}{stamp.stdout.strip()}_{run_id}.md")
        code, output = stamp.returncode, f"date names {target}"
        ok = code == 0 and os.path.isfile(os.path.join(repo, target))
        want = "sh's date to name the archive collide wrote"
    else:
        print(f"preflight {check}: nothing to check")
        return 0
    print(f"preflight {check}: {'ok' if ok else 'FAIL'}: wanted {want}; got exit {code}: {output[-600:]}")
    return 0 if ok else 1


# ---- snapshot ----------------------------------------------------------------

def archives(repo):
    folder = os.path.join(repo, ARCHIVE_DIR)
    found = {}
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.startswith(ARCHIVE_PREFIX) and name.endswith(".md"):
                found[name] = sha256_file(os.path.join(folder, name))
    return found


def product(repo, base):
    """Every path that differs from the base commit, tracked or untracked, with
    its sha256 ("deleted" when it is gone). The log and the archive folder are
    excluded through .git/info/exclude, which run.sh writes."""
    changed = git(repo, "diff", "--name-only", "-z", base).split("\0")
    untracked = git(repo, "ls-files", "--others", "--exclude-standard", "-z").split("\0")
    state = {}
    for path in sorted(set(p for p in changed + untracked if p)):
        full = os.path.join(repo, path)
        state[path] = sha256_file(full) if os.path.isfile(full) else "deleted"
    return state


def product_text(repo, base):
    """The diff from the base commit plus the text of every untracked file."""
    parts = [git(repo, "diff", base)]
    for path in git(repo, "ls-files", "--others", "--exclude-standard", "-z").split("\0"):
        if path:
            parts.append(read_text(os.path.join(repo, path)) or "")
    return "\n".join(parts)


def ledger(repo):
    records = []
    text = read_text(os.path.join(repo, LEDGER)) or ""
    for line in text.splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def snapshot(repo, base):
    return {
        "base": git(repo, "rev-parse", base).strip(),
        "head": git(repo, "rev-parse", "HEAD").strip(),
        "log": read_text(os.path.join(repo, LOG)) or "",
        "archives": archives(repo),
        "product": product(repo, base),
        "ledger_ids": sorted(set(str(r.get("agent_id")) for r in ledger(repo) if r.get("agent") != "main")),
    }


# ---- the hook log --------------------------------------------------------------

def cmd_toollog(path):
    """The PreToolUse hook run.sh passes each claude call: append one line for
    this tool call to path. It prints nothing and exits 0 whatever happens, so
    it never blocks or changes a call; a single write keeps the lines of
    parallel agents whole."""
    try:
        event = json.loads(sys.stdin.read())
        if not isinstance(event, dict) or not isinstance(event.get("tool_name"), str):
            return 0
        given = event.get("tool_input") if isinstance(event.get("tool_input"), dict) else {}
        record = {key: event[key] for key in ("session_id", "agent_id", "agent_type", "tool_name", "tool_use_id", "cwd")
                  if isinstance(event.get(key), str) and event[key]}
        kept = {}
        for key in TOOL_INPUT_KEYS:
            value = given.get(key)
            if isinstance(value, str):
                kept[key] = value[:TOOL_TEXT_LIMIT]
                if key == "prompt":
                    record["prompt_chars"] = len(value)
        record["tool_input"] = kept
        data = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
        handle = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
        try:
            os.write(handle, data)
        finally:
            os.close(handle)
    except Exception:  # noqa: BLE001  (a hook that fails must not block the call)
        pass
    return 0


def read_tool_log(path):
    """The records toollog wrote, in call order; None when there is no file."""
    text = read_text(path) if path else None
    if text is None:
        return None
    records = []
    for line in text.splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def spawned_agent(record):
    """The agent a spawn record starts, without the plugin prefix, or None."""
    if record.get("tool_name") not in SPAWN_TOOLS:
        return None
    agent = str((record.get("tool_input") or {}).get("subagent_type") or "general-purpose")
    return agent[len(PLUGIN_PREFIX):] if agent.startswith(PLUGIN_PREFIX) else agent


def main_calls(records):
    """The main session's calls: a subagent's call carries an agent_id."""
    return [r for r in records if not r.get("agent_id")]


def repo_path(path, cwd, repo):
    """path relative to repo (resolved against cwd), or the absolute path when
    it lies outside repo."""
    full = os.path.normpath(os.path.join(cwd or repo, path))
    rel = os.path.relpath(full, os.path.normpath(repo))
    return full if rel == os.pardir or rel.startswith(os.pardir + os.sep) else rel


def product_source(paths):
    """The tracked paths the Stage 0 bound does not let the main session read."""
    return sorted(p for p in paths if not STAGE0_DOCS.search(p))


def strip_heredocs(command):
    """command without its here-document bodies, so text a Bash call appends to
    the log (a Goal entry naming npm test, say) never reads as a command."""
    kept, end = [], None
    for line in command.split("\n"):
        if end is not None:
            if line.lstrip("\t") == end:
                end = None
            continue
        kept.append(line)
        match = HEREDOC.search(line)
        if match:
            end = match.group(2)
    return "\n".join(kept)


def simple_commands(text):
    """text's simple commands, each as (words, input files): its words with
    redirections taken out, and the files its < redirections read. Each line
    is lexed as the shell would, so quoted text stays one word; a line whose
    quotes do not balance splits on whitespace and operators alone."""
    commands = []
    for line in FD_DUP.sub(" ", text).replace("&>", ">").split("\n"):
        try:
            lexer = shlex.shlex(line, posix=True, punctuation_chars=True)
            lexer.whitespace_split = True
            tokens = list(lexer)
        except ValueError:
            tokens = [t for t in re.split(r"\s+|([();<>|&]+)", line) if t]
        words, inputs, target = [], [], None
        for token in tokens:
            if target is not None:
                if target == "<":
                    inputs.append(token)
                target = None
            elif token in REDIRECTS:
                target = token
            elif SHELL_OPERATOR.fullmatch(token):
                commands.append((words, inputs))
                words, inputs = [], []
            else:
                words.append(token)
        commands.append((words, inputs))
    return [c for c in commands if c[0] or c[1]]


def covered_paths(word, cwd, repo, product, recursive):
    """The product files a path word reaches: the file it names, the files a
    shell glob in it matches, or, for a recursive search, the files under the
    directory it names."""
    path = repo_path(word, cwd, repo)
    if any(ch in word for ch in "*?["):
        return [p for p in product if fnmatch.fnmatch(p, path)]
    if path in product:
        return [path]
    if recursive:
        return [p for p in product if path == "." or p.startswith(path.rstrip("/") + "/")]
    return []


def bash_reads(command, cwd, repo, product):
    """The product files a Bash command reads, heredoc bodies aside: a
    READ_PROGRAMS command's file arguments, a recursive search over a directory
    that holds product files (grep -r, rg, and git grep search the working
    directory when they name no path), an input redirection, or a git show
    <rev>:<path>. A cd earlier in the command moves where later paths
    resolve. product holds repo-relative paths (product_source)."""
    reached = []
    for kept, inputs in simple_commands(strip_heredocs(command)):
        for word in inputs:
            reached += covered_paths(word, cwd, repo, product, False)
        while kept and (re.match(r"[A-Za-z_][A-Za-z0-9_]*=", kept[0]) or kept[0] in SHELL_PREFIXES):
            kept = kept[1:]
        if kept[:1] == ["timeout"]:
            kept = kept[2:]
        if not kept:
            continue
        program, args = os.path.basename(kept[0]), kept[1:]
        if program == "cd":
            cwd = os.path.normpath(os.path.join(cwd, args[0])) if args else repo
            continue
        if program == "git" and args[:1] == ["show"]:
            reached += [p for arg in args[1:] if ":" in arg and not arg.startswith("-")
                        for p in covered_paths(arg.split(":", 1)[1], repo, repo, product, False)]
            continue
        search = program in SEARCH_PROGRAMS or (program == "git" and args[:1] == ["grep"])
        if program == "git" and args[:1] == ["grep"]:
            args = args[1:]
        elif program not in READ_PROGRAMS:
            continue
        if program in ALWAYS_RECURSIVE and "--files" in args:
            continue  # rg --files lists paths, a listing the bound allows
        cut = args.index("--") if "--" in args else len(args)
        options = [a for a in args[:cut] if a.startswith("-")]
        positional = [a for a in args[:cut] if not a.startswith("-")] + args[cut + 1:]
        named_script = any(o in ("-e", "-f") or o.startswith(("--regexp", "--file", "--expression"))
                           for o in options)
        if (search or program in SCRIPT_PROGRAMS) and not named_script:
            positional = positional[1:]
        recursive = program in ALWAYS_RECURSIVE or program == "git" or (search and any(
            o in ("--recursive", "--dereference-recursive")
            or (not o.startswith("--") and ("r" in o[1:] or "R" in o[1:])) for o in options))
        if recursive and not positional:
            positional = ["."]
        for word in positional:
            reached += covered_paths(word, cwd, repo, product, recursive)
    return sorted(set(reached))


def grep_covers(given, cwd, repo, product):
    """The product files a Grep call searches: those under its path (the cwd
    when it names none) that its glob, if any, matches."""
    root = repo_path(given.get("path") or ".", cwd, repo)
    covered = [p for p in product if root == "." or p == root or p.startswith(root + "/")]
    glob = given.get("glob")
    if glob:
        covered = [p for p in covered if fnmatch.fnmatch(p, glob) or fnmatch.fnmatch(os.path.basename(p), glob)]
    return covered


def stage0_judgment(records, repo, product):
    """S8's Stage 0 rule over a hook log (SKILL.md's Stage 0 bound): before its
    first squad-recon spawn the main session reads no product source, by a Read
    of a product file, a Grep over one, or a Bash command that reads one
    (bash_reads), and runs no test or build command.
    product holds the repo-relative paths of product source (product_source);
    S8's prompt names no file, so none is exempt as a file the user named.
    Returns (ok, what it found)."""
    calls = main_calls(records)
    recon = next((i for i, r in enumerate(calls) if spawned_agent(r) == "squad-recon"), None)
    if recon is None:
        return False, "the hook log has no main-session squad-recon spawn"
    product, broken, read = set(product), [], []
    for record in calls[:recon]:
        tool, given, cwd = record.get("tool_name"), record.get("tool_input") or {}, record.get("cwd") or repo
        if tool == "Read" and given.get("file_path"):
            path = repo_path(given["file_path"], cwd, repo)
            read.append(path)
            if path in product:
                broken.append(f"Read {path}")
        elif tool == "Grep":
            covered = grep_covers(given, cwd, repo, sorted(product))
            if covered:
                broken.append(f"Grep {given.get('pattern')!r} over {len(covered)} product files ({', '.join(covered[:3])})")
        elif tool == "Bash":
            command = given.get("command") or ""
            reached = bash_reads(command, cwd, repo, sorted(product))
            if TEST_RUN.search(strip_heredocs(command)):
                broken.append("Bash " + repr(command[:120]))
            elif reached:
                broken.append(f"Bash {command[:120]!r} reads {len(reached)} product files ({', '.join(reached[:3])})")
    found = (f"{recon} main-session calls before the first squad-recon spawn, reading "
             + (", ".join(sorted(set(read))) or "no file"))
    if broken:
        found += "; against the bound: " + "; ".join(broken)
    return not broken, found


def pointer_form():
    """SKILL.md's spawn pointer (Spawn prompts and routing) as (limit, keys,
    values): the most characters a prompt may have, its lines' keys in order,
    and for each key whose placeholder lists its words (<A|B>) those words."""
    text = read_text(SKILL_PATH) or ""
    match = re.search(r"Every stage spawn prompt is a pointer of at most ([0-9]+) characters, in exactly this "
                      r"form:\s*```\n(.*?)\n```", text, re.DOTALL)
    if not match:
        raise SetupError(f"{SKILL_PATH}: no spawn pointer reading 'Every stage spawn prompt is a pointer of at most "
                         f"<N> characters, in exactly this form:' and a fenced block")
    keys, values = [], {}
    for line in match.group(2).split("\n"):
        key, _, value = line.partition(": ")
        keys.append(key)
        words = re.fullmatch(r"<([A-Za-z]+(?:\|[A-Za-z]+)+)>", value)
        if words:
            values[key] = words.group(1).split("|")
    return int(match.group(1)), keys, values


REVIEW_APPEND = re.compile(r"(?m)^" + re.escape(check_logs.REVIEW_HEADING) + r"[ \t]*$")


def pointer_judgment(records):
    """S8's spawn-prompt rule (SKILL.md's Spawn prompts and routing): every
    main-session spawn of a squad stage gets the pointer and nothing else: at
    most the form's characters (the hook log's prompt_chars), one line per key
    of the form in its order, and Stage: and Mode: values the form lists.
    A helper spawned for a DELEGATE: subtask is exempt, since the subtask's
    procedure is its prompt (DELEGATE step 2): every squad-helper spawn, and a
    squad-mech spawn whose prompt does not open with the form's first key,
    made after a spawn of a stage that writes log entries and before any
    main-session append of a ## High-stakes review since that spawn.
    squad-mech's Stage 1 archive comes before any such spawn and its closing
    archive after the review, so both stay held to the form.
    Returns (ok, what it found)."""
    limit, keys, values = pointer_form()
    spawns, helpers, stage_seen, reviewed = [], 0, False, False
    for record in main_calls(records):
        agent = spawned_agent(record) or ""
        given = record.get("tool_input") or {}
        if record.get("tool_name") == "Bash" and REVIEW_APPEND.search(str(given.get("command") or "")):
            reviewed = True
        if not agent.startswith("squad-"):
            continue
        opens = str(given.get("prompt") or "").lstrip().startswith(keys[0] + ":")
        if agent == "squad-helper" or (agent == "squad-mech" and stage_seen and not reviewed and not opens):
            helpers += 1
            continue
        spawns.append(record)
        if agent != "squad-mech":
            stage_seen, reviewed = True, False
    sizes, broken = [], []
    for record in spawns:
        prompt = str((record.get("tool_input") or {}).get("prompt") or "")
        size = int(record.get("prompt_chars") or len(prompt))
        sizes.append(size)
        lines = [line.partition(": ") for line in prompt.strip().split("\n")]
        wrong = [f"{size} characters"] if size > limit else []
        if [line[0].strip() for line in lines] != keys or not all(line[2].strip() for line in lines):
            wrong.append("not one line per pointer key")
        else:
            wrong += [f"{key}: {value.strip()}" for key, _, value in lines
                      if key in values and value.strip() not in values[key]]
        if wrong:
            broken.append(f"{spawned_agent(record)} ({', '.join(wrong)})")
    found = (f"{len(spawns)} stage spawn prompts, the longest {max(sizes or [0])} characters against the pointer's "
             f"{limit}; DELEGATE helper spawns exempt: {helpers}")
    if not spawns:
        return False, "the hook log has no main-session stage spawn"
    if broken:
        found += "; not the pointer: " + "; ".join(broken)
    return not broken, found


def main_usage(records, session):
    """The main session's billed input (input + cache_write + cache_read),
    output, calls, and models from its ledger line for session with the most
    calls: the hook writes a running total at every stop, and hooks that run
    at once can land out of order. None when it has no line."""
    mains = [(int(r.get("calls") or 0), i, r) for i, r in enumerate(records)
             if r.get("agent") == "main" and r.get("session") == session]
    if not mains:
        return None
    last = max(mains, key=lambda item: item[:2])[2]
    billed = sum(int(last.get(key, 0) or 0) for key in ("input", "cache_write", "cache_read"))
    return {"billed": billed, "output": int(last.get("output", 0) or 0), "calls": last.get("calls"),
            "models": last.get("models") or "model unknown"}


def budget_judgment(records, session):
    """S8's budget rule (WO-3f acceptance): the main session's billed input and
    output stay at or below MAIN_BUDGET_INPUT and MAIN_BUDGET_OUTPUT.
    Returns (ok, what it found)."""
    usage = main_usage(records, session)
    if usage is None:
        return False, f"{LEDGER} has no main-session line for session {session}"
    ok = usage["billed"] <= MAIN_BUDGET_INPUT and usage["output"] <= MAIN_BUDGET_OUTPUT
    return ok, (f"main session ({usage['models']}, {usage['calls']} calls): billed input {usage['billed']:,} against "
                f"{MAIN_BUDGET_INPUT:,}, output {usage['output']:,} against {MAIN_BUDGET_OUTPUT:,}")


def audit_spawns(records):
    """The main session's audit spawns in a hook log, as (finders, skeptics):
    spawns of an agent outside the squad, a skeptic being one whose prompt
    carries the skeptic brief, which asks it to refute a finding."""
    spawns = [r for r in main_calls(records) if spawned_agent(r) and not spawned_agent(r).startswith("squad-")]
    skeptics = [r for r in spawns if "refute" in str((r.get("tool_input") or {}).get("prompt") or "").lower()]
    finders = [r for r in spawns if r not in skeptics]
    return finders, skeptics


def audit_counts(entry):
    """(Findings n, skeptics run k, cap) from an ## Audit Findings entry, or None."""
    for _, text in entry["body"]:
        match = re.fullmatch(r"Findings: ([0-9]+); skeptics run: ([0-9]+) \(cap ([0-9]+)\)", text)
        if match:
            return tuple(int(group) for group in match.groups())
    return None


def s9_judgment(entries, records, protocol):
    """S9's audit-cap rule (WO-3f acceptance): the call appended one
    ## Audit Findings entry whose finders found more findings than the skeptic
    cap, whose skeptics run equal the cap, and whose other findings read
    UNREVIEWED, and the hook log shows exactly that many skeptic spawns.
    Returns (ok, what it found)."""
    cap, unreviewed_word = protocol.audit["cap"], protocol.audit["unreviewed"]
    finders, skeptics = audit_spawns(records)
    spawned = f"the hook log shows {len(finders)} finder and {len(skeptics)} skeptic spawns"
    audits = [e for e in entries if e["heading"] == check_logs.AUDIT_HEADING]
    if len(audits) != 1:
        return False, f"{len(audits)} new {check_logs.AUDIT_HEADING} entries; {spawned}"
    counts = audit_counts(audits[0])
    if counts is None:
        return False, f"the {check_logs.AUDIT_HEADING} entry has no 'Findings: <n>; skeptics run: <k> (cap <N>)' line"
    total, run, _ = counts
    unreviewed = sum(1 for _, text in audits[0]["body"] if text.startswith(f"- {unreviewed_word} "))
    found = (f"Findings: {total}; skeptics run: {run}; {unreviewed} {unreviewed_word} (cap {cap}); {spawned}")
    if total <= cap:
        found += f"; the finders returned {total} findings, so the cap of {cap} never bound"
    ok = total > cap and run == cap and unreviewed == total - run and len(skeptics) == run
    return ok, found


LIVE_FIXTURES = os.path.join("tests", "fixtures", "live")
# The checks whose rules read the hook log or the ledger, each with its cases
# in tests/fixtures/live/<check>.json.
LOG_RULE_CHECKS = ("s8", "s9")


def seed_text(fixture):
    """The seed log a tests/fixtures/live/ file names ("seed"), or ""."""
    name = fixture.get("seed")
    if not name:
        return ""
    return read_text(os.path.join(REPO_ROOT, "tests", "fixtures", "logs", f"{name}.log.md")) or ""


def judge_case(check, fixture, case):
    """Apply a live check's rule to one case of tests/fixtures/live/<check>.json
    (check 8b runs every case): the hook log a live call could leave
    ("events"), with S8's ledger lines ("ledger") for its session ("session"),
    or the lines S9's call could append to the file's seed ("append"). S8's
    repo is the seeds' worktree, and its product source is the file's fixture
    repo (tests/fixtures/<repo>/) as tracked. Returns (ok, what it found)."""
    events = case.get("events") or []
    if check == "s8":
        folder = os.path.join("tests", "fixtures", fixture.get("repo") or "")
        tracked = [p for p in git(REPO_ROOT, "ls-files", "-z", "--", folder).split("\0") if p]
        if not fixture.get("repo") or not tracked:
            raise SetupError(f"{LIVE_FIXTURES}/{check}.json names no tracked fixture repo ('repo')")
        product = product_source([os.path.relpath(p, folder) for p in tracked])
        ok_reads, reads = stage0_judgment(events, SEED_WORKTREE, product)
        ok_pointer, pointers = pointer_judgment(events)
        ok_budget, budget = budget_judgment(case.get("ledger") or [], case.get("session"))
        return ok_reads and ok_pointer and ok_budget, f"{reads}; {pointers}; {budget}"
    if check == "s9":
        start = len(seed_text(fixture).rstrip("\n").splitlines()) + 2
        protocol = check_logs.load_protocol(SKILL_PATH)
        return s9_judgment(entries_of(case.get("append") or [], start), events, protocol)
    raise SetupError(f"no hook-log or ledger rule for check {check!r}")


def cmd_snapshot(repo, base, out):
    state = snapshot(repo, base)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=1, sort_keys=True)
    print(f"snapshot: {len(state['product'])} changed product paths, {len(state['archives'])} archives, "
          f"log {len(state['log'].splitlines())} lines")
    return 0


# ---- verify --------------------------------------------------------------------

class Report(object):
    def __init__(self):
        self.failures = 0

    def ok(self, condition, message, detail=""):
        if condition:
            print(f"  ok    {message}")
        else:
            self.failures += 1
            print(f"  FAIL  {message}" + (f": {detail}" if detail else ""))
        return condition

    def note(self, message):
        print(f"  note  {message}")


def entries_of(lines, first_number=1):
    _, entries = check_logs.split_entries(list(enumerate(lines, first_number)))
    return entries


def fields(entry):
    found = {}
    for _, text in entry["body"]:
        match = re.match(r"([A-Z][A-Za-z' ]*): (.*)$", text)
        if match and match.group(1) not in found:
            found[match.group(1)] = match.group(2)
    return found


def executor_routes():
    """Classification word -> executor agent, from SKILL.md's Stage 4 list."""
    text = read_text(SKILL_PATH) or ""
    routes = dict(re.findall(r"^- \*\*(MECHANICAL|STANDARD|COMPLEX)\*\* → spawn `([a-z-]+)`", text, re.MULTILINE))
    if set(routes) != {"MECHANICAL", "STANDARD", "COMPLEX"}:
        raise SetupError(f"{SKILL_PATH}: Stage 4 no longer lists '- **<CLASS>** → spawn `<agent>`' for all three classes")
    return routes


class Context(object):
    def __init__(self, repo, base, before, result, events=None):
        self.repo = os.path.abspath(repo)
        self.base = base
        self.before = before
        self.result = result
        self.events = events   # the hook log's records, or None without one
        stats = result.get("subagent_stats") or {}
        self.by_type = {
            (k[len(PLUGIN_PREFIX):] if k.startswith(PLUGIN_PREFIX) else k): v
            for k, v in (stats.get("by_type") or {}).items()
        }
        self.denials = result.get("permission_denials") or []
        self.after = snapshot(repo, base)

        active = self.after["log"]
        self.cleared = not active.strip()
        self.log_path, self.log_text = None, ""
        if not self.cleared:
            self.log_path, self.log_text = os.path.join(self.repo, LOG), active
        else:
            fresh = [name for name in self.after["archives"] if name not in before["archives"]]
            if fresh:
                self.log_path = os.path.join(self.repo, ARCHIVE_DIR, sorted(fresh)[-1])
                self.log_text = read_text(self.log_path) or ""
        self.before_lines = before["log"].splitlines()
        self.lines = self.log_text.splitlines()
        self.prefix_kept = self.lines[:len(self.before_lines)] == self.before_lines
        self.all_entries = entries_of(self.lines)
        self.new_entries = entries_of(self.lines[len(self.before_lines):], len(self.before_lines) + 1) if self.prefix_kept else []
        statuses = [e for e in self.all_entries if e["heading"] == check_logs.STATUS_HEADING]
        self.status = fields(statuses[-1]) if statuses else {}

    def new(self, heading_prefix):
        return [e for e in self.new_entries if e["heading"].startswith(heading_prefix)]

    def new_decisions(self, decision_type):
        return [e for e in self.new("## Decision") if fields(e).get("Type") == decision_type]

    def stage_sequence(self):
        sequence = []
        for entry in self.new_entries:
            heading = entry["heading"]
            if heading in (check_logs.STATUS_HEADING, "## Decision") or heading.startswith("## Delegated"):
                continue
            if heading.endswith(check_logs.CONT):
                heading = heading[:-len(check_logs.CONT)]
            if not sequence or sequence[-1] != heading:
                sequence.append(heading)
        return sequence


def expect_by_type(ctx, report, wanted, what):
    report.ok(ctx.by_type == wanted, f"subagent_stats.by_type is {wanted or 'empty'} ({what})", f"got {ctx.by_type}")


def expect_no_executor(ctx, report):
    spawned = {k: v for k, v in ctx.by_type.items() if k.startswith("squad-executor")}
    report.ok(not spawned, "no executor spawn in subagent_stats.by_type", f"got {spawned}")


def expect_product_unchanged(ctx, report):
    report.ok(ctx.after["head"] == ctx.before["head"], "no commit was made", f"HEAD moved to {ctx.after['head'][:12]}")
    moved = sorted(p for p in set(ctx.before["product"]) | set(ctx.after["product"])
                   if ctx.before["product"].get(p) != ctx.after["product"].get(p))
    report.ok(not moved, "no product file changed during this call", ", ".join(moved))


def expect_log_kept(ctx, report):
    report.ok(not ctx.cleared, f"the active {LOG} is not cleared")


def new_archives(ctx):
    return sorted(name for name in ctx.after["archives"] if name not in ctx.before["archives"])


def expect_no_new_archive(ctx, report, why="a work order remains, finding 9"):
    fresh = new_archives(ctx)
    report.ok(not fresh, f"no new archive in {ARCHIVE_DIR}/ ({why})", ", ".join(fresh))


def expect_waiting_for_grant(ctx, report):
    report.ok(ctx.status.get("Grant") == "none", "the latest ## Status reads 'Grant: none'", f"Grant: {ctx.status.get('Grant')}")
    report.ok("grant" in ctx.status.get("Next", "").lower(), "the latest ## Status's Next: awaits a grant",
              f"Next: {ctx.status.get('Next')}")


def expect_gate_denies(ctx, report, protocol):
    reason = check_logs.gate_denial(protocol.gate, ctx.log_text) if ctx.log_text else "no log"
    report.ok(reason is not None and check_logs.NEEDS_HUMAN_DENIAL not in reason,
              "the grant hook denies an executor spawn on the log as it now stands", "the hook allows it")


def expect_no_new_grant(ctx, report):
    report.ok(not ctx.new_decisions("grant"), "no new ## Decision of Type grant (the user granted nothing new)")


def expect_no_work_order(ctx, report, work_order):
    """No new entry runs, covers, or grants work_order. A new Status may
    name it on its Plan: line as the next work order, which Stage 5 and the
    resume table require after a PASS on an earlier one; its Grant: line
    still may not cover it."""
    named = []
    for entry in ctx.new_entries:
        for number, text in entry["body"]:
            if entry["heading"] == check_logs.STATUS_HEADING and text.startswith("Plan: "):
                continue
            if re.match(r"(Plan|Covers|Grant): ", text) and re.search(r"\b" + re.escape(work_order) + r"\b", text):
                named.append(f"line {number}: {text}")
    report.ok(not named, f"no new entry runs, covers, or grants {work_order}", "; ".join(named))


def expect_log_unchanged(ctx, report):
    report.ok(ctx.after["log"] == ctx.before["log"],
              f"{LOG} is byte for byte the log this call found (sha256 unchanged)")


def changed_during_call(ctx):
    """Product paths whose content this call changed (the scenario's own
    commits before the call are not counted)."""
    return sorted(p for p in set(ctx.before["product"]) | set(ctx.after["product"])
                  if ctx.before["product"].get(p) != ctx.after["product"].get(p))


def result_text(ctx):
    return str(ctx.result.get("result") or "")


def expect_recon_baseline(ctx, report):
    """Finding 14: the new Recon entry's Checks: block names the baseline
    result. The fixture's goal names npm test, and its test script passes on
    the untouched tree, so the baseline ran, exited 0, and changed nothing."""
    recon = ctx.new("## Recon")
    body = recon[-1]["body"] if recon else []
    at = check_logs.label_at(body, check_logs.CHECKS_LABEL)
    items = [x for _, x in body[at + 1:at + 3]] if at is not None else []
    baseline = items[1] if len(items) == 2 else ""
    report.ok(bool(items) and re.fullmatch(check_logs.GOAL_FACTS_LINE, items[0]) is not None,
              "the new ## Recon entry's Checks: block opens with its goal facts line", f"got {items[:1]}")
    report.ok(re.fullmatch(check_logs.BASELINE_LINE, baseline) is not None and "test" in baseline.split("`")[1]
              and " -> exit 0; " in baseline and baseline.endswith("; tree changed: no"),
              "the new ## Recon entry's baseline line ran the test command on the untouched tree: exit 0, tree unchanged",
              f"got {baseline!r}")


def check_s1_plan(ctx, report, protocol):
    """S1 turn 1: /squad plan <goal> from an empty log."""
    expect_by_type(ctx, report, {"squad-mech": 1, "squad-recon": 1, "squad-pm": 1}, "mech 1, recon 1, pm 1")
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_recon_baseline(ctx, report)
    wanted = [protocol.goal, "## Recon", "## PM — Plan"]
    got = ctx.stage_sequence()
    report.ok(got == wanted, f"the new stage entries run {' → '.join(wanted)}", f"got {got}")
    report.ok(ctx.status.get("Mode") == "plan", "the latest ## Status reads 'Mode: plan'", f"Mode: {ctx.status.get('Mode')}")
    expect_waiting_for_grant(ctx, report)
    expect_gate_denies(ctx, report, protocol)


def check_s1_approve(ctx, report, protocol):
    """S1 turn 2: "Plan approved; keep it shelved." via --resume."""
    expect_by_type(ctx, report, {}, "0 spawns")
    decisions = ctx.new("## Decision")
    types = [fields(e).get("Type") for e in decisions]
    report.ok(types == ["plan-approved"], "one new ## Decision, of Type plan-approved", f"got {types}")
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_waiting_for_grant(ctx, report)
    expect_gate_denies(ctx, report, protocol)


def seed_classification(ctx):
    _, entries = check_logs.split_entries(list(enumerate(ctx.before_lines, 1)))
    plans = [e for e in entries if e["heading"] == "## PM — Plan"]
    for _, text in plans[-1]["body"] if plans else []:
        match = re.match(r"Classification: (MECHANICAL|STANDARD|COMPLEX)\b", text)
        if match:
            return match.group(1)
    raise SetupError("the seed's latest ## PM — Plan entry has no 'Classification: <MECHANICAL|STANDARD|COMPLEX>' line")


def expect_entry_evidence(ctx, report, protocol):
    """Finding 16: the new Executor entry's Files changed: line names exactly
    the product paths that differ from the base commit, and the new verdict
    answers each of its For acceptance: points with one Executor points: line."""
    executors = ctx.new("## Executor")
    verdicts = [e for e in ctx.new_entries if e["heading"] in check_logs.VERDICT_HEADINGS]
    if not executors or not verdicts:
        report.ok(False, "a new ## Executor entry and a new PM verdict to compare", "one of them is missing")
        return
    body = executors[-1]["body"]
    listed = next((x[len("Files changed: "):] for _, x in body if x.startswith("Files changed: ")), "")
    named = sorted(p.strip() for p in listed.split(",") if p.strip() and p.strip() != "none")
    report.ok(named == sorted(ctx.after["product"]),
              "the Executor's Files changed: line names exactly the paths git shows changed from the base",
              f"Files changed: {named}; changed: {sorted(ctx.after['product'])}")
    point = protocol.criteria["point"]
    at = check_logs.label_at(body, check_logs.POINTS_LABEL)
    asked = [i for _, i in check_logs.point_lines(body, at, point)] if at is not None else []
    verdict = verdicts[-1]["body"]
    at = check_logs.label_at(verdict, protocol.criteria["points"])
    answered = [i for _, i in check_logs.point_lines(verdict, at, point)] if at is not None else []
    report.ok(sorted(answered) == sorted(asked), "the verdict answers each Executor point once (Executor points:)",
              f"asked {asked}, answered {answered}")


def check_s2(ctx, report, protocol):
    """S2: the log grants r1 WO-1; "Resume the squad run." runs WO-1 alone."""
    classification = seed_classification(ctx)
    executor = executor_routes()[classification]
    expect_by_type(ctx, report, {executor: 1, "squad-pm": 1}, f"one {executor} for {classification}, one PM")
    report.ok(not ctx.denials, "permission_denials is empty", json.dumps(ctx.denials)[:400])
    changed = sorted(ctx.after["product"])
    outside = [p for p in changed if p not in S2_WO1_FILES]
    report.ok(bool(changed) and not outside, f"the changed files are within WO-1's list ({', '.join(S2_WO1_FILES)})",
              f"changed {changed}")
    report.ok(S2_WO2_MARK not in product_text(ctx.repo, ctx.base), f"the tree has none of WO-2's {S2_WO2_MARK} work")
    executors = ctx.new("## Executor")
    report.ok(len(executors) == 1, "one new ## Executor entry", f"got {len(executors)}")
    verdicts = [e["heading"] for e in ctx.new_entries if e["heading"] in ("## PM — PASS", "## PM — FAIL")]
    report.ok(verdicts == ["## PM — PASS"], "one new PM verdict, a PASS", f"got {verdicts}")
    report.ok(not ctx.new("## PM — Plan"), "no new ## PM — Plan entry")
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_no_new_grant(ctx, report)
    expect_no_work_order(ctx, report, "WO-2")
    expect_entry_evidence(ctx, report, protocol)


def check_s2b(ctx, report, protocol):
    """S2b: the grant names r1, the log ends at r2."""
    expect_no_executor(ctx, report)
    report.ok(not ctx.new("## Executor"), "no new ## Executor entry")
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_no_new_grant(ctx, report)
    expect_gate_denies(ctx, report, protocol)


def check_s2c(ctx, report, protocol):
    """S2c: WO-1 already has a PASS and the grant covers WO-1 alone."""
    expect_by_type(ctx, report, {}, "0 spawns")
    report.ok(not ctx.new("## Executor"), "no new ## Executor entry")
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_no_new_grant(ctx, report)
    expect_no_work_order(ctx, report, "WO-2")


def check_s2o(ctx, report, protocol):
    """Second run: /squad <another goal> over S2's open run (finding 11)."""
    expect_by_type(ctx, report, {}, "0 spawns: no squad-mech archive over an open run")
    expect_log_unchanged(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_product_unchanged(ctx, report)
    text = result_text(ctx).lower()
    report.ok(any(word in text for word in ("park", "abandon", "worktree")),
              "the final message offers to park or abandon the open run, or a separate worktree",
              result_text(ctx)[:300])


def new_plan_attempts(ctx):
    return [fields(e).get("Attempt") for e in ctx.new_entries if e["heading"] == "## PM — Plan"]


def named_sources(ctx, entry):
    """The tracked src/ files an entry names, by path or by file name."""
    text = "\n".join(t for _, t in entry["body"])
    files = [p for p in git(ctx.repo, "ls-files", "src").splitlines() if p]
    return sorted(p for p in files if p in text or os.path.basename(p) in text)


def check_s3a(ctx, report, protocol):
    """S3a: commit B edits src/server/db/store.js, which the plan names."""
    expect_no_executor(ctx, report)
    report.ok("squad-recon" in ctx.by_type and "squad-pm" in ctx.by_type,
              "a squad-recon and a squad-pm spawn (scoped re-map, then a new plan attempt)", f"got {ctx.by_type}")
    got = ctx.stage_sequence()
    report.ok(got == ["## Recon", "## PM — Plan"], "the new stage entries run ## Recon → ## PM — Plan", f"got {got}")
    recon = ctx.new("## Recon")
    report.ok(bool(recon) and "store.js" in "\n".join(t for _, t in recon[-1]["body"]),
              "the new ## Recon entry re-maps src/server/db/store.js, the path commit B changed")
    seed = [e for e in entries_of(ctx.before_lines) if e["heading"] == "## Recon"]
    if recon and seed:
        mapped, scoped = named_sources(ctx, seed[0]), named_sources(ctx, recon[-1])
        report.ok(len(scoped) < len(mapped),
                  f"the new ## Recon entry names fewer src/ files than the seed's full map ({len(mapped)}), so it "
                  f"re-maps only what commit B moved", f"it names {scoped}")
    report.ok(new_plan_attempts(ctx) == ["2"], "the new plan is attempt 2, revision r2", f"got {new_plan_attempts(ctx)}")
    report.ok(not changed_during_call(ctx), "no product file changed during this call", ", ".join(changed_during_call(ctx)))
    expect_log_kept(ctx, report)
    expect_no_new_grant(ctx, report)
    expect_gate_denies(ctx, report, protocol)


def check_s3b(ctx, report, protocol):
    """S3b: commit B adds docs/notes.md, which the plan does not name."""
    classification = seed_classification(ctx)
    executor = executor_routes()[classification]
    expect_by_type(ctx, report, {executor: 1, "squad-pm": 1}, f"one {executor} for {classification}, one PM, no Recon")
    head = ctx.before["head"]
    order = [e["heading"] for e in ctx.new_entries
             if e["heading"] == "## Executor"
             or (e["heading"] == check_logs.STATUS_HEADING and len(fields(e).get("Base", "")) >= 7
                 and head.startswith(fields(e).get("Base", "")))]
    report.ok(bool(order) and order[0] == check_logs.STATUS_HEADING and "## Executor" in order,
              f"a new ## Status records Base: {head[:7]} (commit B) before the new ## Executor entry", f"got {order}")
    changed = changed_during_call(ctx)
    outside = [p for p in changed if p not in S2_WO1_FILES]
    report.ok(bool(changed) and not outside, f"the files this call changed are within WO-1's list", f"changed {changed}")
    verdicts = [e["heading"] for e in ctx.new_entries if e["heading"] in ("## PM — PASS", "## PM — FAIL")]
    report.ok(verdicts == ["## PM — PASS"], "one new PM verdict, a PASS", f"got {verdicts}")
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_no_work_order(ctx, report, "WO-2")


def check_accept_only(ctx, report, verdict):
    expect_by_type(ctx, report, {"squad-pm": 1}, "pm 1: no executor and no next work order")
    report.ok(not ctx.new("## Executor"), "no new ## Executor entry")
    verdicts = [e["heading"] for e in ctx.new_entries if e["heading"] in ("## PM — PASS", "## PM — FAIL")]
    report.ok(verdicts == [verdict], f"one new PM verdict, a {verdict[len('## PM — '):]}", f"got {verdicts}")
    report.ok(not changed_during_call(ctx), "no product file changed during this call", ", ".join(changed_during_call(ctx)))
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_no_new_grant(ctx, report)
    new_verdicts = [e for e in ctx.new_entries if e["heading"] in check_logs.VERDICT_HEADINGS]
    tested = fields(new_verdicts[-1]).get("Tested", "") if new_verdicts else ""
    commit = tested.split(",", 1)[0]
    report.ok(len(commit) >= 7 and ctx.after["head"].startswith(commit) and tested.endswith("working tree clean"),
              f"the verdict's Tested: line names commit C ({ctx.after['head'][:12]}) and a clean working tree",
              f"Tested: {tested}")
    report.ok(ctx.status.get("Plan", "").startswith("r1, "), "the latest ## Status names plan r1 as the one accepted",
              f"Plan: {ctx.status.get('Plan')}")


def check_s4(ctx, report, protocol):
    """S4: the external implementation of WO-1 is commit C; accept it."""
    check_accept_only(ctx, report, "## PM — PASS")
    expect_no_work_order(ctx, report, "WO-2")


def check_s4b(ctx, report, protocol):
    """S4b: commit C also adds WO-2's event code to src/server/log.js."""
    check_accept_only(ctx, report, "## PM — FAIL")
    fails = ctx.new("## PM — FAIL")
    body = "\n".join(t for _, t in fails[-1]["body"]) if fails else ""
    report.ok("log.js" in body or "WO-2" in body, "the FAIL cites the out-of-scope WO-2 change in src/server/log.js",
              body[:300])


def criteria_rows(entry):
    """{criterion ID: (Result, How, Evidence)} from the entry's criteria table."""
    body = entry["body"]
    at = check_logs.label_at(body, check_logs.TESTED.rstrip(": "))
    rows = {}
    for _, text in body[at + 3:] if at is not None else []:
        if not text.startswith("|"):
            break
        parts = [part.strip() for part in text.strip().strip("|").split(" | ", 3)]
        if len(parts) == 4:
            rows[parts[0]] = tuple(parts[1:])
    return rows


def entry_text(entry):
    return "\n".join(text for _, text in entry["body"])


def s5_judgment(entries, base):
    """S5's rule for the PM entries a call appended: no PASS, and one verdict
    on the browser check's criterion: a FAIL whose row reads not met, or a
    pending entry whose row reads not met: pre-existing, citing a run on the
    base commit, and whose needs-human: blocker asks to waive or re-scope that
    criterion. Returns (ok, what it found). Check 8b runs it over the outcomes
    in tests/fixtures/logs/s5.expect.json."""
    judged = [e for e in entries if e["heading"] in check_logs.VERDICT_HEADINGS + (check_logs.PENDING_HEADING,)]
    passes = [e for e in judged if e["heading"] == "## PM — PASS"]
    if passes:
        return False, f"a ## PM — PASS at line {passes[0]['line']}"
    if len(judged) != 1:
        return False, f"{len(judged)} new PM verdict or pending entries"
    entry = judged[0]
    result = criteria_rows(entry).get(S5_CRITERION, (None,))[0]
    found = f"a {entry['heading']!r} entry whose {S5_CRITERION} row reads {result!r}"
    if entry["heading"] == "## PM — FAIL":
        return result == "not met", found
    question = next((text for _, text in entry["body"] if text.startswith("- needs-human:")), "")
    asks = question.startswith(check_logs.WAIVE_QUESTION) and re.search(r"\b" + S5_CRITERION + r"\b", question)
    # The Tested: line names HEAD, which is the base commit when the change is
    # uncommitted, so the run on the base commit is cited elsewhere.
    cited = "\n".join(text for _, text in entry["body"] if not text.startswith(check_logs.TESTED))
    cites_base = base[:7] in cited or re.search(r"base commit|worktree", cited, re.IGNORECASE) is not None
    return (result == check_logs.PRE_EXISTING and bool(asks) and cites_base,
            f"{found}, asking {question!r}, citing " + ("a" if cites_base else "no") + " run on the base commit")


def check_s5(ctx, report, protocol):
    """S5: the Executor calls a failing browser check pre-existing; "Continue the squad run."."""
    expect_by_type(ctx, report, {"squad-pm": 1}, "pm 1: the ACCEPT the latest Status names, and no executor")
    ok, found = s5_judgment(ctx.new_entries, ctx.before["base"])
    report.ok(ok, f"no PASS: {S5_CRITERION} reads 'not met' in a FAIL, or 'not met: pre-existing' in a pending entry "
                  f"that cites the base-commit run and asks 'needs-human: waive or re-scope {S5_CRITERION}'", found)
    judged = [e for e in ctx.new_entries if e["heading"] in check_logs.VERDICT_HEADINGS + (check_logs.PENDING_HEADING,)]
    text = entry_text(judged[-1]) if judged else ""
    report.ok(re.search(r"check[:-]overflow", text) is not None and re.search(r"\bexit 1\b", text) is not None,
              "the PM entry records the browser check it re-ran, exit 1")
    report.ok(re.search(r"npm test.*\bexit 0\b", text) is not None, "the PM entry records npm test, exit 0: the unit tests pass")
    report.ok(not changed_during_call(ctx), "no product file changed during this call", ", ".join(changed_during_call(ctx)))
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report, "nothing passed")
    expect_no_new_grant(ctx, report)


def recon_tool_line(entry):
    """The Recon entry's Checks: line after the goal facts that names the
    browser the criteria need as missing or failing, or None."""
    body = entry["body"]
    at = check_logs.label_at(body, check_logs.CHECKS_LABEL)
    items = []
    for _, text in body[at + 1:] if at is not None else []:
        if not text.startswith("- "):
            break
        items.append(text)
    for text in items[1:]:
        code = re.search(r"-> exit ([0-9]+)", text)
        if BROWSER_WORDS.search(text) and ((code and code.group(1) != "0") or MISSING_WORDS.search(text)):
            return text
    return None


def check_s5b(ctx, report, protocol):
    """S5b: no browser for the check AC2 names; "Continue the squad run." at Recon."""
    expect_by_type(ctx, report, {"squad-recon": 1}, "recon 1: no plan and no executor")
    report.ok(not ctx.denials, "permission_denials is empty: nothing tried to spawn past the blocker",
              json.dumps(ctx.denials)[:400])
    recon = ctx.new("## Recon")
    entry = recon[-1] if recon else None
    tool = recon_tool_line(entry) if entry else None
    report.ok(tool is not None, "the new ## Recon entry's Checks: block names the missing browser",
              "no Checks: line names Chromium, Playwright, or the browser check as missing or failing")
    blocker = check_logs.needs_human_line(entry) if entry else None
    why = "\n".join(text for number, text in entry["body"] if blocker and number > blocker) if entry else ""
    report.ok(blocker is not None and BROWSER_WORDS.search(why) is not None,
              "the Recon entry ends with a needs-human: blocker about the browser", why[:300])
    report.ok(not ctx.new(check_logs.PLAN_HEADING) and not ctx.new("## Executor"), "no plan or Executor entry: the run stopped at Recon")
    reason = check_logs.gate_denial(protocol.gate, ctx.log_text) if ctx.log_text else None
    report.ok(reason is not None and check_logs.NEEDS_HUMAN_DENIAL in reason,
              "the grant hook holds an executor spawn on the open needs-human: blocker", str(reason))
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report, "the run stopped at Recon")


def check_s6a(ctx, report, protocol):
    """S6a: the log ends in a high-stakes PASS; "Continue."."""
    expect_by_type(ctx, report, {"squad-mech": 1}, "mech 1: the closing archive, and no spawn before the review")
    fresh = new_archives(ctx)
    report.ok(ctx.cleared and len(fresh) == 1, f"the active {LOG} is empty and one new archive holds the log",
              f"cleared {ctx.cleared}, new archives {fresh}")
    report.ok(not fresh or fresh[0].endswith("_" + log_run(ctx.before["log"]) + ".md"),
              "the archive is named for the run ID", ", ".join(fresh))
    reviews = ctx.new(check_logs.REVIEW_HEADING)
    review = reviews[-1] if reviews else None
    report.ok(len(reviews) == 1, f"one new {check_logs.REVIEW_HEADING} entry, which the archive holds", f"got {len(reviews)}")
    got = fields(review) if review else {}
    report.ok(got.get("Result") == "upheld", "the review reads 'Result: upheld'", f"Result: {got.get('Result')}")
    dirty = len(ctx.after["product"])
    tree = "clean" if not dirty else f"{dirty} changed file" + ("s" if dirty != 1 else "")
    tested = got.get("Tested", "")
    commit = tested.split(",", 1)[0]
    report.ok(len(commit) >= 7 and ctx.after["head"].startswith(commit) and tested.endswith("working tree " + tree),
              f"the review's Tested: line names HEAD ({ctx.after['head'][:12]}) and a working tree of {tree}",
              f"Tested: {tested}")
    checked = entry_text(review) if review else ""
    report.ok(re.search(r"npm test.*-> exit 0", checked) is not None, "the review re-ran npm test itself, exit 0")
    at = ctx.new_entries.index(review) if review else len(ctx.new_entries)
    after = [e["heading"] for e in ctx.new_entries[at + 1:]]
    report.ok(after == [check_logs.STATUS_HEADING], "the archive ends with the review and the ## Status after it",
              f"after the review: {after}")
    stages = [e["heading"] for e in ctx.new_entries
              if e["heading"] not in (check_logs.STATUS_HEADING, check_logs.DECISION_HEADING, check_logs.REVIEW_HEADING)]
    report.ok(not stages, "no stage entry: the main session reviewed, and ACCEPT did not run again", f"got {stages}")
    report.ok(not changed_during_call(ctx), "no product file changed during this call", ", ".join(changed_during_call(ctx)))


def check_s6b(ctx, report, protocol):
    """S6b: /squad <new goal> over a parked log whose archive name collides."""
    expect_by_type(ctx, report, {"squad-mech": 1}, "mech 1: the Stage 1 archive, and nothing after its failure")
    expect_log_unchanged(ctx, report)
    expect_no_new_archive(ctx, report, "no retry under another name")
    earlier = sorted(ctx.before["archives"])
    report.ok(bool(earlier) and all(ctx.after["archives"].get(n) == h for n, h in ctx.before["archives"].items()),
              f"the colliding archive keeps its sha256 ({', '.join(earlier)})")
    expect_product_unchanged(ctx, report)
    report.ok("ARCHIVE FAILED" in result_text(ctx), "the final message reports ARCHIVE FAILED", result_text(ctx)[:300])


def check_s7b(ctx, report, protocol):
    """S7b: three FAILs are logged; "Resume the squad run."."""
    expect_by_type(ctx, report, {}, "0 spawns")
    expect_log_unchanged(ctx, report)
    expect_no_new_archive(ctx, report)
    expect_product_unchanged(ctx, report)
    text = result_text(ctx)
    report.ok(re.search(r"\b(three|3)\b", text, re.IGNORECASE) is not None and "fail" in text.lower(),
              "the final message names the three-FAIL stop", text[:300])


def expect_tool_log(ctx, report):
    return report.ok(bool(ctx.events), "run.sh's hook log recorded this call's tool calls", "no hook log, or an empty one")


def check_s8(ctx, report, protocol):
    """S8: the reference run, "/squad <goal>" on an empty log (WO-3f)."""
    report.ok("squad-recon" in ctx.by_type, "a squad-recon spawn (Stage 2)", f"got {ctx.by_type}")
    verdicts = [e["heading"] for e in ctx.new_entries if e["heading"] in check_logs.VERDICT_HEADINGS]
    report.ok("## PM — PASS" in verdicts, "the run reaches a PM PASS, so its usage is a whole reference run's",
              f"verdicts {verdicts}")
    if expect_tool_log(ctx, report):
        tracked = git(ctx.repo, "ls-tree", "-r", "-z", "--name-only", ctx.before["base"]).split("\0")
        ok, found = stage0_judgment(ctx.events, ctx.repo, product_source([p for p in tracked if p]))
        report.ok(ok, "before the first squad-recon spawn the main session reads no product source (Read, Grep, or "
                      "a Bash read) and runs no test or build (SKILL.md's Stage 0 bound)", found)
        if ok:
            report.note(found)
        ok, found = pointer_judgment(ctx.events)
        report.ok(ok, "every main-session stage spawn prompt is the pointer and nothing else (SKILL.md's Spawn "
                      "prompts and routing)", found)
        if ok:
            report.note(found)
    ok, found = budget_judgment(ledger(ctx.repo), ctx.result.get("session_id"))
    report.ok(ok, f"the main session stays within {MAIN_BUDGET_INPUT:,} billed input and {MAIN_BUDGET_OUTPUT:,} output "
                  f"tokens (the ledger's main-session line)", found)
    if ok:
        report.note(found + "; the ledger's output can read low (the ledger check below notes any shortfall)")


def check_s9(ctx, report, protocol):
    """S9: the audit seed, WO-1 with about 30 planted defects; "Resume the squad run." (WO-3f)."""
    report.ok(set(ctx.by_type) == {"general-purpose"},
              "every spawn is the host's general-purpose agent (finders and skeptics), and no squad agent runs",
              f"got {ctx.by_type}")
    if expect_tool_log(ctx, report):
        cap = protocol.audit["cap"]
        ok, found = s9_judgment(ctx.new_entries, ctx.events, protocol)
        report.ok(ok, f"the finders' findings exceed the cap of {cap}, one skeptic spawn per reviewed finding runs "
                      f"{cap} skeptics, and the ## Audit Findings entry marks the rest "
                      f"{protocol.audit['unreviewed']}", found)
        if ok:
            report.note(found + f"; the seed plants about {S9_PLANTED}")
        finders, skeptics = audit_spawns(ctx.events)
        report.ok(sum(ctx.by_type.values()) == len(finders) + len(skeptics),
                  "subagent_stats counts the finder and skeptic spawns the hook log shows",
                  f"by_type {ctx.by_type}, hook log {len(finders)} + {len(skeptics)}")
        for role, spawns in (("finder", finders), ("skeptic", skeptics)):
            models = collections.Counter(str((r.get("tool_input") or {}).get("model") or "none") for r in spawns)
            report.note(f"{role} spawns by model: {dict(models)}")
    tail = [e["heading"] for e in ctx.new_entries[-2:]]
    report.ok(tail == [check_logs.AUDIT_HEADING, check_logs.STATUS_HEADING] and "squad-pm" in ctx.status.get("Next", ""),
              "the call ends with the ## Audit Findings entry and a ## Status whose Next: spawns squad-pm (ACCEPT)",
              f"last entries {tail}, Next: {ctx.status.get('Next')}")
    expect_product_unchanged(ctx, report)
    expect_log_kept(ctx, report)
    expect_no_new_archive(ctx, report, "the run stops before acceptance")
    expect_no_new_grant(ctx, report)


CHECKS = collections.OrderedDict([
    ("s1-plan", check_s1_plan),
    ("s1-approve", check_s1_approve),
    ("s2", check_s2),
    ("s2b", check_s2b),
    ("s2c", check_s2c),
    ("s2o", check_s2o),
    ("s3a", check_s3a),
    ("s3b", check_s3b),
    ("s4", check_s4),
    ("s4b", check_s4b),
    ("s5", check_s5),
    ("s5b", check_s5b),
    ("s6a", check_s6a),
    ("s6b", check_s6b),
    ("s7b", check_s7b),
    ("s8", check_s8),
    ("s9", check_s9),
])


def check_ledger(ctx, report):
    """WO-3c acceptance: the usage ledger's lines for this session total the
    host's billed input within 1% and never exceed its output, and this call's
    new lines name one agent per spawn (an agent continued with SendMessage
    writes a line at each stop, and its last one counts)."""
    session = ctx.result.get("session_id")
    records = [r for r in ledger(ctx.repo) if r.get("session") == session]
    if not records:
        if ctx.by_type:
            report.ok(False, f"{LEDGER} has lines for session {session}", "none, though the call spawned agents")
        else:
            report.note(f"{LEDGER} has no line for this session; the call spawned nothing, so none is due")
        return
    agents, main = {}, None
    for record in records:
        if record.get("agent") == "main":
            main = record
        else:
            agents[str(record.get("agent_id"))] = record
    if not report.ok(main is not None, f"{LEDGER} has a main-session line for session {session}"):
        return
    rows = list(agents.values()) + [main]
    billed = sum(int(r.get("input", 0)) + int(r.get("cache_write", 0)) + int(r.get("cache_read", 0)) for r in rows)
    output = sum(int(r.get("output", 0)) for r in rows)
    usage = (ctx.result.get("modelUsage") or {}).values()
    host_billed = sum(int(m.get("inputTokens", 0)) + int(m.get("cacheCreationInputTokens", 0))
                      + int(m.get("cacheReadInputTokens", 0)) for m in usage)
    host_output = sum(int(m.get("outputTokens", 0)) for m in usage)
    report.ok(abs(billed - host_billed) <= LEDGER_TOLERANCE * max(host_billed, 1),
              f"ledger billed input {billed:,} is within 1% of modelUsage {host_billed:,}")
    # The host writes a message with parallel tool calls to the transcript
    # before its stream ends and never updates that record's output count
    # (3 where modelUsage counted 193 on Claude Code 2.1.282), so the ledger's
    # output can only read low. Assert that bound and report the shortfall.
    report.ok(output <= host_output, f"ledger output {output:,} does not exceed modelUsage {host_output:,}")
    if host_output and output < host_output:
        report.note(f"ledger output reads {host_output - output:,} tokens "
                    f"({(host_output - output) / host_output:.1%}) below modelUsage")
    added = collections.Counter(r.get("agent") for aid, r in agents.items() if aid not in set(ctx.before["ledger_ids"]))
    report.ok(dict(added) == ctx.by_type, "the ledger gained lines for one agent per spawn", f"ledger {dict(added)}, spawned {ctx.by_type}")


def cmd_verify(check, repo, base, state_path, result_path, summary, label, tools=None):
    with open(state_path, encoding="utf-8") as handle:
        before = json.load(handle)
    events = read_tool_log(tools)
    report = Report()
    print(f"{label or check}: check {check}")
    try:
        with open(result_path, encoding="utf-8") as handle:
            result = json.load(handle)
        if not isinstance(result, dict):
            raise ValueError("not a JSON object")
    except (OSError, ValueError) as error:
        report.ok(False, f"{result_path} holds the claude -p JSON result", str(error))
        return finish(report, summary, label, check, None)

    protocol = check_logs.load_protocol(SKILL_PATH)
    ctx = Context(repo, base, before, result, events)
    report.note(f"cost ${float(result.get('total_cost_usd') or 0):.2f}, {result.get('num_turns')} turns, "
                f"by_type {ctx.by_type or '{}'}, {len(ctx.denials)} permission denials")
    if events is not None:
        report.note(f"hook log: {len(events)} tool calls, {len(main_calls(events))} of them the main session's")
    for denial in ctx.denials:
        report.note("denied: " + json.dumps(denial)[:300])
    report.ok(result.get("is_error") is False and result.get("subtype") == "success",
              "claude -p finished without error", f"subtype {result.get('subtype')}, is_error {result.get('is_error')}")
    report.ok(ctx.log_path is not None, "the call left a log (the active log, or a new archive when it cleared it)")
    if ctx.log_path:
        report.note(f"log: {os.path.relpath(ctx.log_path, ctx.repo)}" + (" (the active log was cleared)" if ctx.cleared else ""))
        report.ok(ctx.prefix_kept, "the log starts with the log this call found (append-only)")
        count, problems = check_logs.lint(check_logs.read_log(ctx.log_path, False), protocol)
        report.ok(not problems, f"the log lints clean with tests/check_logs.py ({count} entries)",
                  "; ".join(f"line {line} [{rule}] {message}" for line, rule, message in problems[:5]))
        blocked = [e["line"] for e in ctx.new_entries if check_logs.needs_human_line(e) is not None]
        if check not in BLOCKER_CHECKS:
            report.ok(not blocked, "no new entry raises a needs-human: blocker", f"entries at lines {blocked}")
    changed = sorted(n for n, h in before["archives"].items() if ctx.after["archives"].get(n) != h)
    report.ok(not changed, "every earlier archive file keeps its sha256", ", ".join(changed))
    CHECKS[check](ctx, report, protocol)
    check_ledger(ctx, report)
    if ctx.status:
        report.note("latest ## Status: " + "; ".join(f"{k}: {v}" for k, v in ctx.status.items() if k in ("Mode", "Plan", "Grant", "Next")))
    return finish(report, summary, label, check, result)


def finish(report, summary, label, check, result):
    verdict = "PASS" if report.failures == 0 else "FAIL"
    print(f"{label or check}: {verdict}" + (f" ({report.failures} failed)" if report.failures else ""))
    if summary:
        cost = float((result or {}).get("total_cost_usd") or 0)
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(f"{label or check}\t{check}\t{verdict}\t{cost:.4f}\n")
    return 0 if report.failures == 0 else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description="Setup and assertions for tests/live/run.sh.")
    sub = parser.add_subparsers(dest="command")
    seed = sub.add_parser("seed")
    seed.add_argument("seed")
    seed.add_argument("repo")
    seed.add_argument("base")
    collide = sub.add_parser("collide")
    collide.add_argument("repo")
    collide.add_argument("shim")
    preflight = sub.add_parser("preflight")
    preflight.add_argument("check", choices=list(CHECKS))
    preflight.add_argument("repo")
    snap = sub.add_parser("snapshot")
    snap.add_argument("repo")
    snap.add_argument("base")
    snap.add_argument("out")
    verify = sub.add_parser("verify")
    verify.add_argument("check", choices=list(CHECKS))
    verify.add_argument("repo")
    verify.add_argument("base")
    verify.add_argument("state")
    verify.add_argument("result")
    verify.add_argument("--tools", help="the hook log toollog wrote for this call")
    verify.add_argument("--summary")
    verify.add_argument("--label")
    toollog = sub.add_parser("toollog")
    toollog.add_argument("path")
    sub.add_parser("checks")
    args = parser.parse_args(argv)
    try:
        if args.command == "seed":
            return cmd_seed(args.seed, args.repo, args.base)
        if args.command == "collide":
            return cmd_collide(args.repo, args.shim)
        if args.command == "preflight":
            return cmd_preflight(args.check, args.repo)
        if args.command == "snapshot":
            return cmd_snapshot(args.repo, args.base, args.out)
        if args.command == "verify":
            return cmd_verify(args.check, args.repo, args.base, args.state, args.result, args.summary, args.label,
                              args.tools)
        if args.command == "toollog":
            return cmd_toollog(args.path)
        if args.command == "checks":
            for name, function in CHECKS.items():
                print(f"{name}\t{function.__doc__}")
            return 0
    except (SetupError, check_logs.ProtocolError, OSError, subprocess.SubprocessError) as error:
        print(f"check_live: {error}", file=sys.stderr)
        return 2
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
