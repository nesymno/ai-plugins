---
name: task-routing
description: Routing map for this project's agent system - which specialist agent owns which concern, which model tier a task belongs on, and the project's hard constraints. Use when decomposing or delegating work.
---

# Routing map

FILL IN the project-specific sections. Keep this file under ~1500 tokens: it
is preloaded into task-composer on every run.

## Agents

| Agent | Owns | Model |
|---|---|---|
| go-coder | Go production code | sonnet |
| go-coder-fast | mechanical Go work with a machine-checkable gate | haiku |
| reviewer | diff review, read-only | opus |
| qa-automation | writing and repairing tests | sonnet |
| qa-verify | running the suite, reporting failures only | haiku |
| devops | infra-as-code edits, never applies | sonnet |
| devops-diag | read-only cluster and CI diagnosis | sonnet |
| doc-writer | godoc, Examples, ADRs, runbooks | sonnet |

## Model tier test

Route to the -fast variant only when all three hold:

1. A deterministic done-gate exists (compiles / tests green / plan empty /
   buf breaking clean).
2. Inputs are fully specified; no design decision remains.
3. The set of files to touch is known in advance.

Escalate to opus for architecture, security, and anything irreversible.

Never re-route a failed task downward. Escalate or return it to the human.

## Project constraints

<!-- FILL IN -->
- Go version:
- Module path:
- Layout: cmd/ internal/ pkg/
- DI: samber/do
- Errors: samber/oops, codes defined in:
- Logging: zap or zerolog, wired in:
- Transport: gRPC + protobuf, REST + swagger
- Test containers required by packages:
- Protected paths (never edit without a human):

## Standing decisions

<!-- FILL IN. Things agents must not relitigate. -->
