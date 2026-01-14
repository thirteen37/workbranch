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
│   └── wb-nuke       # Bulk cleanup (dangerous)
├── skills/workbranch/SKILL.md   # Teaches Claude the worktree workflow
├── hooks/hooks.json             # PreToolUse hook to soft-block commits on main
├── commands/nuke.md             # User-invocable cleanup command
└── .claude-plugin/plugin.json   # Plugin manifest
```

## Shell Script Conventions

All scripts follow these patterns:

```bash
#!/bin/bash
set -euo pipefail

# Error format - lets Claude parse and recover
echo "ERROR: <message> | ACTION: <what to do>"
exit 1

# Success format
echo "SUCCESS: <message>"
echo "BRANCH: <branch-name>"
```

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

- Branch names can contain `/` (e.g., `feature/login`, `fix/auth-bug`) - use `|` as sed delimiter instead of `/`
- When writing regex patterns, ensure they handle slashes in branch names

## Known Issues

- PreToolUse:Bash hook has schema validation errors (needs investigation)
