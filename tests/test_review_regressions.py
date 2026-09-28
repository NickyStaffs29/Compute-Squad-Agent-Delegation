#!/usr/bin/env python3
"""Behavioral regressions found in the 4.4.0 independent review (no model calls)."""
import contextlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import types
import unittest
from unittest import mock

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_logs
import resume_next
sys.path.insert(0, str(Path(__file__).resolve().parent / "live"))
import check_live

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/logs"


def lines(text):
    return list(enumerate(text.splitlines(), 1))


def fixture(name):
    return (FIXTURES / (name + ".log.md")).read_text()


def through(text, heading):
    """Keep the log through the last named entry, before main writes Status."""
    start = text.rindex("\n" + heading + "\n")
    end = text.find("\n## ", start + 1)
    return text if end < 0 else text[:end] + "\n"


class ProtocolRegressionTests(unittest.TestCase):
    def lint(self, text):
        return check_logs.lint(lines(text), check_logs.load_protocol(check_logs.SKILL_PATH))[1]

    def test_unknown_decision_type_is_rejected(self):
        text = fixture("resume-decision").replace("Type: grant", "Type: invented")
        self.assertTrue(any(rule == "decision" for _, rule, _ in self.lint(text)))

    def test_human_resolution_respawns_blocked_stage_without_relocking(self):
        text = fixture("needs-human-stop") + '''
## Decision
Timestamp: 2026-09-03T08:06:00Z
Type: resolution
Covers: ## Recon, Timestamp: 2026-09-03T08:04:41Z
User's words: "The required runner is now installed; rerun the unchanged check."
'''
        self.assertEqual([], self.lint(text))
        action, _ = resume_next.next_action(lines(text))
        self.assertIn("re-spawn squad-recon", action)

    def test_resolution_must_identify_the_pending_entry(self):
        text = fixture("needs-human-stop") + '''
## Decision
Timestamp: 2026-09-03T08:06:00Z
Type: resolution
Covers: ## Recon, Timestamp: 2026-09-03T07:00:00Z
User's words: "It is ready."
'''
        self.assertTrue(any(rule == "decision" for _, rule, _ in self.lint(text)))

    def test_resolution_reruns_a_held_review(self):
        text = fixture("review-held") + '''
## Decision
Timestamp: 2026-09-10T09:35:00Z
Type: resolution
Covers: ## High-stakes review, Timestamp: 2026-09-10T09:31:44Z
User's words: "Support sessions have the same owner restriction."
'''
        self.assertEqual([], self.lint(text))
        self.assertIn("run a new high-stakes review", resume_next.next_action(lines(text))[0])

    def test_held_review_accepts_separate_answers_with_or_without_status(self):
        for intervening_status in (False, True):
            with self.subTest(status=intervening_status):
                text = fixture("review-held").replace(
                    "- a support session reads another account's PDF | open",
                    "- a support session reads another account's PDF | open\n"
                    "- a service session reads another account's PDF | open")
                status = text[text.rindex("\n## Status\n"):].split("\n## High-stakes review\n", 1)[0]
                for minute, role in ((35, "Support"), (36, "Service")):
                    text += f'''
## Decision
Timestamp: 2026-09-10T09:{minute}:00Z
Type: resolution
Covers: ## High-stakes review, Timestamp: 2026-09-10T09:31:44Z
User's words: "{role} sessions have the same owner restriction."
'''
                    self.assertEqual([], self.lint(text))
                    self.assertIn("run a new high-stakes review", resume_next.next_action(lines(text))[0])
                    if minute == 35 and intervening_status:
                        text += status.replace("09:24:30Z", "09:35:30Z")

    def test_resolution_rejects_a_superseded_held_review(self):
        text = fixture("review-held")
        new_review = text[text.rindex("\n## High-stakes review\n"):]
        new_review = new_review.replace("09:31:44Z", "09:40:00Z").replace("Result: held", "Result: upheld")
        new_review = new_review.replace("| open", "| owner restriction verified")
        text += new_review
        self.assertEqual([], self.lint(text))
        text += '''
## Decision
Timestamp: 2026-09-10T09:41:00Z
Type: resolution
Covers: ## High-stakes review, Timestamp: 2026-09-10T09:31:44Z
User's words: "Support sessions have the same owner restriction."
'''
        self.assertTrue(any(rule == "decision" for _, rule, _ in self.lint(text)))
        self.assertIn("stop: resolution names no pending", resume_next.next_action(lines(text))[0])

    def test_resolution_does_not_supply_an_executor_grant(self):
        text = fixture("execute-granted") + '''
BLOCKER:
- needs-human: whether the missing runner is available
- why: the runner cannot be found
'''
        status = text[text.rindex("\n## Status\n"):].split("\n## Executor\n", 1)[0]
        status = re.sub(r"^Grant: .*", "Grant: none", status, flags=re.M)
        status = re.sub(r"^Timestamp: .*", "Timestamp: 2026-09-03T08:42:00Z", status, flags=re.M)
        text += status + '''
## Decision
Timestamp: 2026-09-03T08:43:00Z
Type: resolution
Covers: ## Executor, Timestamp: 2026-09-03T08:41:27Z
User's words: "The runner is now installed."
'''
        self.assertEqual([], self.lint(text))
        action, _ = resume_next.next_action(lines(text))
        self.assertIn("await a grant", action)
        self.assertNotIn("spawn squad-executor", action)

    def test_executor_resume_uses_durable_audit_intent(self):
        text = through(fixture("audit-findings"), "## Executor")
        text = re.sub(r"^Audit: .*\n", "", text, flags=re.M)
        text = text.replace("Attended: yes\n", "Attended: yes\nAudit: yes\n", 1)
        action, _ = resume_next.next_action(lines(text))
        self.assertIn("run the audit", action)

    def test_legacy_log_without_audit_intent_stops_for_resolution(self):
        text = through(fixture("audit-findings"), "## Executor")
        text = re.sub(r"^Audit: .*\n", "", text, flags=re.M)
        action, _ = resume_next.next_action(lines(text))
        self.assertIn("ask the user", action)
        self.assertNotIn("ACCEPT", action)

    def test_user_relock_can_supply_missing_legacy_audit_intent(self):
        text = fixture("relock-recorded").replace("Audit: no\n", "", 1)
        self.assertEqual([], self.lint(text))

    def test_stale_decision_does_not_grant_governing_revision(self):
        text = fixture("resume-decision")
        plan = re.search(r"(?ms)^## PM — Plan\n.*?(?=^## |\Z)", text).group(0)
        second = plan.replace("Attempt: 1\n", "Attempt: 2\nAnswers: ## Status 2026-09-02T09:10:05Z\n", 1)
        second = re.sub(r"^Timestamp: .*", "Timestamp: 2026-09-02T09:11:00Z", second, count=1, flags=re.M)
        text = text.replace("## Decision\n", second + "\n## Decision\n", 1)
        self.assertEqual([], self.lint(text))
        action, _ = resume_next.next_action(lines(text))
        self.assertIn("await a grant for r2", action)
        self.assertNotIn("spawn squad-executor", action)

    def test_execute_handoff_runs_tree_and_base_checks(self):
        text = fixture("plan-shelved")
        pos = text.rindex("\n## Status\n")
        status = text[pos:]
        status = re.sub(r"^Mode: .*", "Mode: execute", status, flags=re.M)
        status = re.sub(r"^Plan: .*", "Plan: r1, work order WO-1", status, flags=re.M)
        status = re.sub(r"^Grant: .*", "Grant: r1 WO-1, per Decision 2026-09-02T09:12:00Z", status, flags=re.M)
        status = re.sub(r"^Next: .*", "Next: execute WO-1 in Claude Code, then accept in Codex", status, flags=re.M)
        text = text[:pos] + status
        self.assertEqual([], self.lint(text))
        action, _ = resume_next.next_action(lines(text), {"dirty": ["src/unlogged.js"]})
        self.assertIn("stop: unlogged edits", action)
        action, _ = resume_next.next_action(lines(text), {"head": "new-base", "moved": ["src/cli/export.js"]})
        self.assertIn("spawn squad-recon", action)


class HookRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.transcript = self.repo / "transcript.jsonl"
        self.transcript.write_text(self.message("old", 100))
        (self.repo / "COMPUTE_SQUAD_LOG.md").write_text("Run: regression\n## PM — Plan\n## Status\nGrant: all revisions, full-mode request\n")

    def message(self, ident, tokens):
        return json.dumps({"type": "assistant", "timestamp": "2026-09-25T10:00:00Z", "message": {
            "id": "msg_" + ident, "model": "fixture-model", "stop_reason": "end_turn",
            "usage": {"input_tokens": tokens, "output_tokens": 5}}}, separators=(",", ":")) + "\n"

    def payload(self, event="SubagentStop"):
        return {"hook_event_name": event, "agent_type": "compute-squad:squad-recon", "agent_id": "test-agent",
                "session_id": "test-session", "cwd": str(self.repo), "agent_transcript_path": str(self.transcript),
                "transcript_path": str(self.transcript)}

    def hook(self, script, payload, timeout=8):
        proc = subprocess.Popen(["/bin/sh", str(ROOT / "skills/compute-squad/hooks" / script)],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, start_new_session=True)
        try:
            stdout, stderr = proc.communicate(json.dumps(payload), timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.communicate()
            self.fail("hook blocked on its input path")
        self.assertEqual(0, proc.returncode)
        return stdout, stderr

    def test_ledger_waits_for_continued_and_first_assistant_flush(self):
        for event, prior in (("SubagentStop", True), ("SubagentStop", False), ("Stop", True)):
            with self.subTest(event=event, prior=prior):
                self.transcript.write_text(self.message("old", 100) if prior else "")
                def append():
                    with self.transcript.open("a") as f:
                        f.write(self.message("new", 900))
                writer = threading.Timer(0.1, append)
                writer.start()
                try:
                    self.assertEqual(("", ""), self.hook("usage-ledger.sh", self.payload(event)))
                finally:
                    writer.join()
                records = [json.loads(l) for l in (self.repo / "compute-squad-archive/usage.jsonl").read_text().splitlines()]
                self.assertEqual(1000 if prior else 900, records[-1]["input"])
                self.assertEqual(2 if prior else 1, records[-1]["calls"])

    def test_hooks_decode_json_escaped_paths(self):
        for name in ('quote"folder', 'back\\slash', 'unicode-\u00e9-\U0001f3cc'):
            with self.subTest(name=name):
                root = self.repo / name
                root.mkdir()
                (root / "COMPUTE_SQUAD_LOG.md").write_text((self.repo / "COMPUTE_SQUAD_LOG.md").read_text())
                payload = self.payload()
                payload["cwd"] = str(root)
                payload["tool_input"] = {"subagent_type": "compute-squad:squad-executor-mechanical"}
                self.assertEqual(("", ""), self.hook("grant-gate.sh", payload))
                self.assertEqual(("", ""), self.hook("usage-ledger.sh", payload))
                self.assertTrue((root / "compute-squad-archive/usage.jsonl").is_file())

    def test_unavailable_ledger_destination_is_silent(self):
        archive = self.repo / "compute-squad-archive"
        archive.write_text("a file, not a directory")
        self.assertEqual(("", ""), self.hook("usage-ledger.sh", self.payload()))
        archive.unlink()
        (archive / "usage.jsonl").mkdir(parents=True)
        self.assertEqual(("", ""), self.hook("usage-ledger.sh", self.payload()))

    def test_fifo_transcript_is_skipped_without_waiting(self):
        self.transcript.unlink()
        os.mkfifo(self.transcript)
        self.assertEqual(("", ""), self.hook("usage-ledger.sh", self.payload(), timeout=2))


class BudgetRegressionTests(unittest.TestCase):
    def test_output_lower_bound_cannot_certify_budget(self):
        records = [{"session": "s", "agent": "main", "input": 100, "output": 12000, "calls": 1}]
        ok, detail = check_live.budget_judgment(records, "s")
        self.assertFalse(ok)
        self.assertIn("unverified", detail)
        ok, detail = check_live.budget_judgment(records, "s", 20000)
        self.assertFalse(ok)
        self.assertIn("unverified", detail)
        self.assertTrue(check_live.budget_judgment(records, "s", 12300)[0])
        self.assertFalse(check_live.budget_judgment(records, "s", 100)[0])


class LedgerRegressionTests(unittest.TestCase):
    """A resumed session's ledger lines are running totals over every turn,
    while modelUsage covers one call: the check compares this call's share."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ledger = Path(self.temp.name) / "compute-squad-archive" / "usage.jsonl"
        self.ledger.parent.mkdir()
        self.turn1 = [self.line("main", "main", 1000, 50), self.line("squad-pm", "a1", 400, 30)]
        self.turn2 = [self.line("main", "main", 1600, 80)]

    @staticmethod
    def line(agent, agent_id, tokens, output):
        return {"v": 1, "session": "s", "agent": agent, "agent_id": agent_id, "input": tokens, "cache_write": 0,
                "cache_read": 0, "output": output}

    def failures(self, earlier, now, host_input, host_output, by_type, totals=True):
        before = {"ledger_ids": sorted(r["agent_id"] for r in earlier if r["agent"] != "main")}
        if totals:
            before["ledger_totals"] = check_live.ledger_totals(earlier)
        self.ledger.write_text("".join(json.dumps(r) + "\n" for r in earlier + now))
        ctx = types.SimpleNamespace(repo=self.temp.name, before=before, by_type=by_type, result={
            "session_id": "s", "modelUsage": {"m": {"inputTokens": host_input, "outputTokens": host_output}}})
        report = check_live.Report()
        with contextlib.redirect_stdout(io.StringIO()):
            check_live.check_ledger(ctx, report)
        return report.failures

    def test_first_turn_counts_every_line(self):
        self.assertEqual(0, self.failures([], self.turn1, 1400, 80, {"squad-pm": 1}))

    def test_resumed_turn_compares_this_calls_share(self):
        self.assertEqual(0, self.failures(self.turn1, self.turn2, 600, 30, {}))
        self.assertGreater(self.failures(self.turn1, self.turn2, 600, 30, {}, totals=False), 0)

    def test_tolerance_and_spawn_checks_still_bite(self):
        self.assertGreater(self.failures(self.turn1, self.turn2, 700, 30, {}), 0)
        self.assertGreater(self.failures(self.turn1, self.turn2, 600, 30, {"squad-pm": 1}), 0)


class PreflightRegressionTests(unittest.TestCase):
    ISOLATED = {"PLAYWRIGHT_BROWSERS_PATH": "/no-browsers", "NPM_CONFIG_PREFIX": "/no-npm-global",
                "NPM_CONFIG_OFFLINE": "true"}

    def preflight(self, script):
        with tempfile.TemporaryDirectory() as repo, \
                mock.patch.object(check_live, "BROWSER_CHECK", ("sh", "-c", script)), \
                mock.patch.dict(os.environ, self.ISOLATED), \
                contextlib.redirect_stdout(io.StringIO()):
            return check_live.cmd_preflight("s5b", repo)

    def test_s5b_premise_survives_cleared_settings(self):
        leak = 'if {}; then echo "check-overflow: no horizontal overflow"; exit 0; fi; echo "check-overflow: cannot run"; exit 2'
        browser, npm = '[ -z "${PLAYWRIGHT_BROWSERS_PATH-}" ]', '[ -z "${NPM_CONFIG_PREFIX-}" ]'
        for cleared in (browser, npm, f"{browser} && {npm}"):
            with self.subTest(leaks_when=cleared):
                self.assertEqual(1, self.preflight(leak.format(cleared)))
        self.assertEqual(0, self.preflight('echo "check-overflow: cannot run: Playwright has no Chromium"; exit 2'))

    @unittest.skipUnless(shutil.which("node") and shutil.which("git"), "needs node and git")
    def test_nobrowser_stand_in_fails_the_check_under_any_environment(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            shutil.copytree(ROOT / "tests/fixtures/repo-ui", repo)
            for args in (["init", "-q"], ["add", "-A"], ["-c", "user.name=t", "-c", "user.email=t@example.invalid",
                                                         "-c", "commit.gpgsign=false", "commit", "-q", "-m", "A"]):
                subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)
            with contextlib.redirect_stdout(io.StringIO()):
                check_live.cmd_nobrowser(str(repo))
            self.assertEqual("", subprocess.run(["git", "-C", str(repo), "status", "--porcelain"], check=True,
                                                capture_output=True, text=True).stdout)
            for env in (dict(os.environ), {k: v for k, v in os.environ.items() if k not in
                                           check_live.S5B_BROWSER_SETTINGS + check_live.S5B_NPM_SETTINGS}):
                code, output = check_live.browser_check(str(repo), env)
                self.assertEqual(2, code, output)
                self.assertIn("cannot run", output)

    def test_nobrowser_integrity_check_reads_package_json_main(self):
        with tempfile.TemporaryDirectory() as repo, contextlib.redirect_stdout(io.StringIO()):
            check_live.cmd_nobrowser(repo)
            ctx, stand_in = types.SimpleNamespace(repo=repo), Path(repo) / check_live.NOBROWSER_DIR

            def failures():
                report = check_live.Report()
                check_live.expect_nobrowser_intact(ctx, report)
                return report.failures

            self.assertEqual(0, failures())
            package = stand_in / "package.json"
            before = json.loads(package.read_text())
            package.write_text(package.read_text().replace('"main": "index.js"', '"main": "real.js"'))
            self.assertEqual(dict(before, main="real.js"), json.loads(package.read_text()))
            self.assertEqual(check_live.NOBROWSER_STUB, (stand_in / "index.js").read_text())
            self.assertEqual(1, failures())


class CandidateRegressionTests(unittest.TestCase):
    """The live harness proves the Compute Squad a call used is the checkout
    under test: an S1 run on Claude Code 2.1.259 read SKILL.md by a path
    relative to the scenario repo, then the installed 4.6.0 copy."""
    ROOT = "/src/compute squad"   # a checkout path with a space in it
    INSTALLED = os.path.expanduser("~/.claude/plugins/cache/compute-squad/compute-squad/4.6.0")
    SKILL_CALL = {"tool_name": "Skill", "tool_input": {"skill": "compute-squad:compute-squad"}, "cwd": "/w"}

    def failures(self, check="s1-plan", plugins=None, bases=(), events=None, verbose=True):
        plugins = [{"name": "compute-squad", "path": self.ROOT}] if plugins is None else plugins
        messages = None
        if verbose:
            messages = [{"type": "system", "subtype": "init", "plugins": plugins},
                        *({"type": "user", "message": {"content": [{"type": "text", "text":
                                                                     f"Base directory for this skill: {b}\n# Compute Squad"}]}}
                          for b in bases),
                        {"type": "result", "subtype": "success"}]
        ctx = check_live.Context.__new__(check_live.Context)
        ctx.repo, ctx.messages = "/w", messages
        ctx.init = messages[0] if messages else None
        ctx.events = [self.SKILL_CALL] if events is None else events
        report = check_live.Report()
        with contextlib.redirect_stdout(io.StringIO()):
            check_live.expect_candidate(ctx, report, check, root=self.ROOT)
        return report.failures

    def test_the_candidate_alone_passes(self):
        self.assertEqual(0, self.failures(bases=[self.ROOT + "/skills/compute-squad"]))
        read = {"tool_name": "Bash", "tool_input": {"command": f'cat "{self.ROOT}/skills/compute-squad/SKILL.md"'}}
        self.assertEqual(0, self.failures(events=[read]))

    def test_an_installed_copy_fails_every_way_it_can_enter(self):
        installed = {"name": "compute-squad", "path": self.INSTALLED}
        self.assertEqual(1, self.failures(plugins=[{"name": "compute-squad", "path": self.ROOT}, installed]))
        self.assertEqual(1, self.failures(plugins=[installed]))
        self.assertEqual(1, self.failures(bases=[self.INSTALLED + "/skills/compute-squad"]))
        for tried in ("skills/compute-squad/SKILL.md", self.INSTALLED + "/skills/compute-squad/SKILL.md",
                      "~/.claude/plugins/marketplaces/compute-squad/agents/squad-pm.md"):
            with self.subTest(tried=tried):
                read = {"tool_name": "Read", "tool_input": {"file_path": tried}, "cwd": "/w"}
                self.assertEqual(1, self.failures(events=[self.SKILL_CALL, read]))
        self.assertEqual(1, self.failures(verbose=False))

    def test_a_first_turn_must_load_the_candidate_skill(self):
        other = {"tool_name": "Read", "tool_input": {"file_path": "/w/COMPUTE_SQUAD_LOG.md"}, "cwd": "/w"}
        self.assertEqual(1, self.failures(events=[other]))
        self.assertEqual(0, self.failures(check="s1-approve", events=[other]))

    def test_a_symlinked_checkout_is_still_the_candidate(self):
        with tempfile.TemporaryDirectory() as temp:
            real = Path(temp) / "real"
            (real / "skills/compute-squad").mkdir(parents=True)
            (Path(temp) / "link").symlink_to(real)
            self.ROOT = str(Path(temp) / "link")
            read = {"tool_name": "Read", "tool_input": {"file_path": str(real / "skills/compute-squad/SKILL.md")}, "cwd": "/w"}
            self.assertEqual(0, self.failures(plugins=[{"name": "compute-squad", "path": str(real)}],
                                              bases=[str(real / "skills/compute-squad")], events=[read]))

    def test_the_archive_and_the_scenario_repo_are_not_protocol_files(self):
        for given in ({"command": "tail -1 compute-squad-archive/usage.jsonl"}, {"file_path": "/w/src/server/log.js"},
                      {"pattern": "reset_requested", "path": "src"}):
            self.assertEqual([], check_live.foreign_protocol_paths(given, "/w", self.ROOT))

    def test_verbose_and_plain_results_both_load(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "turn1.json"
            path.write_text(json.dumps([{"type": "system", "subtype": "init"}, {"type": "result", "session_id": "a"}]))
            result, messages = check_live.load_call(str(path))
            self.assertEqual(("a", 2), (result["session_id"], len(messages)))
            path.write_text(json.dumps({"type": "result", "session_id": "b"}))
            self.assertEqual(({"type": "result", "session_id": "b"}, None), check_live.load_call(str(path)))


class ResetFixtureRegressionTests(unittest.TestCase):
    """tests/fixtures/repo-reset/ must honor its own CLAUDE.md, which the
    cooldown goal's privacy criterion repeats: no response or log line
    reveals whether an account exists."""
    FIXTURE = ROOT / "tests/fixtures/repo-reset"
    SERVICE = "src/server/auth/reset.service.js"
    CODES = "const EVENT_CODES = Object.freeze(['reset_request_received']);"
    # One app, requests a second apart: a known address's send, its second
    # request (refused once WO-1's cooldown exists), and an unknown address.
    PROBE = """
const { createApp } = require('./src/server/app');
const { createFakeClock } = require('./src/server/clock');
const clock = createFakeClock();
const app = createApp({ clock, accounts: [{ email: 'ada@example.com' }] });
const seen = {};
for (const [name, email] of [['send', 'ada@example.com'], ['cooldown', 'ada@example.com'], ['unknown', 'nobody@example.com']]) {
  const logged = app.log.events.length;
  const mailed = app.outbox.length;
  const res = app.handle({ method: 'POST', path: '/api/auth/reset-request', body: { email } });
  seen[name] = { res, events: app.log.events.slice(logged), emails: app.outbox.length - mailed };
  clock.advance(1000);
}
console.log(JSON.stringify(seen));
"""
    # Each tree the scenarios build, with the one event each request must log:
    # the base, WO-1 as S2c, S4, and S6a apply it, S4b's commit C, and WO-1
    # plus the completed WO-2.
    TREES = (((), "reset_requested"), (("wo1",), "reset_requested"), (("wo1", "wo2-event"), "reset_requested"),
             (("wo1", "wo2"), "reset_request_received"))

    @contextlib.contextmanager
    def tree(self, patches):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            shutil.copytree(self.FIXTURE, repo)
            subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True, capture_output=True)
            for name in patches:
                subprocess.run(["git", "-C", str(repo), "apply", str(ROOT / f"tests/live/repo-reset-{name}.patch")],
                               check=True, capture_output=True)
            yield repo

    def privacy_problems(self, repo, code):
        """What breaks the privacy rule: responses that differ, or a request
        whose log is anything but the one { code } event. It also confirms
        the probe reached each case: the send mails, the unknown address does
        not, and the second request is refused once the cooldown exists."""
        run = subprocess.run(["node", "-e", self.PROBE], cwd=repo, capture_output=True, text=True, timeout=60)
        self.assertEqual(0, run.returncode, run.stderr)
        seen = json.loads(run.stdout)
        problems = []
        if len({json.dumps(v["res"], sort_keys=True) for v in seen.values()}) != 1:
            problems.append(f"responses differ: {[v['res'] for v in seen.values()]}")
        problems += [f"{name} logged {v['events']}, not exactly [{{'code': {code!r}}}]"
                     for name, v in seen.items() if v["events"] != [{"code": code}]]
        cooldown = "RESEND_COOLDOWN_MS" in (repo / self.SERVICE).read_text()
        self.assertEqual({"send": 1, "cooldown": 0 if cooldown else 1, "unknown": 0},
                         {name: v["emails"] for name, v in seen.items()}, "the probe must reach every case")
        return problems

    @unittest.skipUnless(shutil.which("node") and shutil.which("git"), "needs node and git")
    def test_reset_responses_and_log_never_tell_known_from_unknown(self):
        for patches, code in self.TREES:
            with self.subTest(patches=patches), self.tree(patches) as repo:
                self.assertEqual([], self.privacy_problems(repo, code))

    @unittest.skipUnless(shutil.which("node") and shutil.which("git"), "needs node and git")
    def test_a_cooldown_only_event_or_an_account_id_fails_the_privacy_check(self):
        branch = "  if (newest && clock.now() - newest.createdAt < RESEND_COOLDOWN_MS) {\n"
        shared = "  log.event('reset_request_received');\n  const account = store.findAccountByEmail(email);\n"
        cooldown_event = {self.CODES: self.CODES.replace("]", ", 'reset_cooldown_hit']")}
        mutations = {
            # The requirement WO-7 replaced: a cooldown-only event with the account id.
            "the old WO-2 event": dict(cooldown_event, **{
                branch: branch + "    log.event('reset_cooldown_hit', { accountId: account.id });\n"}),
            "a cooldown-only event": dict(cooldown_event, **{branch: branch + "    log.event('reset_cooldown_hit');\n"}),
            "an accountId field": {shared: "  const account = store.findAccountByEmail(email);\n"
                                           "  log.event('reset_request_received', account ? { accountId: account.id } : {});\n"},
        }
        flagged = {"the old WO-2 event": ["cooldown"], "a cooldown-only event": ["cooldown"],
                   "an accountId field": ["send", "cooldown"]}
        for name, edits in mutations.items():
            with self.subTest(mutation=name), self.tree(("wo1", "wo2")) as repo:
                for old, new in edits.items():
                    path = repo / ("src/server/log.js" if old == self.CODES else self.SERVICE)
                    text = path.read_text()
                    self.assertEqual(1, text.count(old), f"{name}: {old!r}")
                    path.write_text(text.replace(old, new))
                problems = self.privacy_problems(repo, "reset_request_received")
                self.assertEqual(flagged[name], [p.split()[0] for p in problems], problems)

    def test_no_fixture_or_example_asks_for_a_cooldown_only_or_account_linked_event(self):
        # The reset scenario's texts: fixture logs, the worked example, the
        # patches, the fixture repo, and the harness's goals.
        forbidden = re.compile(r"cooldown_hit|log\.event\([^)\n]*account|logs? [^.\n]*event[^.\n]*with (?:the )?account ?id",
                               re.IGNORECASE)
        paths = [*FIXTURES.glob("*.log.md"), ROOT / "docs/example-log.md", *(ROOT / "tests/live").glob("repo-reset-*.patch"),
                 *(p for p in self.FIXTURE.rglob("*") if p.is_file()), ROOT / "tests/live/run.sh"]
        found = [f"{p.relative_to(ROOT)}:{n}: {m.group(0)}" for p in paths
                 for n, line in enumerate(p.read_text().splitlines(), 1) for m in forbidden.finditer(line)]
        self.assertEqual([], found)
        self.assertEqual("reset_request_received", check_live.S2_WO2_MARK)

    def test_live_seed_map_quotes_match_the_fixture_lines_they_cite(self):
        # The seeds run.sh's scenarios put on this fixture (REPO defaults to it).
        blocks = re.findall(r"^    (s\w+)\)\n(.*?);;", (ROOT / "tests/live/run.sh").read_text(), re.MULTILINE | re.DOTALL)
        seeds = sorted({re.search(r"SEED=(\S+)", body).group(1) for _, body in blocks if "REPO=" not in body})
        self.assertIn("s2", seeds)
        cite = re.compile(r'^- ((?:src/|CLAUDE\.md|package\.json)\S*?):([0-9]+)(?:-[0-9]+)? [^"]*"([^"]+)"')
        checked = 0
        for seed in seeds:
            log = FIXTURES / f"{seed}.log.md"
            text = log.read_text()
            for number, line in enumerate(text.splitlines(), 1):
                match = cite.match(line)
                if not match:
                    continue
                path, at, quote = match.groups()
                lines = (self.FIXTURE / path).read_text().splitlines()
                with self.subTest(log=log.name, line=number):
                    self.assertLessEqual(int(at), len(lines), f"{path} has no line {at}")
                    self.assertIn(quote, lines[int(at) - 1], f"{path}:{at} no longer reads {quote!r}")
                checked += 1
        self.assertGreater(checked, 0)


class EvidenceRegressionTests(unittest.TestCase):
    def test_moved_base_checks_fresh_reads_not_complete_map_size(self):
        product = ["src/server/db/store.js", "src/server/middleware/rateLimit.js"]
        read = {"agent_type": "compute-squad:squad-recon", "tool_name": "Read",
                "tool_input": {"file_path": product[0]}}
        self.assertTrue(check_live.remap_reads([read], "/repo", product)[0])
        unrelated = dict(read, tool_input={"file_path": product[1]})
        self.assertFalse(check_live.remap_reads([read, unrelated], "/repo", product)[0])
        shell = dict(read, tool_name="Bash", tool_input={"command": "cat " + product[1]})
        self.assertFalse(check_live.remap_reads([read, shell], "/repo", product)[0])
        callers = dict(read, tool_name="Bash", tool_input={"command": "rg deleteResetTokens src"})
        self.assertTrue(check_live.remap_reads([read, callers], "/repo", product)[0])

    def test_example_review_runs_the_planned_gate(self):
        sample = (ROOT / "docs/example-log.md").read_text()
        review = sample.split("## High-stakes review\n", 1)[1].split("## Status\n", 1)[0]
        self.assertIn("npm run ci:verify", review)


if __name__ == "__main__":
    unittest.main()
