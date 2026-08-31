---
name: feature-workflow
description: Use when taking a Go feature from request to shipped tested code with this plugin - or when unsure which agent to dispatch next, how the enforcement gates fit the sequence, or where specs and plans belong.
---

# Feature workflow

## Overview

This plugin gives you **execution and enforcement, not planning**. Its agents
are single-purpose and refuse to cross lines: `go-coder` writes no tests and
does not review itself; `go-qa-automation` does not touch production code;
`go-reviewer` reports and never edits. Hooks (`go-check`, `test-integrity`,
`skill-allowlist`, `config-guard`) fire session-wide and
block the shortcuts.

**You are the orchestrator.** Spec, plan, and commit are your job. Everything
between is a dispatch to a scoped agent, followed by a checkpoint you verify
before moving on.

## When to use

- Any change larger than a one-line fix to a Go service that uses this plugin
- You have a feature request and need a repeatable path to prod-ready code
- Mid-flight and unsure which agent comes next

Not for: trivial mechanical edits (dispatch `go-coder-fast` directly), or
plugin-repo changes (`improver`, `harness-gate`).

**Too large for one spec?** If the request spans more than one cohesive
deliverable - multiple independent endpoints, a migration plus a feature, work
that a single reviewer could not judge in one diff - split it into separate
specs and run each through the full sequence. One spec = one feature = one
reviewable PR. Splitting up front beats a plan no reviewer can hold in their
head.

## go-coder vs go-coder-fast

Dispatch `go-coder-fast` (haiku, no Skill tool) only when the task is **fully
specified and machine-checkable**: boilerplate, a mechanical refactor,
generation from an existing pattern - where "done" is `go build`/`vet`/lint
green and nothing else. Anything needing judgment, a new abstraction, or a
reasoning skill goes to `go-coder`. `go-coder-fast` stops and returns the task
if it turns out ambiguous or harder than stated - treat that as a signal to
re-dispatch to `go-coder`, not a failure.

## The sequence

