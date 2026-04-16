# AI-SOP.md

Zenith Commander -- AI Engineering Standard Operating Procedure

This document defines how AI assistants should work in this repository.
`AGENTS.md` remains the single source of truth for architecture, code style,
localization, testing, and project-specific engineering rules.

This SOP is optimized for the current workflow:

- OpenAI Codex is the primary development agent.
- Codex may inspect code, edit files, run commands, build, test, and debug.
- Other AI tools may be used as optional helpers, but they do not own fixed,
  exclusive phases of the workflow.

---

## 1. Core Operating Model

Codex is allowed to perform end-to-end development work:

- understand requirements
- inspect the codebase
- modify production code
- update or add tests
- run builds
- run targeted tests
- debug failures
- summarize results and residual risks

Codex must keep changes minimal, scoped, and consistent with `AGENTS.md`.

### One-line Rule

> Codex develops, verifies, and reports. Other agents assist only when useful.

---

## 2. Source Of Truth

- `AGENTS.md` defines project rules.
- `AI-SOP.md` defines workflow rules.
- If this SOP conflicts with `AGENTS.md`, follow `AGENTS.md`.
- If the user gives an explicit instruction for the current task, follow the
  user's instruction unless it would be unsafe or destructive.

---

## 3. Development Workflow

### Phase 0 -- Understand

Codex should clarify the requested behavior when needed, then inspect the
relevant code paths before making changes.

Required behavior:

- identify the files and modules likely affected
- avoid broad refactors unless explicitly requested
- preserve existing architecture and layering
- follow localization rules from `AGENTS.md`

### Phase 1 -- Implement

Codex may edit production code, tests, and project files.

Rules:

- keep the change focused on the requested behavior
- do not move files across layers without explicit instruction
- do not silently change unrelated behavior
- do not delete files unless explicitly requested
- do not revert user changes or unrelated dirty worktree changes

### Phase 2 -- Verify

After production code or test changes, Codex must run verification before
claiming completion.

Default verification:

- run a build when code or project files changed
- run only the tests directly related to the modified code or affected feature
  area

Examples of related tests:

- modified service/model/view tests
- plugin tests for the modified plugin
- targeted UI tests for the changed user flow
- focused regression tests for the bug being fixed

Do not run the full test suite by default during feature development.

Run the full test suite only when:

- the user explicitly requests it
- preparing for release, merge, or PR
- the change is broad enough that targeted tests cannot provide useful coverage
- targeted tests pass but there is a credible risk outside the touched area

### Phase 3 -- Report

Codex must report:

- what changed
- where it changed
- what verification was run
- pass/fail status
- known failures or residual risks

Do not claim a fix is complete without verification evidence.

---

## 4. Test Execution Delegation

When sub agents are available, Codex should prefer delegating verification to a
lightweight test sub agent.

Default test sub agent model:

- `gpt-5.4-mini`

The test sub agent should only report:

- command executed
- pass/fail status
- failing test names and key error lines when failures exist

The test sub agent should not:

- modify files
- propose implementation changes unless explicitly asked
- run unrelated full-suite verification by default

Codex remains responsible for interpreting failures and deciding next steps.

---

## 5. Command Execution Rules

Codex may run local commands needed for development and verification, including:

- `rg`
- `swift`
- `xcodebuild`
- targeted test commands
- formatting or linting commands when appropriate
- diagnostic commands needed for debugging

Safety rules:

- prefer non-destructive commands
- do not run destructive git commands unless explicitly requested
- do not use `git reset --hard` or `git checkout --` without explicit approval
- do not modify permissions, delete files, or rewrite git history unless the
  task explicitly requires it and the user has approved it
- do not run network-dependent tests unless explicitly required

---

## 6. Debugging Rules

Codex may debug build failures, test failures, and runtime behavior.

Debugging expectations:

- reproduce or gather evidence before fixing
- identify the failing layer or code path
- make the smallest useful change
- add or update a focused regression test when applicable
- rerun the relevant verification after the fix

Avoid trial-and-error patches without understanding the failure.

---

## 7. Optional Helper Tools

Other AI tools can be used when helpful, but no tool has exclusive ownership of
implementation, testing, or execution.

Recommended usage:

- Copilot: local autocomplete or small code suggestions
- Gemini CLI: optional external execution or comparison when explicitly useful
- Codex sub agents: focused testing, review, or bounded parallel investigation

These helpers must follow `AGENTS.md` and must not override Codex's responsibility
for final integration and reporting.

---

## 8. Final Discipline Rule

> Keep the workflow evidence-driven: inspect, implement, verify, report.

This SOP is not a restriction against Codex doing development work. It exists to
make Codex development safer, more focused, and easier to verify.
