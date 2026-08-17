# Compute Squad

A staged agent delegation pipeline for Claude Code and Codex: your top-tier session runs strategy, the strongest tier plans and adversarially accepts the work, execution routes to a MECHANICAL, STANDARD, or COMPLEX model tier, and the cheapest tier handles zero-judgment busywork — all through a shared, auditable log.

Three steps to a working setup: **install**, **run**, **auto-update**. Each step shows Claude Code first, Codex right after — use whichever matches your setup. Everything else on this page is reference.

## 1. Install

**Claude Code.** Requires Opus access on your Claude Code plan — the PM stage runs on Opus with no fallback tier. Paste these two lines in your terminal:

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

**Codex.** Prerequisites: Codex CLI 0.134 or newer, a working `git`, `/bin/bash`, a logged-in Codex CLI, and access to `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna` on your Codex account — the pipeline hard-codes all three with no fallback tier. Those IDs resolve on the author's account as of August 2026; they are not stable public API guarantees, so verify them against your own account before relying on the Codex path. The first two commands install the native plugin; a checkout is also required because the updater copies the seven named agent TOMLs and generates the four Codex V2 profile files:

```bash
codex plugin marketplace add https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation
codex plugin add compute-squad@compute-squad
mkdir -p "$HOME/src"
git clone https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation "$HOME/src/compute-squad"
bash "$HOME/src/compute-squad/codex/update.sh"
```

If `$HOME/src/compute-squad` already exists, do not run `git clone` into it again. Use a clean checkout of this repository on `main`, or choose another empty directory; the updater fast-forwards whichever branch is currently checked out.

The updater also refreshes the configured marketplace and plugin. The plugin commands do not copy the repository's agent TOMLs by themselves. Start a new Codex session after installation so the plugin skill is loaded. Full Codex setup, routing table, update command, and a manual-prompt fallback for older Codex versions are in [`codex/README.md`](codex/README.md).

## 2. Run it

**Claude Code:**

```
/squad add rate limiting to the password-reset endpoint
```

Or say any of: `run the squad: <goal>`, `run compute squad`, `compute squad this`, `full pipeline on this`.

**Codex:**

```bash
codex --profile compute-squad "Run the squad: add rate limiting to the password-reset endpoint"
# For a non-interactive or scheduled run:
codex exec --profile compute-squad "Run the squad: add rate limiting to the password-reset endpoint"
```

The first form opens an interactive session; `codex exec` is the non-interactive form. Either way, run it from your project root, in a session that can read and write the repo.

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

The updater runs `git pull --ff-only`, `codex plugin marketplace upgrade compute-squad`, and `codex plugin add compute-squad@compute-squad`, then refreshes the agents and Codex V2 profile files. There is no `codex plugin update` command; the top-level `codex update` updates the CLI itself, not this plugin. Start a new Codex session after a plugin update.

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

What Compute Squad actually sells is verification and auditability that don't depend on operator discipline, plus capacity: a run works in its own agents instead of occupying your session, so you can have several going at once. It gets there by routing by decision density — stages that decide run strong models, stages that execute against a tight spec run cheap ones, and the review layer is never below the work it checks, and a tier above by default, so mistakes get caught by something stronger than what made them. That routing is also the math that makes the pipeline affordable: on list prices, it puts a run roughly 30 to 40% below an all-Opus worker pool running the same stages — the comparison is to a pool of Opus agents, not a single session.

One skill. Seven agents. A shared log. A role hierarchy that mirrors how a functional team actually operates:

| Role | Claude model | Codex model | Agent | Owns |
|---|---|---|---|---|
| Strategy | Main session | `gpt-5.6-sol` high | none. This is you and your session model | Goal, gaps, acceptance criteria, final judgment |
| PM | Opus | `gpt-5.6-sol` max | `squad-pm` | The plan and the acceptance decision |
| Execution on MECHANICAL | Haiku | `gpt-5.6-luna` max | `squad-executor-haiku` | The same executor protocol, cheapest model |
| Execution | Sonnet | `gpt-5.6-terra` max | `squad-recon`, `squad-executor`, `squad-helper` | Mapping the codebase, implementing the plan, delegated subtasks |
| Execution on COMPLEX | Opus | `gpt-5.6-sol` max | `squad-executor-opus` | The same executor protocol, stronger model |
| Intern | Haiku | `gpt-5.6-luna` max | `squad-mech` | Busywork. Nothing that requires judgment |

## How a run works

Six stages run in order, every time. Nothing skips, even for a one-line change — the entries can be
short, but the discipline can't.

- **Stage 0 — Strategy**, your session, before any agent spawns: interrogates the goal, clarifies
  gaps with you, locks the goal and acceptance criteria into the log's `## Goal — Locked` entry.
- **Stage 1 — Archive**, `squad-mech`: starts every run from a clean log. Failed runs are never
  discarded. They are evidence.
