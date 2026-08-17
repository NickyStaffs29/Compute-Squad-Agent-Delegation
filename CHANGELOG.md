# Changelog

## 3.9.2 — 2026-08-17

Accuracy pass from an external-persona review: closes the last self-diagnosed claim errors and
scopes every unverifiable assertion to its evidence.

- **README FAQ tier claim corrected (F4, finally).** "Acceptance always reviews from a tier up"
  misstated the design — on COMPLEX work, execution and acceptance both run on Opus. The FAQ now
  matches `references/routing-rules.md`'s accurate phrasing: never below the work, a tier above by
  default. This was the one finding from `LEFTOVER_FINDINGS.md` still open in README prose.
- **`LEFTOVER_FINDINGS.md` marked as a historical snapshot.** A header now states it reflects the
  v3.6.0 tree, records which findings were since resolved (N1 in 3.9.0, F4 here), and notes N5
  stays open by choice. The file is an audit record, not a live punch list.
- **Pricing and cost claims scoped to their evidence.** The cost table is labeled as list prices
  observed on the author's account (July 2026) to verify before relying on, and the 30-40%
  figure is labeled a back-of-envelope estimate with its uniform-token-volume assumption stated,
  not a measurement.
- **Codex model IDs scoped to their evidence.** README's Codex prerequisites now state the three
  hard-coded model IDs resolve on the author's account as of August 2026 and are not stable
  public API guarantees.

## 3.9.1 — 2026-08-17

Aligns the product description across every surface, including the GitHub repository About text.

- **One description everywhere.** `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  `.claude-plugin/marketplace.json` now carry a byte-identical description, and the two trailing
  platform clauses are dropped — the sentence already names both platforms, so the clauses only
  created two strings that could drift. `README.md`'s opening tagline is the same sentence without
  the leading product name, which the `# Compute Squad` heading above it already supplies.
- **Short enough for GitHub.** The canonical sentence was shortened to 335 characters. GitHub
  rejects a repository description over 350 (HTTP 422), so the previous 384-character version could
  not be used as the About text and that surface had to be worded separately.
- **`scripts/verify.sh` check 7e.** Asserts the three manifest descriptions are byte-identical and
  that the canonical string still fits GitHub's 350-character About limit, so neither the wording
  nor the length can drift out of alignment again. The GitHub About text itself lives outside the
  repository and cannot be checked by CI — it must be updated by hand when this string changes.

## 3.9.0 — 2026-08-17

Applies every surviving finding from the documentation audit: the Rank 7 protocol consolidation, the
three-way naming gap, and the lower-priority findings. Follow-up to 3.8.0's Codex
delegation-guarantee pass.

- **Rank 7: one canonical protocol description.** `skills/compute-squad/SKILL.md` (Claude Code) and
  `codex/SKILL.md` (Codex) are the two canonical, runtime-loaded full descriptions of the pipeline.
  `README.md`'s "How a run works" and "The delegation structure", and `codex/README.md`'s "How to
  run it", no longer independently retell all six stages; they summarize and point at the canonical
  files, keeping only the human-only color and the content that is structurally load-bearing (the
  `## Goal — Locked` template). `scripts/verify.sh` gains check 7: byte-identical diffs for the
  Goal-Locked template (3 files) and the BLOCKER grammar block (2 files), plus presence checks for
  the 5-helper cap (4 files) and the three Codex model IDs (2 files), so the next silent drift fails
  CI instead of shipping. The BLOCKER grammar's existing drift between the two SKILL.md files (a
  dropped article and comma) is fixed as part of this pass.
- **Naming gap resolved.** "Squad Manager," "the orchestrating session," and `codex/SKILL.md`'s H1
  "Codex Manager Protocol" named the same actor three ways. All three collapse to "the orchestrating
  session" repo-wide (33 tracked "Squad Manager" occurrences plus one more in `docs/example-log.md`
  a plain grep missed because it line-wrapped mid-word). `CHANGELOG.md`'s own historical entries are
  left untouched as a historical record.
- **CONTRIBUTING.md rewritten.** Names all five version-bump locations explicitly, names
  `scripts/verify.sh` as the local pre-commit gate matching CI, and fixes the self-contradiction
  between its "five places" opening line and its own seven-item sync-rule list.
