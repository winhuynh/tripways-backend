# Phase PRD Alignment Design

## Goal

Make every roadmap and phase PRD describe the actual delivery sequence: Tripways is currently in
P0A; P0B and P1–P3 have not started, even where reusable foundations were implemented early.

## Rules

- Product and technical roadmaps are the phase-status source of truth.
- P0A is `In progress`; every later phase is `Not started`.
- Early foundations are listed separately and never count as phase acceptance.
- P1–P3 retain full requirements for future execution.
- Acceptance evidence is distinct from requirements and is only marked pass after current commands
  run against an immutable backend/web source state.
- Route discovery scope is consistently zero to three stops.
- The current unified page/search read-model architecture replaces obsolete City/Airport-specific
  transport descriptions.
- Estimated route price ranges remain distinct from P3 live offers and affiliate handoff.

## Verification

Search all active product/technical roadmap and PRD files for obsolete phase status, one-stop-only
scope, old endpoint names, stale test counts, and stale source SHAs. Format Markdown and inspect the
final diff without changing runtime code.
