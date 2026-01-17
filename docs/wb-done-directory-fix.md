# wb-done Working Directory Solutions

This document explores approaches to fix the working directory issue that occurs after running `wb done`.

## Problem Description

### What Happens

When `wb done` runs successfully, it:
1. Merges the current branch into main
2. Switches to main branch
3. Deletes the current worktree directory

### Why the Agent Gets Stuck

After step 3, the agent's shell session still has its current working directory (`pwd`) pointing to the deleted worktree path. Subsequent commands fail with `ENOENT: no such file or directory` because the directory no longer exists.

### Current Behavior and Failure Mode

1. Agent runs `wb done` from `/Users/yuxi/Documents/my-feature`
2. Script succeeds, worktree deleted
3. Shell session still points to `/Users/yuxi/Documents/my-feature`
4. Next command (e.g., `ls`, `git status`) fails with ENOENT
5. Agent doesn't reliably recover - may retry the same command or get confused

The agent has difficulty recovering because:
- It doesn't automatically detect the invalid working directory
- SKILL.md instructions to `cd` afterward aren't consistently followed
- The error message doesn't clearly indicate the cause is a deleted directory

---

## Approaches

### A: Run from Main Worktree

**Description**: Require `wb done <branch>` to be run from the main worktree, not from within the worktree being deleted.

**Implementation**:
- Modify `wb-done` to require a branch name argument
- Script operates on the specified branch's worktree while running from main
- User/agent is already in main, so no directory issue arises

**Pros**:
- Prevents the problem entirely by design
- Clean conceptual model: "you manage worktrees from main"
- No recovery mechanism needed

**Cons**:
- Requires script changes to `wb-done`
- Changes existing behavior (currently works from within worktree)
- Agent must learn new workflow (navigate to main first)
- Less convenient for interactive use

---

### B: One-Liner Command Pattern

**Description**: Agent chains commands so that `cd` to main happens in the same command as `wb done`.

**Example**:
```bash
main_wt=$(git worktree list | grep '\[main\]' | awk '{print $1}') && wb done && cd "$main_wt"
```

**Implementation**:
- No script changes needed
- Update SKILL.md to prescribe this pattern
- Agent must follow the pattern consistently

**Pros**:
- Zero script changes
- Works with current `wb-done` implementation
- Single command means atomic success/failure

**Cons**:
- Relies entirely on agent following SKILL.md
- Pattern is complex and easy to get wrong
- If agent forgets the pattern, problem recurs
- Doesn't help interactive users

---

### C: Claude Code Hook

**Description**: Configure a post-bash hook that detects when pwd becomes invalid and automatically resets it.

**Implementation**:
```json
{
  "hooks": {
    "post-bash": {
      "command": "if [ ! -d \"$PWD\" ]; then cd $(git worktree list | head -1 | awk '{print $1}'); fi"
    }
  }
}
```

**Pros**:
- Automatic recovery without agent involvement
- Works for any command that deletes current directory
- No script changes needed
- No reliance on agent following instructions

**Cons**:
- Requires user-side configuration
- Not portable across users/machines
- Hook complexity and potential performance impact
- May mask other problems (user might want to know directory was deleted)

---

### D: Strengthen SKILL.md Only

**Description**: Make the SKILL.md instructions more emphatic about changing directory after `wb done`.

**Current wording** (if any) gets strengthened to:
```markdown
**CRITICAL**: After `wb done`, immediately run:
```bash
cd /path/to/main/worktree
```
Failure to do this WILL cause all subsequent commands to fail.
```

**Pros**:
- Simplest change
- No script modifications
- No user configuration needed

**Cons**:
- Already tried with limited success
- LLM compliance is not guaranteed
- Doesn't solve the fundamental issue
- Relies entirely on prompt adherence

---

### E: Script Outputs EXECUTE Command

**Description**: Have `wb-done` output a special line that the agent is instructed to execute.

**Implementation**:
```bash
# At end of wb-done
echo "EXECUTE: cd $main_worktree_path"
```

SKILL.md instructs:
> When you see `EXECUTE:` in script output, immediately run that command.

**Pros**:
- Script provides exact recovery command
- Agent has explicit instruction to follow
- Works dynamically with correct path
- Pattern can be reused for other scripts

**Cons**:
- Still relies on agent compliance
- Requires both script change and SKILL.md update
- May not work if agent doesn't parse output correctly
- Unusual pattern that may confuse agent

---

## Tradeoffs Matrix

| Approach | Reliability | Complexity | User Config | Behavior Change |
|----------|-------------|------------|-------------|-----------------|
| A: Run from main | High | Medium | None | Yes - significant |
| B: One-liner | Low | Low | None | Yes - command pattern |
| C: Hook | High | Medium | Required | None |
| D: Strengthen SKILL.md | Low | Very Low | None | None |
| E: EXECUTE output | Medium | Low | None | Yes - minor |

**Reliability**: How likely the solution prevents/recovers from the problem
- High = reliably works
- Medium = usually works
- Low = depends on agent compliance

**Complexity**: Implementation effort
- Very Low = text changes only
- Low = minor script changes
- Medium = significant script changes or configuration

**User Config**: Whether users must configure something
- None = works out of the box
- Required = users must set up hooks/settings

**Behavior Change**: Impact on existing workflow
- None = transparent
- Minor = small adjustment
- Significant = different workflow

---

## Recommendation

### Primary: Implement Approach A (Run from Main)

This is the most reliable solution because it prevents the problem rather than recovering from it. The workflow becomes:

1. From main worktree, run `wb done feature-branch`
2. Script handles merge and cleanup
3. User/agent remains in valid directory throughout

This aligns with the conceptual model that worktrees are managed from the main worktree, similar to how `wb new` is typically run from main.

### Secondary: Implement Approach E (EXECUTE output) as fallback

For backwards compatibility and cases where the agent does run `wb done` from within a worktree (before learning the new pattern), have the script output:

```
EXECUTE: cd /path/to/main/worktree
```

Update SKILL.md to instruct the agent to always execute `EXECUTE:` lines. This provides a recovery mechanism during the transition period.

### Implementation Order

1. Update `wb-done` to support `wb done <branch>` from main
2. Keep existing behavior working (detect if already in worktree)
3. Add `EXECUTE:` output for recovery
4. Update SKILL.md with new workflow and EXECUTE instruction
5. Test both patterns work correctly
