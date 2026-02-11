---
name: workbranch
description: This skill should be used when starting work on a "new feature", "bug fix", "branch", "isolated development", when the user asks to "create a worktree", "set up a branch for development", "work on feature X", "fix bug Y", when discussing git worktree management, or when recovering from mistakes like "made changes on main by mistake", "accidentally committed to main", "forgot to create a worktree", "need to move changes to a branch". Provides git worktree workflow that should be the DEFAULT approach for all feature and bugfix development.
version: 0.3.1
---

# Git Worktree Management

## Overview

Git worktrees enable isolated development by creating separate working directories for different branches. This skill teaches the **default workflow** for all feature and bugfix development: always create a worktree before starting work on a new branch.

**Core principle**: Never use `git checkout` or `git switch` for feature/bugfix work. Always create a worktree instead.

## Script Invocation (IMPORTANT)

**All wb commands MUST be invoked using `${CLAUDE_PLUGIN_ROOT}`:**

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x
${CLAUDE_PLUGIN_ROOT}/scripts/wb list
${CLAUDE_PLUGIN_ROOT}/scripts/wb status
```

**Do NOT run bare `wb` commands** - the `${CLAUDE_PLUGIN_ROOT}` variable is only available within Claude Code and ensures the correct plugin version is used.

**Examples:**
- ✅ Correct: `${CLAUDE_PLUGIN_ROOT}/scripts/wb new my-feature`
- ❌ Wrong: `wb new my-feature`

## When to Use Worktrees

Create a worktree for:
- Any new feature development
- Any bug fix work
- Any branch that will have ongoing work
- Experimental changes that need isolation

The only exceptions:
- Quick one-line fixes that can be committed immediately
- Viewing code on another branch temporarily (read-only)

## Commands

The workbranch plugin provides a unified `wb` command with subcommands:

### wb new - Create Worktree

Create a new worktree for a branch:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb new <branch-name> [source-branch]
```

- If branch exists, checks it out in a new worktree
- If branch doesn't exist, creates it from source-branch (default: current HEAD)
- Copies config files based on `.workbranch` configuration
- Runs post-create commands (e.g., `npm install`)

**Example usage**:
```bash
# Create worktree for new feature
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-user-auth

# Create worktree from specific branch
${CLAUDE_PLUGIN_ROOT}/scripts/wb new hotfix-login-bug main
```

### wb list - List Worktrees

Show all worktrees with their status:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb list
```

Output includes:
- Worktree path
- Branch name
- Ahead/behind count vs default branch

Run this to check existing worktrees before creating new ones.

### wb status - Pre-flight Check

Check current location before making changes:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb status
```

**Output fields**:
- LOCATION: `main` or `worktree`
- BRANCH: Current branch name
- DEFAULT_BRANCH: Repository default (main/master)
- ON_DEFAULT: Whether on default branch
- WORKTREE_PATH: Current worktree path
- MAIN_WORKTREE: Main worktree path
- DIRTY: Whether uncommitted changes exist

**Options**:
- `--json`: JSON output
- `--check-main`: Exit 0 if on main, 1 otherwise
- `--check-worktree`: Exit 0 if in worktree, 1 otherwise

**Pre-flight pattern**:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb status
# If LOCATION: main and ON_DEFAULT: true, run 'wb new <branch>' first
```

### wb rm - Remove Worktree

Remove a worktree when done:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb rm <worktree-path> [--delete-branch]
```

- Removes the worktree directory
- With `--delete-branch`: also deletes the branch (only if merged)
- Fails if worktree has uncommitted changes

### wb move - Rescue Changes from Main

Move uncommitted changes and/or local commits from main to a new worktree:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb move <branch-name> [--commits N]
```

- Detects uncommitted changes and commits ahead of origin/main
- Stashes uncommitted work, resets main to match remote
- Creates new worktree and applies changes there
- Use `--commits N` to move only the last N commits

**Example usage**:
```bash
# Move all divergent changes to a new branch
${CLAUDE_PLUGIN_ROOT}/scripts/wb move feature-login

# Move only the last 2 commits
${CLAUDE_PLUGIN_ROOT}/scripts/wb move hotfix-auth --commits 2
```

### wb done - Merge and Cleanup

Finish work on a branch by merging to main and cleaning up:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb done [branch-name] [options]
```

**Modes**:
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done <branch>` — Run from **main worktree**, specify branch to merge (recommended)
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb done` — Run from **feature worktree**, infers branch from HEAD (legacy)

