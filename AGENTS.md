# Repository instructions

## Scope

This repository is the `nesymno` Claude Code plugin and its marketplace: nine
scoped Go/DevOps agents, the hooks that enforce their boundaries, the harness
that proves the hooks still fire, and an installer for the third-party skills
the agents reference. It is distributed through the Claude Code plugin
marketplace (`.claude-plugin/marketplace.json`).

## Layout

    .claude-plugin/plugin.json        plugin manifest
    .claude-plugin/marketplace.json   marketplace entry (source ".")
    agents/                           the nine agent definitions
    hooks/hooks.json                  every gate, wired at plugin scope
    hooks/*.sh                        enforcement scripts (read .agent_type)
    harness/verify-gates.sh           proves the hooks still block
    harness/cases/                    behavioural fixture per hook
    harness/fixtures/                 Go files the test-integrity fixtures load
    skills/platform-runbook/          bundled skill (fill in per environment)
    commands/                         /nesymno:* slash commands
    scripts/install-skills.sh         installs the third-party skills loosely
    .github/workflows/agent-gates.yml CI: runs verify-gates on every push

## Operating principles

- Working code only. Plausibility is not correctness; verify before reporting
  done.
- Never fabricate file paths, APIs, command output, or test results. Read the
  file, run the command, or say what is unknown.
- Say when a premise appears wrong before implementing around it.
- Touch only what the task requires. No drive-by refactors or formatting.
- Keep communication direct. Skip flattery, filler, and emoji.

## Editing rules

- **Plugin agents cannot use frontmatter hooks** and frontmatter does not
  expand `${CLAUDE_PLUGIN_ROOT}`. Every gate lives in `hooks/hooks.json` and
  fires session-wide; each script branches on `.agent_type` and exits 0 for
  agents it does not name. Do not reintroduce `hooks:` blocks into agent
  frontmatter.
- Agent frontmatter supports: `name`, `description`, `model`, `effort`,
  `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`,
  `isolation`. Nothing else is read.
- When you rename an agent, update its `agent_type` branch in every hook
  (`hooks/*.sh`) and its fixtures under `harness/cases/`. A stale branch means
  a silently disabled gate.
- Skills preloaded via `skills:` inject the full SKILL.md at startup. Keep it
  to 2 per agent. Scoping comes from `disallowedTools` or the allowlist hook,
  never from `skills:` alone.
- `hooks/skill-allowlist.sh` and `scripts/install-skills.sh` must agree: every
  name in an `ALLOWED` list or an agent `skills:` block is installed by the
  script or bundled under `skills/`.
- Use plain skill names (`golang-context`), not namespaced (`plugin:name`), in
  agent frontmatter and the allowlist.

## Verification

- Run `harness/verify-gates.sh` after any change to `agents/`, `hooks/`,
  `harness/`, `skills/`, or `scripts/install-skills.sh`. It must end
  `... 0 failure(s)`. Skill warnings are acceptable; failures are not.
- Add a fixture under `harness/cases/<hook>/` for every new enforced behaviour
  and every evasion an agent actually finds.
- `jq -e .` must parse `plugin.json`, `marketplace.json`, and `hooks/hooks.json`.
- After editing a hook's payload parsing, confirm the jq path against a real
  payload with `hooks/_payload-debug.sh` before trusting it.

## Releasing

- Bump `version` in `.claude-plugin/plugin.json` and the marketplace entry
  together.
- CI (`agent-gates.yml`) gates every push touching the plugin. Do not merge
  with the gate red.