- **Canonical product description.** One description, varying only by a trailing platform clause,
  now lives in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  `.claude-plugin/marketplace.json`; `.codex-plugin/plugin.json`'s
  `interface.shortDescription`/`longDescription` are updated to match. All copies name the
  MECHANICAL/STANDARD/COMPLEX three-way routing instead of flat "Sonnet executes."
  `.agents/plugins/marketplace.json` is confirmed to have no `description` field in its real schema
  and is left alone. `README.md`'s opening tagline and
  `skills/compute-squad/references/routing-rules.md`'s summary line, the last two places still
  describing a flat "four-tier" pipeline with "Sonnet executes", are brought in line with the same
  wording; the stale "Updated 2026-08-02" stamp is dropped from the routing reference.
- **Prerequisites documented.** Both install sections in `README.md`, and `codex/README.md`'s
  native-install section, now state their model-access prerequisite (Opus for Claude;
  `gpt-5.6-sol`/`terra`/`luna` for Codex) and the Codex CLI 0.134+ floor, previously only a comment
  in `codex/profiles.toml`.
- **Build and verify harden against stray files.** `scripts/build-plugin.sh` now zips the
  git-tracked file set (`git ls-files`) instead of `zip -r` over live directories, so an untracked
  file cannot enter `dist/compute-squad.plugin`. `scripts/verify.sh` check 2 asserts the agent set
  against `git ls-files agents/*.md` instead of a bare glob.
- **README repo-layout tree completed.** Adds the seven tracked paths it omitted, including
  `scripts/verify.sh` (the actual CI gate), `codex/README.md`, `codex/update.sh`,
  `codex/build-agents.py`, `.github/`, `.gitignore`, and `LICENSE`.
- **Lower-priority findings.** Fixed: `codex/SKILL.md` documents the `(cont.)` re-spawn convention
  (B3); `codex/README.md`'s updater-order sentence now matches `codex/update.sh`'s actual order
  (B4); the Codex CLI version floor is reader-facing (D6); the unused "Fable" row is removed from
  `routing-rules.md`'s cost table (D7); "Claude Cowork" is glossed at first use (D8); `codex/SKILL.md`
  glosses Sol/Terra/Luna where it first uses the shorthand (D10). Declined, with reasons logged:
  `codex/build-agents.py`'s unguarded tier-term substitution (D2, latent risk only, no live misfire,
  a word-boundary fix carries its own miss-risk); the duplicated Codex install command block in
  `README.md`/`codex/README.md` (C4, two lines of copy-paste-stable CLI syntax, not protocol prose).
- **GitHub repository metadata.** Replacement About description, homepage, and topics text produced
  for the user to paste by hand; this run does not change GitHub settings.

Version bumped to 3.9.0 in all five synced locations; `dist/compute-squad.plugin` rebuilt;
`codex/agents/*.toml` regenerated from `agents/*.md` via `python3 codex/build-agents.py`.

## 3.8.0 — 2026-08-17

Closes the Codex delegation-guarantee gap: explicit spawn wording, self-reporting log attribution, a documented Luna fallback, a safe agent prune, and an accurate README.

- **Codex spawn wording.** `codex/SKILL.md`'s Stage 4 routing table and Intra-stage delegation section use the explicit "spawn" verb on every branch, matching the Claude-side skill, plus a new anti-absorption sentence in Hard rules: the orchestrating session must spawn the named agent at every stage instead of doing the stage's work itself.
- **Log entry attribution.** `agents/squad-recon.md`, `agents/squad-pm.md`, `agents/squad-executor.md`, `agents/squad-executor-haiku.md`, and `agents/squad-executor-opus.md` add an `Agent: <name> (<tier>)` line to their log-entry heredoc templates, regenerated into `codex/agents/*.toml` and mirrored by hand in `codex/02-recon.md` through `codex/05-pm-accept.md` and one worked run in `docs/example-log.md`, so a collapsed single-session Codex run is visible in `COMPUTE_SQUAD_LOG.md` without external tooling.
- **Luna subagent fallback documented.** `codex/README.md` documents the reported Multi-Agent V2 restriction on `gpt-5.6-luna` as a subagent target and the manual, per-run workaround; this is documentation only, not a default routing change, since the restriction is unverified against official docs.
- **`codex/update.sh` prunes retired agents.** Removes the three known-retired agent TOMLs (`squad-design.toml`, `squad-manager.toml`, `squad-verifier.toml`) from `$CODEX_HOME/agents` by explicit name, leaving vibecheck's `vc-*.toml` files untouched.
- **README accuracy.** Removes the false "no agent-spawning at all" claim about the Codex path.

