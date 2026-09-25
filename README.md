# Compute Squad

A staged agent delegation pipeline for Claude Code and Codex: your top-tier session runs strategy, the strongest tier plans and adversarially accepts the work, execution routes to a MECHANICAL, STANDARD, or COMPLEX model tier, and the cheapest tier handles zero-judgment busywork — all through a shared, auditable log.

Three steps to a working setup: **install**, **run**, **auto-update**. Each step shows Claude Code first, Codex right after — use whichever matches your setup. Everything else on this page is reference.

## 1. Install

**Claude Code.** Requires access to every model the routing table below names; the PM runs on the top rung with no fallback, and a stage whose model is unavailable stops the run. Paste these two lines in your terminal:

```bash
claude plugin marketplace add NickyStaffs29/Compute-Squad-Agent-Delegation
claude plugin install compute-squad@compute-squad
```

Or from inside a Claude Code session:

```
/plugin marketplace add NickyStaffs29/Compute-Squad-Agent-Delegation
/plugin install compute-squad@compute-squad
```

That's everything: all seven squad agents, the orchestration skill, and the `/squad` command install together. The first run in a project asks you once to trust the plugin's agents and skill. Answer it and it does not come back.

**Codex.** Prerequisites: Codex CLI 0.144 or newer, a working `git`, `python3`, `/bin/bash`, and a logged-in Codex CLI. Install from a clean checkout, in a terminal:

```bash
mkdir -p "$HOME/src"
git clone https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation "$HOME/src/compute-squad"
bash "$HOME/src/compute-squad/codex/update.sh"
```

On its first run the updater shows the models your account's catalog (`codex debug models`) lists, then asks which model and reasoning effort fills each tier (top, mid, bottom) and which effort the main session uses. Enter keeps the value shown, which on first setup is the release default from the routing table below. It saves nothing until you type `yes`, and it rejects a model the catalog hides or retires, an effort the model lacks, and one model on two tiers. Your choices live in `$CODEX_HOME/compute-squad/choices.conf`, outside the checkout, so no update overwrites them. The updater then renders one build of this checkout with your models, installs the plugin from it (`compute-squad@compute-squad-local`), and copies the seven agents and four profiles from the same build. Change the models later with `bash "$HOME/src/compute-squad/codex/update.sh" --review-models`.

If `$HOME/src/compute-squad` already exists, do not run `git clone` into it again. Use a clean checkout of this repository on `main`, or choose another empty directory; the updater fast-forwards whichever branch is currently checked out and stops if the checkout has uncommitted changes, because the plugin installs from it.

If an earlier release installed `compute-squad@compute-squad` from the GitHub marketplace, the updater removes that copy after installing the local build, so only one copy of the skill loads. Any other installed copy, such as one from a personal marketplace, stops the update before it changes anything and prints the `codex plugin remove` command for it. Start a new Codex session after installation so the plugin skill is loaded. Full Codex setup, routing table, update command, and a manual-prompt fallback for older Codex versions are in [`codex/README.md`](codex/README.md).

## 2. Run it

**Claude Code:**

```
/squad add rate limiting to the password-reset endpoint
```

Or say any of: `run the squad: <goal>`, `run compute squad`, `compute squad this`, `full pipeline on this`.

Modes: `/squad plan <goal>` stops after the plan with no product edits. `/squad execute WO-1` runs one work order of the plan in the log, records your command as its grant, and accepts it. `/squad accept` reviews an implementation made elsewhere against that plan. Plain `/squad <goal>` runs the full pipeline, and the request itself is the execution grant.

**Codex:**

```bash
codex --profile compute-squad "Run the squad: add rate limiting to the password-reset endpoint"
# For a non-interactive or scheduled run:
codex exec --profile compute-squad "Run the squad: add rate limiting to the password-reset endpoint"
```

The first form opens an interactive session; `codex exec` is the non-interactive form. Either way, run it from your project root, in a session that can read and write the repo.

An unattended run (`codex exec`, or a headless or scheduled Claude run) stops at the first decision that needs you, leaves the log intact, and reports the stage to resume from.

