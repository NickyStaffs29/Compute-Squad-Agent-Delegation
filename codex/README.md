# Compute Squad for Codex

The repository ships a native Codex plugin plus five prompt files for older Codex versions. The native path loads the shared `skills/compute-squad/SKILL.md` orchestration skill and uses the same seven named agents as the Claude package; both implementations coordinate through `COMPUTE_SQUAD_LOG.md`.

## Native Codex install

Requires Codex CLI 0.144 or newer, a working `git`, `/bin/bash`, and access on your Codex account
to the three models in the generated routing table under How to run it, one per rung with no
fallback. A stage whose model your account cannot use stops the run and reports the setup gap.

```bash
codex plugin marketplace add https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation
codex plugin add compute-squad@compute-squad
```

Install the generated agent definitions into the user agent directory:

```bash
mkdir -p "$HOME/src"
git clone https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation "$HOME/src/compute-squad"
bash "$HOME/src/compute-squad/codex/update.sh"
```

The update script pulls the clone, refreshes the configured marketplace, installs the plugin, copies all seven agents, removes any retired agent TOMLs the repo no longer ships, and writes the four current Codex V2 profile files. Before it installs anything, it checks every pinned model and reasoning effort against `codex debug models`, and it stops with the installed setup unchanged if a model is missing, retired, or lacks that effort. The native plugin manifest supplies the skill and command; this updater supplies the separate agent TOMLs and profile files. It expects `codex` and `git` on `PATH` for an interactive install. For a scheduler, set `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME` to absolute paths; use an absolute path to the updater script as well.

`codex/profiles.toml` is the repository reference for those V2 profile files, not a file to copy verbatim into `$CODEX_HOME/config.toml`. Current Codex loads a selected profile from `$CODEX_HOME/<profile>.config.toml`; the updater extracts each `[profiles.<name>]` table into that format. The `compute-squad` profile is the one selected by the quick-start command and controls the top-level session. Native named agents use the `model` and `model_reasoning_effort` fields in their own TOMLs; the other three profiles are for manual or fallback launches. Each agent TOML also pins its worker model's `model_reasoning_effort` to `max`.

Codex injects `AGENTS.md` into a session by itself, and no squad stage reads project instruction files. If your project keeps its rules only in `CLAUDE.md`, add `project_doc_fallback_filenames = ["CLAUDE.md"]` to `$CODEX_HOME/config.toml`. Codex loads one instruction file per directory, so a directory that has both files contributes only `AGENTS.md`.

After installing or updating the plugin, start a new Codex session before running:

```bash
codex --profile compute-squad "Run the squad: <goal>"
# For a non-interactive or scheduled run:
codex exec --profile compute-squad "Run the squad: <goal>"
```

The first form opens an interactive session; `codex exec` is the non-interactive form. The top rung runs strategy, the PM, and COMPLEX execution; the mid rung runs Recon and standard execution; the bottom rung runs MECHANICAL and intern work. The generated table under How to run it names each rung's model and effort.

## Updating an installed setup

Current Codex has no `codex plugin update` command. The top-level `codex update` updates the CLI itself, not this plugin. Run the checked-in updater instead:

```bash
CODEX_BIN="$(command -v codex)" GIT_BIN="$(command -v git)" \
  bash "$HOME/src/compute-squad/codex/update.sh"
```

The updater refreshes the local clone with `git pull --ff-only` first, then checks every pinned model against `codex debug models` and stops with `$CODEX_HOME` unchanged if the check fails, then runs `codex plugin marketplace upgrade compute-squad`, then `codex plugin add compute-squad@compute-squad`, then copies the agent definitions and profile values. There is no separate `codex plugin update` command. For launchd, cron, or Task Scheduler, invoke `/bin/bash` with absolute paths to the updater, `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME`; schedulers do not reliably inherit an interactive shell's `PATH`. If `CODEX_BIN` is a runtime shim, include its interpreter's directory in that `PATH`. The model check runs `python3` from that `PATH`; without it, the updater checks model names only and warns that reasoning efforts were not validated. On macOS, put these values in the LaunchAgent's `EnvironmentVariables` dictionary, use a per-user LaunchAgent, and do not place shell assignments or `$HOME` in launchd's `ProgramArguments`. Use the scheduler's native stdout/stderr log settings. The updater does not create a schedule itself.

## Bottom-rung subagent fallback

`squad-mech` and `squad-executor-mechanical` run on the bottom-rung Codex model
by default (see the generated table under How to run it). Some Multi-Agent V2
setups have been reported to reject that model family as a delegation target;
this repo has not verified that against official Codex docs, so the shipped
TOMLs and profiles keep the bottom rung as the default, and `scripts/verify.sh`
holds them to `models.conf`.

If a `squad-mech` or `squad-executor-mechanical` spawn fails specifically because
the target model is rejected as a subagent, apply one of these manually for
that run only — do not hand-edit the shipped TOMLs or profiles to work around
an unverified, possibly session-specific restriction:

- Launch that one session with `multi_agent_version = "v1"` in its profile, or
  use your Codex client's "delegate new thread" phrasing if it documents one.
