# Compute Squad for Codex

The repository ships a native Codex plugin plus five prompt files for older Codex versions. The native path loads the shared `skills/compute-squad/SKILL.md` orchestration skill and uses the same seven named agents as the Claude package; both implementations coordinate through `COMPUTE_SQUAD_LOG.md`.

## Native Codex install

Requires Codex CLI 0.144 or newer, a working `git`, `python3`, `/bin/bash`, and a logged-in Codex
CLI. Each tier (top, mid, bottom) runs one model with no fallback: the one you choose from your
account's catalog. A stage whose model your account cannot use stops the run and reports the setup
gap. Install from a clean checkout, in a terminal:

```bash
mkdir -p "$HOME/src"
git clone https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation "$HOME/src/compute-squad"
bash "$HOME/src/compute-squad/codex/update.sh"
```

On its first run the updater reads `codex debug models` and lists every model your account's catalog lists, with the efforts each supports and whether the catalog marks it superseded or retiring. A listing is availability, not a recommendation. It then asks for the top, mid, and bottom tier's model and reasoning effort, then the main session's effort. Enter keeps the value shown: your saved choice, or on first setup the release default from the generated table under How to run it. It rejects a model the catalog hides or has retired, an effort the model lacks, and a model another tier already holds, and asks again. It prints every role's resulting model and effort, and the four profiles, with the changes, and saves only when you type `yes`; anything else, end of input, or Ctrl-C cancels with nothing changed. Nothing picks, ranks, or substitutes a model for you. Your choices are saved in `$CODEX_HOME/compute-squad/choices.conf`, outside the checkout, with a fingerprint of the catalog they were made against. `models.conf` stays the release default and the checkout is never written. Rerun the questions any time with `bash "$HOME/src/compute-squad/codex/update.sh" --review-models`.

The updater then renders one build into `$CODEX_HOME/compute-squad/build`: this checkout's plugin (`.codex-plugin/` and `skills/`, with the skill's routing block naming your models), the seven agent TOMLs, and the four Codex V2 profile files, all from one render. It installs the plugin from that directory as the local marketplace `compute-squad-local` (`codex plugin marketplace add`, then `codex plugin add compute-squad@compute-squad-local`), copies the agents and profiles from the same build, removes any retired agent TOMLs the repo no longer ships, and, if an earlier release installed `compute-squad@compute-squad` from the GitHub marketplace, removes that copy so only one skill loads (your marketplace entry stays). Any other installed and enabled copy, such as `compute-squad@personal`, stops the update before it changes anything, with the `codex plugin remove` command for it; the updater never removes a copy you installed yourself. Before it installs anything it checks your models and efforts against the catalog, and it stops with the installed setup unchanged if a model is missing, retired, or lacks that effort. It also stops if the checkout has uncommitted changes to tracked files, because the plugin installs from it, and if another update holds `$CODEX_HOME/compute-squad/update.lock`. It expects `codex`, `git`, and `python3` on `PATH` for an interactive install. For a scheduler, set `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME` to absolute paths, put `python3` on the scheduler's `PATH`, and use an absolute path to the updater script as well.

`codex/profiles.toml` is the repository reference for those V2 profile files with the release default models, not a file to copy verbatim into `$CODEX_HOME/config.toml`. Current Codex loads a selected profile from `$CODEX_HOME/<profile>.config.toml`; the updater writes each one from your choices in that format. The `compute-squad` profile is the one selected by the quick-start command and controls the top-level session. Native named agents use the `model` and `model_reasoning_effort` fields in their own TOMLs; the other three profiles are for manual or fallback launches. Each installed agent TOML pins its tier's model and `model_reasoning_effort`; the release defaults pin `max`.

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

