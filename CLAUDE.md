# CLAUDE.md

## MANDATORY: Worktree-First Development

**Before making ANY code changes to this repository:**

1. Run `git branch --show-current` to check current branch
2. If on `main` or `master`, STOP and create a worktree first:
   ```bash
   wb new <descriptive-branch-name>
   ```
3. Navigate to the new worktree directory
4. Only then proceed with modifications

This is not optional. This plugin enforces worktree-based development. Do not skip this step even for "small" changes.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin that manages git worktrees for isolated development. It provides shell scripts, a skill, and a command.

## Architecture

```
workbranch/
├── scripts/          # Shell scripts that do the actual work
│   ├── wb            # Unified dispatcher (wb <subcommand>)
│   ├── wb-new        # Create worktree with config copying
│   ├── wb-list       # List worktrees with status
│   ├── wb-rm         # Remove worktree
│   ├── wb-move       # Rescue changes from main to worktree
│   ├── wb-done       # Merge branch to main and cleanup worktree
│   ├── wb-nuke       # Bulk cleanup (dangerous)
│   ├── wb-lib        # Shared functions library
│   └── wb-test       # Integration tests
├── skills/workbranch/SKILL.md   # Teaches Claude the worktree workflow
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

### Dependencies

Scripts must use only POSIX shell features and standard Unix utilities:
- **Allowed**: bash, sed, awk, grep, cut, tr, sort, uniq, realpath, etc.
- **Avoid**: Python, Perl, Ruby, or other interpreters

This ensures scripts work on any system with a basic Unix environment. When a utility might not exist, provide a pure bash fallback.

## Testing Scripts

Run the integration test suite:

```bash
./scripts/wb-test           # Run all tests
./scripts/wb-test --verbose # Show detailed output
```

Or run scripts manually using the `wb` dispatcher or directly:

```bash
# Using dispatcher
wb list
wb new test-branch
wb move feature-name
wb rm ../test-branch --delete-branch

# Or directly
./scripts/wb-list
./scripts/wb-new test-branch
```

## Development Guidelines

- **Use worktrees for all changes**: See MANDATORY section at top of this file. Never commit directly to main.
- Branch names can contain `/` (e.g., `feature/login`, `fix/auth-bug`) - use `|` as sed delimiter instead of `/`
- When writing regex patterns, ensure they handle slashes in branch names

## Known Issues

None currently tracked.

