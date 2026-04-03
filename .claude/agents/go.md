---
name: go
description: |
  Project orchestrator skill. Routes development tasks to the right agent chains.
  Invoke with /go before any non-trivial task.
---

# Dev Workflow Orchestrator

**Announce at start:** "I'm using the /go orchestrator to plan and route this task."

---

## Step 0: Session Warm-Up (always first)

Before classifying the task, run two quick checks:

1. **Episodic memory** — search past conversations for similar tasks:

   > 🔧 Skill: `Serena read_memory` — "Find past decisions related to: [task topic]"
   >
   > **Fallback (no Serena):** `episodic-memory:search-conversations` or skip if unavailable.
   >
   > **Skip when ALL of these are true:** single-line change, no API involved, no new files.
   > **Run when ANY is true:** new library/API, new module, architectural decision, recurring pattern, same error seen before.

2. **Task list** — check for existing related work:
   > Call `TaskList`.
   >
   > **If related open tasks found:**
   >
   > - Tasks still pending: mention them, ask user "should I continue those or start fresh?"
   > - Tasks blocked: check if current request unblocks them — if yes, route to that chain
   > - Tasks in_progress: note active work, don't duplicate scope
   > - Tasks completed: use as context, don't recreate
   >
   > **Empty list:** proceed normally — no notes needed

---

## Step 1: Classify the Task

Read the user's request. Assign exactly one category:

| #   | Category              | Keywords / Signals                                                                                                              |
| --- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| A   | **Bug**               | error, crash, traceback, broken, not working, deploy fail, 403/401, won't start                                                |
| B   | **Feature**           | add, implement, new module, new dashboard, new handler, integrate, improve, enhance                                             |
| C   | **Review**            | review, check code, before PR, ready to merge, is it ok?                                                                        |
| D   | **Architecture**      | how to structure, where to put, split, trade-off, monolith, decompose, should I split                                           |
| E   | **Tests**             | enough tests?, edge cases, coverage, what tests to write, boundary cases                                                        |
| F   | **Deploy/Merge**      | push, merge, deploy, ready to deploy, ship it                                                                                   |
| G   | **Text/Copy**         | proofread, sounds like chatgpt, notification text, README text, rewrite copy                                                     |
| H   | **Refactor**          | refactor, simplify, remove duplication, rename, improve structure, file too big                                                  |
| I   | **Research/Question** | how does it work, explain, which is better, should I use X, just a question, no changes needed                                  |

If multiple categories → use **first match** (A before B, B before C...).

> **Note:** "should I..." alone → category I (question). "should I split/decompose..." → category D (architecture).
> **Note:** "improve" without clear spec → category B (Feature), but brainstorming will determine actual scope. May re-classify to H (Refactor) or D (Architecture) after brainstorming.

> **After brainstorming:** if brainstorming reveals the task is different from the initial category — re-classify before selecting chain.

---

## Step 2: Select Chain

> **Notation:**
>
> - 🔧 `skill-name` = invoke as skill in main context (no agent spawn, runs synchronously)
> - 🤖 `agent-name` = spawn as subagent via Agent tool
> - 📋 `Plan Mode` = EnterPlanMode → read-only (Write/Edit/Bash blocked) → plan → ExitPlanMode → user approval
> - `[in main context]` = Claude does this step directly

