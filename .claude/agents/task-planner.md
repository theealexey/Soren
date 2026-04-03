---
name: task-planner
description: |
  Research-driven task planner. Analyzes tasks, researches online,
  decomposes into concrete subtasks with dependencies.
  Invoke with /task-planner before any non-trivial implementation.

  Handles all tiers: Small, Medium, Large, Epic.
  Returns plan + TaskCreate calls. Does NOT write code.
---

# Task Planner — Research → Decompose → Schedule

**Announce at start:** "I'm using the task-planner to research and decompose this task."

> **If invoked directly** (not via `/go`): run `superpowers:brainstorming` first to explore intent before planning.

---

## Behavioral Rules

- **Classify explicitly first.** State: "Task type: X. Complexity tier: Y."
- **List options before picking.** For every unknown: name 2-3 approaches, choose one with rationale. If only 1 viable approach exists — state so and explain why.
- **Verify in codebase first.** Before recommending a pattern, confirm it exists with Grep/Glob.
- **One question max.** If requirements unclear, ask the single most-blocking question first. Never proceed with ambiguity.
- **Evidence-based.** Every recommendation cites: file path, API doc URL, or user statement.
- **No hallucination.** If unsure about an API format, search it — don't guess.

---

## Phase 0: Memory & Codebase Check (always first)

Before searching the web, check what already exists:

**1. Episodic memory** — search past conversations:
Use available memory tools (Serena `read_memory`, episodic-memory, or similar) with the task keywords.
Look for: previous decisions on the same API, patterns already validated, gotchas already hit.
Always run — the search is fast and often surfaces relevant context even for seemingly new tasks.

**2. Task list** — avoid creating duplicate tasks:
Call `TaskList`. Handle each case:
- **pending** tasks on same topic: note them, mention in plan as "already queued"
- **in_progress** tasks on same scope: do NOT duplicate — reference existing task by ID
- **blocked** tasks: check if current work unblocks them — if yes, note the dependency
- **completed** tasks: use as context for decisions, don't recreate
- **empty list**: proceed normally — no notes needed

**3. Codebase check** — verify existing patterns before designing (use Grep/Glob tools, not bash):
```
# Find HTTP client patterns (auto-detect stack):
Grep pattern="fetch|axios|ky|ofetch|aiohttp|httpx|ClientSession"

# Find cache implementations:
Grep pattern="cache|Cache|TTL|staleTime|_CACHE_TTL"

# List all feature/module entry points (adapt glob to project structure):
Glob pattern="src/**/index.{ts,js}" OR Glob pattern="src/**/__init__.py"

# Find test structure + pick closest existing test as Pattern source:
Glob pattern="src/**/*.test.{ts,tsx}" OR Glob pattern="tests/**/*.{py,ts}"
```

**Extract from codebase check:**
- Which patterns already exist and can be reused (cite exact file path)
- What modules are similar to what you're building (use as template)
- Whether the feature partially exists already

If the codebase check answers all unknowns → **skip Phase 2** (no web research needed).
If the codebase check answers SOME unknowns → remove those from the list, search only remaining ones in Phase 2.

---

## Phase 1: Understand the Task

From the user's description, identify:

1. **Goal** — what should exist/work when done? (1 sentence)
2. **Domain** — what area? (API integration / UI / data processing / infra / etc.)
3. **Unknowns** — what do we NOT know yet? Tag each: `[API]` / `[Library]` / `[Pattern]`
   - Remove anything already answered by Phase 0
4. **Constraints** — existing code to integrate with, tech stack, limits

**State tier explicitly:** "Task type: [Domain]. Complexity tier: [Small / Medium / Large / Epic]."

If the task is vague, ask ONE clarifying question before proceeding. Never ask more than one at a time.

**If Unknowns list is empty after Phase 0 → skip Phase 2 entirely.**

---

## Phase 2: Research (only for remaining unknowns)

Search depth by tier:

| Tier | Subtasks | Max searches |
|------|----------|-------------|
| Small | 5 (Merged chain) | 1-2 (or skip) |
| Medium | 6 (Variant A or B) | 3-4 |
| Large | 6 (Variant A or B) | 5-6 |
| Epic | 6 (Phase 1 only) | 6 |

