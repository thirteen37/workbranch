# CLAUDE.md

## MANDATORY: Worktree-First Development

**Before making ANY code changes to this repository:**

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/wb status` to check current location
2. If `LOCATION: main` and `ON_DEFAULT: true`, STOP and create a worktree first:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/wb new <descriptive-branch-name>
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
│   ├── wb-status     # Show current worktree status
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

## Working Without Remotes

Workbranch supports local-only workflows when no git remote is configured:

- `${CLAUDE_PLUGIN_ROOT}/scripts/wb new <branch>` - Works normally, creates worktree from local branches
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb list` - Shows worktrees with ahead/behind counts vs default branch
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb status` - Shows current worktree status
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done --skip-merge` - Cleans up worktree without fetching/pushing
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done --local-only` - Skips all remote operations (fetch/pull/push)

Remote operations are automatically skipped when no remote is detected.

## Sandbox Limitations

In Claude Code sandbox environments:

**Working commands:**
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb list` - List worktrees (read-only)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb status` - Check worktree status (read-only)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done --dry-run` - Preview merge/cleanup actions
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb nuke --dry-run` - Preview bulk cleanup

**Blocked commands:**
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb new` - Cannot create worktrees (write restrictions)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb rm` - Cannot remove worktrees (write restrictions)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done` - Cannot merge/cleanup (write restrictions)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb move` - Cannot create worktrees (write restrictions)

To use write commands, disable sandbox with `/sandbox` command.

## Output Control

All workbranch scripts support verbosity control flags to reduce token usage while maintaining debugging capability:

### Flags

- **`--verbose`**: Show detailed output including git commands and progress steps
- **`--json`**: Output structured JSON instead of text (for programmatic use)

### Default Behavior

By default, scripts produce minimal output:
- Major milestones are shown (e.g., "Creating worktree", "Merging branch")
- Detailed sub-steps are hidden (shown with `--verbose`)
- Git command output is suppressed (shown with `--verbose`)
- Final results use structured key-value format

This reduces token consumption by 60-80% in typical Claude Code sessions.

### Usage Examples

```bash
# Minimal output (default)
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x

# Detailed output for debugging
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x --verbose

# JSON output for programmatic use
${CLAUDE_PLUGIN_ROOT}/scripts/wb list --json

# Combine flags where supported
${CLAUDE_PLUGIN_ROOT}/scripts/wb done --skip-merge --verbose
```

### Which Scripts Support These Flags

All scripts support `--verbose` and `--json`:
- `wb status` - Already had `--json`, now also supports `--verbose`
- `wb list` - List worktrees with optional JSON output
- `wb new` - Create worktree with progress tracking
- `wb rm` - Remove worktree with status reporting
- `wb move` - Move changes with multi-phase tracking
- `wb done` - Merge and cleanup with detailed progress
- `wb nuke` - Bulk cleanup with summary reporting

### When to Use Verbose Mode

Use `--verbose` when:
- Debugging script behavior or git operations
- Understanding why a command failed
- Learning how the scripts work
- Troubleshooting merge conflicts or branch issues

### When to Use JSON Mode

Use `--json` when:
- Integrating with other tools or scripts
- Building automation on top of workbranch
- Need machine-readable output
- Parsing results programmatically

**Note**: Error messages always include `| ACTION:` guidance regardless of verbosity mode.

## Script Invocation

### Within Claude Code (Normal Usage)

When Claude uses the workbranch skill, it invokes scripts via `${CLAUDE_PLUGIN_ROOT}`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x
```

This variable is set by Claude Code and points to the installed plugin directory.

### Direct Script Access (Development Only)

When developing the plugin, run scripts directly from the repository:

```bash
# From main worktree
./scripts/wb-test
./scripts/wb-list

# From feature worktree
../workbranch/scripts/wb new another-feature
```

**Never** instruct Claude to run bare `wb` commands without `${CLAUDE_PLUGIN_ROOT}` prefix, as this will fail with "command not found" errors.

## Shell Script Standards

All scripts must follow these conventions for consistency.

### Script Header

