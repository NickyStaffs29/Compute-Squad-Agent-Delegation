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

The heading list, the opening entry, the timestamp form and the blocker
grammar are read from skills/compute-squad/SKILL.md, so the linter follows
the protocol text. If that text changes shape, the linter stops with status 2
instead of guessing. Python 3.9 stdlib only.
"""
import argparse
import datetime
import os
import re
import sys

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
)

HEADING_BULLET = "- Log entries use only these headings: "
CONT = " (cont.)"


class ProtocolError(Exception):
    """The skill text the rules are read from no longer has the expected shape."""


class Protocol(object):
    def __init__(self, fixed, cont, delegated, goal, time_format, targets):
        self.fixed = fixed            # listed headings without a placeholder
        self.cont = cont              # listed headings that may add " (cont.)"
        self.delegated = delegated    # "## Delegated — ", the part before <stage>
        self.goal = goal              # the heading every log opens with
        self.time_format = time_format
        self.targets = targets        # the stages a rerun: blocker may name


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

    return Protocol(fixed, cont, delegated, goal.group(1), stamp.group(1), first.group(1).split("|"))


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