**Options**:
- `--squash`: Squash all commits into one before merging
- `--rebase`: Rebase onto target branch before merging
- `--skip-merge`: Skip merge (use when already merged via PR)
- `--target <branch>`: Target branch to merge into (default: auto-detect)
- `--keep-remote`: Don't delete the remote branch
- `--dry-run`: Show what would be done without executing
- `--discard-changes`: Discard uncommitted changes and force removal (DANGEROUS)

#### Preferred Usage (from main worktree)

Run from the main worktree with the branch name as argument. This avoids the deleted-directory problem:

```bash
# From main worktree
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch        # Standard merge + cleanup
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --squash   # Squash merge
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --skip-merge   # Already merged via PR
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --dry-run      # Preview what would happen
```

#### Legacy Usage (from feature worktree)

Running from within a feature worktree still works but requires immediate navigation:

```bash
# From feature worktree
${CLAUDE_PLUGIN_ROOT}/scripts/wb done
cd /path/to/main  # IMPORTANT: Navigate away immediately!
```

---

**EXECUTE Output for Claude**

When running `wb done` from a feature worktree, the script outputs an `EXECUTE:` line at the end:

```
EXECUTE: cd /path/to/main/worktree
```

**When you see `EXECUTE:` in script output, immediately run that command.**

---

## Workflow for Feature/Bug Development

### Starting Work

1. **Check existing worktrees**: Run `${CLAUDE_PLUGIN_ROOT}/scripts/wb list` to see current state
2. **Create worktree**: Run `${CLAUDE_PLUGIN_ROOT}/scripts/wb new <branch-name>` for the feature/fix
3. **Navigate to worktree**: Change to the worktree directory
4. **Begin development**: The worktree is isolated and ready

### During Development

- Work proceeds in the worktree directory
- Commits go to the branch associated with that worktree
- Main worktree remains on the default branch, undisturbed

### Finishing Work

Use the `wb done` command to complete work on a branch. The **recommended approach** is to run from the main worktree with the branch name:

```bash
# From main worktree (recommended)
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch
```

This handles the entire workflow: merge to main, push, remove worktree, and delete branches.

#### Option A: Direct Merge (Default)

From the main worktree:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch              # Standard merge
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --squash     # Squash merge
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --rebase     # Rebase then merge
```

#### Option B: With Pull Request

1. **Push branch**: `git push -u origin <branch-name>`
2. **Create PR**: Open a pull request for code review
3. **After merge**: Once the PR is merged, clean up from main worktree:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-branch --skip-merge
   ```

