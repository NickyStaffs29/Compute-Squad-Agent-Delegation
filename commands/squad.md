---
description: Run the Compute Squad pipeline on a goal
argument-hint: [plan|execute|accept] <goal or work order>
---

Process this request with the Compute Squad protocol. This slash command is already expanded: do not invoke `Skill` for `compute-squad:squad` again. Read the candidate SKILL.md named below directly once (unless its complete contents are already loaded). If its first word is `plan`, `execute`, or `accept`, that word is the mode; otherwise the mode is `full`:

$ARGUMENTS

Follow this plugin's own skill, `${CLAUDE_PLUGIN_ROOT}/skills/compute-squad/SKILL.md`, exactly: start at Stage 0 and read the latest `## Status` entry of any existing `COMPUTE_SQUAD_LOG.md` first. Before any stage, confirm the top, mid, and bottom model IDs with the human for this invocation, even on resume; the same ID may fill more than one rung. Run every stage the mode permits, in order, and no other, coordinating exclusively through the log. Never spawn an executor without a grant the log records for the governing plan revision and work order.
