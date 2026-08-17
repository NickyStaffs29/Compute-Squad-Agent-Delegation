# Leftover Findings — v3.3.0 → v3.6.0 hardening, blind re-audit

Three blind auditors (protocol consistency, packaging/tooling, claims accuracy) re-ran the
original analysis against the v3.6.0 working tree with no access to the findings list, the
phase history, or the hardening brief. This file reports what is left.

Scoring rule used: **REMAINING** = an auditor rediscovered the original finding, i.e. the
implemented fix failed to eliminate it as its phase spec intended. Residual gaps that sit
outside what the phase spec asked for are listed as **NEW** instead, with a cross-reference.

## Scorecard (F1–F14)

| ID | Finding | Status | Note |
|----|---------|--------|------|
| F1 | Locked goal/criteria never in the log | FIXED | Goal entry present and consistent across all five locations; see N7 for an attribution slip in the example log's commentary |
| F2 | Blockers have no defined format | FIXED | Grammar defined and wired; see N4 — Recon's entry format still mandates prose "blockers/risks" |
| F3 | MECHANICAL routes identically to STANDARD | FIXED | Three-way routing landed; see N6 — manifest descriptions still say flat "Sonnet executes" |
| F4 | "Reviewer always a tier above" is false on COMPLEX | **REMAINING** | README.md:219 (FAQ): "Acceptance always reviews from a tier up." The fix hit the intro, rule 2, and routing-rules.md but missed the FAQ |
| F5 | Log appends are whole-file rewrites | FIXED | All workers append via Bash heredoc; the two legitimate whole-file writes are named as exceptions |
| F6 | Default-REFUTED kills hard-to-reproduce finding classes | FIXED | Concurrency/accessibility carve-out present in audit-prompts.md |
| F7 | Cost claim vs all-Opus baseline framing | FIXED | Capacity-first intro; 30–40% demoted to routing math with baseline stated |
| F8 | No CI; checks enforced manually | FIXED (as specified) | verify.sh + ci.yml exist and work; see N5 — codex/, references/, docs/ sync is still unenforced |
| F9 | No commands/ dir | FIXED | /squad command exists, packaged, documented; see N12 |
| F10 | Hooks for archive immutability | DEFERRED | Out of scope for this run |
| F11 | README tree lists build-plugin.sh twice | FIXED | Listed once; see N11 — the tree now omits verify.sh |
| F12 | PASS entry claims archive before it runs | FIXED | PASS entry states intent only; see N10 for the resulting log-only-rule tension |
| F13 | plugin.json missing homepage/repository/license | FIXED | All three present and correct |
| F14 | Generate codex/ from agents/ | DEFERRED | Out of scope for this run; N5 and N14 strengthen its case |

## New findings (ranked by severity)

### High

**N1 — "The Squad Manager" is the protocol's central actor and is defined nowhere.**
Used throughout `skills/compute-squad/SKILL.md` (14, 83), `references/routing-rules.md` (29),
`agents/squad-pm.md` (48, 60, 74), `agents/squad-recon.md` (40), all three executor files,
`agents/squad-helper.md`, `agents/squad-mech.md` (28), and `docs/example-log.md` (112–113).
No `agents/squad-manager.md` exists; the role lists in SKILL.md (16–25) and routing-rules.md
(5–14) have no Squad Manager row; README.md never uses the term (0 hits) and calls the same
function "the orchestrating session." No file states the two terms are the same thing.

**N2 — The execution escalation ladder's Opus rung is unreachable.**
`SKILL.md:94–95` and `routing-rules.md:26`: haiku → sonnet → opus, "two FAILs at a tier moves
execution up one tier" — reaching Opus by escalation requires 4 executor FAILs, but the run-wide
stop rule halts everything at 3 total FAILs. `squad-executor-opus` is reachable only via the
PM's COMPLEX classification, never via the documented escalation path. Same genus as original F3.

