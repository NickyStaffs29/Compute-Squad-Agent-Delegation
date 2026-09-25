#!/usr/bin/env python3
"""Behavioral regressions found in the 4.4.0 independent review (no model calls)."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import threading
import unittest

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
        (self.repo / "COMPUTE_SQUAD_LOG.md").write_text("Run: regression\n## PM — Plan\n## Status\nGrant: r1 all\n")

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
