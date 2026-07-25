# Compute Squad

Most multi-agent setups have an org chart problem. The strongest model does the typing and the supervision. The cheap models sit idle. Every task gets the same treatment whether it needs judgment or just execution.

Compute Squad routes by decision density instead. Stages that decide get strong models. Stages that execute against a tight spec get cheap ones. Runs cost roughly 30 to 40% less than an all-Opus worker pool, and quality goes up, because the review layer is always a tier above the work it checks.

One skill. Four agents. A shared log. A role hierarchy that mirrors how a functional team actually operates:

| Role | Model | Agent | Owns |
|---|---|---|---|
| Strategy | Your main session (top tier recommended) | none. This is you and your session model | Goal, gaps, acceptance criteria, final judgment |
| PM | Opus | `squad-pm` | The plan and the acceptance decision |
| Execution | Sonnet | `squad-recon`, `squad-executor` | Mapping the codebase, implementing the plan |
| Intern | Haiku | `squad-mech` | Busywork. Nothing that requires judgment |

Works in Claude Code, Claude Cowork, and Codex (as a manual prompt pack).

## Install

**Claude Code, from your terminal.** Paste these two lines:

```bash
claude plugin marketplace add NickyStaffs29/Compute-Squad-Agent-Delegation
claude plugin install compute-squad@compute-squad
```

Or from inside a Claude Code session:

```
/plugin marketplace add NickyStaffs29/Compute-Squad-Agent-Delegation
/plugin install compute-squad@compute-squad
```

**Team rollout.** Add this to your project's `.claude/settings.json` and the plugin auto-installs for everyone who trusts the repo:

```json
{
  "extraKnownMarketplaces": {
    "compute-squad": {
      "source": { "source": "github", "repo": "NickyStaffs29/Compute-Squad-Agent-Delegation" }
    }
  },
  "enabledPlugins": { "compute-squad@compute-squad": true }
}
```

**Claude Cowork.** Download the package and drop it into any chat, then accept the install:

```bash
curl -L -o compute-squad.plugin https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation/raw/main/dist/compute-squad.plugin
```