## 3.7.0 — 2026-08-02

Native Codex plugin packaging brings the Compute Squad workflow to Codex without dropping the existing Claude package.

- **Codex plugin.** Added a native `.codex-plugin` manifest, Codex marketplace registration, shared-skill Codex routing, generated Codex agent definitions, and model profiles.
- **Codex routing.** Maps the PM and COMPLEX execution to `gpt-5.6-sol`, standard execution to `gpt-5.6-terra`, and mechanical work to `gpt-5.6-luna`, with max reasoning pinned for worker profiles.
- **Sync and verification.** Added generation and validation gates so Codex agents stay aligned with the existing protocol and the Claude distribution remains independently packaged.

## 3.6.0 — 2026-08-02

A slash command entry point, true log appends, and skeptic guidance for concurrency and accessibility findings.

- **New: `/squad <goal>` slash command.** `commands/squad.md` starts the full pipeline at Stage 0 with `$ARGUMENTS` as the goal — same entry point as the trigger phrases, now also reachable as a command. Added to `scripts/build-plugin.sh`'s zip list and `scripts/verify.sh`'s dist content-diff, and documented in the README repo-layout tree and install section.
- **True appends, not Read-then-Write.** `squad-recon`, `squad-pm`, `squad-executor`, `squad-executor-haiku`, `squad-executor-opus`, and the matching Codex prompts (`02-recon.md` through `05-pm-accept.md`) now append log entries with a single Bash/shell heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`) instead of reading the file and writing it back whole, which could silently drop an entry another stage appended in between. `squad-recon` loses the `Write` tool entirely — its one permitted mutation is now the Bash append — and its Bash restriction carries the explicit carve-out (read-only inspection, plus exactly this one append form). Whole-file `Write` remains legitimate in exactly two places, now named as such everywhere they occur: `squad-mech`'s (and `01-archive.md`'s) truncate-after-verified-archive, and the PM's clear-on-PASS. `SKILL.md` and `references/routing-rules.md` state the same rule at the protocol level.
- **Skeptic guidance for concurrency and accessibility findings.** `references/audit-prompts.md`'s skeptic brief now says failure to reproduce is not refutation for these two dimensions — a race needs the right interleaving, an accessibility gap needs the right assistive-tech path — so refute only by demonstrating the guard, the serialization point, or the compliant attribute; otherwise CONFIRM. The default-REFUTED-when-uncertain rule is unchanged for every other dimension.

## 3.5.0 — 2026-08-02

MECHANICAL execution routes to Haiku. **Experimental, pending evidence from real runs** — this is a routing change, not a validated cost/quality result; watch FAIL rates on MECHANICAL-classified work before trusting the savings.

- **New agent: `squad-executor-haiku`.** The executor protocol verbatim (mirrors `squad-executor.md`), on Haiku, scoped to plans the PM classifies MECHANICAL. Carries one added discipline line beyond the shared protocol: if a task turns out to need more than transcribing an explicitly specified change, it stops and logs a `BLOCKER:` (`rerun: Plan`) naming the plan as under-classified, rather than pushing through.
- **Stage 4 routing is now three-way.** MECHANICAL → `squad-executor-haiku` (Haiku), STANDARD → `squad-executor` (Sonnet), COMPLEX → `squad-executor-opus` (Opus). Previously MECHANICAL and STANDARD both ran Sonnet.
- **Execution escalation ladder.** Same-stage-fails-twice escalation for execution now climbs `squad-executor-haiku` → `squad-executor` → `squad-executor-opus` (haiku → sonnet → opus) instead of starting at Sonnet; two FAILs at a tier moves execution up one tier. The general "escalate one tier on repeated FAIL" rule for other stages is unchanged.
- **Rationale.** The plan is required to carry the intelligence regardless of which model executes it, and the Opus PM still reviews every classification the same way — so pushing MECHANICAL work to the cheapest tier widens the gap between executor and reviewer rather than narrowing it, consistent with the pipeline's own verification-asymmetry thesis. This is a default, not a guarantee: it ships as the stated option pending evidence from real runs, not because MECHANICAL-on-Haiku has been run-tested here.
- **Docs.** `skills/compute-squad/SKILL.md` (role list, Stage 4, escalation rules), `skills/compute-squad/references/routing-rules.md` (role table, escalation rule, verification-asymmetry note), `README.md` (agent table, agents section, routing rule 1, repo layout), and `codex/README.md` (suggested-model table) all updated to the three-way routing.

## 3.4.1 — 2026-08-02

Copy hardening: no oversold claims, no past-tense claims about actions that haven't happened yet.

- **"Always a tier above" softened.** The README intro, README rule 2, and `references/routing-rules.md` now say the reviewer is "never below the work, and a tier above by default" — accurate once COMPLEX escalates execution to Opus and acceptance holds at the same tier instead of climbing further. The adjacent caveat about that COMPLEX case is unchanged.
- **README intro reframed.** Leads with what the pipeline actually sells — verification and auditability that don't depend on operator discipline, plus capacity from runs not occupying your session — then the decision-density routing, then the 30-40% cost arithmetic, now explicit that the comparison baseline is an all-Opus worker pool running the same stages, not a single session.
- **Repo-layout tree fixed.** Removed the duplicate `scripts/build-plugin.sh` line.
- **PASS entries no longer claim the future.** The PM's `## PM — PASS` entry (in `agents/squad-pm.md`, `codex/05-pm-accept.md`, and `docs/example-log.md`) now states the archive target as intent (`Archive target: compute-squad-archive/<name>`) instead of claiming the copy is already made and verified — that entry is written before the copy exists. The verified-archive confirmation moved to the PM's final summary message, which sits outside the append-only log.
- **plugin.json metadata.** Added `homepage`, `repository`, and `license: MIT`.