```zsh
#!/usr/bin/env zsh
# wb-<name> - Brief description
# Usage: wb-<name> <required-arg> [optional-arg] [--flag]

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/wb-lib"
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

### Configuration

Scripts read configuration from `.workbranch` in the target project root (key=value format, colon-separated lists).

### Dependencies

Scripts require **ZSH 5.0+** and standard Unix utilities:
- **ZSH**: Default on macOS, available via package manager on Linux
- **Allowed utilities**: git, sed, grep, find, realpath, etc.
- **Avoid**: Python, Perl, Ruby, or other interpreters

### ZSH Idioms

Scripts use ZSH-specific features for cleaner code:

```zsh
# Script directory (instead of BASH_SOURCE dance)
SCRIPT_DIR="${0:A:h}"

# String substitution (instead of sed for simple cases)
worktree_path="${path_template//\$NAME/$branch_name}"

# Split string by delimiter (instead of IFS)
patterns=("${(@s.:.)WB_CONFIG[copy]}")

# Regex captures (instead of BASH_REMATCH)
if [[ "$line" =~ '^worktree (.+)$' ]]; then
    path="$match[1]"
fi

# Associative arrays for config
typeset -gA WB_CONFIG
WB_CONFIG[path]='../$NAME'
```

Note: ZSH regex patterns must be quoted in `[[ ]]` conditionals.

### Sandbox-Safe Scripting

**CRITICAL: Avoid heredocs** - they create temp files that fail in sandbox mode:

```zsh
# BAD - heredoc fails in sandbox
cat <<EOF
ERROR: message
  details here
EOF

# GOOD - use echo/printf instead
echo "ERROR: message"
echo "  details here"
```

**Reserved ZSH Parameters** - avoid these variable names:
- `commands` - autoloaded associative array, causes "can't change type" error
- Use alternative names: `cmd_list`, `post_create_cmds`, etc.

```zsh
# BAD - conflicts with ZSH builtin
local -a commands
commands=("$@")

# GOOD - use different name
local -a cmd_list
cmd_list=("$@")
```

## Testing Scripts

Run the integration test suite:

```bash
./scripts/wb-test           # Run all tests
./scripts/wb-test --verbose # Show detailed output
```

When developing the plugin, run scripts directly from the repository:

```bash
# Direct invocation for development
./scripts/wb-list
./scripts/wb-new test-branch
./scripts/wb-rm ../test-branch --delete-branch

# Or using the dispatcher
./scripts/wb list
./scripts/wb new test-branch
```

**Note:** These examples are for plugin development only. When Claude uses the plugin, it invokes scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/wb`.

## Code Quality

### Shellcheck

All scripts are checked with shellcheck to catch common shell scripting issues. While shellcheck doesn't fully support ZSH syntax, it can still catch many generic bugs.

**Run shellcheck locally:**
```bash
./scripts/shellcheck-all           # Check all scripts
./scripts/shellcheck-all --fix     # Show fix suggestions
```

**Install git hooks:**
```bash
./scripts/install-hooks
```

This sets up a pre-commit hook that automatically runs shellcheck on modified scripts before each commit.

**CI Integration:**
- Shellcheck runs automatically on all PRs via GitHub Actions
- See `.github/workflows/shellcheck.yml`

**Note:** Many shellcheck warnings are excluded for ZSH-specific syntax:
- ZSH array indexing (`$match[1]`)
- ZSH parameter expansions (`${(@s:/:)path}`)
- ZSH glob qualifiers (`(N)`)
- Top-level `local` declarations
- Quoted regex patterns in `[[ =~ ]]`

The test suite (`wb-test`) remains the primary quality check for functionality.

## Development Guidelines

- **Use worktrees for all changes**: See MANDATORY section at top of this file. Never commit directly to main.
- Branch names can contain `/` (e.g., `feature/login`, `fix/auth-bug`) - use ZSH `${//}` substitution instead of sed
- When writing regex patterns, ensure they are quoted and handle slashes in branch names
- When writing scripts that interact with remotes, use `wb_get_remote()` and check `wb_has_remote()` first
- Always check `wb_check_remote_reachable()` before network operations (handles sandbox)
- Use $remote_name variable instead of hardcoding "origin"

## Releasing

To release a new version:

1. Create a GitHub release with a `v`-prefixed tag (e.g., `v0.3.0`)
2. The release workflow automatically:
   - Updates version in `plugin.json` and `SKILL.md`
   - Commits and pushes the changes
   - Notifies the marketplace to update its version listing

Verify the workflow succeeded by checking the repository's Actions tab.

## Known Issues

None currently tracked.

