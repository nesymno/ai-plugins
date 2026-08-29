---
description: Run the nesymno enforcement-gate check (hooks block, fixtures pass, references resolve).
---

Run the plugin's gate verification and report the result:

```
"${CLAUDE_PLUGIN_ROOT}"/harness/verify-gates.sh
```

Expect a final line like `gates: N fixture(s) passed, 0 failure(s), M warning(s)`.

- **failures** must be zero before trusting any agent. Report each `FAIL` line verbatim.
- **warnings** about unresolved third-party skills are expected until `scripts/install-skills.sh` has been run; list them but do not treat them as blocking.
