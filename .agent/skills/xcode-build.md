---
description: Check Xcode project build status
---

# Xcode Build Check

This workflow checks the build status of an Xcode project.

## Steps

1. **Auto-detect project directory**: Use the current workspace directory or find the directory containing `.xcodeproj` or `.xcworkspace` files.

2. **Auto-detect scheme name**: Run the following command to list available schemes:

```bash
xcodebuild -list -json
```

Parse the JSON output to get the scheme name. Usually the scheme name matches the project name.

3. **Run build check**: Execute the xcodebuild command with detected parameters:

```bash
cd "<detected_project_directory>" && xcodebuild -scheme "<detected_scheme>" build 2>&1 | tail -50
```

## Auto-detection Logic

- **Project Directory**:

  - Check the current active workspace
  - Look for `.xcodeproj` or `.xcworkspace` files in the workspace root
  - If multiple projects exist, use the one matching the workspace name

- **Scheme Name**:
  - Parse output from `xcodebuild -list`
  - Default to the first available scheme or the one matching the project name

## Notes

- If build fails, the output will contain error messages for debugging
- `tail -50` limits output to the last 50 lines to avoid excessive output
- Remove `| tail -50` if full output is needed
