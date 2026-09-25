#!/usr/bin/env python3
"""Lint Compute Squad logs against the log grammar in the shared skill.

This is check 8a of scripts/verify.sh. It also runs on any saved log:

    python3 tests/check_logs.py COMPUTE_SQUAD_LOG.md compute-squad-archive/*.md
    python3 tests/check_logs.py --fenced docs/example-log.md

--fenced reads a document whose entries sit in ```markdown blocks, such as
docs/example-log.md, and skips the prose around them. Each violation prints
as "<path>:<line>: [<rule>] <message>". Exit status: 0 when every log is
clean, 1 on any violation, 2 when a log cannot be read or the rules cannot
be read from the skill.

The heading list, the opening entry, the timestamp form, the blocker
grammar, the Goal template's Attended: field and criterion IDs, the re-lock
rule, the criteria block's shape, and the top-rung executor are read from
skills/compute-squad/SKILL.md, so the linter follows the protocol text. The
Result values of the criteria block and the Recon and Executor labels are
tables below; scripts/verify.sh checks 7g and 7w hold the PM body and the
templates to them (--labels prints the labels).
The routing fields each stage entry carries are the table FIELDS below; the
linter stops unless SKILL.md's fixed-lines rule names every one of them, and
scripts/verify.sh check 7i holds the stage templates in agents/*.md and
codex/0*.md to it (--fields prints it). If that text changes shape, the
linter stops with status 2 instead of guessing. The grant rule runs the Claude Code grant hook,
skills/compute-squad/hooks/grant-gate.sh, with sh over the log above each
Executor entry, so a log from either host is held to the rule the hook
enforces; a denial for an open needs-human: blocker is the needs-human
rule's to report. The review rules hold the main session's
## High-stakes review entries to the procedure in SKILL.md's Stage 5: a
review follows every high-stakes PASS, its Rerun: line appears only when it
is overturned, and an upheld review closes the run. The answers rule holds
every re-run to the Answers: line that names what sent it back (finding 13),
and the recon-checks rule holds the Recon entry's Checks: block to its
goal-facts line and one baseline line (finding 14); scripts/verify.sh check 7x
holds the Recon template to the same forms. Python 3.9 stdlib only.
"""
import argparse
import collections
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL_PATH = os.path.join(REPO_ROOT, "skills", "compute-squad", "SKILL.md")

# Rule ids and what each one checks. scripts/verify.sh requires a failing
# fixture under tests/fixtures/logs/ for every rule listed here.
RULES = (
    ("goal-first", "the log opens with the Goal entry, with no text before it"),
    ("heading", "every '## ' line is on the closed heading list, only the listed headings add"
                " ' (cont.)', and a Delegated entry names the stage whose DELEGATE: block it answers"),
    ("timestamp-form", "every entry has exactly one Timestamp: line, in the date -u form"),
    ("timestamp-order", "timestamps never decrease in log order"),
    ("blocker", "a BLOCKER: block ends its entry, with one rerun or needs-human item and one why item"),
    ("blocker-prose", "no line starts with 'Blocker', so blockers are never listed in prose"),
    ("grant", "the log above every Executor entry, (cont.) included, makes the grant hook allow an executor"
              " spawn: its latest ## Status grants the current plan revision"),
    ("re-lock", "every Goal entry after the first directly follows a re-lock Decision, says the run is attended,"
                " and has a Supersedes: line naming the prior Goal entry's timestamp"),
    ("needs-human", "no entry other than a Status or a Goal follows a needs-human: blocker until a Decision"
                    " records the user's answer"),
    ("fields", "every stage entry carries its routing fields, one value each, in order directly under its Agent:"
               " line, and no other line of any entry starts with a routing field (a Status keeps its Plan: line)"),
    ("attempt", "each Attempt: counts its heading's entries without (cont.) up to and including it: per work order"
                " for the Executor, over PASS and FAIL for the PM's verdicts (a pending entry takes the next number),"
                " and a (cont.) entry repeats the attempt it extends"),
    ("governing-plan", "a Status's Plan: line names the latest plan revision, and an Executor's Plan: line names that"
                       " revision and the work order the latest Status names (all when none names one)"),
    ("high-stakes", "no 'High-stakes: no' line follows a 'High-stakes: yes' line"),
    ("cont", "a (cont.) entry continues its own stage after a BLOCKING DELEGATE: block and the Delegated entry"
             " answering it"),
    ("next-line", "a line starting 'Next: ' sits only in a ## Status entry, since squad-mech's open-run guard and the"
                  " one-active-run rule read the latest such line in the log"),
    ("criteria", "every Goal entry numbers its criteria AC1, AC2, and so on; every PASS and FAIL entry, and every pending"
                 " entry that carries a Tested: line or asks about a criterion ID, carries the criteria block: a Tested:"
                 " line, the table with one row per criterion ID of the latest Goal entry and a known Result and How,"
                 " then Regressions:, Outside scope:, and Executor points:; a PASS has only met or waived rows and"
                 " Regressions: none; not checked appears only in a FAIL, or for a criterion of a later work order of the"
                 " governing plan, named in Evidence; a not met: pre-existing row in a pending entry is put to the user"
                 " as needs-human: waive or re-scope <ID>"),
    ("waiver", "every waived row names a ## Decision of Type waiver above it whose Covers: line names the criterion ID,"
               " and cites that Decision's timestamp"),
    ("parity", "when the Executor entry a verdict judges was written by the top-rung executor, every met row reads"
               " reproduced, not inspected"),
    ("labels", "every ## Recon and ## Executor entry, (cont.) aside, carries its template's labels in order, numbers"
               " its For acceptance: points F1, F2, and so on, and states its Commit: tree in the Tested: form"),
    ("executor-points", "a verdict's Executor points: answer each F<n> point of the Executor entry it judges with"
                        " exactly one '- F<n>:' line, and no other"),
    ("totals", "every ## PM — Plan entry, (cont.) aside, has exactly one Totals: line"),
    ("review-after-pass", "after a high-stakes PASS (one at or below a 'High-stakes: yes' line), the next entry other"
                          " than a ## Status or ## Decision is a ## High-stakes review, or nothing"),
    ("review-rerun", "a ## High-stakes review has a Rerun: line if and only if its Result: reads overturned"),
    ("review-close", "an upheld ## High-stakes review has no open risk and no unapproved decision, and once one"
                     " upholds the PASS of the governing plan's last work order, only ## Status entries follow it"),
    ("answers", "an entry carries an Answers: line from attempt 2 on and never before it; a Recon, Plan, or Executor"
                " entry's names by heading and timestamp a ## PM — FAIL, ## High-stakes review, ## Decision, ## Status,"
                " or entry ending in a BLOCKER: block, at or after the stage's previous attempt; a verdict's names the"
                " latest ## PM — FAIL or overturned"
                " ## High-stakes review since the latest PASS, or reads none when there is none"),
    ("recon-checks", "every ## Recon entry's Checks: block opens with a '- goal facts:' line, then its baseline line: a"
                     " check line ending '; tree changed: <no | the paths>', or '- baseline: not run, <why>'"),
)

