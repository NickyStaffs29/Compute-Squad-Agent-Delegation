# Compute Squad for Codex

The repository ships a native Codex plugin plus five prompt files for older Codex versions. The native path loads the shared `skills/compute-squad/SKILL.md` orchestration skill and uses the same seven named agents as the Claude package; both implementations coordinate through `COMPUTE_SQUAD_LOG.md`.

The native path requires Codex CLI with V2 profile support (the repository documents 0.134+), Git, and Bash. It supports macOS/Linux and WSL/Git Bash on Windows; the updater is not a native PowerShell script.

## Native Codex install

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

The update script pulls the clone, refreshes the configured marketplace, installs the plugin, copies all seven agents, and writes the four current Codex V2 profile files. It expects `codex` and `git` on `PATH` for an interactive install. For a scheduler, set `CODEX_BIN` and `GIT_BIN` to absolute paths; `CODEX_HOME` can override the default `~/.codex` directory.

The plugin install and the agent/profile installation are separate steps: `codex plugin add` installs the plugin skill, while the updater copies `codex/agents/*.toml` and converts the repository profile manifest into native profile files.

`codex/profiles.toml` is the repository source manifest for those V2 profile files; Codex consumes the four generated `$CODEX_HOME/<profile>.config.toml` files. The main profile controls the top-level session; each agent TOML also pins its worker model's `model_reasoning_effort` to `max`.

After installing or updating the plugin, start a new Codex session before running:

```bash
codex --profile compute-squad "Run the squad: <goal>"
```

This starts an interactive Codex session with the prompt supplied. For a non-interactive run, use:

```bash
codex exec --profile compute-squad "Run the squad: <goal>"
```

The routing is Sol (`gpt-5.6-sol`) for strategy, PM, and COMPLEX execution; Terra (`gpt-5.6-terra`) for Recon and standard execution; and Luna (`gpt-5.6-luna`) for MECHANICAL and intern work. Worker profiles use `max` reasoning.

## Updating an installed setup

Current Codex has no `codex plugin update` command. Run the checked-in updater instead:

```bash
CODEX_BIN="$(command -v codex)" GIT_BIN="$(command -v git)" \
  bash "$HOME/src/compute-squad/codex/update.sh"
```

The updater uses `codex plugin marketplace upgrade compute-squad`, then `codex plugin add compute-squad@compute-squad`, pulls the agent definitions and profile values, and refreshes the local clone with `git pull --ff-only`. For an interactive update, the command above is sufficient.

For a scheduler, use one continued command with absolute paths and an explicit log path:

```bash
CODEX_HOME="/absolute/path/to/.codex" \
CODEX_BIN="/absolute/path/to/codex" \
GIT_BIN="/absolute/path/to/git" \
/bin/bash "/absolute/path/to/compute-squad/codex/update.sh" \
  >> "/absolute/path/to/compute-squad-update.log" 2>&1
```

Do not rely on an interactive shell's `$HOME` or `PATH`. The Bash updater supports macOS/Linux and WSL/Git Bash on Windows; native Windows PowerShell is not supported. OS jobs need network access and write access to the clone and `CODEX_HOME`. Codex CLI cannot create or manage native Codex Scheduled tasks; those are created from the ChatGPT desktop/web Scheduled tasks interface. The updater does not create an OS schedule itself.

## Manual fallback

If the Codex version does not support the native plugin manifest, run the manually sequenced sessions below. Each stage reads and appends to the same `COMPUTE_SQUAD_LOG.md` in the repo root.

## How to run it

**Stage 0 — Strategy (you, before any session).** Interrogate your own goal: what does done look like, what's out of scope, what could this break. Write down the goal (one sentence), concrete acceptance criteria, what's out of scope, and any assumptions (only if you're running unattended; otherwise "none"). You own these; no session may redefine them.

Then run the sessions in order:

| Order | Prompt file | Stage | Suggested model |
|---|---|---|---|
| 1 | `01-archive.md` | Archive the prior log | `gpt-5.6-luna` max |
| 2 | `02-recon.md` | Read-only codebase mapping | `gpt-5.6-terra` max |
| 3 | `03-pm-plan.md` | Spec + task breakdown, no code | `gpt-5.6-sol` max |
| 4 | `04-execute.md` | Implementation, exactly per plan | Terra max; Luna max for MECHANICAL, Sol max for COMPLEX |
| 5 | `05-pm-accept.md` | Adversarial acceptance, PASS/FAIL | `gpt-5.6-sol` max |

The fallback has one execute prompt file, not three; you pick the model per run. The native plugin's generated TOMLs preserve the three routing variants (`squad-executor-haiku`, `squad-executor`, and `squad-executor-opus`) with fixed Codex model IDs.

After session 1 (`01-archive.md`) reports the fresh log is ready, append the `## Goal — Locked` entry yourself as its first entry, before pasting `02-recon.md`:

```markdown
## Goal — Locked
<timestamp line>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

Sessions 2 through 5 read the goal and acceptance criteria from that entry — nothing to fill in on their end.

**On FAIL:** the acceptance session names exactly one stage to re-run. Re-run that stage's session (and every stage after it) with the log intact. Same stage fails twice: use a stronger model for the third attempt. Three total FAILs: stop and rethink the goal.

**On PASS:** the acceptance session appends its PASS entry, archives the full log, and clears the active log. If it flagged the change high-stakes, it leaves the log intact for your own review, and you clear it once that review is done.

## The DELEGATE protocol in Codex

Stages may end their log entry with a `DELEGATE:` block listing zero-judgment subtasks. In Codex, you are the switchboard: run each delegated subtask in a cheap-model session (paste the exact procedure from the block), append results to the log under `## Delegated — <stage>`, then re-run the requesting stage if it marked the request `BLOCKING`. A re-run stage appends a `## <Stage> (cont.)` entry covering only the remainder. Delegation flows downward only and is capped at 5 helper sessions per stage per run; past that, the stage's scoping is the problem, and it should say so in its entry instead.

## Rules that keep it honest

- Every stage appends to `COMPUTE_SQUAD_LOG.md`; no stage rewrites history; the log is cleared only after a PASS, by the acceptance session or by you on a high-stakes change.
- Archive a non-empty log to `compute-squad-archive/` in the repo root before every new run, and again on PASS. Never discard a prior or failed run.
- No stage skips, even for one-line changes. The entries can be short; the discipline can't.
- A blocker is a `BLOCKER:` block at the end of a stage's own entry (`rerun: <Recon|Plan|Executor>` or `needs-human: <the decision required>`, plus `why:`) — never freeform prose. `rerun:` re-runs that stage and everything after it and counts toward the three-FAIL stop; `needs-human:` comes back to you at Stage 0.
- The executor never accepts its own work. You, not any session, own the goal and acceptance criteria.
