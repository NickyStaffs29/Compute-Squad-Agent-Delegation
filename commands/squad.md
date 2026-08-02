---
description: Run the Compute Squad pipeline on a goal
argument-hint: <goal>
---

Run the compute-squad skill's full pipeline, starting at Stage 0 (Strategy), using the following as the goal:

$ARGUMENTS

Follow `skills/compute-squad/SKILL.md` exactly: interrogate the goal, clarify gaps with the user, and lock the goal and acceptance criteria in Stage 0, then run Stage 1 (Archive) through Stage 5 (Accept) in order, coordinating exclusively through `COMPUTE_SQUAD_LOG.md`. Do not skip stages and do not start implementing before the goal is locked.
