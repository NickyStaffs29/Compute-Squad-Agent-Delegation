#!/usr/bin/env python3
"""The resume table as code: check 8b of scripts/verify.sh.

    python3 tests/resume_next.py [--state JSON] <log>
    python3 tests/resume_next.py --rows

Prints the next action skills/compute-squad/references/resume.md gives for a
log, and the step or table row that gave it. The state says what the
session sees besides the log, as a JSON object whose keys are all optional:

    request   "resume" (default) or "new-goal": /squad over the log with a
              different goal, which the one-active-run rule in SKILL.md and
              squad-mech's open-run guard decide
    host      the host this session runs on (default "Claude Code")
    handed    true when the user's words hand this session the action a
              Next: line gives another host (default false)
    head      the commit git rev-parse HEAD prints (default: the latest
              Status's Base:, so the base has not moved)
    moved     the paths git diff --name-only <Base> HEAD lists
    dirty     the paths git status --porcelain lists
    audit     true for an audit-grade run, whose Executor entry is followed
              by the audit and its ## Audit Findings entry (default false)
    continuable
              true when this session spawned the agent that wrote the last
              entry and can still message it, so a BLOCKING DELEGATE: block
              continues that agent instead of re-spawning the stage (default
              false: a new session cannot message an earlier session's agent)

The model follows the steps and rows of resume.md in order. It reads the
table from that file and stops with status 2 if a row's first column or the
key phrase of its action no longer matches ROWS below, or if a step it
implements is no longer in the file, so a change to the table has to change
this model too. Routing to an executor follows SKILL.md's Stage 4 list, the
escalation rules, and the grant rule. Plans name files in prose, so the base
check matches a moved path, or its file name, against the text of the
governing plan's work-order section and its "Must NOT change:" sentence.
Python 3.9 stdlib only.
"""
import argparse
import json
import os
import re
import sys

sys.dont_write_bytecode = True   # leave no tests/__pycache__ in the checkout
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_logs  # noqa: E402  (the 8a linter: log parser and headings)

REPO_ROOT = check_logs.REPO_ROOT
RESUME_PATH = os.path.join(REPO_ROOT, "skills", "compute-squad", "references", "resume.md")
SKILL_PATH = check_logs.SKILL_PATH

GOAL = "## Goal — Locked"
STATUS = check_logs.STATUS_HEADING
DECISION = "## Decision"
DELEGATED = "## Delegated — "
RECON = "## Recon"
PLAN = check_logs.PLAN_HEADING
EXECUTOR = check_logs.EXECUTOR_HEADING
PENDING = check_logs.PENDING_HEADING
PASS = "## PM — PASS"
FAIL = "## PM — FAIL"
REVIEW = check_logs.REVIEW_HEADING
AUDIT = check_logs.AUDIT_HEADING
CONT = check_logs.CONT
FAIL_LINE = re.compile(r"^(Rerun: |- rerun: )")
# A helper result that refused a step or reports one not run (DELEGATE steps 2 and 4).
REFUSAL = re.compile(r"REFUSED:|\bnot run:")
REFUSED_SOURCE = ", a step refused or not run"
HOSTS = ("Claude Code", "Codex")
RUN_STATE = ("COMPUTE_SQUAD_LOG.md", "compute-squad-archive/")
FILES_CHANGED = "Files changed: "   # the Executor entry's line the tree check reads (finding 16)
# Recon's baseline run may leave files behind, which it names on its baseline
# line and never cleans up (finding 14); the tree check reads those too.
TREE_CHANGED = "; tree changed: "
CLASS_RUNG = {"MECHANICAL": 0, "STANDARD": 1, "COMPLEX": 2}