**N3 — The stage-escalation rule implies an Opus-tier Recon that does not exist.**
`SKILL.md:94` / `routing-rules.md:26` ("Same stage fails twice → escalate that stage one model
tier") applies to any stage a PM FAIL can name, including Recon. Only `agents/squad-recon.md`
exists, with `model: sonnet` fixed in frontmatter (line 23); there is no `squad-recon-opus`.
README.md:148 itself explains models are fixed per agent file — the same constraint that
produced three executor files was never applied to Recon.

### Medium

**N4 — Recon's mandatory entry format conflicts with the blocker grammar.** *(adjacent to F2)*
`SKILL.md:106`: "Freeform prose blockers are a protocol violation." But `agents/squad-recon.md:55`
and `codex/02-recon.md:31` mandate "Paragraph 2: blockers, risks, and anything ambiguous…" as
prose, and neither file references the `BLOCKER:` grammar. The worked example
(`docs/example-log.md:37–41`) shows prose "Blockers/risks: none blocking."

**N5 — Three of the five sync locations have no automated enforcement.** *(residual of F8)*
`CONTRIBUTING.md:5–13, 21` declares five-way sync mandatory, but `scripts/verify.sh` (the only
gate CI runs) contains zero references to `codex/`, `references/`, or `docs/example-log.md`.
A PR that changes SKILL.md protocol and forgets codex/ passes CI green.

**N6 — Both manifests still describe execution as flat "Sonnet executes".** *(fallout of Phase 4 / F3)*
`.claude-plugin/plugin.json:4` and `.claude-plugin/marketplace.json:10` vs the three-way
MECHANICAL→Haiku / STANDARD→Sonnet / COMPLEX→Opus routing in `SKILL.md:63–69`.

**N7 — Example log misattributes the Goal-entry append to squad-mech.** *(fallout of Phase 2 / F1)*
`docs/example-log.md:5`: "Then `squad-mech` archives any prior log, appends that entry as the
first line of the fresh log" vs `SKILL.md:51`: the orchestrating session appends it "after
squad-mech reports." `agents/squad-mech.md:21–27` has no Goal-entry step.

**N8 — The worked PASS entry names the wrong log-clearer.**
`docs/example-log.md:112–113` (inside the quoted PM entry): "the Squad Manager clears it
afterwards" vs the narrative at line 118, `SKILL.md:77`, `agents/squad-pm.md:82`, and
`routing-rules.md:48`, which all assign the high-stakes clear to the main session. Concrete
instance of the N1 terminology gap.

**N9 — The resume branch has no defined routing consequence.**
`SKILL.md:47` and `README.md:231` offer "resume from the last logged entry," but no file maps
log state → next stage to spawn (resume after a bare Recon entry vs after a PM plan vs after a
`## Delegated` entry vs after a BLOCKER is unspecified everywhere).

### Low

**N10 — Archive verification is deliberately kept outside the log.** *(design consequence of F12 fix)*
`squad-pm.md:86` places the verified-archive confirmation in the PM's transient summary message
while `SKILL.md:114` declares the log the only coordination channel; the durable record can
never show whether the archive was actually verified. Possibly acceptable — flagging the tension.

**N11 — README repo-layout tree omits `scripts/verify.sh`.** *(fallout of Phase 1)*
`README.md:178–208` lists only `scripts/build-plugin.sh`; `verify.sh` is the CI gate and is
never mentioned anywhere in README.

**N12 — CONTRIBUTING.md's sync list omits `commands/`.** *(fallout of Phase 5)*
`CONTRIBUTING.md:9–13` enumerates the synchronized copies; `commands/squad.md` is packaged and
verified (CHANGELOG 3.6.0) but absent from the list.

**N13 — Dead stage name "verify" survives in the skill's trigger phrase.**
`SKILL.md:8` frontmatter lists trigger "recon-plan-execute-verify"; no stage named Verify exists
post-v3 (terminal stage is Accept). README.md:81's trigger list also omits this phrase, so the
two trigger enumerations disagree.

**N14 — The packaged-path list is duplicated with no shared source of truth.**
`scripts/build-plugin.sh:14, 26–30` and `scripts/verify.sh:246` hardcode the same five paths
independently; drift between them would make check 5 silently stop verifying part of the zip.

**N15 — marketplace.json ↔ plugin.json are never cross-checked.**
verify.sh check 1 only parses each as JSON; nothing ties `marketplace.json`'s plugin
name/description to `plugin.json`'s. A one-sided rename would pass CI.

**N16 — Nothing tells a contributor to run verify.sh locally.**
`CONTRIBUTING.md`'s "Before you commit" checklist duplicates verify.sh's logic in prose without
naming the script; the only mention of `verify.sh` in any .md is a passing CHANGELOG line.

**N17 — squad-helper and squad-mech (delegated mode) lack the "log is the record" instruction.**
Every other worker is told the spawn prompt is a pointer and the log is the record;
`agents/squad-helper.md` and `agents/squad-mech.md`'s delegated-subtask mode are not. Possibly
intentional (procedures are self-contained) — flagging the asymmetry.

## Deferred (out of scope for this run)

- **F10 — Hooks for mechanical enforcement of archive immutability.** Exploratory; not attempted.
- **F14 — Generate codex/ prompts from agents/ to shrink the sync surface.** Not attempted; note
  that N5 (codex/ unenforced by CI) and N14 (duplicated path lists) both strengthen the case for it.
