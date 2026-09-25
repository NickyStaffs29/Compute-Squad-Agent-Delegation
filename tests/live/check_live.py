#!/usr/bin/env python3
"""Setup and assertions for the live tier, tests/live/run.sh (report section 6).

run.sh calls this script; it never calls a model itself.

    check_live.py seed <seed.log.md> <repo> <base>
    check_live.py collide <repo> <shim dir>
    check_live.py preflight <check> <repo>
    check_live.py snapshot <repo> <base> <state.json>
    check_live.py verify <check> <repo> <base> <state.json> <result.json> [--summary FILE --label TEXT]
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

Python 3.9 stdlib only.
"""
import argparse
import collections
import hashlib
import json
import os
import re
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
    def __init__(self, repo, base, before, result):
        self.repo = os.path.abspath(repo)
        self.base = base
        self.before = before
        self.result = result
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
])


def check_ledger(ctx, report):
    """WO-3c acceptance: the usage ledger's lines for this session total the
    host's billed input within 1% and never exceed its output, and this call
    added one line per spawn."""
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
    report.ok(dict(added) == ctx.by_type, "the ledger gained one line per spawned agent", f"ledger {dict(added)}, spawned {ctx.by_type}")


def cmd_verify(check, repo, base, state_path, result_path, summary, label):
    with open(state_path, encoding="utf-8") as handle:
        before = json.load(handle)
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
    ctx = Context(repo, base, before, result)
    report.note(f"cost ${float(result.get('total_cost_usd') or 0):.2f}, {result.get('num_turns')} turns, "
                f"by_type {ctx.by_type or '{}'}, {len(ctx.denials)} permission denials")
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
    verify.add_argument("--summary")
    verify.add_argument("--label")
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
            return cmd_verify(args.check, args.repo, args.base, args.state, args.result, args.summary, args.label)
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