# The table's rows, in order: the first column exactly, and a phrase its
# action column must contain.
ROWS = (
    ("Ends in a `BLOCKER:` block", "`rerun:` re-runs the named stage, then every later stage."),
    ("Ends in a `DELEGATE:` block", "if the block is `BLOCKING`, continue or re-spawn that stage to finish"),
    ("`## Decision`", "Append the `## Status` it implies, then perform that `Next:`."),
    ("`## Goal — Locked`", "re-spawn the stage that raised it instead."),
    ("`## Recon`", "Spawn `squad-pm` in PLAN mode."),
    ("`## PM — Plan`", "apply the grant rule and spawn the executor on the higher of the latest `Classification:` line's "
                       "rung and the rung escalation has reached."),
    ("`## Executor`", "In an audit-grade run, run the audit. Otherwise spawn `squad-pm` in ACCEPT mode."),
    ("`## Audit Findings`", "Spawn `squad-pm` in ACCEPT mode."),
    ("`## PM — Accept (pending)`", "spawn `squad-pm` in ACCEPT mode for the verdict."),
    ("`## PM — FAIL`", "Re-run the stage on its `Rerun:` line at the rung the escalation rules give"),
    ("`## PM — PASS` in a high-stakes run", "Run the high-stakes review procedure (Stage 5) before anything else. "
                                            "Never spawn ACCEPT again for this verdict."),
    ("`## PM — PASS` in any other run", "Otherwise the PM's archive or clear did not finish: hand back to the user."),
    ("`## High-stakes review` reading `Result: upheld`", "Otherwise spawn `squad-mech` to close the run."),
    ("`## High-stakes review` reading `Result: held`", "then run a new review. An unattended run stops."),
    ("`## High-stakes review` reading `Result: overturned`", "It counts as a FAIL: re-run the stage on its `Rerun:` line"),
)
# Text of the steps this model implements, which resume.md must still carry.
STEPS = (
    ("step 1", "If either entry is missing, ask the user what to do next"),
    ("step 2", "lines matching `^(Rerun: |- rerun: )`. At three, stop and hand back to the user"),
    ("step 2", "append a `## Status` only when none follows the third FAIL."),
    ("step 3", "If `Next:` names another host or session and the user's words do not hand that action to this one"),
    ("step 3", "`Next: none` means the run is closed"),
    ("step 4", "If no entry follows the latest `## Status`, perform its `Next:`."),
    ("step 4", "from the last entry that is neither a `## Status` nor a `## Delegated — <stage>` entry, using the "
               "first row that matches"),
    ("step 4", "A heading's row also covers its `(cont.)` entry. If no row matches"),
    ("step 5", "Before any executor spawn, run the tree check and the base check below."),
    ("DELEGATE row", "only the session that spawned the stage's agent can continue it, so any other session "
                     "re-spawns it."),
    ("DELEGATE row", "If it is not, but a result reports a step `REFUSED:` or `not run:`, re-spawn that stage for a "
                     "new, complete entry (DELEGATE steps 2 and 4)."),
    ("tree check", "A listed path other than `COMPUTE_SQUAD_LOG.md` and `compute-squad-archive/` that no "
                   "`Files changed:` line of this run names, and that no `## Recon` baseline line of this run names "
                   "after `tree changed:`, means"),
    ("base check", "Base check, when `Base:` names a commit that differs from `git rev-parse HEAD`"),
    ("base check", "If no listed path is in the governing plan's must-NOT-change list or among the files and tests "
                   "of the work order about to run, append a `## Status` with the new `Base:` and continue."),
    ("high-stakes", "A run is high-stakes once any line in the log reads `High-stakes: yes`"),
)
ONE_ACTIVE_RUN = "When a new run would start over a non-empty log whose latest `Next:` line is not `Next: none`, do not spawn the archive."


class ProtocolError(Exception):
    """resume.md or SKILL.md no longer reads the way this model assumes."""


def flat(text):
    return " ".join(text.split())


