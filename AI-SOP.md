# AI-SOP.md

Zenith Commander -- AI Engineering Standard Operating Procedure

This document defines the **strict, non-overlapping collaboration
rules** between the following AI tools:

- GitHub Copilot
- OpenAI Codex (CLI)
- Gemini CLI

This SOP is designed to maximize:

- ✅ Engineering efficiency
- ✅ Codex credit efficiency
- ✅ Architectural consistency
- ✅ Build & release reliability

AGENTS.md is the **single source of truth for all code rules**.
AI-SOP.md defines **how tools are used**.

---

## 1. Core Role Definition (Never Change)

| Tool       | Role                                     | Forbidden To Do        |
| ---------- | ---------------------------------------- | ---------------------- |
| Copilot    | Local code generation & logic assistance | Project-wide refactors |
| Codex      | Cross-file & structural refactors        | Build / test / debug   |
| Gemini CLI | Execution & automation                   | Business logic design  |

### One-line Rule:

> Copilot writes. Codex restructures. Gemini executes.

---

## 2. Global Safety Rules

These rules are absolute and never violated:

- Codex MUST NOT run:
  - build
  - test
  - dev server
  - docker
- Gemini MUST NOT modify production source code.
- Copilot MUST NOT perform multi-module refactors.
- All tools MUST follow AGENTS.md strictly.

---

## 3. Daily Development Workflow (Mandatory)

### Phase 0 -- Design & Clarification

Tools allowed:

- Human
- Copilot

Tasks:

- Feature understanding
- Interaction design
- Logic sketching

Codex & Gemini are forbidden here.

---

### Phase 1 -- Local Implementation (Copilot Only)

Allowed:

- SwiftUI Views
- Service functions
- Async/await logic
- Tests
- Documentation comments

Forbidden:

- Large architectural change
- Multi-module refactor

---

### Phase 2 -- Structural Decision Gate

Ask these 3 questions:

1.  Does this change affect multiple files?
2.  Does this affect architecture or layering?
3.  Does this require global rule sync?

If ANY answer is "Yes" → Codex stage allowed.

---

### Phase 3 -- Structural Refactor (Codex Only)

Codex may be used ONLY for:

- Cross-file refactors
- Rule synchronization
- Architecture cleanup
- Naming unification
- API migration

Codex Prompt MUST:

- Reference AGENTS.md
- Be deterministic
- Be one-shot
- Forbid testing and building

After completion:
✅ Codex must be stopped immediately.

---

### Phase 4 -- Build & Verification (Gemini CLI Only)

All commands go to Gemini:

```bash
xcodebuild build
xcodebuild test
./build-dmg.sh
docker-compose up -d
```

If failure:

- Human + Copilot fix
- Gemini reruns
- Codex is forbidden

---

### Phase 5 -- Pre-Release Global Audit (Optional Codex)

Only if:

- All tests pass
- No functional bugs remain

Allowed:

- Architecture audit
- Convention audit
- Dead code scan

Forbidden:

- New features
- Behavioral changes

---

### Phase 6 -- Packaging & Release (Gemini Only)

Final release is always executed by Gemini:

```bash
./build-dmg.sh
```

---

## 4. Codex Usage Blacklist (Instant Credit Killer)

Codex MUST NEVER be used for:

- Debugging build failures
- Running tests
- Running dev servers
- Trial-and-error fixes
- Log exploration
- Environment setup

Codex is a **CTO-level structural tool**, not a technician.

---

## 5. Copilot Golden Rules

Copilot is used for:

- Function writing
- View writing
- Test writing
- Code explanation
- Local refactors
- Async logic generation

Copilot must NOT:

- Redesign architecture
- Modify cross-module contracts
- Perform bulk renaming across modules

---

## 6. Gemini CLI Golden Rules

Gemini is used for:

- Build
- Test
- Docker
- CI simulation
- Packaging
- Log analysis
- Automation scripts

Gemini must NOT:

- Rewrite business logic
- Perform architectural changes
- Modify core rules
- Gemini MUST NOT “add extra steps” that the user didn’t ask for.
- Gemini MUST NOT modify source code files, Only the user did ask for.
- Gemini MUST ask for confirmation BEFORE executing any command that:
  - deletes files (rm, rm -rf, trash, shred, etc.)
  - modifies permissions (chmod, chown)
  - modifies git state (git reset, git clean, git push, git rebase)
- If the user provides an explicit shell command, Gemini MUST:
  - Show the exact command it will execute
  - Ask for a simple yes/no confirmation
  - Execute only that command after confirmation

---

## 7. Codex Credit Protection Rules

Before running Codex, ALL must be true:

- [ ] Design confirmed
- [ ] No ambiguity remains
- [ ] Change is deterministic
- [ ] No command execution needed
- [ ] Only 1 Codex session active
- [ ] AGENTS.md rules identified

If ANY unchecked → Codex is forbidden.

---

## 8. Mental Model Summary

Copilot = Hands\
Codex = Brain\
Gemini = Legs

Hands build.\
Brain restructures.\
Legs execute.

---

## 9. Final Discipline Rule

> Exploration → Copilot\
> Structure → Codex\
> Execution → Gemini

Violating this rule directly reduces:

- Code quality
- Credit efficiency
- System stability

---

## 10. This Document Is Law

This SOP applies to:

- Personal development
- Team development
- Open source collaboration
- Future AI tool extension

This file evolves with tooling, but the **three-role separation never
changes**.
