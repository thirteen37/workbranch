---
name: workbranch
description: This skill should be used when starting work on a "new feature", "bug fix", "branch", "isolated development", when the user asks to "create a worktree", "set up a branch for development", "work on feature X", "fix bug Y", when discussing git worktree management, or when recovering from mistakes like "made changes on main by mistake", "accidentally committed to main", "forgot to create a worktree", "need to move changes to a branch". Provides git worktree workflow that should be the DEFAULT approach for all feature and bugfix development.
version: 0.1.0
---

# Git Worktree Management

## Overview

Git worktrees enable isolated development by creating separate working directories for different branches. This skill teaches the **default workflow** for all feature and bugfix development: always create a worktree before starting work on a new branch.

**Core principle**: Never use `git checkout` or `git switch` for feature/bugfix work. Always create a worktree instead.

## When to Use Worktrees

Create a worktree for:
- Any new feature development
- Any bug fix work
- Any branch that will have ongoing work
- Experimental changes that need isolation

The only exceptions:
- Quick one-line fixes that can be committed immediately
- Viewing code on another branch temporarily (read-only)

## Shell Scripts

The workbranch plugin provides shell scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`:

### wb-new - Create Worktree

Create a new worktree for a branch:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-new <branch-name> [source-branch]
```

- If branch exists, checks it out in a new worktree
- If branch doesn't exist, creates it from source-branch (default: current HEAD)
- Copies config files based on `.workbranch` configuration
- Runs post-create commands (e.g., `npm install`)

**Example usage**:
```bash
# Create worktree for new feature
${CLAUDE_PLUGIN_ROOT}/scripts/wb-new feature-user-auth

# Create worktree from specific branch
${CLAUDE_PLUGIN_ROOT}/scripts/wb-new hotfix-login-bug main
```

### wb-list - List Worktrees

Show all worktrees with their status:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-list
```

Output includes:
- Worktree path
- Branch name
- Ahead/behind count vs default branch

Run this to check existing worktrees before creating new ones.

### wb-rm - Remove Worktree

Remove a worktree when done:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-rm <worktree-path> [--delete-branch]
```

- Removes the worktree directory
- With `--delete-branch`: also deletes the branch (only if merged)
- Fails if worktree has uncommitted changes

### wb-move - Rescue Changes from Main

Move uncommitted changes and/or local commits from main to a new worktree:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-move <branch-name> [--commits N]
```

- Detects uncommitted changes and commits ahead of origin/main
- Stashes uncommitted work, resets main to match remote
- Creates new worktree and applies changes there
- Use `--commits N` to move only the last N commits

**Example usage**:
```bash
# Move all divergent changes to a new branch
${CLAUDE_PLUGIN_ROOT}/scripts/wb-move feature-login

# Move only the last 2 commits
${CLAUDE_PLUGIN_ROOT}/scripts/wb-move hotfix-auth --commits 2
```

### wb-done - Merge and Cleanup

Finish work on a branch by merging to main and cleaning up:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done [options]
```

Run this from **within a feature worktree** when you're done with the branch.

**Options**:
- `--squash`: Squash all commits into one before merging
- `--rebase`: Rebase onto target branch before merging
- `--skip-merge`: Skip merge (use when already merged via PR)
- `--target <branch>`: Target branch to merge into (default: auto-detect)
- `--keep-remote`: Don't delete the remote branch
- `--dry-run`: Show what would be done without executing

**Example usage**:
```bash
# Standard merge + full cleanup
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done

# Squash merge
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done --squash

# Already merged via GitHub PR, just cleanup
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done --skip-merge

# Preview what would happen
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done --dry-run
```

## Workflow for Feature/Bug Development

### Starting Work

1. **Check existing worktrees**: Run `wb-list` to see current state
2. **Create worktree**: Run `wb-new <branch-name>` for the feature/fix
3. **Navigate to worktree**: Change to the worktree directory
4. **Begin development**: The worktree is isolated and ready

### During Development

- Work proceeds in the worktree directory
- Commits go to the branch associated with that worktree
- Main worktree remains on the default branch, undisturbed

### Finishing Work

Use `wb-done` to complete work on a branch. Run it from within the feature worktree:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb-done
```

This handles the entire workflow: merge to main, push, remove worktree, and delete branches.

#### Option A: Direct Merge (Default)

From within your feature worktree, simply run:
```bash
wb-done              # Standard merge
wb-done --squash     # Squash merge
wb-done --rebase     # Rebase then merge
```

#### Option B: With Pull Request

1. **Push branch**: `git push -u origin <branch-name>`
2. **Create PR**: Open a pull request for code review
3. **After merge**: Once the PR is merged, clean up:
   ```bash
   wb-done --skip-merge
   ```

The `--skip-merge` flag skips the merge phase (since it's already merged via PR) and just cleans up the worktree and branches.

**Note**: For manual cleanup without `wb-done`, use `wb-rm <path> --delete-branch`. This only deletes branches that have been merged. If you need to abandon unmerged work, use `git branch -D <branch>` manually after removing the worktree.

## Handling Existing WIP Worktrees

When starting work and a worktree already exists for the target branch (from a previous interrupted session):

1. **Detect**: Run `wb-list` to check for existing worktree
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
| Worktree already exists | Use existing worktree or remove with wb-rm |
| Branch already checked out | Remove the other worktree first |
| Uncommitted changes | Commit or stash changes first |
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
- Suggest removing the worktree with `wb-rm <path> --delete-branch`
- The `--delete-branch` flag safely deletes only merged branches

### Recovering from Mistakes on Main

When changes are accidentally made on main instead of a worktree:

1. **Stop immediately**: Don't continue making changes
2. **Run wb-move**: `wb-move <appropriate-branch-name>`
3. **Navigate to worktree**: Move to the new worktree directory
4. **Continue work**: Resume development on the feature branch

This handles both uncommitted changes and local commits that diverged from origin/main.

## Script Locations

All scripts are in the plugin's scripts directory:

- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-new`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-list`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-rm`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-move`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-done`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-nuke` (dangerous cleanup, user-invoked only)

Execute scripts using their full path with `${CLAUDE_PLUGIN_ROOT}` for portability.

## Quick Reference

| Task | Command |
|------|---------|
| List worktrees | `wb-list` |
| Create worktree | `wb-new <branch>` |
| Create from branch | `wb-new <branch> <source>` |
| Finish work (merge + cleanup) | `wb-done` |
| Finish with squash merge | `wb-done --squash` |
| Cleanup after PR merge | `wb-done --skip-merge` |
| Remove worktree | `wb-rm <path>` |
| Remove + delete branch | `wb-rm <path> --delete-branch` |
| Rescue changes from main | `wb-move <branch>` |
| Rescue specific commits | `wb-move <branch> --commits N` |
