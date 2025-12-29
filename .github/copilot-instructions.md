# GitHub Copilot Instructions

## Generic Communication Guidelines

- Be succinct and be aware that expansive generative AI answers are costly and slow
- Avoid providing explanations, trying to teach unless asked for, your chat partner is an expert
- Stop apologising if corrected, just provide the correct information or code
- Prefer code unless asked for explanation
- Stop summarizing what you've changed after modifications unless asked for

## General Execution Guidelines

### Before Making Changes

- Commit current modifications to ensure a clean state.
- Run any necessary pre-build checks or tests to validate the existing codebase.

### After Making Changes

- Automatically run the build process.
- Must Ensure the build succeeds; if it fails, revert changes or fix issues before proceeding.
- Commit the new changes with a descriptive message.
- Commit message MUST use in english.

### Commit Message Guidelines

#### Format

```markdown
<type>(<scope>): <subject>
<blank line>

<body>
<blank line>
<footer>
```

Type,Description
feat,A new feature for the agent or system
fix,A bug fix
docs,Documentation only changes
style,"Changes that do not affect the meaning of the code (white-space, formatting, etc.)"
refactor,A code change that neither fixes a bug nor adds a feature
perf,A code change that improves performance
test,Adding missing tests or correcting existing tests
build,Changes that affect the build system or external dependencies
ci,Changes to our CI configuration files and scripts
chore,Other changes that don't modify src or test files
revert,Reverts a previous commit
Sources

### Additional Notes

- Always prioritize code quality and follow project-specific conventions.
- If build failures occur, analyze logs and address root causes promptly.

### Tools

- Using ripgrep instead of grep.
- We are on macOS.
