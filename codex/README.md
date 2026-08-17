# Compute Squad for Codex

The repository ships a native Codex plugin plus five prompt files for older Codex versions. The native path loads the shared `skills/compute-squad/SKILL.md` orchestration skill and uses the same seven named agents as the Claude package; both implementations coordinate through `COMPUTE_SQUAD_LOG.md`.

## Native Codex install

Requires Codex CLI 0.134 or newer, a working `git`, `/bin/bash`, and access to `gpt-5.6-sol`,
`gpt-5.6-terra`, and `gpt-5.6-luna` on your Codex account — Model routing in
[`codex/SKILL.md`](SKILL.md) hard-codes all three with no fallback tier.

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

The update script pulls the clone, refreshes the configured marketplace, installs the plugin, copies all seven agents, removes any retired agent TOMLs the repo no longer ships, and writes the four current Codex V2 profile files. The native plugin manifest supplies the skill and command; this updater supplies the separate agent TOMLs and profile files. It expects `codex` and `git` on `PATH` for an interactive install. For a scheduler, set `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME` to absolute paths; use an absolute path to the updater script as well.

`codex/profiles.toml` is the repository reference for those V2 profile files, not a file to copy verbatim into `$CODEX_HOME/config.toml`. Current Codex loads a selected profile from `$CODEX_HOME/<profile>.config.toml`; the updater extracts each `[profiles.<name>]` table into that format. The `compute-squad` profile is the one selected by the quick-start command and controls the top-level session. Native named agents use the `model` and `model_reasoning_effort` fields in their own TOMLs; the other three profiles are for manual or fallback launches. Each agent TOML also pins its worker model's `model_reasoning_effort` to `max`.

After installing or updating the plugin, start a new Codex session before running:

```bash
codex --profile compute-squad "Run the squad: <goal>"
# For a non-interactive or scheduled run:
codex exec --profile compute-squad "Run the squad: <goal>"
```

The first form opens an interactive session; `codex exec` is the non-interactive form. The routing is Sol (`gpt-5.6-sol`) for strategy, PM, and COMPLEX execution; Terra (`gpt-5.6-terra`) for Recon and standard execution; and Luna (`gpt-5.6-luna`) for MECHANICAL and intern work. Worker profiles use `max` reasoning.

## Updating an installed setup

Current Codex has no `codex plugin update` command. The top-level `codex update` updates the CLI itself, not this plugin. Run the checked-in updater instead:

```bash
CODEX_BIN="$(command -v codex)" GIT_BIN="$(command -v git)" \
  bash "$HOME/src/compute-squad/codex/update.sh"
```

The updater refreshes the local clone with `git pull --ff-only` first, then runs `codex plugin marketplace upgrade compute-squad`, then `codex plugin add compute-squad@compute-squad`, then copies the agent definitions and profile values. There is no separate `codex plugin update` command. For launchd, cron, or Task Scheduler, invoke `/bin/bash` with absolute paths to the updater, `CODEX_BIN`, `GIT_BIN`, and `CODEX_HOME`; schedulers do not reliably inherit an interactive shell's `PATH`. If `CODEX_BIN` is a runtime shim, include its interpreter's directory in that `PATH`. On macOS, put these values in the LaunchAgent's `EnvironmentVariables` dictionary, use a per-user LaunchAgent, and do not place shell assignments or `$HOME` in launchd's `ProgramArguments`. Use the scheduler's native stdout/stderr log settings. The updater does not create a schedule itself.

## Luna subagent fallback

`gpt-5.6-luna` is documented as a valid Codex subagent model, and `squad-mech`
and `squad-executor-haiku` are routed to it by default (see Model routing in
`codex/SKILL.md`). Some Multi-Agent V2 setups have been reported to reject
Luna as a delegation target; this repo has not verified that against official
Codex docs, so the shipped TOMLs and profiles keep `gpt-5.6-luna` as the
default and `scripts/verify.sh` asserts it.

If a `squad-mech` or `squad-executor-haiku` spawn fails specifically because
the target model is rejected as a subagent, apply one of these manually for
that run only — do not hand-edit the shipped TOMLs or profiles to work around
an unverified, possibly session-specific restriction:

- Launch that one session with `multi_agent_version = "v1"` in its profile, or
  use your Codex client's "delegate new thread" phrasing if it documents one.
- Or run the affected stage through the manual fallback below
  (`01-archive.md` or `04-execute.md`) at `gpt-5.6-terra` instead of
  `gpt-5.6-luna` for that stage only.

## Manual fallback

If the Codex version does not support the native plugin manifest, run the manually sequenced sessions below. Each stage reads and appends to the same `COMPUTE_SQUAD_LOG.md` in the repo root.

## How to run it

**Stage 0 — Strategy (you, before any session).** Interrogate your own goal: what does done look
like, what's out of scope, what could this break. Write down the goal (one sentence), concrete
acceptance criteria, what's out of scope, and any assumptions (only if you're running unattended;
otherwise "none"). You own these; no session may redefine them.

Then run the sessions in order:

| Order | Prompt file | Stage | Suggested model |
|---|---|---|---|
| 1 | `01-archive.md` | Archive the prior log | `gpt-5.6-luna` max |
| 2 | `02-recon.md` | Read-only codebase mapping | `gpt-5.6-terra` max |
| 3 | `03-pm-plan.md` | Spec + task breakdown, no code | `gpt-5.6-sol` max |
| 4 | `04-execute.md` | Implementation, exactly per plan | Terra max; Luna max for MECHANICAL, Sol max for COMPLEX |
| 5 | `05-pm-accept.md` | Adversarial acceptance, PASS/FAIL | `gpt-5.6-sol` max |

The fallback has one execute prompt file, not three; you pick the model per run. The native plugin's
generated TOMLs preserve the three routing variants (`squad-executor-haiku`, `squad-executor`, and
`squad-executor-opus`) with fixed Codex model IDs.

After session 1 (`01-archive.md`) reports the fresh log is ready, append the `## Goal — Locked`
entry yourself as its first entry, before pasting `02-recon.md`:

```markdown
## Goal — Locked
<timestamp line>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

Sessions 2 through 5 read the goal and acceptance criteria from that entry — nothing to fill in on
their end.

**On FAIL:** re-run the named stage's session (and every stage after it) with the log intact; the
same stage failing twice escalates to a stronger model for the third attempt. Three total FAILs stop
the run and hand the full log history back to you — a separate rule from Stage 0's, which is that
any change to the locked goal itself returns there.

**On PASS:** the accept session archives the log, verifies the copy, then clears the active log —
unless it flagged the change high-stakes, in which case it leaves the log intact for your own review
and you clear it once that review is done.

Delegation and the full blocker grammar work exactly as in the native plugin path; see "Intra-stage
delegation" and "Log and escalation rules" in [`codex/SKILL.md`](SKILL.md) for the complete rules.
The one difference here: since you are pasting each stage by hand, you are the one who runs any
`DELEGATE:` subtask and pastes the next stage's prompt, in place of the orchestrating session. You,
not any session, own the goal and acceptance criteria.