## 3. Get updates automatically

**Claude Code** — auto-update is built in; you just flip it on once. Run `/plugin`, open the **Marketplaces** tab, select **compute-squad**, and choose **Enable auto-update**. Claude Code then refreshes the marketplace and updates the plugin in the background — nothing else to set up.

**Codex** — create this as a weekly Scheduled task/automation in the Codex desktop app. Codex CLI can run the updater, but it does not create recurring schedules. Open the Compute Squad checkout as the local project, then paste this into a Codex session:

```
Create a weekly Scheduled task for the Compute Squad project.

On each run:
1. From the repository root, verify this is a clean checkout of
   `NickyStaffs29/Compute-Squad-Agent-Delegation` on `main`. If it is not,
   stop and report the problem.
2. Run `/bin/bash codex/update.sh`.
3. Report whether the update succeeded and include any command failure.

Use the Codex Scheduled task/automation feature. Do not create a macOS
LaunchAgent, cron job, Windows Task Scheduler entry, or any other OS-level
scheduled task. For local-project runs, keep the computer on and the Codex
desktop app available.
```

Run the updater once in a terminal first, so your model choices are saved: a scheduled run cannot ask, so with no saved choices it exits 3 and reports the setup gap instead of installing release defaults. After that, each run does `git pull --ff-only`, then checks your saved models against `codex debug models` and stops with nothing installed if one is retired, missing, or lacks its effort, then renders the build and installs the plugin, agents, and Codex V2 profile files from it. When the catalog has changed since you chose, a scheduled run warns and keeps your choices; a run in a terminal asks whether to review them. Nothing changes a model mid-run: a running session keeps the skill and agents it loaded, and a run resumed in a new session uses the new models from its next stage. There is no `codex plugin update` command; the top-level `codex update` updates the CLI itself, not this plugin. Start a new Codex session after a plugin update.

Prefer manual updates? In Claude Code, run these whenever you like (marketplace first — it refreshes the source, then the plugin update pulls the new version):

```
/plugin marketplace update compute-squad
/plugin update compute-squad
```

In Codex, for a one-off update, rerun the updater command from
[`codex/README.md`](codex/README.md); do not recreate the scheduler just to
refresh the plugin.

To remove from Claude Code: `/plugin uninstall compute-squad@compute-squad`. Uninstalling removes the agents and the skill but leaves `COMPUTE_SQUAD_LOG.md` and `compute-squad-archive/` in your project untouched.

<details>
<summary><strong>Other install targets: teams, Claude Cowork</strong></summary>

**Team rollout.** Add this to your project's `.claude/settings.json` and the plugin auto-installs for everyone who trusts the repo:

```json
{
  "extraKnownMarketplaces": {
    "compute-squad": {
      "source": { "source": "github", "repo": "NickyStaffs29/Compute-Squad-Agent-Delegation" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "compute-squad@compute-squad": true }
}
```

**Claude Cowork.** Claude Cowork is Anthropic's drop-a-file chat installer. Download [`dist/compute-squad.plugin`](https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation/raw/main/dist/compute-squad.plugin), drop it into any chat, and accept the install. In Cowork, run the squad from a session with your project folder connected so the agents can read and write the repo and the log.

</details>

Version history is in [CHANGELOG.md](CHANGELOG.md).

---

# Reference

Everything below is background on how the pipeline works. You don't need any of it to install or run the squad.

## Why it exists

Most multi-agent setups have an org chart problem. The strongest model does the typing and the supervision. The cheap models sit idle. Every task gets the same treatment whether it needs judgment or just execution.

What Compute Squad actually sells is verification and auditability that don't depend on operator discipline, plus capacity: a run works in its own agents instead of occupying your session, so you can have several going at once, one per git worktree. It gets there by routing by decision density — stages that decide run strong models, stages that execute against a tight spec run cheap ones, and the review layer is never below the work it checks, and a tier above by default, so mistakes get caught by something stronger than what made them. The ladder is placed where a wrong call is expensive, not where tokens are cheap: the top rung plans and accepts, every stage that exercises judgment runs on the mid rung or above, and the bottom rung takes only transcription-grade and zero-judgment work. What it buys is capacity and review that is independent of the work, not a smaller bill. Prices are not a routing input; one measured run's cost is a dated snapshot in the FAQ.