| Phase       | Who                               | Output                            | Gate at this step                                          |
| ----------- | --------------------------------- | --------------------------------- | --------------------------------------------------------- |
| 0 Intake    | you                               | feature branch, ticket, touch-point list | premise sound; size fits one spec                  |
| 1 Spec      | you + `superpowers:brainstorming` | `docs/specs/<feature>.md`         | every criterion testable; **human approves spec (STOP #1)** |
| 2 Plan      | you + `superpowers:writing-plans` | `docs/plans/<feature>.md`         | executable unaided; **human approves plan (STOP #2)**     |
| 3 Implement | `go-coder` (or `go-coder-fast`)   | feature code                      | `go-check`: gofmt/build/vet/golangci-lint green            |
| 4 Tests     | `go-qa-automation`                | tests, worktree-isolated          | `test-integrity`: no skips / weakened asserts             |
| 5 Verify    | `go-qa-verifier`                  | PASS/FAIL report + coverage delta | build + vet + `test -race` clean, 0 unexplained skips     |
| 6 Review    | `go-reviewer`                     | findings list                     | `go-precheck.sh` passes; loop to 3, max 3 rounds then escalate |
| 7 DoD       | you                               | checklist below all green         | `govulncheck` clean                                       |
| 8 Ship      | you                               | commit + PR referencing spec/plan | CI (`agent-gates.yml`) is the backstop                    |

## Phase detail

**0 Intake.** Capture the request verbatim. Grep the touch points (~5 min).
Cut a feature branch off `main` now - `git switch -c feat/<feature>` - so every
later phase has a home and phase 8 has something to PR. If the premise is
wrong, say so now, before anyone plans. Check the size: if it will not fit one
reviewable spec, split it (see "When to use").

**1 Spec.** Drive `superpowers:brainstorming` with the ticket. Fill
`templates/spec.md`. Every acceptance criterion must be phrased as an assertion
a test can check - no "should be fast", give a number. **Then STOP (#1): get
explicit human approval of the spec before writing any plan.** The spec is the
contract; a misread here poisons everything built on it. Mark `Status: approved`
and record the approver before phase 2. Do not draft the plan against an
unapproved spec.

**2 Plan.** With the spec approved, drive `superpowers:writing-plans` with it.
Fill `templates/plan.md`: file-by-file changes in dependency order, new
signatures, test level and risk per change, sequencing, and the DoD. **Then STOP
(#2): get explicit human approval of the plan before dispatching any agent.**
Everything downstream spends real agent budget against these two documents - a
misread caught here is free, caught in phase 6 is not. Mark the plan
`Status: approved` and record the approver before phase 3.

**3 Implement.** The `go-check` hook runs after every edit; the agent lands it
green before continuing. `go-coder` writes no tests by design. For a large
plan, dispatch one section per `go-coder`. Steps the plan marks independent /
parallelizable can be dispatched concurrently - see
`superpowers:dispatching-parallel-agents`. Sequence the dependent ones per the
plan's ordering.

**Keep the docs live.** If implementation reveals the plan is wrong (a
constraint, a missing dependency, a better shape), stop and update
`docs/plans/<feature>.md` - and the spec if scope shifts - before continuing.
The PR links these as the source of truth; a stale plan misleads the reviewer
and the next engineer.

**4 Tests.** Give `go-qa-automation` the spec's acceptance criteria. It runs in
worktree isolation (`isolation: worktree`) - a separate branch/worktree off
your current HEAD, so its writes do not collide with yours. Note the worktree
path and branch it reports. If a test cannot pass honestly it stops and reports
the defect - that is a valid outcome and means phase 3 has a bug.

**5 Verify.** First pull the test worktree's changes into your feature branch,
then verify from your branch:

```
git fetch <worktree-path-or-branch>          # or: cd <worktree> && git push
git merge --no-ff <qa-branch>                # land the tests on feat/<feature>
git worktree remove <worktree-path>          # clean up when merged
```

Then dispatch `go-qa-verifier`. It reports only failures and skips; also have
it report the coverage delta on changed packages so a drop is visible before
review.

**6 Review.** `go-reviewer` runs `hooks/go-precheck.sh` first and stops if
static analysis is not clean. Feed each finding back to `go-coder`. If a fix
changes behaviour, re-run phase 4 for that path. Repeat until the review is
clean - but **cap the loop at 3 rounds**. If it has not converged by then, or
`go-coder` and `go-reviewer` disagree on whether a finding is real, stop and
escalate to a human with both positions. A loop that will not close is a design
problem, not a code problem.

**7 DoD.** Walk the checklist below yourself. Run `govulncheck ./...` - it is
not in the `go-check` hook, so nothing else catches a vulnerable dependency
before ship. Nothing merges with an item unchecked.

**8 Ship.** Commit message and PR body link `docs/specs/<feature>.md` and
`docs/plans/<feature>.md`. Summarize scope, non-goals, migrations.

## Dispatch prompts

```
go-coder        Implement section N of docs/plans/<feature>.md. Files: [...].
                Follow surrounding package patterns. Spec: docs/specs/<feature>.md.

go-qa-automation Write tests for the acceptance criteria in docs/specs/<feature>.md.
                Production code: [files]. State the level and justify it.
                Report the worktree path and branch you used.

go-qa-verifier  Run the full suite on branch feat/<feature> (tests already merged in).
                Report failures, unexplained skips, and the coverage delta on the
                changed packages. Spec: docs/specs/<feature>.md.

go-reviewer     Review the diff for <feature>. Base: main. Spec: docs/specs/<feature>.md,
                plan: docs/plans/<feature>.md - flag anything that drifts from them.
```

## Definition of Done

- [ ] Spec + plan marked `approved` before implementation began
- [ ] Every acceptance criterion maps to a passing test
- [ ] `go-qa-verifier` → PASS, 0 failing packages, 0 unexplained skips
- [ ] Coverage on changed packages did not regress (delta reported)
- [ ] `go-reviewer` → no blocking findings
- [ ] gofmt / build / vet / golangci-lint clean (gate-enforced; confirm anyway)
- [ ] `govulncheck ./...` clean (not gate-enforced — run it)
- [ ] Plan and spec still match what shipped (updated if it drifted)
- [ ] Migrations and rollback documented in the spec
- [ ] Diff contains no out-of-scope or drive-by changes

## Common mistakes

| Mistake                                                                | Consequence                                                        |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Skipping the spec, going straight to `go-coder`                        | no testable criteria, review has nothing to check against          |
| Letting `go-coder` write its own tests                                 | it will not; the dispatch stalls                                   |
| Treating a `go-qa-automation` "cannot pass honestly" report as failure | it is a real bug found in phase 3                                  |
| Merging with the CI gate red                                           | `agent-gates.yml` is the backstop, not the first check             |
| Dispatching agents before human approves spec+plan                     | budget burned re-doing work against a misread spec                 |
| Verifying without merging the QA worktree into your branch             | verifier runs against code that has no tests; false PASS           |
| Plan drifts during phase 3, doc never updated                          | reviewer and PR reader trust a spec that no longer holds           |
| Shipping without `govulncheck`                                         | no gate scans dependencies; a known CVE reaches prod               |
| Looping phase 6 forever on a contested finding                         | cap at 3 rounds, escalate — it is a design dispute, not a bug      |
| Renaming an agent without updating hooks                               | that agent silently loses its gate (`harness-gate` hunts for this) |
