# prod-ready-go-infra-coding

A Claude Code plugin: nine scoped Go/DevOps agents, hard skill allowlists, and
hooks that enforce the boundaries the prompts describe. Prompts persuade; hooks
enforce.

## Install

```
/plugin marketplace add nesymno/ai-plugins
/plugin install prod-ready-go-infra-coding@nesymno
```

Then, once per machine, install the third-party skills the agents reference and
prove the gates work:

```
git clone https://github.com/nesymno/ai-plugins && cd ai-plugins
./scripts/install-skills.sh          # reads SKILL.md files as it goes - review them
./harness/verify-gates.sh            # expect: N fixture(s) passed, 0 failure(s)
```

`scripts/install-skills.sh` installs the Go skills loosely under
`~/.claude/skills/` (not as plugins) so the plain names in agent frontmatter
and in `hooks/skill-allowlist.sh` resolve. `platform-runbook` ships inside the
plugin; fill it in for your environment at
`skills/platform-runbook/SKILL.md` (it is preloaded into `devops` and
`devops-analyzer`, so keep it under ~1500 tokens).

## Agents

| Agent | Model | Preloaded | Enforced by |
|---|---|---|---|
| go-coder | sonnet | golang-safety | go-check, skill-allowlist |
| go-coder-fast | haiku | - | go-check, no Skill tool |
| go-reviewer | opus | golang-safety, golang-concurrency | go-precheck gate, bash-write-guard, skill-allowlist |
| go-qa-automation | sonnet | golang-testing, golang-stretchr-testify | test-integrity, skill-allowlist |
| go-qa-verifier | haiku | - | bash-write-guard, read-only tools |
| devops | sonnet | platform-runbook | infra-readonly, infra-validate, skill-allowlist |
| devops-analyzer | sonnet | platform-runbook | infra-readonly, read-only tools |
| harness-gate | sonnet | - | bash-write-guard, read-only tools |
| improver | sonnet | - | config-guard, skill-allowlist |

## How enforcement works in a plugin

Plugin agents **cannot carry frontmatter hooks**, so every gate is wired once
at plugin scope in `hooks/hooks.json` and fires for the whole session. Each
hook script reads `.agent_type` from the payload and enforces only for the
agents it names; for every other agent and for the main thread it exits 0 and
does nothing.

| Hook | Event | Enforces for | Effect |
|---|---|---|---|
| skill-allowlist | PreToolUse:Skill | go-coder, go-reviewer, go-qa-automation, devops, devops-analyzer, improver | per-agent lazy-skill allowlist |
| bash-write-guard | PreToolUse:Bash | go-reviewer, go-qa-verifier, harness-gate | keep a read-only agent read-only |
| infra-readonly | PreToolUse:Bash | devops, devops-analyzer | block live-infra mutation |
| config-guard | PreToolUse:Edit\|Write | improver | block edits to agents/hooks/harness/settings → write a proposal |
| go-check | PostToolUse:Edit\|Write | any (Go files only) | gofmt / build / vet / golangci-lint |
| test-integrity | PostToolUse:Edit\|Write | any (`*_test.go` only) | block weakening a test |
| infra-validate | PostToolUse:Edit\|Write | any (infra files only) | terraform/actionlint/hadolint/... |
| session-start | SessionStart | - | run verify-gates, warn if a gate is broken |
| telemetry | SubagentStop | - | append one line per finished subagent for `improver` |

`hooks/go-precheck.sh` is not a hook; `go-reviewer` runs it by hand as its
first step.

## Verifying the gates

`harness/verify-gates.sh` (also `/nesymno:verify-gates`) checks: `jq` present,
every hook script executable, every behavioural fixture in `harness/cases/`
produces its expected exit code, every skill named in an agent resolves (or is
listed in `install-skills.sh` — a warning, not a failure), and every hook path
in `hooks/hooks.json` exists and is executable. CI runs the same script on
every push touching the plugin, plus weekly.

## Known weaknesses

- **agent_type is the whole mechanism.** Rename an agent without updating the
  matching branch in every hook and that agent silently loses its gate.
  `harness-gate` hunts for exactly this.
- **The Bash denylists leak.** `bash-write-guard` and `infra-readonly` catch
  common shapes, not every shape. Pair `infra-readonly` with `permissions.deny`
  in the host project's `settings.json`, which Claude Code enforces itself.
- **improver's eval numbers are synthetic.** They say "this edit did not make
  things worse", not "this helps in production". The honest health metric is
  the share of tasks that finish green without your intervention.
- **Subagent transcripts expire** (default 30 days). `improver` must extract
  telemetry before it analyses routing.

## Verify the hook payload shapes once

The hooks parse the payload with `jq`; field names are not guaranteed across
Claude Code versions. Once per hook type, swap in the debug helper in
`hooks/hooks.json`:

```
{ "type": "command",
  "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/_payload-debug.sh pretool-bash" }
```

Trigger the tool, read `/tmp/claude-hook-payload-pretool-bash.json`, correct
the jq paths (`.agent_type`, `.tool_input.command`, `.tool_input.file_path`,
`.tool_input.skill`) if they have moved.