- **Stage 2 — Recon**, `squad-recon`: maps the codebase read-only.
- **Stage 3 — Plan**, `squad-pm` (PLAN mode): turns the map into a spec and classifies the work.
- **Stage 4 — Execute**, the executor the classification routes to: implements exactly what the plan
  says.
- **Stage 5 — Accept**, `squad-pm` (ACCEPT mode): tries to fail the work, then PASS or FAIL. Say "be
  thorough" and it adds an audit fan-out.

The full protocol for each stage — grammar, PASS/FAIL/BLOCKER handling, escalation, and the
audit-grade fan-out — is canonical in [`skills/compute-squad/SKILL.md`](skills/compute-squad/SKILL.md)
for Claude Code and [`codex/SKILL.md`](codex/SKILL.md) for Codex. This page is a summary, not a
second copy.

A complete worked run with every log entry format is in [`docs/example-log.md`](docs/example-log.md).

## What a run needs and leaves behind

A run creates two things in your project root:

- `COMPUTE_SQUAD_LOG.md`, the active log every stage appends to.
- `compute-squad-archive/`, timestamped copies of past runs. The log is archived before a new run starts and again on PASS, so a failed run is never lost.

Both are run state, not source. Add them to your `.gitignore` unless you specifically want run history in version control:

```
COMPUTE_SQUAD_LOG.md
compute-squad-archive/
```

A first run in a project with no log file is normal. Stage 1 creates it empty and the pipeline proceeds.

## The agents

### squad-recon (Sonnet, read-only)

The mapper. Given a locked goal, it sweeps the codebase and pins down exactly what the change touches: files, functions, line ranges, call sites, tests, migrations, config, and the invariants that must survive (auth boundaries, privacy rules, logging hygiene). It reads whole subsystems rather than fragments. It writes nothing except its log entry.

Its standard: the PM should never have to guess. Ambiguity Recon cannot resolve gets named explicitly in its entry, so the plan resolves it on purpose instead of by accident.

### squad-pm (Opus, two modes)

The project manager. Plans work, accepts deliverables, never writes product code. One agent, two invocations per run.

**PLAN mode** produces the spec: exact files and functions to change, the change to each, tests to add and what each asserts, what must NOT change, and the verification plan. The bar is an ordered task list a junior engineer could follow without a single judgment call. That bar is the whole system. Cheap execution is only safe because the plan carries the intelligence. PLAN also classifies the work: MECHANICAL, STANDARD, or COMPLEX. MECHANICAL routes execution to `squad-executor-haiku`, COMPLEX routes it to `squad-executor-opus`, and STANDARD stays on `squad-executor`.

**ACCEPT mode** is adversarial by instruction. It re-derives expectations from the locked criteria before reading the Executor's account, so the Executor's framing cannot anchor it. It re-runs the full test suite itself. It never trusts logged claims. It attempts refutations: concurrency, empty and duplicate data, permission boundaries. FAIL comes with evidence and exactly one named stage to re-run. PASS archives the log first, then clears it, and hands high-stakes changes back to your session to review and clear. Nothing clears the log before a PASS.

Decisions the PM is not allowed to make: anything product-level, irreversible, or cost-bearing, and anything that would change the locked goal. Those get logged as named blockers and go back to the human. Guessing past a blocker is a protocol violation, not initiative.

### squad-executor (Sonnet), squad-executor-haiku (Haiku), and squad-executor-opus (Opus)

The builder. Reads the full log, then works the PM's task list in order. Exactly what the plan says. No more, no less.

If the plan is wrong or impossible, it stops and logs a blocker naming Plan as the stage to re-run. It does not improvise a better design, because an executor that improvises invalidates the acceptance review downstream. A judgment call the plan left open is a plan defect and gets reported as one.

It runs the project's own test and verify commands as it goes and will not log completion with failing tests.

`squad-executor-haiku` and `squad-executor-opus` are the same agent definition on Haiku and Opus respectively. `squad-executor-haiku` runs when the PM classifies the work MECHANICAL — transcription-grade by the PM's own classification, so it carries one extra discipline line: any task that turns out to need more than transcribing an explicitly specified change is a blocker naming Plan, not something to push through. `squad-executor-opus` runs when the PM classifies the work COMPLEX, or when execution escalates after two FAILs. Three definitions instead of one flag, because an agent's model is fixed in its frontmatter.

### squad-helper (Sonnet, the delegated worker)

The execution-tier half of the DELEGATE protocol. When a stage delegates a subtask that is too specified to need judgment but too involved for the intern, `squad-helper` runs the exact procedure and returns the result in its final message. It never writes the log; the orchestrating session does. Handed anything that needs a design decision, it refuses and sends it back as a plan defect.

### squad-mech (Haiku, the intern)

Zero-judgment busywork, executed exactly. Log archival before every run (verified copy first, truncate second, never the reverse). File rotation. Formatting normalization. Inventories. Fixture generation from an exact template.

Its one skill beyond following procedure is knowing what it is not: handed anything that requires a judgment call, it refuses and reports that the task needs a higher tier. An intern that knows its lane is worth more than a mid-level that does not.