HEADING_BULLET = "- Log entries use only these headings: "
CONT = " (cont.)"
EXECUTOR_HEADING = "## Executor"
GATE = os.path.join("hooks", "grant-gate.sh")   # relative to the skill's directory
GATE_AGENT = "compute-squad:squad-executor"
NEEDS_HUMAN_DENIAL = "needs-human blocker unresolved"   # the hook's reason for an open needs-human: blocker
STATUS_HEADING = "## Status"
CONT_RULE = ", and only for a stage continuing after its own `BLOCKING` `DELEGATE:` block"
FIELDS_BULLET = "- Routing values sit on fixed lines at the top of an entry"
HIGH_STAKES_RULE = "A run is high-stakes once any line in the log reads `High-stakes: yes`; no later entry lowers it."
# The routing fields of each stage entry, in order under its Agent: line, as
# (name, template placeholder, value pattern). A (cont.) entry carries its
# heading's fields. A field in OPTIONAL_FIELDS may be absent (Answers: appears
# from attempt 2, which the answers rule checks); the template still carries
# its line. Keep this table and the templates in agents/*.md in step:
# scripts/verify.sh check 7i compares them.
ATTEMPT = ("Attempt", "<n>", r"[1-9][0-9]*")
RERUN = ("Rerun", "<Recon|Plan|Executor>", r"Recon|Plan|Executor")
VERDICT_ANSWERS = ("Answers", "<from attempt 2: the latest FAIL or overturned review since the latest PASS, or none>", r"\S.*")
STAGE_ANSWERS = ("Answers", "<from attempt 2: the entry that sent this stage back>", r"\S.*")
HIGH_STAKES = ("High-stakes", "<yes|no>", r"yes|no")
FIELDS = collections.OrderedDict([
    ("## Recon", (ATTEMPT, STAGE_ANSWERS)),
    ("## PM — Plan", (
        ATTEMPT,
        STAGE_ANSWERS,
        ("Classification", "<MECHANICAL|STANDARD|COMPLEX>", r"MECHANICAL|STANDARD|COMPLEX"),
        HIGH_STAKES,
    )),
    ("## Executor", (ATTEMPT, STAGE_ANSWERS, ("Plan", "r<N>, work order <ID or all>", r"r[1-9][0-9]*, work order [A-Za-z0-9][A-Za-z0-9-]*"))),
    ("## PM — Accept (pending)", (ATTEMPT, VERDICT_ANSWERS)),
    ("## PM — PASS", (ATTEMPT, VERDICT_ANSWERS, HIGH_STAKES)),
    ("## PM — FAIL", (ATTEMPT, VERDICT_ANSWERS, HIGH_STAKES, RERUN)),
    ("## High-stakes review", (("Result", "<upheld | overturned | held>", r"upheld|overturned|held"), RERUN)),
])
OPTIONAL_FIELDS = ("Answers",)
# Fields optional on one heading only: a review's Rerun: line appears only
# when it is overturned (the review-rerun rule).
OPTIONAL_BY_HEADING = {"## High-stakes review": ("Rerun",)}
# The fields a line outside any stage entry's fixed lines may never start
# with: the FAIL count reads every Rerun: line, and squad-mech's close guard
# reads the latest Result: line.
LOOSE_FIELDS = ("Rerun", "Result")
FIELD_NAMES = sorted({name for fields in FIELDS.values() for name, _, _ in fields})
PLAN_HEADING = "## PM — Plan"
VERDICT_HEADINGS = ("## PM — PASS", "## PM — FAIL")
PENDING_HEADING = "## PM — Accept (pending)"
DECISION_HEADING = "## Decision"
REVIEW_HEADING = "## High-stakes review"
REVIEW_RISKS = "Risks"
REVIEW_DECISIONS = "Decisions after lock"
# The PM's criteria block (finding 2). Its shape, the Tested: line, the
# table's header and separator, and the labels after the table, is read from
# the bare-fenced block in SKILL.md's Stage 5 that opens with TESTED; the
# criterion ID prefix from the Goal template's first criterion line; the
# top-rung executor from Stage 4's COMPLEX route. The Result and How values
# are the PM's (agents/squad-pm.md, "Result is exactly one of ..."); check 7g
# holds RESULTS to that sentence.
TESTED = "Tested: "
TREE_FORM = r"[0-9a-f]{7,40}, working tree (?:clean|[1-9][0-9]* changed files?)"
RESULTS = ("met", "not met", "not met: pre-existing", "waived", "not checked")
PASS_RESULTS = ("met", "waived")
FAIL_ONLY_RESULTS = ("not checked",)
PRE_EXISTING = "not met: pre-existing"
HOW = ("reproduced", "inspected")
WAIVE_QUESTION = "- needs-human: waive or re-scope "
# The labels of the Recon and Executor templates, in order (finding 16);
# scripts/verify.sh check 7w holds the templates to them (--labels prints them).
LABELS = collections.OrderedDict([
    ("## Recon", ("Checks", "Map", "Callers", "Tests", "Invariants", "Open for the PM")),
    ("## Executor", ("Tasks", "Files changed", "Checks", "Deviations", "For acceptance", "Commit")),
])
POINTS_LABEL = "For acceptance"
# The Recon entry's Checks: block (finding 14), as agents/squad-recon.md step 5
# and its template give it; scripts/verify.sh check 7x holds the template to
# these forms. The first line reports the goal's stated facts and the second
# the baseline run, or why it did not run; the tool checks follow.
CHECKS_LABEL = "Checks"
GOAL_FACTS_LINE = r"- goal facts: \S.*"
BASELINE_LINE = r"- `[^`]+` -> exit [0-9]+; \S.*; tree changed: \S.*"
BASELINE_SKIPPED = r"- baseline: not run, \S.*"
# What a stage's Answers: line may name (finding 13): an entry that sends a
# stage back. A Status stands for a moved base commit.
ANSWERED_HEADINGS = ("## PM — FAIL", "## High-stakes review", "## Decision", "## Status")
COMMIT_LABEL = "Commit"
TOTALS = "Totals: "


class ProtocolError(Exception):
    """The skill text the rules are read from no longer has the expected shape."""


class Protocol(object):
    def __init__(self, fixed, cont, delegated, goal, time_format, targets, gate, relock, criteria=None):
        self.fixed = fixed            # listed headings without a placeholder
        self.cont = cont              # listed headings that may add " (cont.)"
        self.delegated = delegated    # "## Delegated — ", the part before <stage>
        self.goal = goal              # the heading every log opens with
        self.time_format = time_format
        self.targets = targets        # the stages a rerun: blocker may name
        self.gate = gate              # the grant hook script, run with sh
        self.relock = relock          # dict: decision heading, type line, attended line, supersedes field
        self.criteria = criteria      # dict: ID prefix, table header and separator, block labels, point prefix, top executor