def load_rows(path=RESUME_PATH):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    lines = text.splitlines()
    try:
        start = lines.index("| Last entry | Next action |")
    except ValueError:
        raise ProtocolError(f"{path}: no '| Last entry | Next action |' table")
    rows = []
    for line in lines[start + 2:]:
        if not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.strip().strip("|").split(" | ")]
        if len(cells) != 2:
            raise ProtocolError(f"{path}: table row {line!r} does not have two cells")
        rows.append(tuple(cells))
    firsts = [first for first, _ in rows]
    wanted = [first for first, _ in ROWS]
    if firsts != wanted:
        raise ProtocolError(f"{path}: the table's rows are {firsts!r}; tests/resume_next.py models {wanted!r}")
    for (first, action), (_, phrase) in zip(rows, ROWS):
        if phrase not in action:
            raise ProtocolError(f"{path}: the row {first!r} no longer says {phrase!r}; update tests/resume_next.py")
    body = flat(text)
    for step, phrase in STEPS:
        if flat(phrase) not in body:
            raise ProtocolError(f"{path}: {step} no longer says {phrase!r}; update tests/resume_next.py")
    with open(SKILL_PATH, encoding="utf-8") as handle:
        skill = flat(handle.read())
    if ONE_ACTIVE_RUN not in skill:
        raise ProtocolError(f"{SKILL_PATH}: no one-active-run rule reading {ONE_ACTIVE_RUN!r}")
    return rows


def executor_routes():
    """Classification word -> executor agent, from SKILL.md's Stage 4 list."""
    with open(SKILL_PATH, encoding="utf-8") as handle:
        text = handle.read()
    routes = dict(re.findall(r"^- \*\*(MECHANICAL|STANDARD|COMPLEX)\*\* → spawn `([a-z-]+)`", text, re.MULTILINE))
    if set(routes) != set(CLASS_RUNG):
        raise ProtocolError(f"{SKILL_PATH}: Stage 4 no longer lists '- **<CLASS>** → spawn `<agent>`' for all three")
    return routes


def body_text(entry):
    return "\n".join(text for _, text in entry["body"])


def field(entry, name):
    return next((text[len(name) + 2:] for _, text in entry["body"] if text.startswith(name + ": ")), None)


def base_heading(heading):
    return heading[:-len(CONT)] if heading.endswith(CONT) else heading


def ends_in(entry, marker):
    """True when the entry's last block (after its prose) starts with marker."""
    last = None
    for _, text in entry["body"]:
        if text.startswith(("BLOCKER:", "DELEGATE:")):
            last = text
    return last is not None and last.startswith(marker)


def blocker_item(entry):
    """The first item of the entry's BLOCKER: block, or None."""
    body = [text for _, text in entry["body"]]
    for index, text in enumerate(body):
        if text.startswith("BLOCKER:"):
            return next((line for line in body[index + 1:] if line.strip()), "")
    return None


def delegate_blocking(entry):
    inside = False
    for _, text in entry["body"]:
        if text.startswith("DELEGATE:"):
            inside = True
        elif text.startswith("BLOCKER:"):
            inside = False
        if inside and "BLOCKING" in text:
            return True
    return False


def named(path, text):
    """True when text names path, by its full path or its file name."""
    if path in text:
        return True
    name = os.path.basename(path.rstrip("/"))
    return bool(name) and re.search(r"(?<![\w./-])" + re.escape(name) + r"(?![\w-])", text) is not None


