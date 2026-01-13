---
description: Clean up merged worktrees (DANGEROUS - removes worktrees and branches)
argument-hint: [--wip] [--dry-run]
allowed-tools: Bash(bash:*), AskUserQuestion
disable-model-invocation: true
---

# Worktree Cleanup

**WARNING: This is a destructive operation. It will remove worktrees and their associated branches.**

## Safety Protocol

Before executing any cleanup:
1. **Always run with --dry-run first** to show what would be removed
2. **Confirm with user** before actual removal
3. **Never run --wip without explicit user confirmation** - this removes unmerged work

## Arguments

- `--dry-run`: Show what would be removed without actually removing
- `--wip`: Also remove WIP (unmerged) worktrees - **DANGEROUS!**

## Execution Steps

### Step 1: Run Dry Run

First, show what would be cleaned up:

```
${CLAUDE_PLUGIN_ROOT}/scripts/wb-nuke --dry-run $ARGUMENTS
```

### Step 2: Present Findings

After dry run, summarize:
- Number of merged worktrees that would be removed
- Number of WIP worktrees (if --wip specified)
- Any potential issues or warnings

### Step 3: Confirm with User

Ask user for explicit confirmation before proceeding. Use AskUserQuestion to present options:
- Proceed with cleanup (remove merged only)
- Proceed with full cleanup including WIP (if --wip was requested)
- Cancel operation

### Step 4: Execute (Only After Confirmation)

Only run the actual cleanup after user confirms:

```
${CLAUDE_PLUGIN_ROOT}/scripts/wb-nuke $ARGUMENTS
```

### Step 5: Report Results

After cleanup, report:
- How many worktrees were removed
- How many branches were deleted
- Any failures or issues encountered

## Important Notes

- This command can only be invoked manually by the user
- Never invoke this command automatically or suggest running it without --dry-run first
- The --wip flag removes unmerged work - always warn prominently about data loss
- If user hasn't specified --dry-run, add it for the first run