def load_protocol(skill_path):
    with open(skill_path, encoding="utf-8") as handle:
        text = handle.read()
    lines = text.splitlines()

    bullets = [line for line in lines if line.startswith(HEADING_BULLET)]
    if len(bullets) != 1:
        raise ProtocolError(f"{skill_path}: expected one line starting {HEADING_BULLET!r}, found {len(bullets)}")
    listed_part, _, rest = bullets[0][len(HEADING_BULLET):].partition(". Only ")
    cont_part, found, after = rest.partition(" may add `" + CONT + "`")
    listed = re.findall(r"`(## [^`]+)`", listed_part)
    cont = re.findall(r"`(## [^`]+)`", cont_part)
    if not listed or not cont or not found or not after.startswith(CONT_RULE):
        raise ProtocolError(
            f"{skill_path}: the heading-list bullet no longer reads '<headings>. Only <headings> may add "
            f"`{CONT}`{CONT_RULE}...'"
        )
    fixed = [heading for heading in listed if "<" not in heading]
    delegated = None
    for heading in listed:
        if "<" not in heading:
            continue
        match = re.fullmatch(r"(## [^<>]+)<stage>", heading)
        if not match or delegated is not None:
            raise ProtocolError(f"{skill_path}: unknown placeholder heading {heading!r}; teach tests/check_logs.py what it names")
        delegated = match.group(1)

    goal = re.search(r"Every fresh log opens with a `(## [^`]+)` entry", text)
    if not goal or goal.group(1) not in fixed:
        raise ProtocolError(f"{skill_path}: no 'Every fresh log opens with a `## ...` entry' rule naming a listed heading")

    stamp = re.search(r"Every entry's `Timestamp:` line is the output of `date -u \+([^`\s]+)`", text)
    if not stamp:
        raise ProtocolError(f"{skill_path}: no \"Every entry's `Timestamp:` line is the output of `date -u +<format>`\" rule")

    block_at = next((i for i in range(len(lines) - 1) if lines[i] == "```" and lines[i + 1] == "BLOCKER:"), None)
    if block_at is None or lines[block_at + 4:block_at + 5] != ["```"]:
        raise ProtocolError(f"{skill_path}: no bare-fenced BLOCKER: block of two items")
    first = re.fullmatch(r"- rerun: <([A-Za-z]+(?:\|[A-Za-z]+)*)>\s+\(or\)\s+needs-human: <[^<>]+>", lines[block_at + 2])
    second = re.fullmatch(r"- why: <[^<>]+>", lines[block_at + 3])
    if not first or not second:
        raise ProtocolError(f"{skill_path}: the BLOCKER: block no longer reads '- rerun: <A|B> (or) needs-human: <...>' then '- why: <...>'")

    relock = re.search(
        r"A re-lock needs the user: in one Bash command, append a `(## [^`]+)` entry of Type ([a-z-]+) quoting "
        r"their words, then a new `(## [^`]+)` entry with the full template and a `([A-Za-z]+): <timestamp of the "
        r"prior Goal entry>` line\.", text,
    )
    if not relock or relock.group(1) not in fixed or relock.group(3) != goal.group(1):
        raise ProtocolError(
            f"{skill_path}: no 'A re-lock needs the user: in one Bash command, append a `## ...` entry of Type <type> "
            f"quoting their words, then a new `{goal.group(1)}` entry ... `<Field>: <timestamp of the prior Goal "
            f"entry>` line.' rule naming a listed heading"
        )
    template_at = next(
        (i for i in range(len(lines) - 1) if lines[i] == "```markdown" and lines[i + 1] == goal.group(1)), None,
    )
    template = []
    for line in lines[template_at + 2:] if template_at is not None else []:
        if line == "```":
            break
        template.append(line)
    attended = [m for m in (re.fullmatch(r"([A-Za-z]+): <([a-z]+)\|[a-z]+>", line) for line in template) if m]
    if len(attended) != 1 or attended[0].group(1) != "Attended":
        raise ProtocolError(f"{skill_path}: the {goal.group(1)!r} template needs one 'Attended: <yes|no>' line")
    if STATUS_HEADING not in fixed:
        raise ProtocolError(f"{skill_path}: {STATUS_HEADING!r} is not on the heading list")
    relock = {
        "decision": relock.group(1),
        "type": "Type: " + relock.group(2),
        "attended": f"{attended[0].group(1)}: {attended[0].group(2)}",
        "supersedes": relock.group(4) + ": ",
    }

    if EXECUTOR_HEADING not in fixed or EXECUTOR_HEADING not in cont:
        raise ProtocolError(f"{skill_path}: {EXECUTOR_HEADING!r} is not a listed heading that may add '{CONT}'")
    unlisted = [heading for heading in FIELDS if heading not in fixed]
    if unlisted:
        raise ProtocolError(f"{skill_path}: the routing-field table names headings not on the list: {unlisted!r}")
    field_bullets = [line for line in lines if line.startswith(FIELDS_BULLET)]
    if len(field_bullets) != 1:
        raise ProtocolError(f"{skill_path}: expected one line starting {FIELDS_BULLET!r}, found {len(field_bullets)}")
    unnamed = [name for name in FIELD_NAMES if "`" + name + ":`" not in field_bullets[0]]
    if unnamed:
        raise ProtocolError(f"{skill_path}: the fixed-lines rule no longer names {unnamed!r}; teach tests/check_logs.py the new fields")
    rerun_values = next(pattern for name, _, pattern in FIELDS["## PM — FAIL"] if name == "Rerun").split("|")
    if rerun_values != first.group(1).split("|"):
        raise ProtocolError(f"{skill_path}: the BLOCKER: rerun targets no longer match the FAIL entry's Rerun: values {rerun_values!r}")
    if HIGH_STAKES_RULE not in " ".join(text.split()):
        raise ProtocolError(f"{skill_path}: no rule reading {HIGH_STAKES_RULE!r}")
    gate = os.path.join(os.path.dirname(os.path.abspath(skill_path)), GATE)
    if not os.path.isfile(gate):
        raise ProtocolError(f"{gate}: the grant hook the grant rule runs is missing")

    ids = [m for m in (re.fullmatch(r"- ([A-Z]+)1: <[^<>]+>", line) for line in template) if m]
    if len(ids) != 1:
        raise ProtocolError(f"{skill_path}: the {goal.group(1)!r} template needs one '- AC1: <...>' criterion line")
    block_at = next((i for i in range(len(lines) - 1) if lines[i] == "```" and lines[i + 1].startswith(TESTED)), None)
    block = []
    for line in lines[block_at + 1:] if block_at is not None else []:
        if line == "```":
            break
        block.append(line)
    tail = block[4:]
    labels = [line.split(":", 1)[0] for line in tail if not line.startswith("- ")]
    point = re.fullmatch(r"- ([A-Z]+)1: <[^<>]+> -> <[^<>]+>", tail[-1]) if tail else None
    if (len(block) < 6 or block[0] != TESTED + "<commit SHA>, working tree <clean | N changed files>"
            or not re.fullmatch(r"\|( [A-Z][a-z]+ \|){4}", block[1]) or not re.fullmatch(r"\|(---\|){4}", block[2])
            or not block[3].startswith("| " + ids[0].group(1) + "1 | ") or not point or len(labels) < 3):
        raise ProtocolError(
            f"{skill_path}: no bare-fenced criteria block reading 'Tested: <commit SHA>, working tree <clean | N changed "
            f"files>', a four-column table with one example row, the labels after it, and a '- F1: <...> -> <...>' line"
        )
    route = re.search(r"\*\*COMPLEX\*\* → spawn `([a-z-]+)`", text)
    if not route:
        raise ProtocolError(f"{skill_path}: no '**COMPLEX** → spawn `<agent>`' route naming the top-rung executor")
    criteria = {
        "prefix": ids[0].group(1),
        "header": block[1],
        "separator": block[2],
        "labels": labels,
        "points": labels[-1],
        "point": point.group(1),
        "top": route.group(1),
    }

    return Protocol(fixed, cont, delegated, goal.group(1), stamp.group(1), first.group(1).split("|"), gate, relock,
                    criteria)


def read_log(path, fenced):
    """Return the log's lines as (line number, text) pairs. With fenced, keep
    only the lines inside ```markdown blocks, numbered as in the file."""
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    if not fenced:
        return list(enumerate(lines, 1))
    kept, inside, blocks = [], False, 0
    for number, line in enumerate(lines, 1):
        if not inside:
            if line == "```markdown":
                inside, blocks = True, blocks + 1
        elif line == "```":
            inside = False
        else:
            kept.append((number, line))
    if not blocks:
        raise ProtocolError(f"{path}: no ```markdown block to read entries from")
    return kept