## 3.4.0 — 2026-08-02

Protocol hardening: the goal is now part of the record, and blockers have a grammar.

- **The Goal — Locked entry.** Every fresh log now opens with a mandatory `## Goal — Locked` entry (goal, acceptance criteria, out of scope, assumptions), composed by Stage 0 and appended by Stage 1 immediately after the archive, before Recon spawns. Every downstream stage — Recon, the PM in both modes, both Executors — now reads the goal and acceptance criteria from that entry instead of trusting its spawn prompt, and Stage 0's resume check ("is this the same goal?") reads it too. In Codex, the operator appends the entry by hand after running `01-archive.md`, and prompts 02-05 point at it instead of carrying `GOAL:` / `ACCEPTANCE CRITERIA:` placeholders.
- **The blocker grammar.** Mirroring the `DELEGATE:` block, a stage that hits a blocker mid-work now ends its own log entry with a `BLOCKER:` block — `rerun: <Recon|Plan|Executor>` or `needs-human: <the decision required>`, plus a one-line `why:` — instead of ad hoc prose. A `rerun:` blocker re-runs that stage and everything after it and counts toward the three-FAIL stop; a `needs-human:` blocker returns to Stage 0; freeform prose blockers are now a named protocol violation.
- **Docs.** `docs/example-log.md` gains a worked `## Goal — Locked` entry ahead of Recon and a BLOCKER commentary example. README's "How a run works" and delegation-structure sections, and every sync location, reflect both changes.

## 3.3.0 — 2026-07-25

Hardening pass so the pipeline runs correctly for a first-time user with no author setup.