One skill. Seven agents. A shared log. A role hierarchy that mirrors how a functional team actually operates:

<!-- routing:begin -->
Snapshot of `models.conf`, reviewed 2026-09-24. Routing reads `models.conf`; this table is generated from it.

| Role | Agent | Claude Code | Codex | Owns |
|---|---|---|---|---|
| Strategy | main session | your session model; top recommended | `gpt-5.6-sol` high | Goal, gaps, acceptance criteria, final judgment |
| PM | `squad-pm` | `fable` (top) | `gpt-5.6-sol` max | The plan and the acceptance decision |
| Recon | `squad-recon` | `opus` (mid) | `gpt-5.6-terra` max | Mapping the codebase |
| Execution | `squad-executor` | `opus` (mid) | `gpt-5.6-terra` max | Implementing the plan |
| Execution on MECHANICAL | `squad-executor-mechanical` | `sonnet` (bottom) | `gpt-5.6-luna` max | The same executor protocol, bottom rung |
| Execution on COMPLEX | `squad-executor-complex` | `fable` (top) | `gpt-5.6-sol` max | The same executor protocol, top rung |
| Delegated execution | `squad-helper` | `sonnet` (bottom) | `gpt-5.6-terra` max | Tightly-specced subtasks |
| Intern | `squad-mech` | `sonnet` (bottom) | `gpt-5.6-luna` max | Busywork. Nothing that requires judgment |
<!-- routing:end -->

## How a run works

In a full run, six stages run in order. Nothing skips within a mode, even for a one-line change: the
entries can be short, but the discipline can't.

- **Stage 0 — Strategy**, your session, before any agent spawns: interrogates the goal, clarifies
  gaps with you, locks the goal and acceptance criteria into the log's `## Goal — Locked` entry.
  It reads no product source beyond files you name, and runs no tests; mapping the code is Recon's
  job.
- **Stage 1 — Archive**, `squad-mech`: starts every run from a clean log. Failed runs are never
  discarded. They are evidence.
- **Stage 2 — Recon**, `squad-recon`: maps the codebase and checks the evidence prerequisites.
- **Stage 3 — Plan**, `squad-pm` (PLAN mode): turns the map into a spec and classifies the work.
- **Stage 4 — Execute**, the executor the classification routes to: implements exactly what the plan
  says.
- **Stage 5 — Accept**, `squad-pm` (ACCEPT mode): tries to fail the work, then PASS or FAIL. Say "be
  thorough" and your session first runs an audit fan-out whose findings the PM must rule on.

The full protocol for each stage (grammar, PASS/FAIL/BLOCKER handling, escalation, and the
audit-grade fan-out) is canonical in [`skills/compute-squad/SKILL.md`](skills/compute-squad/SKILL.md),
which Claude Code and the Codex plugin both load. This page is a summary, not a second copy.

A complete worked run with every log entry format is in [`docs/example-log.md`](docs/example-log.md).

## What a run needs and leaves behind

A run creates two things in your project root:

- `COMPUTE_SQUAD_LOG.md`, the active log every stage appends to.
- `compute-squad-archive/`, copies of past runs named by UTC time and run ID. The log is archived before a new run starts and again on PASS, or, on a high-stakes change, after an upheld high-stakes review, and an existing archive is never overwritten, so a failed run is never lost.
  - `compute-squad-archive/usage.jsonl` (Claude Code only): one line each time a stage stops, with its model, elapsed time and tokens, written by a plugin hook and never cleared. A stage continued with SendMessage stops more than once, and its last line is its total.

Both are run state, not source. Add them to your `.gitignore` unless you specifically want run history in version control:

```
COMPUTE_SQUAD_LOG.md
compute-squad-archive/
```

A first run in a project with no log file is normal. Stage 1 creates it empty and the pipeline proceeds.