def split_entries(lines):
    """Return (lines before the first heading, entries). Each entry is a dict
    with its heading's line number, the heading, and its body lines."""
    preamble, entries = [], []
    for number, text in lines:
        if text.startswith("## "):
            entries.append({"line": number, "heading": text, "body": []})
        elif entries:
            entries[-1]["body"].append((number, text))
        else:
            preamble.append((number, text))
    return preamble, entries


def stage_names(heading):
    """The names a Delegated entry may use for the stage that wrote heading:
    the heading itself, or its first or last part, each with or without a
    trailing suffix such as (pending), e.g. PM, Plan, PM — Plan, and Accept or
    PM — Accept for PM — Accept (pending)."""
    name = heading[3:]
    if name.endswith(CONT):
        name = name[:-len(CONT)]
    names = set()
    for form in (name, re.sub(r" \([^()]*\)$", "", name)):
        parts = form.split(" — ")
        names.update((form, parts[0], parts[-1]))
    return names


def check_heading(entry, earlier, protocol, report):
    heading = entry["heading"]
    if heading in protocol.fixed:
        return
    if heading.endswith(CONT):
        base = heading[:-len(CONT)]
        if base in protocol.cont:
            return
        if base in protocol.fixed or (protocol.delegated and base.startswith(protocol.delegated)):
            report(entry["line"], "heading", f"{heading!r}: only {', '.join(protocol.cont)} may add '{CONT}'")
            return
    elif protocol.delegated and heading.startswith(protocol.delegated):
        stage = heading[len(protocol.delegated):]
        requester = next(
            (e for e in reversed(earlier)
             if not e["heading"].startswith(protocol.delegated) and e["heading"] != STATUS_HEADING),
            None,
        )
        if requester is None or not any(text.startswith("DELEGATE:") for _, text in requester["body"]):
            report(entry["line"], "heading", f"{heading!r} answers no DELEGATE: block; the entry above it has none")
        elif stage not in stage_names(requester["heading"]):
            report(
                entry["line"], "heading",
                f"{heading!r} must name the requesting stage, {requester['heading']!r} at line {requester['line']}",
            )
        return
    report(entry["line"], "heading", f"{heading!r} is not on the closed heading list in the skill's Hard rules")


def check_timestamps(entries, protocol, report):
    previous = None
    for entry in entries:
        stamps = [(number, text) for number, text in entry["body"] if text.startswith("Timestamp:")]
        if len(stamps) != 1:
            report(entry["line"], "timestamp-form", f"{entry['heading']!r} has {len(stamps)} Timestamp: lines; every entry has exactly one")
            continue
        number, text = stamps[0]
        value = text[len("Timestamp: "):] if text.startswith("Timestamp: ") else None
        try:
            when = datetime.datetime.strptime(value or "", protocol.time_format)
        except ValueError:
            when = None
        if when is None or when.strftime(protocol.time_format) != value:
            report(number, "timestamp-form", f"{text!r} is not the output of date -u +{protocol.time_format}")
            continue
        if previous is not None and when < previous[1]:
            report(number, "timestamp-order", f"{value} is earlier than the timestamp at line {previous[0]} above it")
        previous = (number, when)


def check_blockers(entry, protocol, report):
    body = entry["body"]
    for index, (number, text) in enumerate(body):
        if text.startswith("Blocker"):
            report(number, "blocker-prose", "a line starts with 'Blocker'; log a blocker only as a BLOCKER: block")
        if not text.startswith("BLOCKER"):
            continue
        if text != "BLOCKER:":
            report(number, "blocker", f"{text!r}: BLOCKER: stands alone on its line, with its items below it")
            continue
        items, after = [], index + 1
        while after < len(body) and body[after][1].strip():
            line = body[after][1]
            if line.startswith("- "):
                items.append(line)
            elif not (line[0] in " \t" and items):
                break
            after += 1
        trailing = [pair for pair in body[after:] if pair[1].strip()]
        if trailing:
            report(trailing[0][0], "blocker", f"text after the BLOCKER: block at line {number}; the block ends its entry")
        rerun = re.fullmatch(r"- rerun: (\S+)", items[0]) if items else None
        first_ok = (rerun is not None and rerun.group(1) in protocol.targets) or (
            bool(items) and re.fullmatch(r"- needs-human: \S.*", items[0]) is not None
        )
        if len(items) != 2 or not first_ok or not re.fullmatch(r"- why: \S.*", items[1]):
            report(
                number, "blocker",
                f"the BLOCKER: block needs exactly '- rerun: <{'|'.join(protocol.targets)}>' or "
                f"'- needs-human: <decision>', then '- why: <reason>'",
            )


def timestamp_of(entry):
    """The value of the entry's first Timestamp: line, or None."""
    return next((text[len("Timestamp: "):] for _, text in entry["body"] if text.startswith("Timestamp: ")), None)


def check_relocks(entries, protocol, report):
    rule = protocol.relock
    goals = [index for index, entry in enumerate(entries) if entry["heading"] == protocol.goal]
    for previous, index in zip(goals, goals[1:]):
        entry, prior = entries[index], entries[previous]
        body = [text for _, text in entry["body"]]
        before = entries[index - 1]
        if before["heading"] != rule["decision"] or rule["type"] not in (text for _, text in before["body"]):
            report(
                entry["line"], "re-lock",
                f"a later {protocol.goal!r} must directly follow a {rule['decision']!r} entry with {rule['type']!r}; "
                f"the entry above it is {before['heading']!r} at line {before['line']}",
            )
        if rule["attended"] not in body:
            report(entry["line"], "re-lock", f"a re-lock needs the user, so its {protocol.goal!r} entry says {rule['attended']!r}")
        stamp = timestamp_of(prior)
        wanted = rule["supersedes"] + (stamp or "<the prior Goal entry's timestamp>")
        if stamp is None or wanted not in body:
            report(
                entry["line"], "re-lock",
                f"a re-lock's {protocol.goal!r} entry needs {wanted!r}, naming the Goal entry at line {prior['line']}",
            )


def needs_human_line(entry):
    """The line number of a BLOCKER: line in the entry whose first non-blank
    line after it is a needs-human: item, as the grant hook reads it."""
    body = entry["body"]
    for index, (number, text) in enumerate(body):
        if re.fullmatch(r"BLOCKER:\s*", text):
            item = next((line for _, line in body[index + 1:] if line.strip()), "")
            if item.startswith("- needs-human:"):
                return number
    return None


def check_needs_human(entries, protocol, report):
    open_at = None
    for entry in entries:
        heading = entry["heading"]
        if heading == protocol.relock["decision"]:
            open_at = None
        elif open_at is not None and heading not in (STATUS_HEADING, protocol.goal):
            report(
                entry["line"], "needs-human",
                f"{heading!r} follows the needs-human: blocker at line {open_at} with no "
                f"{protocol.relock['decision']!r} between them; no stage runs until the user decides",
            )
        found = needs_human_line(entry)
        if found is not None:
            open_at = found