- Or run the affected stage through the manual fallback below
  (`01-archive.md` or `04-execute.md`) on the mid-rung model instead of the
  bottom-rung one, for that stage only.

## Manual fallback

If the Codex version does not support the native plugin manifest, run the manually sequenced sessions below. Each stage reads and appends to the same `COMPUTE_SQUAD_LOG.md` in the repo root.

## How to run it

**Stage 0 — Strategy (you, before any session).** Interrogate your own goal: what does done look
like, what's out of scope, what could this break. Write down the goal (one sentence), concrete
acceptance criteria, what's out of scope, and any assumptions (only if you're running unattended;
otherwise "none"). You own these; no session may redefine them.

Then run the sessions in order:

<!-- routing:begin -->
| Order | Prompt file | Stage | Model (rung) |
|---|---|---|---|
| 1 | `01-archive.md` | Archive the prior log | `gpt-5.6-luna` max (bottom) |
| 2 | `02-recon.md` | Read-only codebase mapping | `gpt-5.6-terra` max (mid) |
| 3 | `03-pm-plan.md` | Spec + task breakdown, no code | `gpt-5.6-sol` max (top) |
| 4 | `04-execute.md` | Implementation, exactly per plan | STANDARD `gpt-5.6-terra` max (mid); MECHANICAL `gpt-5.6-luna` max (bottom); COMPLEX `gpt-5.6-sol` max (top) |
| 5 | `05-pm-accept.md` | Adversarial acceptance, PASS/FAIL | `gpt-5.6-sol` max (top) |
<!-- routing:end -->

The fallback has one execute prompt file, not three; you pick the model per run. The native plugin's
generated TOMLs preserve the three routing variants (`squad-executor-mechanical`, `squad-executor`, and
`squad-executor-complex`) with fixed Codex model IDs.

After session 1 (`01-archive.md`) reports an archive path or an already-empty log (not
`ARCHIVE FAILED` or `ARCHIVE REFUSED`), append the `## Goal — Locked` entry yourself as its first entry, then the first
`## Status` (template under **Modes and grants** below), before pasting `02-recon.md`:

```markdown
## Goal — Locked
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Run: <UTC date and a slug: lowercase letters, digits, hyphens>
Attended: <yes|no>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

Sessions 2 through 5 read the goal and acceptance criteria from that entry — nothing to fill in on
their end.

**Modes and grants.** A `plan` run is sessions 1 to 3 only. You write the `## Status` and `## Decision` entries yourself: a `## Status` right after the Goal entry, and another after every stage entry and decision (after a re-lock decision, only once its new Goal entry follows it). Paste `04-execute.md` only when the latest `## Status` grants the plan revision and work order you are about to execute.

```markdown
## Status
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Run: <run ID from the Goal entry>
Mode: <full | plan | execute | accept>
Worktree: <repo root path and branch>
Base: <commit SHA the governing plan was mapped against>
Plan: <none | r<N>, work order <ID or all>>
Grant: <none | r<N> <work order or all>, per Decision <timestamp> | all revisions, full-mode request>
Next: <the one permitted next action, or none when the run is closed>
Stop: <where this invocation ends>
```

```markdown
## Decision
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Type: <grant | plan-approved | waiver | re-lock | park | abandon>
Covers: <plan revision and work order, or criterion ID>
User's words: "<verbatim>"
```

**On FAIL:** re-run the named stage's session (and every stage after it) with the log intact. Each FAIL
or `rerun:` blocker counts against the stage it names, and that stage's next session runs one model
rung up (bottom to mid, mid to top); a stage already on the top rung re-runs there. Each re-run is a
new, complete entry, never `(cont.)`. Three total FAILs stop the run and hand the full log history
back to you, a separate rule from Stage 0's, which is that any change to the locked goal itself
returns there. Record that change as a `## Decision` entry of
Type re-lock followed by a new full `## Goal — Locked` entry with a `Supersedes:` line; sessions 2
through 5 read the latest one.

**On PASS:** the accept session archives the log, verifies the copy, then clears the active log —
unless it flagged the change high-stakes, in which case it leaves the log intact for your own review.
Once that review is done, close the run with the archive command in the Hard rules of
[`skills/compute-squad/SKILL.md`](../skills/compute-squad/SKILL.md), which archives the log again and
clears it only after `cmp` succeeds. While the plan has a work order after the one accepted, the
accept session archives and clears nothing, and the next work order waits for your grant.

**Resuming, or taking over a run from the other host:** before pasting the next prompt, follow [`skills/compute-squad/references/resume.md`](../skills/compute-squad/references/resume.md), which maps the log's latest state to the next session to run. When you hand a work order to Claude Code or back to Codex, append the `## Status` handoff entry yourself (template in [`SKILL.md`](../skills/compute-squad/SKILL.md)) before closing the session.

Each prompt file is generated from the matching agent definition in `agents/` by
`codex/build-agents.py`, so it carries the native path's delegation, continuation, and blocker
rules; never hand-edit it. Since you paste each stage by hand, you run any `DELEGATE:` subtask,
append its results, and paste the next stage's prompt, in place of the orchestrating session. You,
not any session, own the goal and acceptance criteria.
