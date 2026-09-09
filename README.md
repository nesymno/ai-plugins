# prod-ready-go-coding

A Claude Code plugin: seven scoped Go agents, hard skill allowlists, and
hooks that enforce the boundaries the prompts describe. Prompts persuade; hooks
enforce.

## Install

```
/plugin marketplace add nesymno/ai-plugins
/plugin install prod-ready-go-coding@nesymno
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
and in `hooks/skill-allowlist.sh` resolve. It also installs
[ripwire](https://github.com/redhat-et/ripwire) - the binary plus its agent
skills - unless `NESYMNO_SKIP_RIPWIRE=1` or a `ripwire` is already on PATH.

You do not need to clone this repo to run that script: installing the plugin
already put it on disk. `"$CLAUDE_PLUGIN_ROOT"/scripts/install-skills.sh` from
any session works, and the clone above is only for reading the source first.

## Retrieval: ripwire instead of grep

Agents that grep a repo spend their context on text they never use. This plugin
routes them onto [ripwire](https://github.com/redhat-et/ripwire), a
deterministic ranked call graph over the repo (~0.3 s to index, ~0.1 s a query,
21 languages), and then **enforces the route** rather than suggesting it.

Enforcing rather than suggesting is deliberate. ripwire ships its own advisory
PreToolUse nudge and its authors retired it on 2026-09-02 after a randomized
A/B measured both nudge tiers inert; their notes put passive skill-description
triggering at ~30-50% reliable. An agent with grep available uses grep. So
`context-discipline` denies and names the replacement verb.

| Piece | What it does |
|---|---|
| `.mcp.json` | starts `ripwire --mcp` as a persistent index server through `scripts/ripwire-mcp.sh` |
| agent `tools:` | each agent gets only the verbs its role needs; no agent gets the three edit verbs |
| `context-discipline` | blocks the Grep tool and recursive `grep`/`rg`/`find -name` in Bash |
| `read-budget` | caps whole-file `Read` per agent per session; ranged reads are free |
| `bash-write-guard` rule 8 | keeps read-only agents out of ripwire's writing verbs |

Both new hooks **self-disable when `ripwire` is not on PATH**, so the plugin
degrades to its previous behaviour instead of breaking; `session-start` says so
once per session.

Every ripwire count is a floor, not a total. In Go specifically, a call through
an interface produces no edge - `agents/go-reviewer.md` carries the full limits
section, and the reviewer is required to say so rather than report a false
clean.

## Agents

| Agent | Model | Preloaded | Enforced by |
|---|---|---|---|
| go-coder | sonnet | golang-safety | go-check, skill-allowlist |
| go-coder-fast | haiku | - | go-check, no Skill tool |
| go-reviewer | opus | golang-safety, golang-concurrency | go-precheck gate, bash-write-guard, skill-allowlist |
| go-qa-automation | sonnet | golang-testing, golang-stretchr-testify | test-integrity, skill-allowlist |
| go-qa-verifier | haiku | - | bash-write-guard, read-only tools |
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
| skill-allowlist | PreToolUse:Skill | go-coder, go-reviewer, go-qa-automation, improver | per-agent lazy-skill allowlist |
| bash-write-guard | PreToolUse:Bash | go-reviewer, go-qa-verifier, harness-gate | keep a read-only agent read-only |
| config-guard | PreToolUse:Edit\|Write | improver | block edits to agents/hooks/harness/settings → write a proposal |
| go-check | PostToolUse:Edit\|Write | any (Go files only) | gofmt / build / vet / golangci-lint |
| test-integrity | PostToolUse:Edit\|Write | any (`*_test.go` only) | block weakening a test |
| context-discipline | PreToolUse:Grep\|Bash | go-coder, go-reviewer, go-qa-automation, go-qa-verifier, harness-gate | block repo-wide text search; name the ripwire verb (off without ripwire) |
| read-budget | PreToolUse:Read | same five | cap whole-file reads per session; ranged reads uncounted (off without ripwire) |
| session-start | SessionStart | - | run verify-gates, warn if a gate is broken or ripwire is missing |
| telemetry | SubagentStop | - | append one line per finished subagent for `improver` |

`hooks/go-precheck.sh` is not a hook; `go-reviewer` runs it by hand as its
first step.

## Feature workflow

The agents execute; they do not plan. The `feature-workflow` skill (also
`/nesymno:feature-workflow`) is the request-to-prod-ready runbook: intake,
spec, plan, then the dispatch sequence across `go-coder`, `go-qa-automation`,
`go-qa-verifier`, and `go-reviewer`, with the gate that fires at each step and
a definition of done. Spec and plan templates live in
`skills/feature-workflow/templates/`. It runs on the main thread, so no
`skill-allowlist` entry and no `install-skills.sh` change is needed.

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
- **The Bash denylist leaks.** `bash-write-guard` catches common shapes, not
  every shape. Pair it with `permissions.deny` in the host project's
  `settings.json`, which Claude Code enforces itself.
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