def gate_denial(gate, log_text):
    """Run the grant hook as Claude Code would for a main-session executor
    spawn, with log_text as the active log. Return None when it allows the
    spawn, or its reason when it denies it."""
    with tempfile.TemporaryDirectory() as root:
        with open(os.path.join(root, "COMPUTE_SQUAD_LOG.md"), "w", encoding="utf-8") as handle:
            handle.write(log_text)
        payload = json.dumps({
            "hook_event_name": "PreToolUse",
            "tool_name": "Agent",
            "tool_input": {"subagent_type": GATE_AGENT},
            "cwd": root,
        })
        # The hook looks for the log at the root of the git repository that
        # holds cwd; the ceiling keeps git from finding one above the temp dir.
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        env["GIT_CEILING_DIRECTORIES"] = os.path.dirname(root)
        try:
            run = subprocess.run(["sh", gate], input=payload, capture_output=True, text=True, env=env, timeout=60)
        except (OSError, subprocess.SubprocessError) as error:
            raise ProtocolError(f"{gate}: could not run the grant hook with sh: {error}")
    if run.returncode != 0:
        raise ProtocolError(f"{gate}: the grant hook exited {run.returncode}: {run.stderr.strip()}")
    if not run.stdout.strip():
        return None
    try:
        output = json.loads(run.stdout)["hookSpecificOutput"]
        decision, reason = output["permissionDecision"], output["permissionDecisionReason"]
    except (ValueError, KeyError, TypeError):
        raise ProtocolError(f"{gate}: the grant hook printed something other than a PreToolUse decision: {run.stdout.strip()!r}")
    if decision != "deny":
        raise ProtocolError(f"{gate}: the grant hook printed a {decision!r} decision; it only ever denies or stays silent")
    return reason


def check_grants(lines, entries, protocol, report):
    for entry in entries:
        if entry["heading"] not in (EXECUTOR_HEADING, EXECUTOR_HEADING + CONT):
            continue
        above = "".join(text + "\n" for number, text in lines if number < entry["line"])
        reason = gate_denial(protocol.gate, above)
        if reason is not None and NEEDS_HUMAN_DENIAL not in reason:
            report(entry["line"], "grant", f"{entry['heading']!r}: the grant hook denies this executor spawn: {reason}")


def base_heading(heading):
    return heading[:-len(CONT)] if heading.endswith(CONT) else heading


def check_fields(entry, report):
    """Check the entry's routing fields and return {name: value} for the ones
    that read correctly."""
    heading, body = entry["heading"], entry["body"]
    fields = FIELDS.get(base_heading(heading), ())
    values, fixed_at = {}, set()
    if fields:
        agent_at = next((i for i, (_, text) in enumerate(body) if text.startswith("Agent: ")), None)
        if agent_at is None:
            report(entry["line"], "fields", f"{heading!r} has no Agent: line for its routing fields to sit under")
        else:
            at = agent_at + 1
            for name, placeholder, pattern in fields:
                number, text = body[at] if at < len(body) else (body[agent_at][0], "<end of entry>")
                match = re.fullmatch(re.escape(name) + ": (" + pattern + ")", text)
                optional = OPTIONAL_FIELDS + OPTIONAL_BY_HEADING.get(base_heading(heading), ())
                if not match and name in optional:
                    continue
                if not match:
                    wanted = ", ".join(f"'{n}: {p}'" + (" (when present)" if n in optional else "")
                                       for n, p, _ in fields)
                    report(number, "fields", f"{heading!r}: under its Agent: line come {wanted}, in that order; found {text!r}")
                    break
                values[name] = match.group(1)
                fixed_at.add(at)
                at += 1
    for index, (number, text) in enumerate(body):
        if index in fixed_at:
            continue
        names = FIELD_NAMES if fields else LOOSE_FIELDS
        stray = next((name for name in names if text.startswith(name + ": ")), None)
        if stray is not None:
            report(number, "fields", f"{heading!r}: a line starting '{stray}:' outside the fixed lines under an Agent: line; "
                                     f"routing and the FAIL count read only those")
    return values


def work_order(plan_value):
    return plan_value.split(", work order ", 1)[1]


def check_attempts(entries, report):
    """Attempt: counts plain entries per key: the heading, the Executor's work
    order, or the PM's verdicts, which PASS and FAIL share."""
    counts = collections.Counter()
    for entry in entries:
        heading = entry["heading"]
        base = base_heading(heading)
        got = entry["fields"].get("Attempt")
        if base not in FIELDS or got is None:
            continue
        if base == EXECUTOR_HEADING:
            if "Plan" not in entry["fields"]:
                continue
            key = (base, work_order(entry["fields"]["Plan"]))
            counted = f"the Executor entries without (cont.) for work order {key[1]}"
        elif base in VERDICT_HEADINGS + (PENDING_HEADING,):
            key, counted = "verdict", "the PM — PASS and PM — FAIL entries"
        else:
            key, counted = base, f"the {base} entries without (cont.)"
        if heading.endswith(CONT):
            want, why = counts[key], "a (cont.) entry repeats the attempt it extends"
        elif base == PENDING_HEADING:
            want, why = counts[key] + 1, "a pending entry takes the number of the verdict it waits for"
        else:
            counts[key] += 1
            want, why = counts[key], f"it counts {counted}, this one included"
        if int(got) != want:
            report(entry["line"], "attempt", f"{heading!r} reads 'Attempt: {got}', expected {want}: {why}")


def check_governing_plan(entries, report):
    plans, status_plan = 0, None
    for entry in entries:
        heading = entry["heading"]
        if heading == PLAN_HEADING:
            plans += 1
        elif heading == STATUS_HEADING:
            value = next((text[len("Plan: "):] for _, text in entry["body"] if text.startswith("Plan: ")), None)
            if value is not None and value != "none":
                match = re.fullmatch(r"r([0-9]+), work order (\S+)", value)
                if not match or int(match.group(1)) != plans:
                    report(entry["line"], "governing-plan",
                           f"the Status reads 'Plan: {value}'; the governing plan revision is "
                           + (f"r{plans}" if plans else "none yet"))
            status_plan = value
        elif base_heading(heading) == EXECUTOR_HEADING and "Plan" in entry["fields"]:
            value = entry["fields"]["Plan"]
            revision = int(value.split(",", 1)[0][1:])
            named = status_plan if status_plan not in (None, "none") else None
            if revision != plans:
                report(entry["line"], "governing-plan",
                       f"{heading!r} reads 'Plan: {value}'; the governing plan revision is r{plans}")
            elif named is not None and value != named:
                report(entry["line"], "governing-plan",
                       f"{heading!r} reads 'Plan: {value}'; the latest Status names 'Plan: {named}'")
            elif named is None and work_order(value) != "all":
                report(entry["line"], "governing-plan",
                       f"{heading!r} reads 'Plan: {value}'; with no Status naming a plan it runs work order all")


def check_high_stakes(entries, report):
    yes_at = None
    for entry in entries:
        for number, text in entry["body"]:
            if text == "High-stakes: yes" and yes_at is None:
                yes_at = number
            elif text == "High-stakes: no" and yes_at is not None:
                report(number, "high-stakes", f"'High-stakes: no' after 'High-stakes: yes' at line {yes_at}; "
                                              "no later entry lowers it")


def delegates_blocking(entry):
    """True when the entry's DELEGATE: block is marked BLOCKING."""
    inside = False
    for _, text in entry["body"]:
        if text.startswith("DELEGATE:"):
            inside = True
        elif text.startswith("BLOCKER:"):
            inside = False
        if inside and "BLOCKING" in text:
            return True
    return False