## The agents

### squad-recon (mid rung, read-only)

The mapper. Given a locked goal, it sweeps the codebase and pins down exactly what the change touches: files, functions, line ranges, call sites, tests, migrations, config, and the invariants that must survive (auth boundaries, privacy rules, logging hygiene). It reads whole subsystems rather than fragments. It changes nothing except its log entry. Its one command beyond inspection is a single baseline run of the test or verify command, whose result opens its entry.

Its standard: the PM should never have to guess. Ambiguity Recon cannot resolve gets named explicitly in its entry, so the plan resolves it on purpose instead of by accident. A goal that cannot be met as written stops as a `needs-human:` blocker.

### squad-pm (top rung, two modes)

The project manager. Plans work, accepts deliverables, never writes product code. One agent, two invocations per run.

**PLAN mode** produces the spec: exact files and functions to change, the change to each, tests to add and what each asserts, what must NOT change, and the verification plan. It starts from Recon's baseline result, reconciles every count the plan states, marks decisions that rest on unverified facts as assumed, and escalates before dropping existing behavior. The bar is an ordered task list a junior engineer could follow without a single judgment call. That bar is the whole system. Cheap execution is only safe because the plan carries the intelligence. PLAN also classifies the work: MECHANICAL, STANDARD, or COMPLEX. MECHANICAL routes execution to `squad-executor-mechanical`, COMPLEX routes it to `squad-executor-complex`, and STANDARD stays on `squad-executor`.

**ACCEPT mode** is adversarial by instruction. It re-derives expectations from the locked criteria before reading the Executor's account, and reads the Executor's account only after its own checks and refutations. It re-runs the full test suite itself. It never trusts logged claims. It attempts refutations: concurrency, empty and duplicate data, permission boundaries. It records a result for every numbered criterion against the exact tree it tested; a criterion that already failed before the change stops for your decision, and only you can waive one. FAIL comes with evidence and exactly one named stage to re-run. On an ordinary change, PASS on the plan's last work order archives the log first, then clears it. On a high-stakes change, PASS archives nothing: your session reviews the tested tree, writes a `## High-stakes review` entry, and only an upheld review sends the log to squad-mech for the verified archive and clear. Nothing clears the log before a PASS. A PASS means the tested tree passed locally, not that it is ready to merge or deploy.

Decisions the PM is not allowed to make: anything product-level, irreversible, or cost-bearing, and anything that would change the locked goal. Those get logged as named blockers and go back to the human. Guessing past a blocker is a protocol violation, not initiative.

### squad-executor, squad-executor-mechanical, and squad-executor-complex

The builder. Reads the full log, then works the task list of the plan revision and work order the latest Status names, in order. Exactly what the plan says. No more, no less.

If the plan is wrong or impossible, it stops and logs a blocker naming Plan as the stage to re-run. It does not improvise a better design, because an executor that improvises invalidates the acceptance review downstream. A judgment call the plan left open is a plan defect and gets reported as one. A check that already fails on the unchanged tree, or fails for a cause outside the plan, stops with a `needs-human:` blocker instead.

It runs the project's own test and verify commands as it goes and will not log completion with failing tests.

`squad-executor-mechanical` and `squad-executor-complex` are the same agent definition on the bottom and top rungs. `squad-executor-mechanical` runs when the PM classifies the work MECHANICAL, transcription-grade by the PM's own classification, so it carries one extra discipline line: any task that turns out to need more than transcribing an explicitly specified change is a blocker naming Plan, not something to push through. `squad-executor-complex` runs when the PM classifies the work COMPLEX, or when an Executor FAIL moves execution to the top rung. Three names instead of one flag, because Codex applies an agent's pinned model over a per-spawn model; in Claude Code the Agent tool's `model` parameter does override frontmatter, which is how Recon escalates.

### squad-helper (the delegated worker)

The execution-tier half of the DELEGATE protocol. When a stage delegates a subtask that is too specified to need judgment but too involved for the intern, `squad-helper` runs the exact procedure and returns the result in its final message. It never writes the log; the orchestrating session does. Handed anything that needs a design decision, it refuses with `REFUSED:` and the step, and the stage that asked for it does that step itself or ends its entry with a blocker.