class Run(object):
    """What the steps and rows read from one log."""

    def __init__(self, lines, state):
        self.state = state
        self.lines = [text for _, text in lines]
        _, self.entries = check_logs.split_entries(lines)
        self.routes = executor_routes()
        goals = [e for e in self.entries if e["heading"] == GOAL]
        self.goal = goals[-1] if goals else None
        at = [i for i, e in enumerate(self.entries) if e["heading"] == STATUS]
        self.status_at = at[-1] if at else None
        self.status = self.entries[self.status_at] if at else None
        plans = [e for e in self.entries if base_heading(e["heading"]) == PLAN]
        self.revision = sum(1 for e in plans if e["heading"] == PLAN)
        latest = max((i for i, e in enumerate(self.entries) if e["heading"] == PLAN), default=None)
        self.plan = [e for e in self.entries[latest:] if base_heading(e["heading"]) == PLAN] if latest is not None else []
        self.plan_text = "\n".join(body_text(e) for e in self.plan)
        self.high_stakes = any(line == "High-stakes: yes" for line in self.lines)

    # -- Status fields ----------------------------------------------------
    def status_field(self, name):
        return field(self.status, name) if self.status else None

    def mode(self):
        return self.status_field("Mode") or "full"

    def base(self):
        return self.status_field("Base")

    def work_order(self):
        plan = self.status_field("Plan") or ""
        match = re.fullmatch(r"r[0-9]+, work order (\S+)", plan)
        return match.group(1) if match else "all"

    # -- the governing plan ---------------------------------------------------
    def work_orders(self):
        found = []
        for line in self.plan_text.splitlines():
            match = re.match(r"(WO-[A-Za-z0-9]+)\b", line)
            if match and match.group(1) not in found:
                found.append(match.group(1))
        return found or ["all"]

    def section(self, work_order):
        if work_order == "all":
            return self.plan_text
        kept, inside = [], False
        for line in self.plan_text.splitlines():
            if re.match(r"WO-[A-Za-z0-9]+\b", line) or line.startswith("Must NOT change"):
                inside = line.startswith(work_order + ",") or line.startswith(work_order + " ") \
                    or line.startswith(work_order + ":")
            if inside:
                kept.append(line)
        return "\n".join(kept)

    def must_not_change(self):
        text = flat(self.plan_text)
        at = text.find("Must NOT change:")
        if at < 0:
            return ""
        rest = text[at:]
        end = rest.find("Verification plan:")
        return rest if end < 0 else rest[:end]

    def classification(self):
        value = next((field(e, "Classification") for e in self.plan if e["heading"] == PLAN), None)
        return value if value in CLASS_RUNG else "COMPLEX"

    def executor_agent(self):
        """The higher of the plan's classification rung and the rung
        escalation has reached for the Executor."""
        agents = [self.routes[c] for c in sorted(CLASS_RUNG, key=CLASS_RUNG.get)]
        rung = CLASS_RUNG[self.classification()]
        runs = [i for i, e in enumerate(self.entries) if e["heading"] == EXECUTOR]
        if runs:
            agent = (field(self.entries[runs[-1]], "Agent") or "").split(" ")[0]
            reached = agents.index(agent) if agent in agents else 0
            later = "\n".join(body_text(e) for e in self.entries[runs[-1]:])
            if re.search(r"^(Rerun: |- rerun: )Executor$", later, re.MULTILINE):
                reached = min(reached + 1, len(agents) - 1)
            rung = max(rung, reached)
        return agents[rung]

    def granted(self, work_order):
        grant = self.status_field("Grant") or "none"
        if grant.startswith("all revisions"):
            return True
        match = re.match(r"r([0-9]+) (\S+?),? ", grant + " ")
        return bool(match) and int(match.group(1)) == self.revision and match.group(2) in ("all", work_order)

    # -- the checks before an executor spawn ---------------------------------
    def executor_spawn(self, action, work_order):
        """Run the tree check and the base check, then the action."""
        explained = "\n".join(text for e in self.entries if base_heading(e["heading"]) == EXECUTOR
                              for _, text in e["body"] if text.startswith(FILES_CHANGED))
        explained += "\n" + "\n".join(text.rsplit(TREE_CHANGED, 1)[1] for e in self.entries
                                       if base_heading(e["heading"]) == RECON
                                       for _, text in e["body"] if re.fullmatch(check_logs.BASELINE_LINE, text))
        unlogged = [p for p in self.state.get("dirty", [])
                    if not p.startswith(RUN_STATE) and not named(p, explained)]
        if unlogged:
            return f"stop: unlogged edits in {', '.join(unlogged)}", "tree check"
        base, head = self.base(), self.state.get("head")
        if base and head and head != base:
            scope = self.section(work_order) + "\n" + self.must_not_change()
            hits = [p for p in self.state.get("moved", []) if named(p, scope)]
            if hits:
                grant = "" if self.mode() == "full" else ", which needs its own grant"
                return (f"spawn squad-recon to re-map {', '.join(hits)}, then squad-pm in PLAN mode for plan "
                        f"attempt {self.revision + 1}{grant}"), "base check: re-map"
            return f"append a Status with Base: {head}, then {action}", "base check: continue"
        return action, None

    def run_executor(self, work_order):
        agent = self.executor_agent()
        return self.executor_spawn(f"spawn {agent} for r{self.revision}, work order {work_order}", work_order)

    def grant_rule(self, work_order):
        """The executor spawn when the latest Status grants work_order of the
        governing revision, else a stop that awaits the grant."""
        if self.granted(work_order):
            return self.run_executor(work_order)
        return f"await a grant for r{self.revision} {work_order}, and stop", None

    def rerun(self, stage):
        if stage == "Executor":
            return self.executor_spawn(
                f"re-run Executor with {self.executor_agent()}, then every later stage", self.work_order())
        spawn = {"Recon": "squad-recon", "Plan": "squad-pm in PLAN mode"}.get(stage)
        if spawn is None:
            return f"stop: the entry names no stage to re-run ({stage or 'nothing'}); show it to the user", None
        return f"re-run {stage} ({spawn}), then every later stage", None

    def next_work_order(self, at=None):
        """The work order after the one the latest Status names, or, with
        at, the latest Status above the entry at that index."""
        orders = self.work_orders()
        current = self.work_order()
        if at is not None:
            status = next((e for e in reversed(self.entries[:at]) if e["heading"] == STATUS), None)
            match = re.fullmatch(r"r[0-9]+, work order (\S+)", (field(status, "Plan") or "") if status else "")
            current = match.group(1) if match else "all"
        if current in orders and orders.index(current) + 1 < len(orders):
            return orders[orders.index(current) + 1]
        return None


