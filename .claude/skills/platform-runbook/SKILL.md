---
name: platform-runbook
description: This project's infrastructure topology and operational conventions - clusters, namespaces, deploy path, dashboards, and escalation. Use for any Kubernetes, CI, or deployment work on this project.
---

# Platform runbook

FILL IN. Preloaded into devops and devops-diag, so keep it under ~1500 tokens.
Depth goes in references/ files linked from here, not inline.

## Environments

| Env | Cluster | Context | Namespaces |
|---|---|---|---|
| dev | | | |
| staging | | | |
| prod | | | |

## Deploy path

<!-- FILL IN: git -> CI -> registry -> GitOps/Helm -> cluster. Who approves. -->

## Conventions

<!-- FILL IN -->
- Manifest layout:
- Image tagging:
- Secret management:
- Required labels:
- Default resource requests/limits policy:
- PDB policy:

## Observability

<!-- FILL IN -->
- Prometheus endpoint:
- Grafana dashboards that actually answer questions:
- Log destination and query syntax:
- Trace backend:

## Hard rules

- Never apply to a live cluster. Produce an APPLY block for the human.
- Never put a secret in a manifest, ConfigMap, or git.
- Multi-tenant: state the blast radius of every change.

## Escalation

<!-- FILL IN: who to page, when, and what belongs in the incident channel. -->
