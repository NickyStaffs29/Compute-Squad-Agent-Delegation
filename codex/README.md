# Compute Squad for Codex

Codex has no nested agent-spawning tool, so the pipeline can't run as one automatic command. It runs instead as a **manually-run sequence of Codex sessions**, one per stage, coordinating through the same `COMPUTE_SQUAD_LOG.md` in your repo root. The discipline is identical; only the trigger is manual.

## How to run it

**Stage 0 — Strategy (you, before any session).** Interrogate your own goal: what does done look like, what's out of scope, what could this break. Write down the goal (one sentence) and concrete acceptance criteria. You own these; no session may redefine them.

Then run the sessions in order, pasting each prompt file and filling in the `<GOAL>` and `<ACCEPTANCE CRITERIA>` placeholders:

| Order | Prompt file | Stage | Suggested model |
|---|---|---|---|
| 1 | `01-archive.md` | Archive the prior log | cheapest available |
| 2 | `02-recon.md` | Read-only codebase mapping | mid tier |
| 3 | `03-pm-plan.md` | Spec + task breakdown, no code | strongest available |
| 4 | `04-execute.md` | Implementation, exactly per plan | mid tier (strongest if the plan said COMPLEX) |
| 5 | `05-pm-accept.md` | Adversarial acceptance, PASS/FAIL | strongest available |

**On FAIL:** the acceptance session names exactly one stage to re-run. Re-run that stage's session (and every stage after it) with the log intact. Same stage fails twice: use a stronger model for the third attempt. Three total FAILs: stop and rethink the goal.

**On PASS:** the acceptance session clears the log as its final step. Done.

## The DELEGATE protocol in Codex

Stages may end their log entry with a `DELEGATE:` block listing zero-judgment subtasks. In Codex, you are the switchboard: run each delegated subtask in a cheap-model session (paste the exact procedure from the block), append results to the log under `## Delegated — <stage>`, then re-run the requesting stage if it marked the request `BLOCKING`.

## Rules that keep it honest

- Every stage appends to `COMPUTE_SQUAD_LOG.md`; no stage rewrites history; only a PASSing acceptance session clears it.
- Archive a non-empty log before every new run (`codex-prompts/compute-squad-archive/` if your repo has it, else `compute-squad-archive/`). Never discard a prior or failed run.
- No stage skips, even for one-line changes. The entries can be short; the discipline can't.
- The executor never accepts its own work. You, not any session, own the goal and acceptance criteria.
