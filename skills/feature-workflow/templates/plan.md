# Plan: <feature>

- **Spec:** docs/specs/<feature>.md (must be `Status: approved` before this plan is written)
- **Status:** draft | approved
- **Approved by / date:** <human> / <date>

## Approach

Two or three sentences: the shape of the change and why this way over the
alternatives.

## Changes, in dependency order

### 1. <package/file> — <what>

- New types / interfaces / signatures:
- Behaviour:
- Test level: unit | integration (testcontainers) | contract | fuzz
- Depends on: none | step N
- Risk: what could break here, or "low"

### 2. ...

## Sequencing

- Lands first: step ...
- Independent, parallelizable: steps ...

## Test strategy

- Per acceptance criterion → which step's tests cover it
- Fixtures / containers needed:

## Definition of Done

- [ ] Spec + plan approved before implementation began
- [ ] Every acceptance criterion maps to a passing test
- [ ] go-qa-verifier → PASS, 0 failing packages, 0 unexplained skips
- [ ] Coverage on changed packages did not regress
- [ ] go-reviewer → no blocking findings
- [ ] gofmt / build / vet / golangci-lint clean
- [ ] govulncheck ./... clean
- [ ] Plan and spec still match what shipped
- [ ] Migrations and rollback documented in the spec
- [ ] Diff contains no out-of-scope changes
