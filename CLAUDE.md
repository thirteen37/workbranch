# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin that manages git worktrees for isolated development. It provides shell scripts, a skill, a hook, and a command.

## Architecture

```
workbranch/
├── scripts/          # Shell scripts that do the actual work
│   ├── wb-new        # Create worktree with config copying
│   ├── wb-list       # List worktrees with status
│   ├── wb-rm         # Remove worktree
│   ├── wb-move       # Rescue changes from main to worktree
│   ├── wb-done       # Merge branch to main and cleanup worktree
│   └── wb-nuke       # Bulk cleanup (dangerous)
├── skills/workbranch/SKILL.md   # Teaches Claude the worktree workflow
├── hooks/hooks.json             # PreToolUse hook to soft-block commits on main
├── commands/nuke.md             # User-invocable cleanup command
└── .claude-plugin/plugin.json   # Plugin manifest
```

## Shell Script Standards

All scripts must follow these conventions for consistency.

### Script Header

```bash
#!/bin/bash
# wb-<name> - Brief description
# Usage: wb-<name> <required-arg> [optional-arg] [--flag]

set -euo pipefail
```

### Usage Function

Every script must have a `usage()` function and support `-h`/`--help`:

```bash
usage() {
    echo "Usage: wb-<name> <args> [options]"
    echo ""
    echo "Description of what the script does."
    echo ""
    echo "Options:"
    echo "  --flag    Description of flag"
    exit 1
}

# For scripts with required args, check before help flag
if [[ $# -lt 1 ]]; then
    usage
fi

# Handle help flag (check first arg or in option loop)
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi
```

### Error Messages

All errors must use this format for Claude to parse and recover:

```bash
echo "ERROR: <message> | ACTION: <what to do>"
exit 1
```

Standard error messages:
- Not in git repo: `ERROR: Not in a git repository | ACTION: Navigate to a git repository first`
- Unknown option: `ERROR: Unknown option: $1 | ACTION: Use -h or --help to see valid options`

### Warning Messages

Non-fatal issues use WARNING (no ACTION required, script continues):

```bash
echo "WARNING: <message>"
```

### Success Output

Scripts that create/modify worktrees output:

```bash
echo "SUCCESS: <description of what was done>"
echo "BRANCH: <branch-name>"
```

Bulk operations (wb-list, wb-nuke) have different output formats appropriate to their function.

### Sed Delimiter

Use `|` as sed delimiter to handle branch names with `/`:

```bash
# Correct
sed "s|\$NAME|$branch_name|g"

# Wrong - fails on feature/login
sed "s/\$NAME/$branch_name/g"
```

### Configuration

Scripts read configuration from `.workbranch` in the target project root (key=value format, colon-separated lists).

## Testing Scripts

Run scripts directly from the repo:

```bash
./scripts/wb-list
./scripts/wb-new test-branch
./scripts/wb-move feature-name
./scripts/wb-rm ../test-branch --delete-branch
```

## Hook Schema

The PreToolUse hook in `hooks/hooks.json` uses the prompt-based hook API. It returns:

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow" | "ask"
  },
  "systemMessage": "Optional message when asking"
}
```

## Development Guidelines

- **Use worktrees for all changes**: This plugin must eat its own dogfood. Always use `/workbranch` to create a worktree before making any changes. Never commit directly to main.
- Branch names can contain `/` (e.g., `feature/login`, `fix/auth-bug`) - use `|` as sed delimiter instead of `/`
- When writing regex patterns, ensure they handle slashes in branch names

