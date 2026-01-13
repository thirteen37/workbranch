---
name: workbranch
description: This skill should be used when starting work on a "new feature", "bug fix", "branch", "isolated development", when the user asks to "create a worktree", "set up a branch for development", "work on feature X", "fix bug Y", or when discussing git worktree management. Provides git worktree workflow that should be the DEFAULT approach for all feature and bugfix development.
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

1. **Push and create PR**: Push the branch and open a pull request
2. **After merge**: Remove worktree with `wb-rm <path> --delete-branch`

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

After a PR is merged:
- Suggest removing the worktree
- Offer to delete the branch if merged

## Script Locations

All scripts are in the plugin's scripts directory:

- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-new`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-list`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-rm`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wb-nuke` (dangerous cleanup, user-invoked only)

Execute scripts using their full path with `${CLAUDE_PLUGIN_ROOT}` for portability.

## Quick Reference

| Task | Command |
|------|---------|
| List worktrees | `wb-list` |
| Create worktree | `wb-new <branch>` |
| Create from branch | `wb-new <branch> <source>` |
| Remove worktree | `wb-rm <path>` |
| Remove + delete branch | `wb-rm <path> --delete-branch` |