def stage_spawn(heading):
    return {
        RECON: "squad-recon", PLAN: "squad-pm in PLAN mode", EXECUTOR: "the executor",
        PENDING: "squad-pm in ACCEPT mode",
    }.get(base_heading(heading), heading)


def stage_agent(heading):
    """The agent a continuation messages: the one that wrote heading."""
    return {
        RECON: "squad-recon", PLAN: "squad-pm", EXECUTOR: "the executor", PENDING: "squad-pm",
    }.get(base_heading(heading), heading)


def row_action(run, index):
    """Apply the first matching row to the entry at index. Returns
    (action, row first column, extra source or None)."""
    entry = run.entries[index]
    heading = entry["heading"]
    base = base_heading(heading)
    if ends_in(entry, "BLOCKER:"):
        item = blocker_item(entry) or ""
        first = ROWS[0][0]
        if item.startswith("- rerun: "):
            action, extra = run.rerun(item[len("- rerun: "):].strip())
            return action, first, extra
        attended = (field(run.goal, "Attended") or "yes") if run.goal else "yes"
        if attended == "no":
            return "stop: an unattended run leaves the needs-human: blocker to the user", first, None
        return "ask the user: " + item[2:].strip(), first, None
    if ends_in(entry, "DELEGATE:"):
        results = [e for e in run.entries[index + 1:] if e["heading"].startswith(DELEGATED)]
        first = ROWS[1][0]
        prefix = "" if results else "run the helpers and append their results, then "
        if delegate_blocking(entry):
            what = "the verdict" if base == PENDING else "a (cont.) entry"
            if run.state.get("continuable"):
                return f"{prefix}continue {stage_agent(heading)} with SendMessage for {what}", first, None
            return f"{prefix}re-spawn {stage_spawn(heading)} for {what}", first, None
        if any(REFUSAL.search(body_text(e)) for e in results):
            if base == EXECUTOR:
                action, extra = run.executor_spawn(
                    f"re-spawn {run.executor_agent()} for a new, complete entry", run.work_order())
                return action, first + REFUSED_SOURCE, extra
            return f"re-spawn {stage_spawn(heading)} for a new, complete entry", first + REFUSED_SOURCE, None
        action, row, extra = heading_row(run, index)
        return prefix + action, first + " / " + row, extra
    return heading_row(run, index)


