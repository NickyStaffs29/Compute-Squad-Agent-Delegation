# Compute Squad

A four-tier agent delegation pipeline for Claude Code (and Codex): your main session runs strategy, an Opus PM plans and accepts the work, Sonnet executes, and Haiku handles the busywork — coordinated through a shared, auditable log.

Three steps to a working setup: **install**, **run**, **auto-update**. Each step shows Claude Code first, Codex right after — use whichever matches your setup. Everything else on this page is reference.

## 1. Install

**Claude Code.** Paste these two lines in your terminal:

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

**Codex.** Add the plugin, then install the seven named agents once so the skill can route each stage:

```bash
codex plugin marketplace add https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation
codex plugin add compute-squad@compute-squad
mkdir -p "$HOME/src"
git clone https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation "$HOME/src/compute-squad"
bash "$HOME/src/compute-squad/codex/update.sh"
```

The updater also writes the Codex V2 profile files from [`codex/profiles.toml`](codex/profiles.toml). Start a new Codex session after installation so the plugin skill is loaded. Full Codex setup, routing table, update command, and a manual-prompt fallback for older Codex versions are in [`codex/README.md`](codex/README.md).

## 2. Run it

**Claude Code:**

```
/squad add rate limiting to the password-reset endpoint
```

Or say any of: `run the squad: <goal>`, `run compute squad`, `compute squad this`, `full pipeline on this`.

**Codex:**

```bash
codex --profile compute-squad "Run the squad: add rate limiting to the password-reset endpoint"
```

Either way, run it from your project root, in a session that can read and write the repo.

## 3. Get updates automatically

**Claude Code** — auto-update is built in; you just flip it on once. Run `/plugin`, open the **Marketplaces** tab, select **compute-squad**, and choose **Enable auto-update**. Claude Code then refreshes the marketplace and updates the plugin in the background — nothing else to set up.

**Codex** — paste this into a Codex session once, and it sets up the recurring job on your device itself:

```
Set up a weekly recurring task on this device that keeps the Compute Squad
plugin up to date. Once a week it should:
  1. Run the repository updater:
     CODEX_BIN=/absolute/path/to/codex GIT_BIN=/absolute/path/to/git
     /bin/bash "$HOME/src/compute-squad/codex/update.sh"
     It runs `git pull --ff-only`,
     `codex plugin marketplace upgrade compute-squad`,
     `codex plugin add compute-squad@compute-squad`, and refreshes the
     agents and Codex V2 profile files. Current Codex has no
     `codex plugin update` command.
Use the OS scheduler (launchd on macOS, cron on Linux, Task Scheduler on
Windows), with absolute executable paths and stdout/stderr redirected to a
log. The updater does not create the schedule. When you're done, tell me the
schedule you created, the command path, and the log path. Start a new Codex
session after a plugin update.
```

Prefer manual updates? In Claude Code, run these whenever you like (marketplace first — it refreshes the source, then the plugin update pulls the new version):

```
/plugin marketplace update compute-squad
/plugin update compute-squad
```

In Codex, re-run steps 1–3 from the Codex prompt above.

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

**Claude Cowork.** Download [`dist/compute-squad.plugin`](https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation/raw/main/dist/compute-squad.plugin), drop it into any chat, and accept the install. In Cowork, run the squad from a session with your project folder connected so the agents can read and write the repo and the log.

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

Six things happen, in order. Nothing skips.

**Stage 0: Strategy. Your session, before any agent spawns.**
The goal gets interrogated. What does done look like. What is out of scope. What could this break. Gaps get surfaced and clarified with you in one batched pass, not dripped across the run. Then the goal and acceptance criteria get locked and composed into a `## Goal — Locked` entry. From this point no agent can redefine them, and every downstream stage reads this entry instead of trusting its spawn prompt. Any change routes back to you. If the session is unattended and nobody answers, Stage 0 makes the most reasonable call on each gap, states every assumption in writing, and proceeds rather than stalling.

**Stage 1: Archive.** `squad-mech` moves any prior log to a timestamped archive file, then appends the `## Goal — Locked` entry from Stage 0 as the first entry of the fresh log, before Recon spawns. Failed runs are never discarded. They are evidence.

**Stage 2: Recon.** `squad-recon` maps the codebase read-only: exact files, functions, line ranges, every call site, every invariant the change must not break.

**Stage 3: Plan.** `squad-pm` turns the map into a spec and an ordered task list tight enough that execution needs zero judgment calls. It classifies the work MECHANICAL, STANDARD, or COMPLEX.

**Stage 4: Execute.** `squad-executor` implements exactly what the plan says. Production quality. No scaffolding, no TODOs, no drive-by refactors. Tests green before it logs done.