The `--skip-merge` flag skips the merge phase (since it's already merged via PR) and just cleans up the worktree and branches.

#### Legacy: Running from Feature Worktree

You can still run the `wb done` command from within a feature worktree (without a branch argument). In this case, you **must** navigate away immediately after completion:

```bash
# From feature worktree
${CLAUDE_PLUGIN_ROOT}/scripts/wb done
cd /path/to/main  # REQUIRED - directory was deleted!
```

The script outputs `EXECUTE: cd /path/to/main` which should be run immediately.

**Note**: For manual cleanup without `wb done`, use `${CLAUDE_PLUGIN_ROOT}/scripts/wb rm <path> --delete-branch`. This only deletes branches that have been merged. If you need to abandon unmerged work, use `git branch -D <branch>` manually after removing the worktree.

## Handling Existing WIP Worktrees

When starting work and a worktree already exists for the target branch (from a previous interrupted session):

1. **Detect**: Run `${CLAUDE_PLUGIN_ROOT}/scripts/wb list` to check for existing worktree
2. **Ask user**: Present options:
   - Resume work in existing worktree
   - Clean up and create fresh worktree
3. **Act accordingly**: Either navigate to existing worktree or remove it first

**Never silently create duplicate worktrees or fail without explanation.**

## Configuration

Projects can customize worktree behavior with a `.workbranch` file in the project root:

```sh
# Files to copy (colon-separated globs)
copy=".env*:.vscode"

# Patterns to ignore when copying
ignore="node_modules:dist:.git"

# Path template ($NAME = branch name)
path="../$NAME"

# Commands to run after worktree creation
post_create="npm install"

# Delete branch when removing worktree (default: false)
delete_branch=false
```

### Configuration Fields

| Field | Description | Default |
|-------|-------------|---------|
| `copy` | Colon-separated file globs to copy | (none) |
| `ignore` | Colon-separated patterns to skip | `node_modules:dist:.git` |
| `path` | Worktree path template | `../$NAME` |
| `post_create` | Commands to run after creation | (none) |
| `delete_branch` | Auto-delete branch on remove | `false` |

If no `.workbranch` file exists, scripts use sensible defaults.

## Error Handling

Scripts return structured error messages:

```
ERROR: <message> | ACTION: <what to do>
```

**Common errors and actions**:

| Error | Action |
|-------|--------|
| Not in a git repository | Navigate to a git repository first |
| Worktree already exists | Use existing worktree or remove with wb rm |
| Branch already checked out | Remove the other worktree first |
| Uncommitted changes | Commit or stash changes, or use `--discard-changes` to force |
| Cannot delete unmerged branch | Use `git branch -D` to force delete |

When an error occurs, read the ACTION portion and follow the guidance.

## Important Behaviors

### Default to Worktrees

When the user asks to work on a feature or fix a bug:
1. First check if they're already in a worktree for that branch
2. If not, create a worktree before starting any development
3. Don't use `git checkout` or `git switch` for feature branches

### Stay in Worktree During Development

Once in a worktree:
- All file edits happen in that worktree
- Commits go to the worktree's branch
- Don't switch back to main worktree until work is complete

### Clean Up After Merge

After work is merged (via PR or direct merge):
- Use the `wb done` command for automatic cleanup (preferred)
- Or use the `wb rm` command for manual cleanup
- The `--delete-branch` flag safely deletes only merged branches

### Recovering from Mistakes on Main

When changes are accidentally made on main instead of a worktree:

1. **Stop immediately**: Don't continue making changes
2. **Run wb move**: `${CLAUDE_PLUGIN_ROOT}/scripts/wb move <appropriate-branch-name>`
3. **Navigate to worktree**: Move to the new worktree directory
4. **Continue work**: Resume development on the feature branch

This handles both uncommitted changes and local commits that diverged from origin/main.

## Script Locations

All scripts are in `${CLAUDE_PLUGIN_ROOT}/scripts/`:
- `wb` — unified dispatcher (routes to `wb-new`, `wb-list`, `wb-status`, `wb-rm`, `wb-move`, `wb-done`, `wb-nuke`)

## Quick Reference

| Task | Command |
|------|---------|
| Check status (pre-flight) | `${CLAUDE_PLUGIN_ROOT}/scripts/wb status` |
| List worktrees | `${CLAUDE_PLUGIN_ROOT}/scripts/wb list` |
| Create worktree | `${CLAUDE_PLUGIN_ROOT}/scripts/wb new <branch>` |
| Create from branch | `${CLAUDE_PLUGIN_ROOT}/scripts/wb new <branch> <source>` |
| Finish work (merge + cleanup) | `${CLAUDE_PLUGIN_ROOT}/scripts/wb done <branch>` (from main) |
| Finish with squash merge | `${CLAUDE_PLUGIN_ROOT}/scripts/wb done <branch> --squash` (from main) |
| Cleanup after PR merge | `${CLAUDE_PLUGIN_ROOT}/scripts/wb done <branch> --skip-merge` (from main) |
| Remove worktree | `${CLAUDE_PLUGIN_ROOT}/scripts/wb rm <path>` |
| Remove + delete branch | `${CLAUDE_PLUGIN_ROOT}/scripts/wb rm <path> --delete-branch` |
| Rescue changes from main | `${CLAUDE_PLUGIN_ROOT}/scripts/wb move <branch>` |
| Rescue specific commits | `${CLAUDE_PLUGIN_ROOT}/scripts/wb move <branch> --commits N` |

## Common Issues

### "command not found: wb"

**Cause:** Attempting to run `wb` commands without `${CLAUDE_PLUGIN_ROOT}` prefix, or running in regular shell instead of through Claude Code.

**Solution:** Always use the full path:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb <command>
```

The `${CLAUDE_PLUGIN_ROOT}` variable is only available within Claude Code. If you see this error, it means:
1. Claude is trying to run bare `wb` commands (should use `${CLAUDE_PLUGIN_ROOT}/scripts/wb`)
2. User is trying to run commands in regular shell (should use Claude Code instead)

### Plugin Development

When developing the workbranch plugin, use relative paths:
```bash
./scripts/wb list
../workbranch/scripts/wb new feature-x
```