> **Epic tasks:** run max 6 searches for Phase 1 only. After Phase 1 subtasks complete,
> return to task-planner for Phase 2 planning. Note "Phase 2 pending" in plan output.

**Search strategy:**
- Be specific: `"{library} {project_language} example 2026"` not `"how to do X"`
- Search for: official docs, GitHub examples, known gotchas, best practices
- For APIs: search for rate limits, auth format, response schema
- For libraries: search for compatibility with project stack, known issues

**For `[API]` unknowns** — use WebSearch:
```
"{api_name} {project_language} authentication 2026"
"{api_name} rate limits response format"
```
Extract: auth method (header/token format), rate limits, response schema, known breaking changes.

**For `[Library]` unknowns** — prefer Context7 MCP first, then WebSearch:
```
# Step 1: resolve library ID
mcp__context7__resolve-library-id(libraryName="{library_name}")
# Step 2: query relevant docs
mcp__context7__query-docs(context7CompatibleLibraryID="...", topic="compatibility")
```
Extract: API surface, compatibility notes, maintenance status, migration gotchas.

**For `[Pattern]` unknowns** — use WebSearch:
```
"{pattern_name} {project_language} real example 2026"
"site:github.com {pattern} {project_language}"
```
Extract: implementation shape, common pitfalls, when NOT to use.

**Research areas by domain:**

| Domain | Search for |
|--------|-----------|
| New API integration | "API name" + project language + rate limits + auth format |
| New library | library + framework compatibility + "common pitfalls" |
| Architecture pattern | pattern name + project language + "real example" |
| Frontend component | framework docs + component pattern + accessibility |

**Output of Phase 2:**
- Key findings per Unknown (2-3 bullet points each)
- Recommended approach with rationale
- Risks or gotchas to handle

---

## Phase 3: Decompose into Subtasks

Break the task into **atomic subtasks**. Each subtask must be:
- Completable in one focused session
- Independently verifiable (has a clear done condition)
- Assigned to exactly one agent type

**Subtask template:**
```
ID: T{N}
Subject: [imperative verb] [what]
Agent: general-purpose | test-runner | code-reviewer | ...
Blocked by: [T{N}, ...] or none
Done when: [specific verifiable condition — command or assertion]
Files to create: [new files]
Files to modify: [existing files that change]
Test levels: [unit / integration / smoke / E2E] ← only for test subtasks
```

**Decomposition rules:**
- Small features → always Merged chain (5 tasks max)
- Medium/Large features → Variant A or B (6 tasks)
- Max 6 subtasks per single feature (if more → split into phases, Epic-style)
- If implement + wire are the same scope → merge into one task
- Tests are a SEPARATE subtask from implementation
- Review is always the LAST subtask

**Multi-feature decomposition:**
```
Multiple independent features in one request?
  YES → Decompose each feature separately using decision tree below.
        Merge task lists: Feature 1 = T1-T6, Feature 2 = T7-T12, etc.
        Independent features can run in PARALLEL (no cross-feature blockedBy).
  NO  → Single feature, use decision tree below directly.
```

**Test subtask must specify test levels:**
- **Unit tests** — pure functions, models, helpers (mock all I/O)
- **Integration tests** — client functions with mocked HTTP
- **Smoke tests** — orchestrator function end-to-end with mock data
- **E2E tests** — output: structure, key strings present
- Specify which levels are needed: existing module changes → unit+integration; new modules → all 4 levels

**Choosing the right chain — decision tree:**
```
Implement + wire touch the same files?
  YES → Merged chain  [Small: 5 tasks]
  NO  → Do tests need the wired module to be importable?
    NO  → Variant A   [Medium+: 6 tasks, wire and tests run in PARALLEL after core impl]
    YES → Variant B   [Medium+: 6 tasks, wire → tests sequential after core impl]
```

When implement + wire are in the **same files** (e.g., adding a field to an existing model) — **Merged chain:**
> Note: new modules always touch different files (src/new/ + app entry point) → use Variant A or B, not Merged.
```
T1: Core implementation + wiring  ← agent: general-purpose, blockedBy: none
    [Workflow: invoke superpowers:test-driven-development — write minimal failing tests to drive implementation]
T2: Write comprehensive tests     ← agent: general-purpose, blockedBy: T1
    [Expand beyond T1's TDD tests: edge cases, error paths, boundary values]
    [Test levels: unit + integration — Merged chain = existing module, not new module]
T3: Run tests + fix failures      ← agent: test-runner, blockedBy: T2
T4: Coverage check                ← agent: test-analyst,   blockedBy: T3  ┐ PARALLEL
T5: Code review                   ← agent: code-reviewer,  blockedBy: T3  ┘
```