def check_cont(entries, protocol, report):
    for index, entry in enumerate(entries):
        heading = entry["heading"]
        if not heading.endswith(CONT) or base_heading(heading) not in protocol.cont:
            continue
        earlier = [e for e in entries[:index] if e["heading"] != STATUS_HEADING]
        answered = False
        while earlier and protocol.delegated and earlier[-1]["heading"].startswith(protocol.delegated):
            earlier.pop()
            answered = True
        requester = earlier[-1] if earlier else None
        if not (answered and requester is not None and base_heading(requester["heading"]) == base_heading(heading)
                and delegates_blocking(requester)):
            report(entry["line"], "cont",
                   f"{heading!r} does not follow a Delegated entry answering its own stage's BLOCKING DELEGATE: "
                   f"block; any other re-spawn writes a new, complete entry under the plain heading")


def check_next_lines(entries, report):
    for entry in entries:
        if entry["heading"] == STATUS_HEADING:
            continue
        for number, text in entry["body"]:
            if text.startswith("Next: "):
                report(number, "next-line", f"{entry['heading']!r}: a 'Next:' line outside a ## Status entry; "
                                            "squad-mech's open-run guard reads the latest one in the log as the run's")


def label_at(body, label, start=0):
    """The index of the first body line from start on that is the label, alone
    or with a value after it, or None."""
    return next((i for i in range(start, len(body))
                 if body[i][1] == label + ":" or body[i][1].startswith(label + ": ")), None)


def label_value(text, label):
    return text[len(label) + 1:].strip()


def point_lines(body, at, point):
    """The (line number, ID) of each '- <point><n>: ' line directly under the
    label line at index at, and the first other line's index."""
    found, index = [], at + 1
    while index < len(body):
        match = re.match(r"- (" + re.escape(point) + r"[1-9][0-9]*): \S", body[index][1])
        if not match:
            break
        found.append((body[index][0], match.group(1)))
        index += 1
    return found


def goal_criteria(entry, prefix, report):
    """Report a Goal entry whose Acceptance criteria are not numbered
    <prefix>1, <prefix>2, and so on, and return its criterion IDs."""
    body = entry["body"]
    at = next((i for i, (_, text) in enumerate(body) if text == "Acceptance criteria:"), None)
    if at is None:
        report(entry["line"], "criteria", f"{entry['heading']!r} has no 'Acceptance criteria:' line")
        return []
    ids = []
    for number, text in body[at + 1:]:
        if text[:1] in (" ", "\t") and ids:
            continue
        if not text.startswith("- "):
            break
        match = re.match(r"- (" + re.escape(prefix) + r"([1-9][0-9]*)): \S", text)
        if not match or int(match.group(2)) != len(ids) + 1:
            report(number, "criteria", f"criterion {len(ids) + 1} must read '- {prefix}{len(ids) + 1}: <criterion>'; "
                                       f"found {text!r}")
            return ids
        ids.append(match.group(1))
    if not ids:
        report(entry["line"], "criteria", f"{entry['heading']!r} lists no acceptance criteria")
    return ids


def judged_executor(entries, index):
    """The Executor entries a verdict at index judges: the latest plain
    ## Executor entry above it and the (cont.) entries after that one."""
    plain = max((i for i in range(index) if entries[i]["heading"] == EXECUTOR_HEADING), default=None)
    if plain is None:
        return []
    return [e for e in entries[plain:index] if base_heading(e["heading"]) == EXECUTOR_HEADING]


def later_work_orders(entries, index):
    """The work orders of the governing plan above index that come after the
    one the latest ## Status above index names, in the plan's order."""
    status = next((e for e in reversed(entries[:index]) if e["heading"] == STATUS_HEADING), None)
    value = next((x[len("Plan: "):] for _, x in status["body"] if x.startswith("Plan: ")), "") if status else ""
    match = re.fullmatch(r"r[0-9]+, work order (\S+)", value)
    latest = max((i for i in range(index) if entries[i]["heading"] == PLAN_HEADING), default=None)
    if not match or latest is None:
        return []
    found = []
    for entry in entries[latest:index]:
        if base_heading(entry["heading"]) != PLAN_HEADING:
            continue
        for _, text in entry["body"]:
            order = re.match(r"(WO-[A-Za-z0-9]+)\b", text)
            if order and order.group(1) not in found:
                found.append(order.group(1))
    return found[found.index(match.group(1)) + 1:] if match.group(1) in found else []


def check_criteria(entries, protocol, report):
    rules = protocol.criteria
    ids, decisions = [], []
    for index, entry in enumerate(entries):
        heading, body = entry["heading"], entry["body"]
        if heading == protocol.goal:
            ids = goal_criteria(entry, rules["prefix"], report)
            continue
        if heading == DECISION_HEADING:
            decisions.append(entry)
            continue
        if heading not in VERDICT_HEADINGS + (PENDING_HEADING,):
            continue
        tested = label_at(body, TESTED.rstrip(": "))
        if tested is None:
            question = next((text for _, text in body if text.startswith("- needs-human:")), "")
            asks = any(re.search(r"\b" + re.escape(i) + r"\b", question) for i in ids)
            if heading != PENDING_HEADING or asks:
                report(entry["line"], "criteria", f"{heading!r} carries no criteria block (no {TESTED.strip()!r} line)")
            continue
        number, text = body[tested]
        if not re.fullmatch(re.escape(TESTED) + TREE_FORM, text):
            report(number, "criteria", f"{text!r} is not 'Tested: <commit SHA>, working tree <clean | N changed files>'")
        if body[tested + 1:tested + 3] and [x for _, x in body[tested + 1:tested + 3]] != [rules["header"], rules["separator"]]:
            report(number, "criteria", f"the table under the Tested: line opens with {rules['header']!r} and "
                                       f"{rules['separator']!r}")
            continue
        rows, at = [], tested + 3
        while at < len(body) and body[at][1].startswith("|"):
            row_number, row = body[at]
            parts = row[2:-2].split(" | ", 3) if row.startswith("| ") and row.endswith(" |") else []
            if len(parts) != 4 or not all(part.strip() for part in parts):
                report(row_number, "criteria", f"{row!r} is not a '| <ID> | <Result> | <How> | <Evidence> |' row")
            else:
                rows.append((row_number, parts))
            at += 1
        seen = collections.Counter(parts[0] for _, parts in rows)
        for criterion in ids:
            if seen[criterion] != 1:
                report(number, "criteria", f"{heading!r} has {seen[criterion]} rows for {criterion}; the latest Goal entry "
                                           f"needs exactly one")
        later = later_work_orders(entries, index)
        for row_number, (criterion, result, how, evidence) in rows:
            if criterion not in ids:
                report(row_number, "criteria", f"{criterion!r} is not a criterion ID of the latest Goal entry ({', '.join(ids)})")
            deferred = result in FAIL_ONLY_RESULTS and any(re.search(r"\b" + re.escape(w) + r"\b", evidence) for w in later)
            if result not in RESULTS:
                report(row_number, "criteria", f"Result {result!r} is not one of {', '.join(RESULTS)}")
            elif heading == "## PM — PASS" and result not in PASS_RESULTS and not deferred:
                report(row_number, "criteria", f"a PASS row reads {result!r}; a PASS has only {' or '.join(PASS_RESULTS)} rows, "
                                               f"and {FAIL_ONLY_RESULTS[0]!r} ones that name a later work order")
            elif heading != "## PM — FAIL" and result in FAIL_ONLY_RESULTS and not deferred:
                report(row_number, "criteria", f"{result!r} appears only in a FAIL entry, or for a criterion a later "
                                               f"work order covers, named in Evidence")
            if how not in HOW:
                report(row_number, "criteria", f"How {how!r} is not one of {', '.join(HOW)}")
        place = at
        values = {}
        for label in rules["labels"]:
            found = label_at(body, label, place)
            if found is None:
                report(number, "criteria", f"{heading!r}: after the table come {', '.join(rules['labels'])}, in that "
                                           f"order; {label + ':'!r} is missing or out of order")
                break
            values[label] = (found, label_value(body[found][1], label))
            place = found + 1
        regressions = values.get(rules["labels"][0])
        if heading == "## PM — PASS" and regressions and regressions[1].rstrip(".") != "none":
            report(body[regressions[0]][0], "criteria", f"a PASS reads 'Regressions: none'; found {body[regressions[0]][1]!r}")
        pre = [parts[0] for _, parts in rows if parts[1] == PRE_EXISTING]
        if heading == PENDING_HEADING and pre:
            question = next((text for _, text in body if text.startswith("- needs-human:")), "")
            missing = [c for c in pre if not (question.startswith(WAIVE_QUESTION)
                                              and re.search(r"\b" + re.escape(c) + r"\b", question))]
            if missing:
                report(entry["line"], "criteria", f"{', '.join(missing)} read {PRE_EXISTING!r}: end the pending entry "
                                                  f"with a BLOCKER: block whose item reads '{WAIVE_QUESTION}<ID>'")
        for row_number, (criterion, result, how, evidence) in rows:
            if result != "waived":
                continue
            covering = [d for d in decisions
                        if "Type: waiver" in (x for _, x in d["body"])
                        and any(x.startswith("Covers: ") and re.search(r"\b" + re.escape(criterion) + r"\b", x)
                                for _, x in d["body"])]
            if not any(timestamp_of(d) and timestamp_of(d) in evidence for d in covering):
                report(row_number, "waiver", f"{criterion} reads waived, but no ## Decision of Type waiver above it "
                                             f"covers {criterion} with the timestamp this row cites")
        judged = judged_executor(entries, index)
        agent = next((x for e in judged[:1] for _, x in e["body"] if x.startswith("Agent: ")), "")
        if agent.startswith("Agent: " + rules["top"] + " ") or agent == "Agent: " + rules["top"]:
            for row_number, (criterion, result, how, evidence) in rows:
                if result == "met" and how != "reproduced":
                    report(row_number, "parity", f"{criterion} is met by {how!r}, but the judged Executor entry is "
                                                 f"{rules['top']}'s, which shares the top rung; reproduce it")
        points = values.get(rules["points"])
        if points is None:
            continue
        asked = []
        for executor in judged:
            at = label_at(executor["body"], POINTS_LABEL)
            if at is not None:
                asked.extend(i for _, i in point_lines(executor["body"], at, rules["point"]))
        answered = collections.Counter(i for _, i in point_lines(body, points[0], rules["point"]))
        if points[1] not in ("", "none"):
            report(body[points[0]][0], "executor-points",
                   f"{rules['points'] + ':'!r} stands alone with '- {rules['point']}<n>:' lines under it, or reads 'none'")
        for point in dict.fromkeys(asked):
            if answered[point] != 1:
                report(body[points[0]][0], "executor-points",
                       f"{point} of the judged Executor entry has {answered[point]} answer lines; it needs exactly one")
        for point in answered:
            if point not in asked:
                report(body[points[0]][0], "executor-points", f"{point} answers no point of the judged Executor entry")


