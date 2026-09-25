---
description: Run the Compute Squad pipeline on a goal
argument-hint: [plan|execute|accept] <goal or work order>
---

Run the compute-squad skill on this request. If its first word is `plan`, `execute`, or `accept`, that word is the mode; otherwise the mode is `full`:

$ARGUMENTS

Follow `skills/compute-squad/SKILL.md` exactly: start at Stage 0 and read the latest `## Status` entry of any existing `COMPUTE_SQUAD_LOG.md` first. Run every stage the mode permits, in order, and no other, coordinating exclusively through the log. Never spawn an executor without a grant the log records for the governing plan revision and work order.