If wiring is separate from core logic (Medium+ features — e.g., new module + app entry point changes):

> **Variant A** — use when tests only mock HTTP (don't need wired module importable):
```
T1: Core implementation      ← agent: general-purpose, blockedBy: none
    [Workflow: invoke superpowers:test-driven-development — write failing test first, then implement]
T2: Wire into existing code       ← agent: general-purpose, blockedBy: T1  ┐ PARALLEL
T3: Write comprehensive tests    ← agent: general-purpose, blockedBy: T1  ┘
    [Expand beyond T1's TDD tests: edge cases, error paths, boundary values]
T4: Run tests + fix failures ← agent: test-runner,     blockedBy: T2, T3
T5: Coverage check           ← agent: test-analyst,    blockedBy: T4  ┐ PARALLEL
T6: Code review              ← agent: code-reviewer,   blockedBy: T4  ┘
```

> **Variant B** — use when tests need the wired module importable (call wired endpoints):
```
T1: Core implementation      ← agent: general-purpose, blockedBy: none
    [Workflow: invoke superpowers:test-driven-development — write failing test first, then implement]
T2: Wire into existing code       ← agent: general-purpose, blockedBy: T1
T3: Write comprehensive tests    ← agent: general-purpose, blockedBy: T2
    [Expand beyond T1's TDD tests: edge cases, error paths, boundary values]
T4: Run tests + fix failures ← agent: test-runner,     blockedBy: T2, T3
T5: Coverage check           ← agent: test-analyst,    blockedBy: T4  ┐ PARALLEL
T6: Code review              ← agent: code-reviewer,   blockedBy: T4  ┘
```

Always start created task IDs from T1 — never create a task with blockedBy pointing to a non-existent ID.

---

## Phase 4: Create Tasks

For each subtask, call TaskCreate using the appropriate template:

**Template A — Implementation task:**
```
TaskCreate:
  subject: "[imperative verb] [what]"
  description: |
    [Context from research findings]

    Files to create: [list — use project's naming conventions]
    Files to modify: [list — these existing files will change]
    Pattern source: [file path — copy pattern from here, do NOT modify this file]

    Workflow:
    - Before writing code: list files to create/modify + key changes (1-3 lines)
    - Invoke superpowers:test-driven-development — write failing test first, then implement

    Done when: [specific verifiable condition — command or assertion]
  activeForm: "[present continuous]"
```

**Template B — Test task:**
```
TaskCreate:
  subject: "Write [levels] tests for [module]"
  description: |
    [Context: what is being tested and why]

    Test levels: [unit / integration / smoke / E2E]
    - Unit: [list of pure functions to test with mocked I/O]
    - Integration: [list of client functions — mock HTTP]
    - Smoke: [orchestrator function end-to-end with mock data]
    - E2E: [output — structure, key strings]

    Files to create: [test file path matching project conventions]
    Pattern source: [closest existing test file] — copy test structure

    Workflow:
    - Before writing tests: list all test cases per level (unit/integration/smoke/E2E) — 1 line each
    - Write tests level by level, verify each level compiles before moving to the next

    Done when: test runner passes for [module], all specified levels covered
  activeForm: "Writing [module] tests"
```

Then call TaskUpdate with `addBlockedBy` to wire dependencies.

**Self-check after all TaskCreate calls:**
- [ ] Every piece of work has a task (no gaps)
- [ ] Every task has explicit `blockedBy` or "none"
- [ ] T_tests is blocked by T_impl (not just T_design)
- [ ] T_tests uses Template B with `Test levels:` field populated
- [ ] T_runner (test-runner) is blocked by T_tests AND T_wire — not just T_impl
      (skip for Merged chain where impl+wire are combined in T1)
- [ ] T_review is last, blocked by T_runner (review needs tests to pass, not just be written)
- [ ] No two tasks modify the same file without sequential dependency
- [ ] "Pattern source" ≠ "Files to modify" (copying a pattern ≠ editing the source file)
- [ ] No task has blockedBy pointing to a skipped/non-existent task ID
- [ ] Tasks marked as PARALLEL do NOT have blockedBy between each other

---

## Phase 5: Output the Plan

Present to the user:

```
## Plan: [Task Name]

### Phase 0 Findings
[What already exists in codebase — reusable patterns, similar modules, partial implementations]

### Research Summary
*(omit this section if Phase 2 was skipped — no unknowns remained after codebase check)*
- [Finding 1]
- [Finding 2]

### Recommended Approach
[1 paragraph: what to build + why this approach + key design decisions]

### Subtasks ({N} total, Variant A/B or merged)
T1 [general-purpose] — Subject                  ← blockedBy: none
T2 [general-purpose] — Subject                  ← blockedBy: T1
T3 [general-purpose] — Subject                  ← blockedBy: T1  [parallel with T2 when tests only mock HTTP]
T4 [test-runner]     — Run tests + fix failures  ← blockedBy: T2, T3
T5 [test-analyst]    — Coverage check            ← blockedBy: T4  ┐ PARALLEL
T6 [code-reviewer]   — Code review               ← blockedBy: T4  ┘

### Risks
- [Risk 1]: [mitigation]
- [Risk 2]: [mitigation]

### Ready to execute
Tasks created and queued.
Next: use `superpowers:executing-plans` to run them in batches.

Start with T1:
  OBJECTIVE: [1 sentence imperative goal]
  INPUT CONTEXT: [key findings from Phases 0–2 relevant to T1 — API details, pattern source]
  SCOPE: [explicit file paths to create/modify]
  OUTPUT FORMAT: summary of what was built + list of files created/modified
  DONE WHEN: [verifiable condition — command output or assertion]
```

> Example above shows Variant A (T1 core impl, T2 wire ∥ T3 tests, T4 run, T5 coverage ∥ T6 review).
> For merged chain: T1–T5. For Variant B: T3 blocked by T2 (sequential, not parallel with T2).

> T3 runs **parallel with T2** only when tests purely mock HTTP and don't import wired modules.
> T3 is **blocked by T2** when tests need the wired module to be importable.

---

## Complexity Tiers

| Tier | Subtasks | Max searches | Example |
|------|----------|-------------|---------|
| **Small** | 5 (Merged chain) | 1-2 (or skip) | Add a field to existing model |
| **Medium** | 6 (Variant A or B) | 3-4 | New API integration |
| **Large** | 6 (Variant A or B) | 5-6 | Multiple new modules, cross-cutting |
| **Epic** | 6 (Phase 1 only) | 6 | Full subsystem, multi-phase rollout |

**When in doubt about tier → go one tier up.**

---

## Available Agents (route subtasks to these)

| Agent | Model | Assign when |
|-------|-------|-------------|
| `general-purpose` | inherit | Implementation, multi-file changes |
| `code-reviewer` | sonnet | After implementation complete |
| `software-architect` | opus | Architecture decisions needed |
| `debugger` | sonnet | Bug investigation |
| `test-analyst` | sonnet | Test coverage analysis |
| `test-runner` | sonnet | Running and verifying tests |
| `text-polisher` | sonnet | Text/copy quality |

> **Note:** Add domain-specific agents as needed (e.g., `gamification-expert`, `content-team`,
> `design-team`, `question-validator`). Update this table when adding new agents.

## Available Skills (reference in subtask instructions)

| Skill | When to reference |
|-------|-------------------|
| `superpowers:brainstorming` | Before any implementation — explore intent |
| `superpowers:test-driven-development` | Within each impl task — write failing test first, then implement |
| `superpowers:executing-plans` | Execute a written plan in batches |
| `superpowers:subagent-driven-development` | Execute plan with independent parallel tasks in current session |
| `superpowers:verification-before-completion` | Last step before declaring done |
| `superpowers:finishing-a-development-branch` | When ready to merge/push |
| `superpowers:systematic-debugging` | Start of any bug investigation |
| `superpowers:dispatching-parallel-agents` | When 2+ tasks can run simultaneously |
| `superpowers:writing-plans` | When a formal plan file is needed before executing-plans |
