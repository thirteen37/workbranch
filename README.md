# workbranch

Git worktree manager for Claude Code. Enables isolated development by creating worktrees for features and bugfixes with automatic config file copying and post-create hooks.

## Features

- **Automatic worktree workflow**: Claude uses worktrees by default for all feature/bugfix work
- **Config file copying**: Automatically copy `.env*`, `.vscode/`, etc. to new worktrees
- **Post-create hooks**: Run commands (e.g., `npm install`) after worktree creation
- **Commit protection**: Soft-blocks commits on main/master, suggests worktree instead
- **Cleanup command**: `/workbranch:nuke` to clean up merged worktrees

## Requirements

- **ZSH 5.0+** - Scripts are written in ZSH for cleaner idioms and better string handling
  - macOS: ZSH is the default shell (since Catalina)
  - Linux: Install via package manager (`apt install zsh`, `dnf install zsh`, etc.)

## Installation

```
/plugin marketplace add thirteen37/thirteen37-plugins
/plugin install workbranch
```

## Usage

Tell Claude to use the workbranch skill when starting feature or bug fix work. Add this to your project's `CLAUDE.md`:

```
You must use the workbranch skill for all feature development and bug fixes.
```

Or include it in your prompt:

- "Use the workbranch skill to set up a branch for the login feature"
- "Fix the checkout bug using the workbranch skill"

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

## For Developers

When developing the workbranch plugin itself, you can run scripts directly:

```bash
# From repository root
./scripts/wb list
./scripts/wb new test-branch

# From worktree
cd ../test-worktree
../workbranch/scripts/wb status
```

**This is only for plugin development.** End users should interact with the plugin through Claude Code.

## Hooks

### Commit Protection

The plugin includes a PreToolUse hook that soft-blocks commits on main/master branches. When Claude attempts to commit on the default branch, it will:

1. Warn that you're committing to main/master
2. Suggest creating a worktree instead
3. Ask for confirmation before proceeding

This ensures the worktree workflow is followed while allowing override when needed.

## How It Works

When you ask Claude to work on a feature or fix a bug:

1. Claude uses the workbranch skill to determine the workflow
2. Claude invokes `${CLAUDE_PLUGIN_ROOT}/scripts/wb` commands on your behalf
3. Development proceeds in the isolated worktree directory
4. After PR merge, use `/workbranch:nuke` command to clean up

The worktree approach keeps your main working directory clean and allows parallel development on multiple features.

## Error Handling

Scripts return structured errors in the format:
```
ERROR: <message> | ACTION: <what to do>
```

This helps Claude understand and recover from errors automatically.

## Development

### Setup

Clone the repo and use the local install script:

```bash
git clone https://github.com/thirteen37/thirteen37-plugins.git
cd thirteen37-plugins/workbranch

# Symlink for live updates (recommended)
./install-local --symlink

# Or copy files to plugin cache
./install-local
```

With `--symlink`, edits take effect immediately without reinstalling.

### Workflow

This plugin eats its own dogfood. Always use `/workbranch` to create a worktree before making changes:

```bash
# From the workbranch directory
wb-new my-feature
cd ../my-feature
# ... make changes ...
```

See `CLAUDE.md` for shell script standards and hook schema.

### Testing

Run scripts directly:

```bash
./scripts/wb-list
./scripts/wb-new test-branch
./scripts/wb-rm ../test-branch --delete-branch
```

## License

MIT