**Stage 5: Accept.** `squad-pm` comes back in acceptance mode and tries to fail the work. It re-runs every verification command itself, checks every invariant, and attempts at least one refutation per acceptance criterion. FAIL names exactly one stage to re-run. PASS archives the log, then clears it. On a high-stakes change (auth, payments, migrations, privacy, production config) the PM leaves the log intact instead, your session does one more review, and your session clears it.

Say "be thorough" and acceptance adds an audit fan-out: parallel Sonnet finders across five dimensions (runtime integrity, security and privacy, dead code, accessibility, docs drift), with Opus skeptics refuting each finding before it counts. A finding that survives a skeptic is a finding. Everything else is noise. The briefs the finders and skeptics run on are in [`skills/compute-squad/references/audit-prompts.md`](skills/compute-squad/references/audit-prompts.md).

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

Four rules generate the whole system.

**1. Route by decision density, not task difficulty.**
Planning and acceptance are where errors cascade, so they run Opus. Mapping and implementation are volume work against a spec, so they run Sonnet by default — or Haiku, when the PM's own classification says the work is transcription-grade (MECHANICAL). Zero-judgment steps run Haiku. Your top-tier session does the one thing only it can do: talk to you, and judge. Opus costs about 1.67x Sonnet per token. A wrong answer that forces an upstream re-run costs more than the tier difference every time, which makes routing up on uncertainty the cheap option.

**2. The reviewer is never below the work, and a tier above by default.**
The Opus PM accepts Sonnet execution. When execution escalates to Opus, acceptance holds at Opus, and high-stakes changes add a top-tier review in your session. The executor never accepts its own output. Nobody has to remember this rule. The structure enforces it.

**3. The hierarchy is fractal. Every level pushes busywork down.**
The PM does not spend Opus tokens assembling changelogs. Recon does not burn its context window on file inventories. Any stage can end its log entry with a `DELEGATE:` block: subtasks, exact procedures, target tier. Subagents cannot spawn subagents, so the orchestrating session acts as the switchboard, runs the helpers (`squad-mech` for intern work, `squad-helper` for execution work), writes their returned results into the log, and re-spawns the requesting stage if it marked the request BLOCKING. Delegation flows downward only, capped at 5 helpers per stage per run. A stage that needs more than 5 helpers has a scoping problem, and the protocol makes it say so.

**4. Escalation runs on evidence, never on vibes.**
Same stage fails acceptance twice: it gets one model tier up on the third attempt. Three total FAILs: the run stops and comes back to you with the full log history. Anything that would change the locked goal returns to Stage 0 and the human. Always. A blocker is never freeform prose: it's a `BLOCKER:` block at the end of a stage's own entry, either `rerun: <stage>` (re-runs that stage and everything after it, counting toward the three-FAIL stop) or `needs-human: <decision>` (returns to Stage 0).

Underneath all four sits the log. `COMPUTE_SQUAD_LOG.md` is the only coordination channel. Every stage appends. No stage rewrites history. Every fresh log opens with a locked `## Goal — Locked` entry, so no stage ever has to trust a prompt over the record. It is cleared only after a PASS and only after that PASS is archived, and failed runs archive rather than vanish. Durable, auditable state is what lets a FAIL re-run one stage instead of the whole pipeline, and it is why the same protocol runs in Codex with no agent-spawning at all.

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
│   ├── SKILL.md              # Codex-specific routing reference
│   ├── agents/*.toml         # generated Codex agent definitions
│   ├── profiles.toml         # Sol/Terra/Luna profile reference
│   └── 01-05*.md             # manual-session fallback prompts
├── docs/example-log.md       # a complete worked run
├── scripts/build-plugin.sh   # rebuilds dist/ from source
├── dist/compute-squad.plugin # drag-and-drop install for Claude Cowork
├── CONTRIBUTING.md           # the sync rule: skill, agents, codex, dist change together
└── CHANGELOG.md              # version history
```

`dist/compute-squad.plugin` is committed on purpose: Claude Cowork installs from a single downloadable file, so the package has to exist at a stable URL. It is a zip of `.claude-plugin/plugin.json`, `skills/`, `agents/`, `commands/`, and `README.md`. It is generated, never hand-edited. After changing any of those sources, run `scripts/build-plugin.sh` from the repo root and commit the rebuilt package with your change.

## FAQ

**Why is strategy not an agent?**
Subagents run headless. They cannot ask you anything, and clarifying gaps with the human is the entire point of Stage 0. So strategy lives in the skill and executes in your top-tier main session.

**Do the models auto-upgrade?**
Yes. Agents use tier aliases, which resolve to the newest model in each class at runtime. New generation ships, the squad picks it up, zero changes required. Agent frontmatter also accepts `inherit` and explicit model IDs. Pin an explicit ID only if a workflow regression-tests better on an older snapshot.

**Why is Sonnet execution safe?**
Three backstops. The plan is required to carry the intelligence. Acceptance always reviews from a tier up. And the PM's COMPLEX classification escalates execution to Opus when a tight spec cannot fully de-risk the work.

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
