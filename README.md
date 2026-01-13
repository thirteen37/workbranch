# workbranch

Git worktree manager for Claude Code. Enables isolated development by creating worktrees for features and bugfixes with automatic config file copying and post-create hooks.

## Features

- **Automatic worktree workflow**: Claude uses worktrees by default for all feature/bugfix work
- **Config file copying**: Automatically copy `.env*`, `.vscode/`, etc. to new worktrees
- **Post-create hooks**: Run commands (e.g., `npm install`) after worktree creation
- **Commit protection**: Soft-blocks commits on main/master, suggests worktree instead
- **Cleanup command**: `/workbranch:nuke` to clean up merged worktrees

## Installation

```bash
claude --plugin-dir /path/to/workbranch
```

Or add to your Claude Code plugins directory.

## Configuration

Create `.workbranch` in your project root:

```sh
# Files to copy (colon-separated globs)
copy=".env*:.vscode"

# Patterns to ignore
ignore="node_modules:dist:.git"

# Path template ($NAME = branch name)
path="../$NAME"

# Commands to run after create (one per line)
post_create="npm install"

# Delete branch when removing worktree
delete_branch=false
```

## Commands

### /workbranch:nuke

Clean up merged worktrees. Use `--wip` flag to also remove unmerged worktrees (dangerous!).

```
/workbranch:nuke          # Remove merged worktrees only
/workbranch:nuke --wip    # Also remove WIP worktrees (DANGEROUS)
```

## Shell Scripts

The plugin includes shell scripts that can be used standalone:

- `wb-new <branch> [source]` - Create worktree with config file copying
- `wb-list` - List worktrees with status
- `wb-rm <path> [--delete-branch]` - Remove worktree
- `wb-nuke [--wip]` - Clean up merged (and optionally WIP) worktrees

## Hooks

### Commit Protection

The plugin includes a PreToolUse hook that soft-blocks commits on main/master branches. When Claude attempts to commit on the default branch, it will:

1. Warn that you're committing to main/master
2. Suggest creating a worktree instead
3. Ask for confirmation before proceeding

This ensures the worktree workflow is followed while allowing override when needed.

## How It Works

When you ask Claude to work on a feature or fix a bug:

1. Claude automatically uses `wb-new` to create an isolated worktree
2. Development proceeds in the worktree directory
3. After PR merge, use `/workbranch:nuke` to clean up

The worktree approach keeps your main working directory clean and allows parallel development on multiple features.

## Error Handling

Scripts return structured errors in the format:
```
ERROR: <message> | ACTION: <what to do>
```

This helps Claude understand and recover from errors automatically.

## License

MIT