- **Two new agents.** `squad-executor-opus` is the COMPLEX and escalation execution variant. It replaces a per-call Opus override the runtime never offered, so COMPLEX work now routes to a real Opus agent. `squad-helper` is the execution-tier DELEGATE worker, replacing a Sonnet helper the protocol named but never defined.
- **Log-write permissions fixed.** `squad-recon` and `squad-pm` now carry the `Write` tool, so the stages that must append to `COMPUTE_SQUAD_LOG.md` can actually do it. The log (and its archive copy) is their only permitted write target.
- **Archive on PASS, with high-stakes deferral.** The PM now appends its PASS entry, archives the full log to `compute-squad-archive/` and verifies the copy, and only then clears the active log. High-stakes changes leave the log intact for the main session's review, which clears it afterwards.
- **Blocker and delegation semantics.** A logged blocker naming an upstream stage re-runs that stage and everything after it and counts toward the three-FAIL stop; a blocker needing a human decision returns to Stage 0. Pre-verdict delegation uses a `## PM — Accept (pending)` entry, and `DELEGATE:` blocks are forbidden inside PASS and FAIL entries. Helpers return results and the Squad Manager writes them, ending the duplicate-writer race. A re-spawned stage appends a `## <Stage> (cont.)` entry; the one-entry rule is per spawn.
- **Audit prompt briefs shipped.** New `skills/compute-squad/references/audit-prompts.md` with the five finder briefs and the skeptic brief, including the required finding format and the default-REFUTED rule.
- **Build script.** New `scripts/build-plugin.sh` rebuilds `dist/compute-squad.plugin` from source; the README explains why the artifact is committed.
- **Docs corrections.** Stage count is six everywhere; the archive location is always `compute-squad-archive/` in the repo root; the frontmatter claim now matches reality (aliases, `inherit`, or explicit model IDs); the worked example treats its auth-path change as high-stakes. Added run-footprint, update and uninstall, cost, resume, and trigger-phrase documentation, plus `CONTRIBUTING.md` and gitignore entries for run state.

## 3.2.0 — 2026-07-25

Public release.

- De-personalized the strategy layer: any main-session model can run Stage 0 (top tier recommended); no dependency on a specific frontier model.
- Added `marketplace.json` so Claude Code users can install directly from this repo.
- Added `codex/` prompt pack: the same pipeline as a manually-run sequence of Codex sessions.
- Added `docs/example-log.md`: a complete worked run showing every log entry format, including a DELEGATE block.
- Added MIT license and this changelog.

## 3.1.0 — 2026-07-25

- **DELEGATE protocol.** The hierarchy is fractal: every stage can request that its zero-judgment busywork be pushed down a tier via a `DELEGATE:` block in its log entry. Subagents cannot spawn subagents, so the Squad Manager acts as the switchboard, running intern (Haiku) or execution (Sonnet) helpers on the requesting stage's behalf. Downward only; capped at 5 helpers per stage per run.

## 3.0.0 — 2026-07-25

Role-hierarchy restructure: strategy / PM / execution / intern.

- **Stage 0 Strategy** added: the main session interrogates the goal, identifies gaps, clarifies them with the user in one batched pass, and locks goal + acceptance criteria before any agent spawns.
- **Design and Verifier merged into an Opus PM** (`squad-pm`) with PLAN and ACCEPT modes. The PM plans the work, classifies execution complexity, and adversarially accepts the deliverable.
- **Executor moved to Sonnet by default**, with an Opus override when the PM classifies work COMPLEX. Verification asymmetry holds by construction: the Opus PM always reviews from a tier above Sonnet execution.
- `squad-mech` scoped explicitly as the intern: zero-judgment busywork only.

## 2.0.0 — 2026-07-24

Decision-density routing for the Opus 5 era.

- Replaced the single-worker-model design with per-stage routing: stages that decide (Design, Verifier, Manager) run stronger models; stages that execute against a tight spec run cheaper ones.
- Added verification asymmetry (the verifier never runs weaker than the executor it checks), retry economics, and escalate-on-repeated-FAIL rules.
- Added Haiku tier for mechanical steps (log archival).

## 1.0.0

Original Compute Squad: a 4-stage pipeline (Recon → Design → Executor → Verifier) driven by an Opus manager spawning Sonnet subagents, coordinated through a shared `COMPUTE_SQUAD_LOG.md`, with log archival before every run and a Verifier that clears the log only on PASS.