The updater refreshes the local clone with `git pull --ff-only` first and stops if the checkout has uncommitted changes. It then reads `codex debug models`. With no saved choices it asks for them on a terminal; with no terminal, as under a scheduler, it exits 3 with `setup gap: no Codex model choices saved` and the `--review-models` command, and installs nothing. It never falls back to the release defaults on its own. With saved choices, when the catalog has changed since you chose, it asks on a terminal whether to review them and warns under a scheduler, keeping them either way. It then checks your models against the catalog and stops with `$CODEX_HOME` unchanged if one is retired, missing, or lacks its effort, naming it. Last it renders the build and installs the plugin, agents, and profiles from it, and prints each tier's model. Nothing switches a model mid-run: a running session keeps the skill and agents it loaded, and a run resumed in a new session uses the new models from its next stage. There is no separate `codex plugin update` command. For launchd, cron, or Task Scheduler, invoke `/bin/bash` with absolute paths to the updater, `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME`; schedulers do not reliably inherit an interactive shell's `PATH`. If `CODEX_BIN` is a runtime shim, include its interpreter's directory in that `PATH`, along with `python3`'s. On macOS, put these values in the LaunchAgent's `EnvironmentVariables` dictionary, use a per-user LaunchAgent, and do not place shell assignments or `$HOME` in launchd's `ProgramArguments`. Use the scheduler's native stdout/stderr log settings. The updater does not create a schedule itself.

The first update from a 4.5.0 install still runs that release's updater, because `bash` keeps reading the script `git pull` replaced: it installs `compute-squad@compute-squad` from the GitHub marketplace with the release models, as before. The next run uses the flow above. Run it once in a terminal (`--review-models` works too) so a scheduled run finds your choices.

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
| 2 | `02-recon.md` | Codebase mapping and baseline check | `gpt-5.6-terra` max (mid) |
| 3 | `03-pm-plan.md` | Spec + task breakdown, no code | `gpt-5.6-sol` max (top) |
| 4 | `04-execute.md` | Implementation, exactly per plan | STANDARD `gpt-5.6-terra` max (mid); MECHANICAL `gpt-5.6-luna` max (bottom); COMPLEX `gpt-5.6-sol` max (top) |
| 5 | `05-pm-accept.md` | Adversarial acceptance, PASS/FAIL | `gpt-5.6-sol` max (top) |
<!-- routing:end -->

The table shows the release defaults; if you saved model choices with the updater, use your models
instead (`$CODEX_HOME/compute-squad/choices.conf` lists them by tier). The fallback has one execute
prompt file, not three; you pick the model per run. The native plugin's
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
Audit: <yes|no>
Goal: <one sentence>
Acceptance criteria:
- AC1: <concrete, verifiable item>
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
Type: <grant | plan-approved | waiver | resolution | re-lock | park | abandon>
Covers: <plan revision and work order, criterion ID, or pending heading and Timestamp>
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

**On PASS:** on an ordinary change the accept session archives the log, verifies the copy, and
clears the active log. On a high-stakes change it archives and clears nothing: run the high-stakes
review procedure in Stage 5 of `skills/compute-squad/SKILL.md` yourself and append its entry, then a `## Status`:

```markdown
## High-stakes review
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Agent: main session (<model ID as your context states it>)
Result: <upheld | overturned | held>
Rerun: <Recon|Plan|Executor>
Tested: <commit SHA>, working tree <clean | N changed files>
Checked:
- `<command>` -> exit <code>; <summary line>
Risks:
- <risk> | <diff line or check line; or open>
Decisions after lock:
- <none, or: decision | approving `## Decision` timestamp, or unapproved>
```

On `Result: upheld`, paste `01-archive.md` followed by "Close the run after an upheld high-stakes
review." On `overturned`, treat the entry as a FAIL naming the stage on its `Rerun:` line. On
`held`, leave the log intact until you have settled the open items. While the plan has a work order
after the one accepted, the accept session archives and clears nothing, and the next work order
waits for your grant; in a high-stakes run it also waits for an upheld review, and the closing
archive waits for an upheld review of the last work order's PASS.

**Resuming, or taking over a run from the other host:** before pasting the next prompt, follow [`skills/compute-squad/references/resume.md`](../skills/compute-squad/references/resume.md), which maps the log's latest state to the next session to run. When you hand a work order to Claude Code or back to Codex, append the `## Status` handoff entry yourself (template in [`SKILL.md`](../skills/compute-squad/SKILL.md)) before closing the session.

Each prompt file is generated from the matching agent definition in `agents/` by
`codex/build-agents.py`, so it carries the native path's delegation, continuation, and blocker
rules; never hand-edit it. Since you paste each stage by hand, you run any `DELEGATE:` subtask,
append its results, and paste the next stage's prompt, in place of the orchestrating session. You,
not any session, own the goal and acceptance criteria.