> **Brainstorming handoff:** After `superpowers:brainstorming` completes, capture and pass forward:
>
> - Confirmed goal (1 sentence, refined from user's original request)
> - Key requirements and constraints discovered during brainstorming
> - Any re-classification of task type
>   These become the INPUT CONTEXT for the planning step (task-planner).

---

### A. Bug → Fix Chain

```
SEQUENCE:

1. 🔧 superpowers:systematic-debugging  → classify bug type before touching code
2. 🤖 test-runner    → "Reproduce: run failing tests, identify exact failure point.
                        If all tests pass → write a minimal reproduction test first,
                        then re-run to confirm it fails before proceeding."
3. 🤖 debugger       → "Root cause: use test-runner output + systematic-debugging classification"
4. [in main context] fix the code (apply minimal fix — match scope to bug, no refactoring)
   [if fix requires changes in 3+ files → STOP, surface to user: describe fix scope + ask confirmation before proceeding]
5. ══ COMPLETION GATE (mandatory, see below) ══
```

**Escalation:** if debugger can't find root cause in 2 turns → STOP, surface to user with:

- What was tested
- What was ruled out
- What information is missing

---

### B. Feature → Build Chain

Assess complexity tier first:

| Tier              | Signal                                                                                              | Chain                                                    |
| ----------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Small**         | 1-3 files, all existing, spec is clear, no research needed                                          | task-planner skill → executing-plans                     |
| **Medium**        | new module OR new dependency OR 4-8 files, but architecture is obvious (existing pattern to follow) | task-planner skill → executing-plans                     |
| **Large/Complex** | 2+ new modules with cross-cutting concerns OR architecture decision is non-obvious OR 9+ files      | software-architect → task-planner skill → executing-plans |
| **Epic**          | Full subsystem, multi-phase rollout, would need >6 subtasks for a single feature                    | Large chain, but task-planner splits into phases (Phase 1 first, return for Phase 2) |

**Key question: "Do I need an architect to decide HOW to structure this?"**

- If existing codebase has a repeating pattern and the new module follows it → **Medium** (no architect needed).
- If the structure is genuinely unclear, or modules interact in new ways → **Large** (architect first).
- **When in doubt about tier → always go one tier up.**

```
SMALL FEATURE — SEQUENCE:

0. 🔧 superpowers:brainstorming  → explore intent + requirements before planning
   [capture output: goal + requirements → pass to task-planner as context]
   [re-classify if brainstorming reveals different task type]
1. 🔧 task-planner skill   → decompose into subtasks (TaskCreate with dependencies)
2. 🔧 superpowers:executing-plans  → implement full plan in batches
   [Source: TaskList — tasks created by task-planner in step 1]
   2a. For each implementation task: 🔧 superpowers:test-driven-development
       → write failing test FIRST, then implement until test passes
       → this is NOT optional — TDD is the default workflow for all T_impl tasks
3. ══ COMPLETION GATE (mandatory, see below) ══

MEDIUM FEATURE — SEQUENCE:

0. 🔧 superpowers:brainstorming  → explore intent + requirements before planning
   [capture output: goal + requirements → pass to task-planner as context]
   [re-classify if brainstorming reveals different task type]
1. 🔧 task-planner skill   → decompose into subtasks (TaskCreate with dependencies)
   [task-planner handles Medium tier — includes web research, Context7 docs]
2. 📋 PLAN APPROVAL GATE (mandatory for Medium/Large, see below)
3. 🔧 superpowers:executing-plans  → implement full plan in batches
   [Source: TaskList — tasks created by task-planner in step 1]
   3a. For each implementation task: 🔧 superpowers:test-driven-development
       → write failing test FIRST, then implement until test passes
       → this is NOT optional — TDD is the default workflow for all T_impl tasks
4. ══ COMPLETION GATE (mandatory, see below) ══

LARGE/COMPLEX FEATURE — SEQUENCE:

0. 🔧 superpowers:brainstorming  → explore intent + requirements before planning
   [capture output: goal + requirements → pass to software-architect as context]
   [re-classify if brainstorming reveals different task type]
1. 🤖 software-architect   → "Design module: structure, interfaces, file list, ADR"
2. 🔧 task-planner skill   → decompose based on architect output (TaskCreate with dependencies)
3. 📋 PLAN APPROVAL GATE (mandatory for Medium/Large, see below)
4. 🔧 superpowers:executing-plans  → implement full plan in batches
   [Source: TaskList — tasks created by task-planner in step 2]
   4a. For each implementation task: 🔧 superpowers:test-driven-development
       → write failing test FIRST, then implement until test passes
       → this is NOT optional — TDD is the default workflow for all T_impl tasks
5. ══ COMPLETION GATE (mandatory, see below) ══
```

---

### Plan Approval Gate (MANDATORY for Medium/Large features)

**This gate runs after task-planner returns the plan. NEVER skip it.**
**Does NOT apply to Small features (task-planner handles those directly).**
**Uses Claude Code's native Plan Mode — Write/Edit/Bash are BLOCKED until user approves.**

```
PLAN APPROVAL GATE — SEQUENCE:

1. Call `EnterPlanMode` tool
   → Write, Edit, Bash tools are now BLOCKED
   → Only read-only tools available (Read, Glob, Grep, WebSearch, WebFetch)

2. Present the plan summary to the user:
   - Goal (1 sentence)
   - Recommended approach + key design decisions
   - Subtask list with dependencies (T1 → T2 → ...)
   - Risks + mitigations
   - Files to create/modify

3. Call `ExitPlanMode` tool → triggers native approval dialog
   [User sees the plan and must explicitly approve]

4. On Approve → Write/Edit/Bash UNBLOCKED → proceed to executing-plans
   On Reject → remain in Plan Mode → adjust plan per user feedback → re-submit ExitPlanMode
```

**Why this gate exists:**
- Write/Edit/Bash are **physically blocked** — not just an instruction, a hard constraint
- executing-plans cannot start until user approves via ExitPlanMode
- Catches wrong assumptions, unnecessary complexity, or missing requirements
- Cheaper to fix the plan than to fix the code

**Fallback:** if EnterPlanMode/ExitPlanMode tools are unavailable (older Claude Code version),
fall back to manual approval: present plan + ask "Approve / Modify / Reject" explicitly

---

### Completion Gate (MANDATORY for all chains that produce code)

**This gate runs after ALL implementation is done. It is NOT optional. NEVER skip it.**
**Applies to: Feature (S/M/L), Bug, Refactor chains.**

```
COMPLETION GATE — SEQUENCE:

1. 🤖 test-runner (parallel) ∥ 🤖 code-reviewer (parallel)
   test-runner:    "Run FULL test suite. Report: total passed/failed, new test count, any regressions."
   code-reviewer:  "Review ALL changes on this branch vs main (git diff main...HEAD).
                    Apply PR Test Coverage Checklist. Verdict: Approve / Request Changes."
   [Multi-feature PRs: launch one code-reviewer per feature scope (parallel OK
    if reviewers touch completely different files)]

2. [if test-runner RED → route to Bug chain (A), fix, then restart gate]
   [if code-reviewer has Critical findings → fix in main context, re-run step 1]
   [if code-reviewer has non-critical findings → fix in main context, proceed to step 3 (no restart needed)]

3. 🤖 test-analyst → "Given test-runner output + code-reviewer findings:
                       Verify test coverage is adequate:
                       - [ ] Unit tests for every new function/helper
                       - [ ] Integration tests for orchestrators with mocked deps
                       - [ ] Setup/teardown resets cache/state between tests
                       - [ ] Smoke test for new modules
                       - [ ] E2E test: browser or integration test covering user-facing flow
                       Return: gap list as [ ] TODOs or PASS."

4. [if test-analyst finds gaps → write missing tests → re-run test-runner to verify]

── HARD GATE: steps 1-4 must ALL be green before proceeding ──

5. 🔧 superpowers:verification-before-completion → MANDATORY final check
   [This is NOT redundant with test-runner. It confirms:
    - tests green RIGHT NOW (not from a previous run)
    - no uncommitted changes left behind
    - no TODO/FIXME introduced during fixes]
   [SKIP = gate failure. Cannot proceed to step 6 without this step.]

6. 🔧 superpowers:finishing-a-development-branch → commit → PR
   [ALWAYS create PR, never push directly to main]
   [PR description must include: what changed, test count before/after, modules affected]
```

**Gate exit criteria (ALL must be true):**

- Full test suite passes (0 failures)
- code-reviewer verdict: Approve (or Approve with suggestions)
- Test coverage adequate (checked by test-analyst)
- `verification-before-completion` explicitly invoked and passed
- PR created on GitHub (not direct commit to main)

---

### C. Review → Quality Chain

```
PARALLEL (launch simultaneously — all 3 need only independent inputs):

🤖 test-runner    "Run full test suite. Report: pass/fail + coverage + flaky"
🤖 code-reviewer  "Review: correctness, security, async patterns, PR checklist"
🤖 test-analyst   "Given current test files + source code: identify coverage gaps and missing edge cases.
                   Return: gap list as [ ] TODOs with test level (unit/integration/E2E).
                   DONE WHEN: gap list produced, each item has clear test case description."

After all complete (SEQUENCE):
[if test-runner shows failures → route to Bug chain (A) before synthesizing verdict]

[in main context] synthesize → verdict: ✅ READY / ⚠️ NEEDS FIXES (itemized list)
```

> **Why all 3 parallel here:** In Review chain, test-analyst analyzes test FILE coverage (static analysis of what's tested), not test-runner output. So it runs parallel with test-runner and code-reviewer. Contrast with Completion Gate where test-analyst uses test-runner output + code-reviewer findings (sequential).

---

### D. Architecture → Design Chain

```
SEQUENCE:

0. 🔧 superpowers:brainstorming  → clarify the design question, explore constraints
   [capture: what decision needs to be made, what constraints apply, what options exist]
1. 🤖 software-architect  "Analyze trade-offs. Return: ADR (Context→Options→Decision→Consequences)"

No implementation follows unless user explicitly confirms direction.
If user confirms → escalate to Feature chain (B).
```

---

### E. Tests → Coverage Chain

```
SEQUENCE:

1. 🤖 test-analyst  → "Analyze tests in [SCOPE: tests/{module}/ directory].
                        Apply BVA/EP/STT. Return: gap list as [ ] TODOs.
                        Focus on: edge cases, error paths, boundary values."
   [IMPORTANT: always specify which test directory/module to analyze]
2. 🤖 general-purpose → "Write missing tests from gap list.
                          Invoke superpowers:test-driven-development for each test case.
                          Pattern source: pick closest existing test file from Step 1 output."
3. 🤖 test-runner   → "Run new tests. Confirm all pass. Check no regressions."
4. [optional] 🤖 code-reviewer → "Review test files only — check for flaky patterns,
   incorrect assertions, missing cleanup fixtures."
```

---

### F. Deploy/Merge → Ship Chain

```
SEQUENCE:

0. [in main context] check git status + current branch → confirm working tree is clean
   [on main/master → warn user: deploying directly from main is unusual, confirm intent]
   [uncommitted changes found → do NOT stash-and-deploy:
    - New feature code → finish via Chain B (Feature) first
    - Messy/unfinished changes → finish via Chain H (Refactor) first
    - Only hotfix/debug artifacts (console.log etc.) → stash and proceed]
1. 🤖 test-runner                        → "Full suite must be green. Report any failures."
2. [if red → go to Bug chain (A)]
3. 🔧 superpowers:verification-before-completion → final confirmation: tests green, repo clean
   [if verification fails → STOP, do NOT present deploy options. Fix issues first.]
4. 🔧 superpowers:finishing-a-development-branch → present options: merge / PR / squash
5. [execute on user confirmation]
```

---

### G. Text → Polish Chain

```
STANDALONE:
🤖 text-polisher  "Polish: proofread, before/after, name antipatterns"
```

---

### H. Refactor → Clean Chain

```
SEQUENCE:

0. 🔧 superpowers:brainstorming  → clarify refactor scope and goals
   [capture: what changes, what must stay intact, performance/correctness constraints]
1. 🤖 software-architect  → "Identify refactor boundaries. What changes, what stays.
                              Return: file list + refactor approach."
2. 🔧 superpowers:writing-plans → write formal plan file from architect output
   [Output: plan file path — pass this to executing-plans in next step]
3. 🔧 superpowers:executing-plans → refactor in batches (reads from plan FILE, not TaskList)
   [Input: plan file path from step 2; small commits, one concern at a time]
4. ══ COMPLETION GATE (mandatory, see above) ══
```

---

### I. Research/Question → Answer Only

```
STANDALONE — no implementation:

Codebase question (how does X work, where is Y defined):
→ 🤖 Explore agent  "Read codebase to find answer. Return: explanation + file references."

External knowledge — simple one-off question (library choice, API format, best practice):
→ [in main context] WebSearch + answer directly

External knowledge — research that feeds a feature plan (complex trade-offs, new API evaluation):
→ [in main context] WebSearch + Context7 docs → summarize findings + recommendation
  [If research confirms a feature is needed → route to Feature chain (B)]

No code changes unless user explicitly requests.
```

---

## Step 3: Handoff Protocol

When launching each agent, ALWAYS provide these 5 fields:

```
OBJECTIVE      — exact goal (1-2 sentences, imperative)
INPUT CONTEXT  — output from previous agent (summarized, not raw logs)
SCOPE          — which files/modules to touch (explicit paths)
OUTPUT FORMAT  — what to return: summary / verdict / file list / gap list / TaskCreate calls
DONE WHEN — how to know the task is done (verifiable condition or command)
```

**Good handoff example (test-runner → debugger):**

```
OBJECTIVE: Find root cause of assertion failure in API client.
INPUT CONTEXT: test-runner output — AssertionError at src/services/__tests__/client.test.ts:88
  Expected: 50_100_000.0, Got: undefined. Test: test_fetch_returns_expected_data
SCOPE: src/services/client.ts, src/services/__tests__/client.test.ts
OUTPUT FORMAT: root cause (1 paragraph) + minimal fix recommendation
DONE WHEN: explains WHY assert fails, not just where
```

**Good handoff example (architect → task-planner):**

```
OBJECTIVE: Decompose the new Dashboard module into implementation tasks.
INPUT CONTEXT: architect output — ADR confirmed: 4-file module (models/client/init/formatter),
  External API, reuse existing HTTP helper, no new dependencies.
SCOPE: src/features/dashboard/ (new), src/features/dashboard/__tests__/ (new), src/app.ts (wire)
OUTPUT FORMAT: TaskCreate calls + dependency graph
DONE WHEN: all tasks created with blockedBy set, ready for executing-plans
```

**Bad handoff (don't do this):**

```
"Fix the failing test" ← no context, no scope, no success criteria
```

---

## Step 4: Parallelization Rules

**ALWAYS parallel (`∥` = run simultaneously):**

- 🤖 `test-runner` ∥ 🤖 `code-reviewer` (Completion Gate step 1 + Review chain: independent concerns)
- 🤖 `test-runner` ∥ 🤖 `code-reviewer` ∥ 🤖 `test-analyst` — **only in Review chain (C)**
  _(In Review chain: test-analyst does static coverage analysis of test files, no dependency on runner/reviewer output)_
  _(In Completion Gate: test-analyst needs test-runner output + code-reviewer findings → sequential after both)_
- Multiple 🤖 `code-reviewer` agents — one per feature scope in multi-feature PRs
  (OK because each reviewer reads different files; merge fixes sequentially after all return)
- Two implementation tasks touching **completely different files** → use `superpowers:dispatching-parallel-agents`

**NEVER parallel:**

- 🤖 `test-analyst` after 🤖 `test-runner` — analyst needs runner output to analyze coverage
- 🤖 `debugger` after 🤖 `test-runner` (needs test output)
- 🤖 `code-reviewer` after 🔧 `executing-plans` (needs implementation first)
- Any two agents touching the same file

---

## Step 5: Checkpoint Protocol

After EACH agent completes — summarize before passing forward. Never pass raw verbose output.

Final status — pick exactly one:

- ✅ **DONE** — what was done, tests pass, ready to commit
- ⚠️ **NEEDS INPUT** — decision required from user (list 2-3 options)
- ❌ **BLOCKED** — what blocks, what information is missing, what to try next

**After code-reviewer returns:**

- No issues found → ✅ DONE — proceed to commit/PR
- Issues found (non-critical) → fix in main context → re-run 🤖 test-runner to verify → done
- Critical or systemic issues (2+ files affected) → escalate to user (see Escalation Protocol below)

---

## Escalation Protocol

Stop and surface to user when:

- Same agent fails twice in a row (crashes, returns wrong output, or exhausts retries)
- Test-runner shows >3 new failures after a fix
- Test-runner fails to start at all (import errors, syntax errors before any test runs) → diagnose import chain, do not retry blindly
- debugger can't isolate root cause after 2 hypotheses
- code-reviewer finds ANY critical security/correctness issue, or systemic issues across 2+ files

When escalating, always provide:

```
ATTEMPTED: [list what was tried]
RULED OUT: [list eliminated causes]
CURRENT STATE: [what's broken right now]
NEED FROM USER: [specific decision or information]
```

---

## Recovery Protocol (Context Compaction)

When context compaction occurs mid-execution (background agents lost, partial state):

0. **Check for plan file first** — Refactor chain uses plan FILE, not TaskList:

   > `Glob pattern="docs/plans/*.md"` — if a plan file exists, resume from it (not TaskList).
   > If multiple plan files found → pick the most recently modified. If ambiguous → ask user.

1. **Assess state** — check TaskList + `git status` + Glob for new/changed files
   - TaskList shows completed tasks → use as progress marker
   - New files on disk but no tests → implementation started, tests pending
   - Tests exist and pass → task likely complete
   - TaskList empty but plan file exists → Refactor chain, resume from plan file

2. **Verify disk state** — run test suite to confirm what works

3. **Resume from TaskList** — update task statuses based on assessment:
   - Files exist + tests pass → mark completed
   - Files exist + no tests → mark in_progress
   - No files → leave as pending

4. **Continue chain** — pick up from the earliest incomplete task.
   Do NOT restart the chain from scratch.
   Do NOT re-run brainstorming or task-planner — their output is in TaskList.

---

## Project Tools Inventory

### Custom Agents (`.claude/agents/`)

| Agent | Model | Use For |
|-------|-------|---------|
| `software-architect` | **opus** | Architecture design, trade-offs, ADR, decomposition |
| `performance-profiler` | sonnet | Bundle size, render perf, N+1 queries, Web Vitals |
| `code-reviewer` | sonnet | Post-implementation review, OWASP, async patterns, PR checklist |
| `debugger` | sonnet | Root cause analysis, error investigation |
| `test-analyst` | sonnet | Test gap analysis, BVA/EP/STT edge cases, test plans |
| `test-runner` | sonnet | Run tests, flaky diagnosis, pass/fail report |
| `text-polisher` | sonnet | Text quality, before/after rewrites |

> **Note:** Add domain-specific agents as needed (e.g., `gamification-expert`, `content-team`,
> `design-team`, `question-validator`). Update this table when adding new agents.

### Built-in Agents

| Agent | Use For |
|-------|---------|
| `Explore` | Fast read-only codebase search (Haiku, cheap) — codebase questions only |
| `general-purpose` | Full tools, any complex multi-step operation |

### Project Skills (`.claude/skills/`)

| Skill | Invoke | Use For |
|-------|--------|---------|
| `go` | `/go` | This orchestrator |
| `task-planner` | `/task-planner` | Research + TaskCreate for all feature tiers |

### Superpowers Skills

| Skill | When |
|-------|------|
| `superpowers:brainstorming` | Step 0 of every Feature + Architecture + Refactor chain — explore intent before planning |
| `superpowers:test-driven-development` | Within T_impl — write failing tests first, then implement |
| `superpowers:systematic-debugging` | At start of any bug investigation |
| `superpowers:verification-before-completion` | Before declaring anything DONE |
| `superpowers:finishing-a-development-branch` | When ready to merge/push |
| `superpowers:writing-plans` | Between architect output and executing-plans (Refactor chain) |
| `superpowers:executing-plans` | When executing a written multi-step plan |
| `superpowers:subagent-driven-development` | When executing plan with independent parallel tasks in current session |
| `superpowers:dispatching-parallel-agents` | When 2+ independent tasks can run in parallel |
| `Serena read_memory` | Search past session decisions (🔧 skill, runs in main context) |

---

## Quick Reference

```
🔧 = skill (main context)   🤖 = agent (spawned)   ∥ = parallel
📋 = PLAN APPROVAL GATE: present plan → user Approve/Modify/Reject
🚪 = COMPLETION GATE (mandatory): 🤖test-runner ∥ 🤖code-reviewer → 🤖test-analyst → 🔧verification → 🔧finishing-branch → PR

Bug?          🔧systematic-debugging → 🤖test-runner → 🤖debugger → fix → 🚪
Feature S?    🔧brainstorming → 🔧task-planner → 🔧executing-plans → 🚪
Feature M?    🔧brainstorming → 🔧task-planner → 📋 → 🔧executing-plans → 🚪
Feature L?    🔧brainstorming → 🤖architect → 🔧task-planner → 📋 → 🔧executing-plans → 🚪
Review?       🤖test-runner ∥ 🤖code-reviewer ∥ 🤖test-analyst → verdict
Architecture? 🔧brainstorming → 🤖software-architect → ADR (standalone)
Tests?        🤖test-analyst [SCOPE] → 🤖general-purpose → 🤖test-runner
Refactor?     🔧brainstorming → 🤖software-architect → 🔧writing-plans → 🔧executing-plans → 🚪
Deploy?       [main]git-status → 🤖test-runner → 🔧verification → 🔧finishing-branch → PR
Text?         🤖text-polisher (standalone)
Codebase Q?   🤖Explore (no changes)
Simple Q?     [in main context] WebSearch → answer
Research Q?   [in main context] WebSearch → findings → route to Feature if needed
```
