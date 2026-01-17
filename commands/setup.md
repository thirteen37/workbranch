---
description: Set up project for worktree-based development
argument-hint: ""
allowed-tools: Read, Edit, Write, AskUserQuestion, Bash(git:*)
---

# Project Setup for Worktree-Based Development

Set up this project to use the workbranch plugin's worktree workflow for all feature and bugfix development.

## Step 1: Verify Git Repository

First, verify this is a git repository:
```bash
git rev-parse --is-inside-work-tree
```

If not a git repository, inform the user and stop.

## Step 2: Review Workbranch Workflow (Context)

The workbranch plugin uses this workflow (from the workbranch skill):
- Never use `git checkout` or `git switch` for feature/bugfix work
- Always create a worktree with `wb new <branch>` before starting work
- Use `wb done <branch>` from main to merge and clean up

This context informs the instructions you will add to CLAUDE.md.

## Step 3: Check Project CLAUDE.md

Check if the project has a CLAUDE.md file at the root:
1. If no CLAUDE.md exists, offer to create one
2. If CLAUDE.md exists, check if it already references the workbranch skill
3. If it doesn't reference workbranch, offer to add instructions

## Step 4: Add Worktree Instructions

When adding instructions to CLAUDE.md, add TWO sections:

### Section 1: At the very top of the file (after any title)

```markdown
## MANDATORY: Worktree-First Development

**Before making ANY code changes to this repository:**

1. Run `git branch --show-current` to check current branch
2. If on `main` or `master`, STOP and create a worktree first:
   ```bash
   wb new <descriptive-branch-name>
   ```
3. Navigate to the new worktree directory
4. Only then proceed with modifications

This is not optional. Use the workbranch skill for the complete workflow.
```

### Section 2: A detailed section (can be placed later in the file)

```markdown
## Worktree-Based Development

This project enforces worktree-based development using the workbranch plugin. **Do not skip this step even for "small" changes.**

### Why Worktrees?

- Keeps main branch clean and always deployable
- Isolates work-in-progress from other tasks
- Enables easy context switching between features
- Prevents accidental commits to main

### Workflow

1. **Before any code change**: Create a worktree with `wb new <branch-name>`
2. **During development**: Work entirely within the worktree directory
3. **After completion**: Use `wb done <branch>` from main to merge and clean up

### Quick Reference

| Task | Command |
|------|---------|
| Create worktree | `wb new <branch>` |
| List worktrees | `wb list` |
| Finish work | `wb done <branch>` (from main) |
| Rescue changes from main | `wb move <branch>` |

Use the workbranch skill for detailed guidance on the worktree workflow.
```

## Step 5: Confirm Setup

After updating (or creating) CLAUDE.md:
1. Summarize what was added/changed
2. Remind the user that the workbranch skill is now the guide for all feature/bugfix work
3. Explain that future Claude sessions will follow the worktree workflow

## Important Notes

- If CLAUDE.md already contains worktree instructions, ask whether to update or leave as-is
- Section 1 (MANDATORY) MUST be at the very top of CLAUDE.md, right after any title
- Section 2 (detailed) can be placed in a logical location within the file
- The instructions reference the workbranch skill so future updates to the skill automatically apply
- Both sections reinforce the requirement - this redundancy is intentional