## The delegation structure

Four rules generate the whole system: route by decision density, not task difficulty; review from a
tier above the work by default; push busywork down a tier through the `DELEGATE:` protocol, downward
only and capped at 5 helpers per stage per run; and escalate on evidence, never on vibes. Opus costs
about 1.67x Sonnet per token — a wrong answer that forces an upstream re-run costs more than the tier
difference every time, which makes routing up on uncertainty the cheap option. The full rules, the
escalation ladder, and the blocker grammar are canonical in
[`skills/compute-squad/SKILL.md`](skills/compute-squad/SKILL.md) for Claude Code and
[`codex/SKILL.md`](codex/SKILL.md) for Codex.

Underneath all four sits the log, `COMPUTE_SQUAD_LOG.md` — durable, auditable state is what lets a
FAIL re-run one stage instead of the whole pipeline, and it is why the same protocol runs in Codex
too: the native plugin spawns the same named agents, and the manual fallback sequences the same
stages by hand when the plugin path is unavailable.

## Repo layout

```
Compute-Squad-Agent-Delegation/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest
│   └── marketplace.json      # makes this repo installable in Claude Code
├── .codex-plugin/
│   └── plugin.json           # native Codex plugin manifest
├── .agents/plugins/
│   └── marketplace.json      # makes this repo discoverable in Codex
├── .github/workflows/
│   └── ci.yml                # runs scripts/verify.sh on every push
├── skills/compute-squad/
│   ├── SKILL.md              # the orchestration protocol
│   └── references/
│       ├── routing-rules.md  # full routing rules, escalation, cost math
│       └── audit-prompts.md  # finder and skeptic briefs for audit-grade runs
├── agents/
│   ├── squad-recon.md        # Sonnet · read-only mapping
│   ├── squad-pm.md           # Opus · PLAN + ACCEPT modes
│   ├── squad-executor.md     # Sonnet · implementation
│   ├── squad-executor-haiku.md # Haiku · implementation on MECHANICAL
│   ├── squad-executor-opus.md # Opus · implementation on COMPLEX
│   ├── squad-helper.md       # Sonnet · delegated execution-tier subtasks
│   └── squad-mech.md         # Haiku · the intern
├── commands/
│   └── squad.md              # /squad <goal> — starts the pipeline at Stage 0
├── codex/
│   ├── README.md             # Codex install, routing, and manual fallback
│   ├── SKILL.md              # Codex-specific routing reference
│   ├── agents/*.toml         # generated Codex agent definitions
│   ├── build-agents.py       # generates codex/agents/*.toml from agents/*.md
│   ├── profiles.toml         # Sol/Terra/Luna profile reference
│   ├── update.sh             # installs/refreshes the native Codex plugin
│   └── 01-05*.md             # manual-session fallback prompts
├── docs/example-log.md       # a complete worked run
├── scripts/
│   ├── build-plugin.sh       # rebuilds dist/ from the git-tracked source set
│   └── verify.sh             # the CI gate; run it before every commit
├── dist/compute-squad.plugin # drag-and-drop install for Claude Cowork
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
Yes. Agents use tier aliases, which resolve to the newest model in each class at runtime. New generation ships, the squad picks it up, zero changes required. Agent frontmatter also accepts `inherit` and explicit model IDs. Pin an explicit ID only if a workflow regression-tests better on an older snapshot.

**Why is Sonnet execution safe?**
Three backstops. The plan is required to carry the intelligence. Acceptance is never below the work it reviews, and a tier above by default — on COMPLEX work, execution and acceptance both run on Opus. And the PM's COMPLEX classification escalates execution to Opus when a tight spec cannot fully de-risk the work.

**Why a shared log instead of passing context directly?**
Durability and auditability. FAILs re-run stages against full history. Failed runs archive instead of vanishing. The append-only file protocol is portable across the Claude and Codex plugin implementations.

**Six stages for a one-line change?**
The stages are mandatory. Their length is not. A one-line change gets a three-sentence Recon entry and a four-line plan. The discipline is the constant; the overhead scales with the work.

**What does a run cost?**
The floor is five agent spawns: the intern, Recon, the PM twice, and the Executor. DELEGATE helpers and an audit fan-out add more on top. As a rough order of magnitude, a small change runs a few hundred thousand tokens end to end, and an audit-grade run is a multiple of that. Treat both as ballpark, not a quote: the real number tracks how much code Recon has to read.

**What if I stop a run halfway?**
Nothing is lost. The log keeps every entry completed so far. Start a new run and Stage 1 archives it before clearing. Or say you want to resume, and the squad picks up from the last logged entry instead of starting over.

**How do I see which agents ran?**
Read `COMPUTE_SQUAD_LOG.md` during a run, or the timestamped copy in `compute-squad-archive/` after one. Every stage that ran has an entry with a timestamp.

## License

MIT. See [LICENSE](LICENSE).
