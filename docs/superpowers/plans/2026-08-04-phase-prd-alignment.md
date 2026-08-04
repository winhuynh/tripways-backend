# Phase PRD Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align all active P0–P3 documents with the current P0A delivery state and implemented
backend architecture.

**Architecture:** Roadmaps own phase status, PRDs retain detailed future requirements, and
acceptance files own dated evidence. Early code foundations are explicitly non-acceptance work.

**Tech Stack:** Markdown product and technical documentation, repository source inspection, ripgrep,
Prettier.

---

### Task 1: Align roadmap status and scope

- [ ] Mark P0A in progress and P0B/P1/P2/P3 not started in both roadmaps.
- [ ] Replace one-stop-only scope with zero-to-three-stop discovery.
- [ ] Separate early foundations from accepted phase outcomes.

### Task 2: Align P0 requirements and evidence

- [ ] Update P0 and P0A architecture to unified page/search read models.
- [ ] Rewrite the stale P0A acceptance snapshot as current in-progress evidence.
- [ ] Mark P0B not started and preserve its detailed future gates.

### Task 3: Align future PRDs

- [ ] Mark product and technical P1–P3 not started.
- [ ] Add current-foundation notes without claiming phase progress.
- [ ] Update P2 to zero-to-three stops and keep P3 live offers distinct from estimates.

### Task 4: Verify documentation consistency

- [ ] Scan active P files for stale endpoint names, source SHAs, test counts, and one-stop-only scope.
- [ ] Run Prettier and `git diff --check`.
- [ ] Do not commit, push, deploy, or change runtime code.