### squad-mech (bottom rung, the intern)

Zero-judgment busywork, executed exactly. Log archival before every run, and the closing archive after an upheld high-stakes review (verified copy first, truncate second, never the reverse). File rotation. Formatting normalization. Inventories. Fixture generation from an exact template.

Its one skill beyond following procedure is knowing what it is not: handed anything that requires a judgment call, it refuses with `REFUSED:` and the step, which goes back to whoever requested it. An intern that knows its lane is worth more than a mid-level that does not.

## The delegation structure

Four rules generate the whole system: route by decision density, not task difficulty; review from a
tier above the work by default; push busywork too large to do in-stage down a tier through the
`DELEGATE:` protocol, downward only and capped at 5 helpers per stage per run; and escalate on
evidence, never on vibes. A wrong answer that forces an upstream re-run costs more than running the
stage one rung higher, which makes routing up on uncertainty the cheap option. The full rules, the
escalation ladder, and the blocker grammar are canonical in
[`skills/compute-squad/SKILL.md`](skills/compute-squad/SKILL.md), which both hosts load.

Underneath all four sits the log, `COMPUTE_SQUAD_LOG.md` — durable, auditable state is what lets a
FAIL re-run one stage instead of the whole pipeline, and it is why the same protocol runs in Codex
too: the native plugin spawns the same named agents, and the manual fallback sequences the same
stages by hand when the plugin path is unavailable.

## Repo layout

```
Compute-Squad-Agent-Delegation/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest, including the grant-gate and usage-ledger hooks
│   └── marketplace.json      # makes this repo installable in Claude Code
├── .codex-plugin/
│   └── plugin.json           # native Codex plugin manifest
├── .agents/plugins/
│   └── marketplace.json      # makes this repo discoverable in Codex
├── .github/workflows/
│   └── ci.yml                # runs scripts/verify.sh on every push; weekly Codex catalog check
├── skills/compute-squad/
│   ├── SKILL.md              # the orchestration protocol
│   ├── hooks/
│   │   ├── grant-gate.sh     # Claude Code only: refuses an executor spawn without a logged grant, and any recon, PM, helper, or executor spawn while a needs-human blocker is open
│   │   └── usage-ledger.sh   # Claude Code only: appends each stage's model, time, and tokens to compute-squad-archive/usage.jsonl
│   └── references/
│       ├── audit-prompts.md  # audit procedure, finder and skeptic briefs
│       └── resume.md         # next-action table, read only on resume or over a non-empty log
├── agents/
│   ├── squad-recon.md        # mid rung · read-only mapping
│   ├── squad-pm.md           # top rung · PLAN + ACCEPT modes
│   ├── squad-executor.md     # mid rung · implementation
│   ├── squad-executor-mechanical.md # bottom rung · implementation on MECHANICAL
│   ├── squad-executor-complex.md # top rung · implementation on COMPLEX
│   ├── squad-helper.md       # delegated execution-tier subtasks
│   └── squad-mech.md         # bottom rung · the intern
├── commands/
│   └── squad.md              # /squad [plan|execute|accept] <goal>: starts at Stage 0
├── codex/
│   ├── README.md             # Codex install, routing, and manual fallback
│   ├── SKILL.md              # reading copy with Codex model names; no host loads it
│   ├── agents/*.toml         # generated Codex agent definitions
│   ├── build-agents.py       # writes model lines, TOMLs, profiles, routing blocks, 01-05*.md, and the Codex build
│   ├── profiles.toml         # generated Codex V2 profile reference
│   ├── update.sh             # asks for Codex model choices; installs plugin, agents, profiles from one build
│   └── 01-05*.md             # manual-session fallback prompts (generated)
├── docs/example-log.md       # a complete worked run
├── scripts/
│   ├── build-plugin.sh       # rebuilds dist/ from the git-tracked source set
│   └── verify.sh             # the CI gate; run it before every commit
├── tests/                    # check 8 linter and fixtures, and the live scenario harness (not packaged)
├── dist/compute-squad.plugin # drag-and-drop install for Claude Cowork
├── models.conf               # model assignments by rung and role; build-agents.py reads it
├── .gitignore                # excludes COMPUTE_SQUAD_LOG.md and its archive
├── CONTRIBUTING.md           # the sync rule: skill, agents, codex, dist change together
├── CHANGELOG.md              # version history
└── LICENSE                   # MIT
```