def heading_row(run, index):
    entry = run.entries[index]
    heading = entry["heading"]
    base = base_heading(heading)
    if base == DECISION:
        kind = field(entry, "Type") or ""
        first = ROWS[2][0]
        if kind == "grant":
            covers = field(entry, "Covers") or ""
            match = re.fullmatch(r"r([0-9]+), work order (\S+)", covers)
            work_order = match.group(2) if match else run.work_order()
            action, extra = run.run_executor(work_order)
            return "append the Status the grant implies, then " + action, first, extra
        if kind == "plan-approved":
            return "append a Status awaiting a grant, and stop", first, None
        if kind in ("park", "abandon"):
            return "append a Status with Next: none", first, None
        return f"append the Status the {kind} Decision implies", first, None
    if base == GOAL:
        first = ROWS[3][0]
        before = run.entries[index - 1] if index else None
        if before is not None and before["heading"] == DECISION and field(before, "Type") == "re-lock":
            raised = [e for e in run.entries[:index - 1] if (blocker_item(e) or "").startswith("- needs-human:")]
            if raised:
                return f"re-spawn {stage_spawn(raised[-1]['heading'])}", first, None
        return "spawn squad-recon", first, None
    if base == RECON:
        return "spawn squad-pm in PLAN mode", ROWS[4][0], None
    if base == PLAN:
        first = ROWS[5][0]
        if run.mode() == "plan":
            return "append a Status awaiting a grant, and stop", first, None
        action, extra = run.grant_rule(run.work_order())
        if action.startswith("await "):
            action = "append a Status that awaits " + action[len("await "):]
        return action, first, extra
    if base == EXECUTOR:
        if run.state.get("audit"):
            return "run the audit procedure and append its ## Audit Findings entry", ROWS[6][0], None
        return "spawn squad-pm in ACCEPT mode", ROWS[6][0], None
    if base == AUDIT:
        return "spawn squad-pm in ACCEPT mode", ROWS[7][0], None
    if base == PENDING:
        return "spawn squad-pm in ACCEPT mode for the verdict", ROWS[8][0], None
    if base == FAIL:
        action, extra = run.rerun(field(entry, "Rerun") or "")
        return action, ROWS[9][0], extra
    if base == PASS:
        following = run.next_work_order()
        if run.high_stakes:
            return "run the high-stakes review procedure", ROWS[10][0], None
        first = ROWS[11][0]
        if following is None:
            return "hand back to the user: the PM's archive or clear did not finish", first, None
        action, extra = run.grant_rule(following)
        return f"append a Status naming {following}, then {action}", first, extra
    if base == REVIEW:
        result = field(entry, "Result")
        if result == "upheld":
            first = ROWS[12][0]
            accepted = max((i for i in range(index) if run.entries[i]["heading"] == PASS), default=None)
            following = run.next_work_order(accepted) if accepted is not None else None
            if following is None:
                return "spawn squad-mech to close the run", first, None
            action, extra = run.grant_rule(following)
            return f"append a Status naming {following}, then {action}", first, extra
        if result == "held":
            first = ROWS[13][0]
            attended = (field(run.goal, "Attended") or "yes") if run.goal else "yes"
            if attended == "no":
                return "stop: an unattended run leaves the review's open items to the user", first, None
            return ("ask the user about the review's open items, record each answer as a Decision, then run a new "
                    "high-stakes review"), first, None
        if result == "overturned":
            action, extra = run.rerun(field(entry, "Rerun") or "")
            return action, ROWS[14][0], extra
    return f"stop: no row for {heading!r}; show the entry to the user", "no row", None


