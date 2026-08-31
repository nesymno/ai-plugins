# harness/

Test suite that proves the enforcement hooks in `hooks/` still enforce. If a
guard hook silently breaks — a bad regex, a lost `+x` bit, a missing `jq` — the
protections fail *open* and nobody notices until the day they were supposed to
block something. This suite catches that.

Run it with:

```bash
harness/verify-gates.sh
```

It runs in CI, from the `SessionStart` hook, and via `/nesymno:verify-gates`.

## Layout

```
harness/
├── verify-gates.sh   # the runner
├── cases/            # per-hook behavioural test cases (the assertions)
└── fixtures/         # real on-disk files that some cases point at
```

## `cases/` — behavioural test cases

One directory per hook. The directory name maps to the hook by convention:
`cases/<name>/` is tested against `hooks/<name>.sh`. A case directory with no
matching hook is a failure.

Each `.json` file is one test case:

```json
{ "expect_exit": 2, "input": { "tool_input": { "file_path": "…" } } }
```

| field           | meaning                                                              |
|------------------|----------------------------------------------------------------------|
| `input`          | JSON payload piped to the hook on stdin (the tool-call event)        |
| `expect_exit`    | asserted exit code — `0` = allow, `2` = block                        |
| `expect_stderr`  | optional substring the hook's stderr must contain — asserts it blocks for the *right reason*, not just the right code |
| `args`           | optional CLI args passed to the hook                                 |

The runner does, for every case:

```
jq -c '.input' case.json | hooks/<name>.sh <args>   →   compare $? to expect_exit
```

When the case depends on which agent made the call, that lives in
`input.agent_type`.

### The four guarded behaviours

| case dir           | hook enforces                                                              |
|--------------------|---------------------------------------------------------------------------|
| `bash-write-guard` | blocks destructive bash (`rm`, `git commit`, pipe-to-`sh`, `sed -i`, `tee`, redirect-to-file); allows read-only forms |
| `skill-allowlist`  | allows/denies which skills an agent may invoke                            |
| `config-guard`     | gates who may edit which config files, by `agent_type`                    |
| `test-integrity`   | blocks weakening tests — e.g. introducing a `t.Skip`                      |

## `fixtures/` — real files the cases inspect

Some hooks don't just parse the payload; they read the file named in it and
grep its contents. `test-integrity` is the example: it opens the target `.go`
file and looks for `t.Skip`. The fixtures are those actual files:

| fixture                | shape                       | expected result |
|------------------------|-----------------------------|-----------------|
| `skip_test.go`         | has `t.Skip(…)`             | **block** (2)   |
| `clean_test.go`        | no skip                     | **allow** (0)   |
| `allowed_skip_test.go` | a permitted skip            | **allow** (0)   |

Kept separate from `cases/` so the JSON stays small and the fixture stays real,
grep-able source that the hook can read off disk.

The `.go` fixtures carry a `//go:build harness_fixtures` constraint so a normal
`go build/test ./...` never compiles them — they exist to be read, not run.

`test-integrity` also compares a file against its own git HEAD (its
function-count-drop check). To keep that deterministic regardless of the
caller's branch or uncommitted edits, the runner seeds a throwaway git repo with
a committed copy of `fixtures/` and runs test-integrity's cases against it, so
HEAD and the worktree always match.

## What else verify-gates.sh checks

Beyond the fixture cases, the runner also gates:

1. **`jq` present** — without it every payload-parsing hook degrades to a no-op.
   Missing `jq` is fatal.
2. **Hook `+x` bit** — a hook without the executable bit blocks nothing.
3. **Agent skill references resolve** — every skill named in `agents/*.md` must
   be bundled, installable via `scripts/install-skills.sh`, or a plugin skill.
   Unresolved-but-installable is a WARN; truly unknown is a failure.
4. **`hooks/hooks.json` paths exist and are executable** — no dead references.
5. **Every gate script actually runs somewhere** — each `hooks/*.sh` must be
   wired in `hooks.json` (an event hook) or invoked by an agent/command (a
   standalone gate like `go-precheck.sh`). A script that is neither is orphaned
   and protects nothing. Helpers (leading `_`) are exempt.

It also guards itself:

- **Canary** — before running the fixture cases, the runner proves its own
  evaluator both fails a deliberately-wrong expectation and passes a correct
  one. A silently broken evaluator would otherwise rubber-stamp every case.
- **Per-hook timeout** — each hook runs under `timeout` (or `gtimeout`) when
  available, so a hanging hook can't hang CI. Absent both, hooks run unguarded.

Exit `0` only if there are zero failures. Warnings don't fail the gate.

## Adding a case

1. Pick the hook you're testing → `cases/<hook-name>/`.
2. Add a `.json` with `input` (the payload) and `expect_exit`.
3. If the hook reads file contents, drop the file in `fixtures/` and point
   `input.tool_input.file_path` at it.
4. Run `harness/verify-gates.sh`.
