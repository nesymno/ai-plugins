# Agent system

Eleven scoped agents, hard skill allowlists, and hooks that enforce the
boundaries the prompts describe. Prompts persuade; hooks enforce. Everything
important here is a hook.

## Layout

    .claude/
      settings.json              session policy: deny rules, hooks, skillOverrides
      agents/                    11 agent definitions
      hooks/                     enforcement scripts
      skills/                    project-owned skills (FILL THESE IN)
      harness/verify-gates.sh    proves the hooks still block
      harness/cases/             behavioural fixtures for each hook
      telemetry/agents.jsonl     SubagentStop log, input to routing analysis

## Agents

| Agent | Model | Preloaded | Enforced by |
|---|---|---|---|
| task-composer | opus | task-routing | no gate (see Known weaknesses) |
| go-coder | sonnet | golang-safety, golang-samber-oops | go-check, allowlist |
| go-coder-fast | haiku | golang-safety, golang-samber-oops | go-check, no Skill tool |
| reviewer | opus | golang-safety, golang-concurrency | go-precheck gate, allowlist |
| qa-automation | sonnet | golang-testing, golang-stretchr-testify | test-integrity, allowlist |
| qa-verify | haiku | - | read-only tools |
| devops | sonnet | platform-runbook, conventional-git | infra-readonly, infra-validate |
| devops-diag | sonnet | platform-runbook | infra-readonly, read-only tools |
| doc-writer | sonnet | golang-documentation, conventional-git | config-guard, allowlist |
| skill-smith | sonnet | skill-progressive-disclosure-design | config-guard, allowlist |
| harness-watch | sonnet | - | read-only tools |

## Setup

    ./install-skills.sh                  # third-party skills, read them first
    chmod +x .claude/hooks/*.sh .claude/harness/*.sh
    .claude/harness/verify-gates.sh      # must be green before anything else

Then fill in the two project skills. They are preloaded, so keep each under
~1500 tokens:

    .claude/skills/task-routing/SKILL.md
    .claude/skills/platform-runbook/SKILL.md

Accept the workspace trust prompt for this folder. Until you do, Claude Code
skips frontmatter hooks from project-level agents and only logs it to the
debug log - the agents run, the gates do not.

Run the composer as the main session:

    claude --agent task-composer

## Verify the payload shapes before trusting the hooks

The hooks parse hook input with jq. Field names are not guaranteed across
versions. Once, per hook type, swap in the debug helper:

    command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/_payload-debug.sh pretool-bash"

Trigger the tool, read /tmp/claude-hook-payload-pretool-bash.json, and correct
the jq paths. A hook reading the wrong field exits 0 and blocks nothing.

## Deployment order

Do not switch all eleven on in one day. You will get a result whose cause you
cannot locate.

1. Hooks and fixtures. verify-gates.sh green before the first agent runs.
2. go-coder + qa-verify. Live with the pair for a week.
3. reviewer + qa-automation. Now the write-test-review loop is closed.
4. devops-diag. Read-only, zero risk, immediately useful.
5. task-composer. Only once the specialists are proven individually -
   otherwise you cannot tell a bad agent from bad routing.
6. devops, doc-writer, skill-smith, harness-watch, in any order.

## Rules that shaped this config

Preload is expensive. `skills:` injects full SKILL.md content at startup, not
the description. The upstream budget is 2-4 skills and under ~10k tokens
loaded at once. Every agent here preloads two.

Preload is not restriction. Scoping comes from `disallowedTools: Skill` or the
allowlist hook, never from `skills:` alone.

permissionMode cannot tighten a subagent. If the parent session is in auto
mode the field is ignored outright; bypassPermissions and acceptEdits from the
parent always win. Real limits come from `tools`, hooks, and permissions.deny.

Never set CLAUDE_CODE_SUBAGENT_MODEL. It outranks every `model:` field and
silently disables the whole routing scheme.

Skills marked with deep-reasoning triggers do not belong in a haiku agent.
go-coder-fast has no Skill tool at all, which makes that structural.

## Known weaknesses

**task-composer has no external gate.** Go code is checked by the linter,
infra by dry-runs, tests by the integrity hook. Routing decisions are checked
by nobody. A composer that systematically sends hard work to haiku shows up as
poor output, not as an error. The only feedback loop is telemetry plus the
discipline of recording misroutes in agent memory.

**infra-readonly.sh is a denylist.** Denylists leak. permissions.deny in
settings.json is the real backstop; the hook catches shapes the deny rules
cannot express. Every evasion an agent actually finds should become a new
fixture in harness/cases/infra-readonly/.

**Skill evals measure synthetic cases.** skill-smith's benchmark numbers say
"this edit did not make things worse", not "this helps in production". The
honest health metric is the share of tasks that go from composer to green
without your intervention.

**Subagent transcripts expire.** Default retention is 30 days. Extract
telemetry regularly or the routing analysis has nothing to read.
