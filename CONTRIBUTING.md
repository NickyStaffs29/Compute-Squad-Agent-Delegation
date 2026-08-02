# Contributing

Open an issue before changing the protocol. Wording fixes, docs, and examples can go straight to a pull request. Anything that changes stage behavior, routing, the DELEGATE rules, or the log format should be discussed first, because those changes land in five places at once.

## The sync rule

The protocol exists in synchronized copies. A protocol change is only complete when all of these move together:

- `skills/compute-squad/SKILL.md` and `skills/compute-squad/references/`
- `agents/*.md`
- `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`
- `codex/SKILL.md`, `codex/agents/*.toml`, `codex/build-agents.py`, and `codex/profiles.toml`
- `codex/*.md`
- `README.md` and `docs/example-log.md`
- `dist/compute-squad.plugin`, rebuilt with `scripts/build-plugin.sh` from the repo root

Never hand-edit `dist/compute-squad.plugin`. It is generated.

## Before you commit

- Agent and skill frontmatter parses as valid YAML, with `model` set to `sonnet`, `opus`, or `haiku`, and at least one `<example>` block in each agent description.
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` parse as valid JSON.
- `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` parse as valid JSON.
- `python3 codex/build-agents.py --check` passes; generated TOMLs are never hand-edited.
- No cross-file contradiction: stage counts, agent names, archive paths, and log-clearing rules read the same everywhere.
- Bump the version in `.claude-plugin/plugin.json` and `SKILL.md`, and add a `CHANGELOG.md` entry.