def new_run(lines):
    """The one-active-run rule: /squad with a different goal over this log."""
    if not any(text.strip() for _, text in lines):
        return "run Stage 1: the log is empty", "new run: empty log"
    nexts = [text for _, text in lines if text.startswith("Next: ")]
    if nexts and nexts[-1] != "Next: none":
        return "refuse the archive: ask the user to resume, park, or abandon the open run", "new run: refuse"
    return "run Stage 1: archive the log and start the new run", "new run: archive"


def next_action(lines, state=None):
    """Return (action, source): the next action and the step or row that gave it."""
    state = dict(state or {})
    unknown = set(state) - {"request", "host", "handed", "head", "moved", "dirty", "audit", "continuable"}
    if unknown:
        raise ProtocolError(f"unknown state keys {sorted(unknown)!r}")
    if state.get("request", "resume") == "new-goal":
        return new_run(lines)
    run = Run(lines, state)
    if run.goal is None or run.status is None:
        return "ask the user: the log has no Goal or no Status entry", "step 1"
    fails = [i for i, text in enumerate(run.lines) if FAIL_LINE.match(text)]
    if len(fails) >= 3:
        third = fails[2]
        status_after = any(text == STATUS for text in run.lines[third:])
        return "stop and hand back to the user: three FAILs" + ("" if status_after else "; append a Status"), "step 2"
    following = run.status_field("Next") or ""
    if following == "none":
        return "closed: a new goal starts at Stage 1", "step 3"
    clause = re.split(r", then |; then ", following)[0]
    hosts = [host for host in HOSTS if "in " + host in clause]
    if hosts and hosts[0] != state.get("host", "Claude Code") and not state.get("handed"):
        return f"stop: Next: hands this action to {hosts[0]}", "step 3"
    after = run.entries[run.status_at + 1:]
    if not after:
        if re.search(r"\bsquad-executor", following):
            action, extra = run.executor_spawn("perform Next: " + following, run.work_order())
            return action, extra or "step 4: perform Next"
        if run.mode() == "accept" or following.startswith("accept"):
            head = state.get("head") or run.base()
            return f"perform Next: {following}; review git diff {run.base()} against {head}", "step 5: accept"
        return "perform Next: " + following, "step 4: perform Next"
    candidates = [i for i, e in enumerate(run.entries)
                  if e["heading"] != STATUS and not e["heading"].startswith(DELEGATED)]
    action, row, extra = row_action(run, candidates[-1])
    return action, extra or "row: " + row


def main(argv=None):
    parser = argparse.ArgumentParser(description="Print the next action references/resume.md gives for a log.")
    parser.add_argument("--state", default="{}", help="the session's state as a JSON object (see the module doc)")
    parser.add_argument("--rows", action="store_true", help="print the table's rows as this model reads them, then exit")
    parser.add_argument("log", nargs="?")
    args = parser.parse_args(argv)
    try:
        rows = load_rows()
        if args.rows:
            for first, action in rows:
                print(f"{first}\t{action}")
            return 0
        if not args.log:
            parser.error("name a log")
        state = json.loads(args.state)
        if not isinstance(state, dict):
            raise ProtocolError("--state must be a JSON object")
        action, source = next_action(check_logs.read_log(args.log, False), state)
    except (OSError, ValueError, ProtocolError, check_logs.ProtocolError) as error:
        print(f"resume_next: {error}", file=sys.stderr)
        return 2
    print(f"{action}\t[{source}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