Or grab [`dist/compute-squad.plugin`](https://github.com/NickyStaffs29/Compute-Squad-Agent-Delegation/raw/main/dist/compute-squad.plugin) directly.

**Codex.** No install. The pipeline runs as a manually sequenced set of sessions using the prompts in [`codex/`](codex/). Start with [`codex/README.md`](codex/README.md).

Updates: push lands here, users run `/plugin marketplace update compute-squad`.

## How a run works

```
run the squad: add rate limiting to the password-reset endpoint
```

Six things happen, in order. Nothing skips.

**Stage 0: Strategy. Your session, before any agent spawns.**
The goal gets interrogated. What does done look like. What is out of scope. What could this break. Gaps get surfaced and clarified with you in one batched pass, not dripped across the run. Then the goal and acceptance criteria get locked. From this point no agent can redefine them. Any change routes back to you.

**Stage 1: Archive.** `squad-mech` moves any prior log to a timestamped archive file. Failed runs are never discarded. They are evidence.

**Stage 2: Recon.** `squad-recon` maps the codebase read-only: exact files, functions, line ranges, every call site, every invariant the change must not break.

**Stage 3: Plan.** `squad-pm` turns the map into a spec and an ordered task list tight enough that execution needs zero judgment calls. It classifies the work MECHANICAL, STANDARD, or COMPLEX.

**Stage 4: Execute.** `squad-executor` implements exactly what the plan says. Production quality. No scaffolding, no TODOs, no drive-by refactors. Tests green before it logs done.

**Stage 5: Accept.** `squad-pm` comes back in acceptance mode and tries to fail the work. It re-runs every verification command itself, checks every invariant, and attempts at least one refutation per acceptance criterion. FAIL names exactly one stage to re-run. PASS clears the log. High-stakes changes get one more review in your session before the run is called done.

Say "be thorough" and acceptance adds an audit fan-out: parallel Sonnet finders across five dimensions (runtime integrity, security and privacy, dead code, accessibility, docs drift), with Opus skeptics refuting each finding before it counts. A finding that survives a skeptic is a finding. Everything else is noise.

A complete worked run with every log entry format is in [`docs/example-log.md`](docs/example-log.md).

## The agents

### squad-recon (Sonnet, read-only)

The mapper. Given a locked goal, it sweeps the codebase and pins down exactly what the change touches: files, functions, line ranges, call sites, tests, migrations, config, and the invariants that must survive (auth boundaries, privacy rules, logging hygiene). It reads whole subsystems rather than fragments. It writes nothing except its log entry.

Its standard: the PM should never have to guess. Ambiguity Recon cannot resolve gets named explicitly in its entry, so the plan resolves it on purpose instead of by accident.

### squad-pm (Opus, two modes)

The project manager. Plans work, accepts deliverables, never writes product code. One agent, two invocations per run.

**PLAN mode** produces the spec: exact files and functions to change, the change to each, tests to add and what each asserts, what must NOT change, and the verification plan. The bar is an ordered task list a junior engineer could follow without a single judgment call. That bar is the whole system. Cheap execution is only safe because the plan carries the intelligence. PLAN also classifies the work: MECHANICAL, STANDARD, or COMPLEX. COMPLEX tells the orchestrator to run execution on Opus instead of Sonnet.

**ACCEPT mode** is adversarial by instruction. It re-derives expectations from the locked criteria before reading the Executor's account, so the Executor's framing cannot anchor it. It re-runs the full test suite itself. It never trusts logged claims. It attempts refutations: concurrency, empty and duplicate data, permission boundaries. FAIL comes with evidence and exactly one named stage to re-run. PASS clears the log, and only PASS clears the log.

Decisions the PM is not allowed to make: anything product-level, irreversible, or cost-bearing, and anything that would change the locked goal. Those get logged as named blockers and go back to the human. Guessing past a blocker is a protocol violation, not initiative.

### squad-executor (Sonnet default, Opus on COMPLEX)

The builder. Reads the full log, then works the PM's task list in order. Exactly what the plan says. No more, no less.

If the plan is wrong or impossible, it stops and logs a blocker naming Plan as the stage to re-run. It does not improvise a better design, because an executor that improvises invalidates the acceptance review downstream. A judgment call the plan left open is a plan defect and gets reported as one.

It runs the project's own test and verify commands as it goes and will not log completion with failing tests.

### squad-mech (Haiku, the intern)

Zero-judgment busywork, executed exactly. Log archival before every run (verified copy first, truncate second, never the reverse). File rotation. Formatting normalization. Inventories. Fixture generation from an exact template.

Its one skill beyond following procedure is knowing what it is not: handed anything that requires a judgment call, it refuses and reports that the task needs a higher tier. An intern that knows its lane is worth more than a mid-level that does not.

## The delegation structure

Four rules generate the whole system.

**1. Route by decision density, not task difficulty.**
Planning and acceptance are where errors cascade, so they run Opus. Mapping and implementation are volume work against a spec, so they run Sonnet. Zero-judgment steps run Haiku. Your top-tier session does the one thing only it can do: talk to you, and judge. Opus costs about 1.67x Sonnet per token. A wrong answer that forces an upstream re-run costs more than the tier difference every time, which makes routing up on uncertainty the cheap option.

**2. The reviewer is always a tier above the work.**
The Opus PM accepts Sonnet execution. When execution escalates to Opus, acceptance holds at Opus, and high-stakes changes add a top-tier review in your session. The executor never accepts its own output. Nobody has to remember this rule. The structure enforces it.

**3. The hierarchy is fractal. Every level pushes busywork down.**
The PM does not spend Opus tokens assembling changelogs. Recon does not burn its context window on file inventories. Any stage can end its log entry with a `DELEGATE:` block: subtasks, exact procedures, target tier. Subagents cannot spawn subagents, so the orchestrating session acts as the switchboard, runs the helpers, and re-spawns the requesting stage if it marked the request BLOCKING. Delegation flows downward only, capped at 5 helpers per stage per run. A stage that needs more than 5 interns has a scoping problem, and the protocol makes it say so.

**4. Escalation runs on evidence, never on vibes.**
Same stage fails acceptance twice: it gets one model tier up on the third attempt. Three total FAILs: the run stops and comes back to you with the full log history. Anything that would change the locked goal returns to Stage 0 and the human. Always.

Underneath all four sits the log. `COMPUTE_SQUAD_LOG.md` is the only coordination channel. Every stage appends. No stage rewrites history. Only a PASSing PM clears it, and failed runs archive rather than vanish. Durable, auditable state is what lets a FAIL re-run one stage instead of the whole pipeline, and it is why the same protocol runs in Codex with no agent-spawning at all.

## Repo layout

```
Compute-Squad-Agent-Delegation/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest
│   └── marketplace.json      # makes this repo installable in Claude Code
├── skills/compute-squad/
│   ├── SKILL.md              # the orchestration protocol
│   └── references/
│       └── routing-rules.md  # full routing rules, escalation, cost math
├── agents/
│   ├── squad-recon.md        # Sonnet · read-only mapping
│   ├── squad-pm.md           # Opus · PLAN + ACCEPT modes
│   ├── squad-executor.md     # Sonnet · implementation, Opus override on COMPLEX
│   └── squad-mech.md         # Haiku · the intern
├── codex/                    # the pipeline as manual Codex session prompts
├── docs/example-log.md       # a complete worked run
└── dist/compute-squad.plugin # drag-and-drop install for Claude Cowork
```

## FAQ

**Why is strategy not an agent?**
Subagents run headless. They cannot ask you anything, and clarifying gaps with the human is the entire point of Stage 0. Agent definitions also pin to the opus, sonnet, and haiku tiers, and your main session is the only place your top-tier model runs. So strategy lives in the skill and executes on whatever model runs your session.

**Do the models auto-upgrade?**
Yes. Agents use tier aliases, which resolve to the newest model in each class at runtime. New generation ships, the squad picks it up, zero changes required. Pin an explicit model ID in an agent's frontmatter only if a workflow regression-tests better on an older snapshot.

**Why is Sonnet execution safe?**
Three backstops. The plan is required to carry the intelligence. Acceptance always reviews from a tier up. And the PM's COMPLEX classification escalates execution to Opus when a tight spec cannot fully de-risk the work.

**Why a shared log instead of passing context directly?**
Durability and auditability. FAILs re-run stages against full history. Failed runs archive instead of vanishing. And a file protocol is portable: the same pipeline runs in Codex, which cannot spawn agents at all.

**Five stages for a one-line change?**
The stages are mandatory. Their length is not. A one-line change gets a three-sentence Recon entry and a four-line plan. The discipline is the constant; the overhead scales with the work.

## License

MIT. See [LICENSE](LICENSE).