def check_labels(entries, protocol, report):
    point = protocol.criteria["point"]
    for entry in entries:
        heading, body = entry["heading"], entry["body"]
        labels = LABELS.get(heading)
        if labels is None:
            continue
        place = 0
        for label in labels:
            found = label_at(body, label, place)
            if found is None:
                report(entry["line"], "labels", f"{heading!r}: its entry carries {', '.join(labels)}, in that order; "
                                                f"{label + ':'!r} is missing or out of order")
                break
            place = found + 1
        at = label_at(body, POINTS_LABEL)
        if heading == EXECUTOR_HEADING and at is not None:
            found = [i for _, i in point_lines(body, at, point)]
            value = label_value(body[at][1], POINTS_LABEL)
            numbered = found == [f"{point}{n}" for n in range(1, len(found) + 1)]
            if not ((value == "none" and not found) or (value == "" and found and numbered)):
                report(body[at][0], "labels", f"{POINTS_LABEL}: reads 'none', or stands alone with points numbered "
                                              f"{point}1, {point}2, and so on under it")
        at = label_at(body, COMMIT_LABEL)
        if heading == EXECUTOR_HEADING and at is not None and not re.fullmatch(
                re.escape(COMMIT_LABEL) + ": " + TREE_FORM, body[at][1]):
            report(body[at][0], "labels", f"{body[at][1]!r} is not 'Commit: <commit SHA>, working tree <clean | N changed files>'")


def check_totals(entries, report):
    for entry in entries:
        if entry["heading"] != PLAN_HEADING:
            continue
        count = sum(1 for _, text in entry["body"] if text.startswith(TOTALS))
        if count != 1:
            report(entry["line"], "totals", f"{entry['heading']!r} has {count} Totals: lines; a plan states its totals once")


def high_stakes_passes(entries):
    """The indexes of the PASS entries at or below a 'High-stakes: yes' line."""
    found, flagged = [], False
    for index, entry in enumerate(entries):
        if any(text == "High-stakes: yes" for _, text in entry["body"]):
            flagged = True
        if entry["heading"] == "## PM — PASS" and flagged:
            found.append(index)
    return found


def review_rows(body, label):
    """The (line number, last cell) of each '- ' row under the label line."""
    at = label_at(body, label)
    rows = []
    for number, text in body[at + 1:] if at is not None else []:
        if not text.startswith("- "):
            break
        rows.append((number, text.rsplit(" | ", 1)[-1].strip() if " | " in text else text[2:].strip()))
    return rows


def check_reviews(entries, report):
    passing = set(high_stakes_passes(entries))
    for index in sorted(passing):
        after = next((e for e in entries[index + 1:] if e["heading"] not in (STATUS_HEADING, DECISION_HEADING)), None)
        if after is not None and after["heading"] != REVIEW_HEADING:
            report(after["line"], "review-after-pass",
                   f"{after['heading']!r} follows the high-stakes PASS at line {entries[index]['line']}; the main session "
                   f"appends a {REVIEW_HEADING!r} entry first")
    for index, entry in enumerate(entries):
        if entry["heading"] != REVIEW_HEADING:
            continue
        result = entry["fields"].get("Result")
        if result is None:
            continue
        rerun = "Rerun" in entry["fields"]
        if rerun != (result == "overturned"):
            report(entry["line"], "review-rerun",
                   f"'Result: {result}' " + ("has a Rerun: line; only an overturned review names a stage to re-run"
                                             if rerun else "needs a Rerun: line naming the earliest stage that must fix it"))
        if result != "upheld":
            continue
        for number, value in review_rows(entry["body"], REVIEW_RISKS):
            if value == "open":
                report(number, "review-close", "an upheld review has an open risk; that is a held review")
        for number, value in review_rows(entry["body"], REVIEW_DECISIONS):
            if value == "unapproved":
                report(number, "review-close", "an upheld review has an unapproved decision; that is a held review")
        accepted = max((i for i in range(index) if entries[i]["heading"] == "## PM — PASS"), default=None)
        if accepted is None or later_work_orders(entries, accepted):
            continue
        for later in entries[index + 1:]:
            if later["heading"] != STATUS_HEADING:
                report(later["line"], "review-close",
                       f"{later['heading']!r} follows the upheld review at line {entry['line']}; after it only a "
                       f"## Status, then squad-mech's closing archive")
                break


