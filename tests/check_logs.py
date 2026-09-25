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
grammar, the Goal template's Attended: field and the re-lock rule are read
from skills/compute-squad/SKILL.md, so the linter follows the protocol text.
If that text changes shape, the linter stops with status 2 instead of
guessing. The grant rule runs the Claude Code grant hook,
skills/compute-squad/hooks/grant-gate.sh, with sh over the log above each
Executor entry, so a log from either host is held to the rule the hook
enforces; a denial for an open needs-human: blocker is the needs-human
rule's to report. Python 3.9 stdlib only.
"""
import argparse
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
)

HEADING_BULLET = "- Log entries use only these headings: "
CONT = " (cont.)"
EXECUTOR_HEADING = "## Executor"
GATE = os.path.join("hooks", "grant-gate.sh")   # relative to the skill's directory
GATE_AGENT = "compute-squad:squad-executor"
NEEDS_HUMAN_DENIAL = "needs-human blocker unresolved"   # the hook's reason for an open needs-human: blocker
STATUS_HEADING = "## Status"


class ProtocolError(Exception):
    """The skill text the rules are read from no longer has the expected shape."""


class Protocol(object):
    def __init__(self, fixed, cont, delegated, goal, time_format, targets, gate, relock):
        self.fixed = fixed            # listed headings without a placeholder
        self.cont = cont              # listed headings that may add " (cont.)"
        self.delegated = delegated    # "## Delegated — ", the part before <stage>
        self.goal = goal              # the heading every log opens with
        self.time_format = time_format
        self.targets = targets        # the stages a rerun: blocker may name
        self.gate = gate              # the grant hook script, run with sh
        self.relock = relock          # dict: decision heading, type line, attended line, supersedes field


def load_protocol(skill_path):
    with open(skill_path, encoding="utf-8") as handle:
        text = handle.read()
    lines = text.splitlines()

    bullets = [line for line in lines if line.startswith(HEADING_BULLET)]
    if len(bullets) != 1:
        raise ProtocolError(f"{skill_path}: expected one line starting {HEADING_BULLET!r}, found {len(bullets)}")
    listed_part, _, rest = bullets[0][len(HEADING_BULLET):].partition(". Only ")
    cont_part, found, _ = rest.partition(" may add `" + CONT + "`")
    listed = re.findall(r"`(## [^`]+)`", listed_part)
    cont = re.findall(r"`(## [^`]+)`", cont_part)
    if not listed or not cont or not found:
        raise ProtocolError(f"{skill_path}: the heading-list bullet no longer reads '<headings>. Only <headings> may add `{CONT}`.'")
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
    gate = os.path.join(os.path.dirname(os.path.abspath(skill_path)), GATE)
    if not os.path.isfile(gate):
        raise ProtocolError(f"{gate}: the grant hook the grant rule runs is missing")

    return Protocol(fixed, cont, delegated, goal.group(1), stamp.group(1), first.group(1).split("|"), gate, relock)


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
        requester = next((e for e in reversed(earlier) if not e["heading"].startswith(protocol.delegated)), None)
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
    check_timestamps(entries, protocol, report)
    check_grants(lines, entries, protocol, report)
    check_relocks(entries, protocol, report)
    check_needs_human(entries, protocol, report)
    return len(entries), sorted(problems)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Lint Compute Squad logs against the skill's log grammar.")
    parser.add_argument("--fenced", action="store_true", help="read entries from ```markdown blocks, as in docs/example-log.md")
    parser.add_argument("--skill", default=SKILL_PATH, help="the SKILL.md to read the grammar from")
    parser.add_argument("--rules", action="store_true", help="print each rule id and what it checks, then exit")
    parser.add_argument("logs", nargs="*", help="log files to lint")
    args = parser.parse_args(argv)
    if args.rules:
        for rule, what in RULES:
            print(f"{rule}\t{what}")
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
