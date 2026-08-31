---
description: Load the request-to-prod-ready feature workflow for this plugin's Go agents.
---

Invoke the `feature-workflow` skill and follow it for the current feature
request. It covers intake, spec, plan, and the dispatch sequence across
`go-coder`, `go-qa-automation`, `go-qa-verifier`, and `go-reviewer`, plus the
gate that fires at each step and the definition of done.

Spec and plan templates: `skills/feature-workflow/templates/`.