def ends_in_blocker(entry):
    return any(text == "BLOCKER:" for _, text in entry["body"])


def names_entry(value, entry):
    """True when value names the entry by its heading and its timestamp."""
    stamp = timestamp_of(entry)
    return bool(stamp) and entry["heading"] in value and stamp in value


def check_answers(entries, report):
    """From attempt 2 on, an entry names what sent it back (finding 13)."""
    for index, entry in enumerate(entries):
        heading = entry["heading"]
        base = base_heading(heading)
        got = entry["fields"].get("Attempt")
        if got is None or not any(name == "Answers" for name, _, _ in FIELDS.get(base, ())):
            continue
        value = entry["fields"].get("Answers")
        answers_at = next((n for n, text in entry["body"] if text.startswith("Answers: ")), entry["line"])
        if int(got) < 2:
            if value is not None:
                report(answers_at, "answers", f"{heading!r} is attempt {got}; an Answers: line appears from attempt 2 on")
            continue
        if value is None:
            report(entry["line"], "answers", f"{heading!r} is attempt {got}; from attempt 2 on, an Answers: line directly "
                                              f"under Attempt: names what sent this stage back")
            continue
        if base in VERDICT_HEADINGS + (PENDING_HEADING,):
            last_pass = max((i for i in range(index) if entries[i]["heading"] == "## PM — PASS"), default=-1)
            sent = [e for e in entries[last_pass + 1:index]
                    if e["heading"] == "## PM — FAIL"
                    or (e["heading"] == REVIEW_HEADING and e["fields"].get("Result") == "overturned")]
            if sent and not names_entry(value, sent[-1]):
                report(answers_at, "answers",
                       f"'Answers: {value}' must name the latest FAIL or overturned review since the latest PASS: "
                       f"'{sent[-1]['heading']} {timestamp_of(sent[-1])}'")
            elif not sent and value != "none":
                report(answers_at, "answers", f"'Answers: {value}': no FAIL or overturned review since the latest PASS, "
                                              f"so it reads 'Answers: none'")
            continue
        # What sent a stage back comes at or after its previous attempt (that
        # attempt's own blocker included); a (cont.) entry repeats its attempt.
        since = 0
        if not heading.endswith(CONT):
            same = [i for i in range(index) if entries[i]["heading"] == heading
                    and (base != EXECUTOR_HEADING or entries[i]["fields"].get("Plan", "").split(", work order ")[-1]
                         == entry["fields"].get("Plan", "").split(", work order ")[-1])]
            since = same[-1] if same else 0
        named = [e for e in entries[since:index] if names_entry(value, e)
                 and (e["heading"] in ANSWERED_HEADINGS or ends_in_blocker(e))]
        if not named:
            report(answers_at, "answers",
                   f"'Answers: {value}' names no {', '.join(ANSWERED_HEADINGS)}, or entry ending in a BLOCKER: block, "
                   f"by its heading and timestamp, at or after this stage's previous attempt")


def check_recon_checks(entries, report):
    """The Recon entry's Checks: block holds the goal facts and the baseline (finding 14)."""
    for entry in entries:
        if entry["heading"] != "## Recon":
            continue
        body = entry["body"]
        at = label_at(body, CHECKS_LABEL)
        if at is None:
            continue   # the labels rule reports the missing label
        items = []
        for number, text in body[at + 1:]:
            if not text.startswith("- "):
                break
            items.append((number, text))
        where = body[at][0]
        if not items or not re.fullmatch(GOAL_FACTS_LINE, items[0][1]):
            report(items[0][0] if items else where, "recon-checks",
                   "the Checks: block opens with '- goal facts: <all confirmed | each false one, with the file:line "
                   "that contradicts it>'")
            continue
        if len(items) < 2 or not (re.fullmatch(BASELINE_LINE, items[1][1]) or re.fullmatch(BASELINE_SKIPPED, items[1][1])):
            report(items[1][0] if len(items) > 1 else items[0][0], "recon-checks",
                   "the second Checks: line is the baseline: '- `<command>` -> exit <code>; <last summary line>; tree "
                   "changed: <no | the paths>', or '- baseline: not run, <why>'")


def lint(lines, protocol):
    """Return (number of entries, problems), each problem (line, rule, message)."""
    problems = []

    def report(line, rule, message):
        problems.append((line, rule, message))

    preamble, entries = split_entries(lines)
    text_first = next((pair for pair in preamble if pair[1].strip()), None)
    if text_first is not None:
        report(text_first[0], "goal-first", f"text before the first entry; the log opens with {protocol.goal!r}")
    elif entries and entries[0]["heading"] != protocol.goal:
        report(entries[0]["line"], "goal-first", f"the log opens with {entries[0]['heading']!r}, not {protocol.goal!r}")
    for index, entry in enumerate(entries):
        check_heading(entry, entries[:index], protocol, report)
        check_blockers(entry, protocol, report)
        entry["fields"] = check_fields(entry, report)
    check_timestamps(entries, protocol, report)
    check_attempts(entries, report)
    check_governing_plan(entries, report)
    check_high_stakes(entries, report)
    check_cont(entries, protocol, report)
    check_next_lines(entries, report)
    check_grants(lines, entries, protocol, report)
    check_relocks(entries, protocol, report)
    check_needs_human(entries, protocol, report)
    check_criteria(entries, protocol, report)
    check_labels(entries, protocol, report)
    check_totals(entries, report)
    check_reviews(entries, report)
    check_answers(entries, report)
    check_recon_checks(entries, report)
    return len(entries), sorted(problems)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Lint Compute Squad logs against the skill's log grammar.")
    parser.add_argument("--fenced", action="store_true", help="read entries from ```markdown blocks, as in docs/example-log.md")
    parser.add_argument("--skill", default=SKILL_PATH, help="the SKILL.md to read the grammar from")
    parser.add_argument("--rules", action="store_true", help="print each rule id and what it checks, then exit")
    parser.add_argument("--fields", action="store_true",
                        help="print each stage heading's routing fields and their template placeholders as JSON, then exit")
    parser.add_argument("--labels", action="store_true",
                        help="print the labels the Recon and Executor entries carry, in order, as JSON, then exit")
    parser.add_argument("logs", nargs="*", help="log files to lint")
    args = parser.parse_args(argv)
    if args.rules:
        for rule, what in RULES:
            print(f"{rule}\t{what}")
        return 0
    if args.labels:
        print(json.dumps(LABELS, ensure_ascii=False))
        return 0
    if args.fields:
        print(json.dumps(collections.OrderedDict(
            (heading, [[name, placeholder] for name, placeholder, _ in fields]) for heading, fields in FIELDS.items()
        ), ensure_ascii=False))
        return 0
    if not args.logs:
        parser.error("name at least one log")
    try:
        protocol = load_protocol(args.skill)
    except (OSError, ProtocolError) as error:
        print(f"check_logs: {error}", file=sys.stderr)
        return 2
    status = 0
    for path in args.logs:
        try:
            count, problems = lint(read_log(path, args.fenced), protocol)
        except (OSError, UnicodeDecodeError, ProtocolError) as error:
            print(f"check_logs: {error}", file=sys.stderr)
            return 2
        for line, rule, message in problems:
            print(f"{path}:{line}: [{rule}] {message}")
        if problems:
            status = 1
        else:
            print(f"{path}: clean ({count} entries)")
    return status


if __name__ == "__main__":
    sys.exit(main())