`dist/compute-squad.plugin` is committed on purpose: Claude Cowork installs from a single downloadable file, so the package has to exist at a stable URL. It is a zip of `.claude-plugin/plugin.json`, `skills/`, `agents/`, `commands/`, and `README.md`. It is generated, never hand-edited. After changing any of those sources, run `scripts/build-plugin.sh` from the repo root and commit the rebuilt package with your change.

## FAQ

**Why is strategy not an agent?**
Subagents run headless. They cannot ask you anything, and clarifying gaps with the human is the entire point of Stage 0. So strategy lives in the skill and executes in your top-tier main session.

**Do the models auto-upgrade?**
Within a family, on Claude Code: each agent carries the alias `models.conf` assigns, and an alias resolves to its family's newest model; changing that is one edit to `models.conf`, under Changing models in CONTRIBUTING.md. On Codex, never: agents pin exact model IDs, and you choose them per tier with `codex/update.sh --review-models`. An update keeps your choices, warns when your account's catalog changes, and stops before installing a saved model the catalog retires or drops.

**Why is bottom-rung execution safe?**
Only MECHANICAL, transcription-grade work runs there, and the plan carries the intelligence. Acceptance runs on the top rung, never below the work and a rung above it by default. When execution reaches the top rung (COMPLEX work, or escalation), execution and acceptance share it, and Stage 5 of the skill names the controls that replace the missing rung.

**Why a shared log instead of passing context directly?**
Durability and auditability. FAILs re-run stages against full history. Failed runs archive instead of vanishing. The append-only file protocol is portable across the Claude and Codex plugin implementations. Your session's spawn prompts only point at the log (stage, mode, repo root, run), and it routes from the log's fixed lines, never from a stage's closing message, so no stage acts on an instruction the log does not record.

**Six stages for a one-line change?**
The stages are mandatory. Their length is not. A one-line change gets a Recon map of a few lines and a four-line plan. The discipline is the constant; the overhead scales with the work.

**What does a run cost?**
A full run spawns at least five agents: the intern, Recon, the PM twice, and the Executor; a plan run spawns three. DELEGATE helpers, FAIL re-runs, and an audit fan-out add more. Snapshot 2026-09-24: one measured run of 3.9.2 on an eight-file fixture repo with a top-rung main session billed about 1.6M input and 47k output tokens and cost $3.00 at list prices, two thirds of it in the main session. List prices that day per million input and output tokens: Fable 5.1 $10/$50, Opus 5.5 $4/$20, Sonnet 5 $2/$10, Haiku 4.5 $1/$5. Treat it as one data point, not a quote; the real number tracks the main session's turns, how much each stage reads (re-sent on every later call), and how many stages re-run. On Claude Code, each run's measured usage per stage is in `compute-squad-archive/usage.jsonl`.

**What if I stop a run halfway?**
Nothing is lost. The log keeps every entry completed so far. Start a new run and the squad asks whether to park it (archive it now, restore it later) or abandon it, or you can start the new goal in a separate git worktree. Or say you want to resume, and the squad picks up from the last logged entry instead of starting over. Before it continues, it checks the working tree for edits no entry explains and re-maps only the files that commits made since the plan touched. Resuming never grants execution of a shelved plan.

**How do I see which agents ran?**
Read `COMPUTE_SQUAD_LOG.md` during a run, or the timestamped copy in `compute-squad-archive/` after one. Every stage that finished has an entry with a timestamp; a stage interrupted before writing one leaves none, which is why a resume checks the working tree first.

## License

MIT. See [LICENSE](LICENSE).
