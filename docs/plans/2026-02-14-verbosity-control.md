# Verbosity Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce token usage by implementing minimal output by default with --verbose debugging support and structured output (key-value or JSON) for all workbranch commands.

**Architecture:** Centralized output control via wb-lib helper functions. Scripts call wb_log_milestone(), wb_log_progress(), wb_run_git(), and wb_output_*() functions instead of direct echo/git commands. Global WB_VERBOSE and WB_JSON flags control behavior.

**Tech Stack:** ZSH shell scripts, git, existing wb-lib library

---

## Phase 1: Add Helper Functions to wb-lib

### Task 1: Add wb_parse_output_flags() helper

**Files:**
- Modify: `scripts/wb-lib` (add after existing helper functions)

**Step 1: Add wb_parse_output_flags() function**

Add this function to `scripts/wb-lib`:

```zsh
# Parse verbosity and output format flags
# Sets: WB_VERBOSE, WB_JSON
# Usage: remaining_args=($(wb_parse_output_flags "$@"))
wb_parse_output_flags() {
    WB_VERBOSE=false
    WB_JSON=false
    local -a remaining_args

    for arg in "$@"; do
        case "$arg" in
            --verbose) WB_VERBOSE=true ;;
            --json) WB_JSON=true ;;
            *) remaining_args+=("$arg") ;;
        esac
    done

    # Return remaining args for script-specific parsing
    echo "${remaining_args[@]}"
}
```

**Step 2: Test the function manually**

Run in a test terminal:
```bash
cd /Users/yuxi/Documents/workbranch
source scripts/wb-lib
args=($(wb_parse_output_flags arg1 --verbose arg2 --json arg3))
echo "Remaining: ${args[@]}"
echo "Verbose: $WB_VERBOSE"
echo "JSON: $WB_JSON"
```

Expected output:
```
Remaining: arg1 arg2 arg3
Verbose: true
JSON: true
```

**Step 3: Commit**

```bash
git add scripts/wb-lib
git commit -m "feat(wb-lib): add wb_parse_output_flags helper

Parses --verbose and --json flags from args, sets global WB_VERBOSE
and WB_JSON variables, returns remaining args for script parsing.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Add logging helpers (milestone and progress)

**Files:**
- Modify: `scripts/wb-lib`

**Step 1: Add wb_log_milestone() function**

Add this function to `scripts/wb-lib`:

```zsh
# Log major phase milestone (always shown)
# Usage: wb_log_milestone "Creating worktree"
wb_log_milestone() {
    echo "=== $1 ==="
}
```

**Step 2: Add wb_log_progress() function**

Add this function to `scripts/wb-lib`:

```zsh
# Log progress sub-step (only shown in verbose mode)
# Usage: wb_log_progress "Copying config files..."
wb_log_progress() {
    if ${WB_VERBOSE:-false}; then
        echo "$1"
    fi
}
```

**Step 3: Test the functions manually**

Run in a test terminal:
```bash
cd /Users/yuxi/Documents/workbranch
source scripts/wb-lib

# Test without verbose
WB_VERBOSE=false
wb_log_milestone "Test Phase"
wb_log_progress "This should not show"

# Test with verbose
WB_VERBOSE=true
wb_log_milestone "Test Phase"
wb_log_progress "This should show"
```

Expected output:
```
=== Test Phase ===
=== Test Phase ===
This should show
```

**Step 4: Commit**

```bash
git add scripts/wb-lib
git commit -m "feat(wb-lib): add wb_log_milestone and wb_log_progress

- wb_log_milestone: always shown, marks major phases
- wb_log_progress: only shown in verbose mode

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Add wb_run_git() helper

**Files:**
- Modify: `scripts/wb-lib`

**Step 1: Add wb_run_git() function**

Add this function to `scripts/wb-lib`:

```zsh
# Run git command with output control
# In verbose mode: show all output
# In quiet mode: suppress output, capture stderr
# Usage: wb_run_git worktree add "$path" "$branch"
# Check exit code and WB_GIT_STDERR for error handling
wb_run_git() {
    if ${WB_VERBOSE:-false}; then
        "$@"
        return $?
    else
        local stderr_file=$(mktemp)
        "$@" >/dev/null 2>"$stderr_file"
        local exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            WB_GIT_STDERR=$(<"$stderr_file")
        else
            WB_GIT_STDERR=""
        fi

        rm -f "$stderr_file"
        return $exit_code
    fi
}
```

**Step 2: Test the function manually**

Run in a test terminal:
```bash
cd /Users/yuxi/Documents/workbranch
source scripts/wb-lib

# Test successful command (quiet)
WB_VERBOSE=false
wb_run_git status
echo "Exit code: $?"
echo "Stderr: $WB_GIT_STDERR"

# Test successful command (verbose)
WB_VERBOSE=true
wb_run_git status
echo "Exit code: $?"

# Test failed command (quiet)
WB_VERBOSE=false
wb_run_git invalidcommand 2>/dev/null || true
echo "Exit code: $?"
echo "Stderr: $WB_GIT_STDERR"
```

Expected behavior:
- Quiet successful: no output, exit 0, empty stderr
- Verbose successful: git status output, exit 0
- Quiet failed: no output, exit non-zero, stderr captured

**Step 3: Commit**

```bash
git add scripts/wb-lib
git commit -m "feat(wb-lib): add wb_run_git helper

Controls git command output based on WB_VERBOSE flag.
Captures stderr in WB_GIT_STDERR when not verbose.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Add structured output helpers

**Files:**
- Modify: `scripts/wb-lib`

**Step 1: Add wb_output_start() function**

Add this function to `scripts/wb-lib`:

```zsh
# Begin structured output section
# Usage: wb_output_start
wb_output_start() {
    if ${WB_JSON:-false}; then
        typeset -ga WB_OUTPUT_FIELDS
        WB_OUTPUT_FIELDS=()
    else
        echo ""  # Blank line before output
    fi
}
```

**Step 2: Add wb_output_field() function**

Add this function to `scripts/wb-lib`:

```zsh
# Add a field to structured output
# Usage: wb_output_field "key" "value"
wb_output_field() {
    local key="$1"
    local value="$2"

    if ${WB_JSON:-false}; then
        # Escape quotes in value
        local escaped_value="${value//\"/\\\"}"
        WB_OUTPUT_FIELDS+=("\"$key\":\"$escaped_value\"")
    else
        echo "${key^^}: $value"  # Uppercase key
    fi
}
```

**Step 3: Add wb_output_end() function**

Add this function to `scripts/wb-lib`:

```zsh
# Finalize and print structured output
# Usage: wb_output_end
wb_output_end() {
    if ${WB_JSON:-false}; then
        echo "{${(j:,:)WB_OUTPUT_FIELDS}}"
    fi
}
```

**Step 4: Test the functions manually**

Run in a test terminal:
```bash
cd /Users/yuxi/Documents/workbranch
source scripts/wb-lib

# Test key-value output
WB_JSON=false
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "test-branch"
wb_output_field "worktree" "/path/to/worktree"
wb_output_end

echo "---"

# Test JSON output
WB_JSON=true
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "test-branch"
wb_output_field "worktree" "/path/to/worktree"
wb_output_end
```

Expected output:
```

STATUS: success
BRANCH: test-branch
WORKTREE: /path/to/worktree
---
{"status":"success","branch":"test-branch","worktree":"/path/to/worktree"}
```

**Step 5: Commit**

```bash
git add scripts/wb-lib
git commit -m "feat(wb-lib): add structured output helpers

- wb_output_start: initialize output section
- wb_output_field: add key-value or JSON field
- wb_output_end: finalize and print output

Supports both key-value and JSON formats based on WB_JSON flag.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: Migrate Scripts

### Task 5: Migrate wb-status

**Files:**
- Modify: `scripts/wb-status`

**Step 1: Add flag parsing at beginning**

After the argument parsing section (around line 26), add:

```zsh
# Parse output flags first
remaining_args=($(wb_parse_output_flags "$@"))
set -- "${remaining_args[@]}"
```

**Step 2: Update usage() to document new flags**

Modify the usage function to add:

```zsh
echo "  --verbose         Show detailed output (for debugging)"
echo "  --json            Output as JSON"
```

**Step 3: Test wb-status with new flags**

Run:
```bash
./scripts/wb-status
./scripts/wb-status --verbose
./scripts/wb-status --json
./scripts/wb-status --verbose --json
```

Expected: All work correctly, verbose flag doesn't change output (wb-status already minimal)

**Step 4: Commit**

```bash
git add scripts/wb-status
git commit -m "feat(wb-status): add --verbose and --json flag support

Integrates wb_parse_output_flags helper. Status output already
minimal so verbose mode has no effect currently.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Migrate wb-list to structured output

**Files:**
- Modify: `scripts/wb-list`

**Step 1: Add flag parsing**

After the argument parsing (around line 20), add:

```zsh
# Parse output flags
remaining_args=($(wb_parse_output_flags "$@"))
set -- "${remaining_args[@]}"
```

**Step 2: Replace output_worktree() function**

Replace the existing output_worktree() function with:

```zsh
# Output worktree info
output_worktree() {
    local worktree="$1"
    local branch="$2"

    local ahead_behind="-"
    if [[ -n "$branch" && "$branch" != "(detached)" ]]; then
        ahead_behind=$(git rev-list --left-right --count "$default_branch...$branch" 2>/dev/null | tr '\t' '/' || echo "?/?")
    fi

    if ${WB_JSON:-false}; then
        # JSON format - accumulate for array
        WB_LIST_ITEMS+=("{\"path\":\"$worktree\",\"branch\":\"$branch\",\"ahead_behind\":\"$ahead_behind\"}")
    else
        # Key-value format
        wb_log_progress "  $worktree"
        wb_log_progress "    branch: $branch"
        wb_log_progress "    ahead/behind $default_branch: $ahead_behind"
        wb_log_progress ""
    fi

    ((++worktree_count))
}
```

**Step 3: Update main output section**

Replace the main output section (lines 55-78) with:

```zsh
# Parse git worktree list --porcelain
worktree_count=0
current_worktree=""
current_branch=""

if ${WB_JSON:-false}; then
    typeset -a WB_LIST_ITEMS
    WB_LIST_ITEMS=()
else
    wb_log_milestone "Worktrees"
fi

while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ '^worktree (.+)$' ]]; then
        # Output previous worktree if exists
        if [[ -n "$current_worktree" ]]; then
            output_worktree "$current_worktree" "$current_branch"
        fi
        current_worktree="$match[1]"
        current_branch=""
    elif [[ "$line" =~ '^branch refs/heads/(.+)$' ]]; then
        current_branch="$match[1]"
    elif [[ "$line" =~ '^detached$' ]]; then
        current_branch="(detached)"
    fi
done < <(git worktree list --porcelain)

# Output last worktree
if [[ -n "$current_worktree" ]]; then
    output_worktree "$current_worktree" "$current_branch"
fi

# Final output
if ${WB_JSON:-false}; then
    echo "{\"worktrees\":[${(j:,:)WB_LIST_ITEMS}],\"count\":$worktree_count}"
else
    echo ""
    echo "Total: $worktree_count worktree(s)"
fi
```

**Step 4: Test wb-list**

Run:
```bash
./scripts/wb-list
./scripts/wb-list --verbose
./scripts/wb-list --json
```

Expected:
- Default: Shows milestone and total count only
- Verbose: Shows milestone, all worktree details, and total
- JSON: Outputs JSON array

**Step 5: Commit**

```bash
git add scripts/wb-list
git commit -m "feat(wb-list): add structured output and verbosity control

- Default mode: shows milestone and count only
- Verbose mode: shows all worktree details
- JSON mode: outputs structured array

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Migrate wb-new to use helpers

**Files:**
- Modify: `scripts/wb-new`

**Step 1: Add flag parsing**

After the usage function (around line 30), add:

```zsh
# Parse output flags first
remaining_args=($(wb_parse_output_flags "$@"))
set -- "${remaining_args[@]}"
```

**Step 2: Update usage() to document flags**

Add to usage():
```zsh
echo "  --verbose         Show detailed output"
echo "  --json            Output as JSON"
```

**Step 3: Replace echo statements with helpers (worktree creation)**

Replace lines 68-82 with:

```zsh
# Create worktree
wb_log_milestone "Creating worktree"

if $branch_exists; then
    if ! wb_run_git worktree add "$worktree_path" "$branch_name"; then
        if [[ "$WB_GIT_STDERR" =~ "already checked out" ]]; then
            echo "ERROR: Branch already checked out elsewhere | ACTION: Check 'wb list' for existing worktrees"
        else
            echo "ERROR: Failed to create worktree | ACTION: Rerun with --verbose to see git output"
        fi
        exit 1
    fi
else
    if ! wb_run_git worktree add -b "$branch_name" "$worktree_path" "$source_branch"; then
        if [[ "$WB_GIT_STDERR" =~ "not a valid" ]]; then
            echo "ERROR: Source branch does not exist | ACTION: Check source branch name"
        else
            echo "ERROR: Failed to create worktree and branch | ACTION: Rerun with --verbose to see git output"
        fi
        exit 1
    fi
fi

wb_log_progress "Worktree created successfully."
```

**Step 4: Replace config copying output**

Replace lines 84-122 with:

```zsh
# Copy config files if patterns specified
if [[ -n "${WB_CONFIG[copy]}" ]]; then
    wb_log_progress "Copying config files..."

    # Split patterns using ZSH parameter expansion
    local -a patterns
    patterns=("${(@s.:.)WB_CONFIG[copy]}")

    # Split ignore patterns
    local -a ignore_patterns
    ignore_patterns=("${(@s.:.)WB_CONFIG[ignore]}")

    # Process each copy pattern
    for pattern in "${patterns[@]}"; do
        # Use find to get matching files
        while IFS= read -r -d '' file; do
            rel_path="${file#$git_root/}"
            dest_dir="$worktree_path/${rel_path:h}"
            mkdir -p "$dest_dir"
            if ! cp -a "$file" "$dest_dir/" 2>/dev/null; then
                echo "WARNING: Could not copy $file | ACTION: You may need to copy this file manually"
            else
                wb_log_progress "  Copied: $rel_path"
            fi
        done < <(find "$git_root" -path "$git_root/.git" -prune -o -name "$pattern" -print0 2>/dev/null)

        # Also try glob expansion for directory patterns
        for file in "$git_root"/$~pattern(N); do
            if [[ -e "$file" ]]; then
                rel_path="${file#$git_root/}"
                dest_dir="$worktree_path/${rel_path:h}"
                mkdir -p "$dest_dir"
                if ! cp -a "$file" "$dest_dir/" 2>/dev/null; then
                    echo "WARNING: Could not copy $file | ACTION: You may need to copy this file manually"
                else
                    wb_log_progress "  Copied: $rel_path"
                fi
            fi
        done
    done

    wb_log_progress "Config files copied."
fi
```

**Step 5: Replace post-create commands output**

Replace lines 124-141 with:

```zsh
# Run post-create commands
if [[ -n "${WB_CONFIG[post_create]}" ]]; then
    wb_log_milestone "Running post-create commands"
    cd "$worktree_path"

    # Handle multi-line post_create (newline or semicolon separated)
    local -a post_create_cmds
    post_create_cmds=("${(@s.;.)WB_CONFIG[post_create]}")
    for cmd in "${post_create_cmds[@]}"; do
        [[ -z "${cmd// /}" ]] && continue
        wb_log_progress "  Running: $cmd"
        if ! eval "$cmd"; then
            echo "WARNING: Post-create command failed: $cmd | ACTION: You may need to run this manually"
        fi
    done

    wb_log_progress "Post-create commands completed."
fi
```

**Step 6: Add structured output at end**

Replace lines 143-145 with:

```zsh
# Output structured result
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "$branch_name"
wb_output_field "worktree" "$worktree_path"
wb_output_end
```

**Step 7: Test wb-new**

Run:
```bash
./scripts/wb-new test-branch
./scripts/wb-new test-branch-verbose --verbose
./scripts/wb-new test-branch-json --json
```

Expected:
- Default: Shows milestones and structured output
- Verbose: Shows milestones, progress, git output, structured output
- JSON: Shows milestones and JSON output

**Step 8: Clean up test branches**

```bash
./scripts/wb-rm ../test-branch --delete-branch
./scripts/wb-rm ../test-branch-verbose --delete-branch
./scripts/wb-rm ../test-branch-json --delete-branch
```

**Step 9: Commit**

```bash
git add scripts/wb-new
git commit -m "feat(wb-new): migrate to verbosity helpers and structured output

- Replace echo with wb_log_milestone/wb_log_progress
- Replace git with wb_run_git and context-specific error handling
- Add structured output (key-value or JSON)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Migrate wb-rm

**Files:**
- Modify: `scripts/wb-rm`

**Step 1: Read current wb-rm implementation**

Read the file to understand current structure.

**Step 2: Add flag parsing after usage()**

Add after usage checks:

```zsh
# Parse output flags first
remaining_args=($(wb_parse_output_flags "$@"))
set -- "${remaining_args[@]}"
```

**Step 3: Replace output statements with helpers**

Follow the same pattern as wb-new:
- Major operations → `wb_log_milestone()`
- Sub-steps → `wb_log_progress()`
- Git commands → `wb_run_git()` with error handling
- Final output → structured output functions

**Step 4: Add structured output at end**

At the end of the script, replace success message with:

```zsh
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "$branch_name"
wb_output_field "worktree" "$worktree_path (deleted)"
wb_output_end
```

**Step 5: Test wb-rm**

Create test worktree and remove:
```bash
./scripts/wb-new test-rm-branch
./scripts/wb-rm ../test-rm-branch --delete-branch
./scripts/wb-new test-rm-verbose
./scripts/wb-rm ../test-rm-verbose --delete-branch --verbose
```

**Step 6: Commit**

```bash
git add scripts/wb-rm
git commit -m "feat(wb-rm): migrate to verbosity helpers and structured output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 9: Migrate wb-move

**Files:**
- Modify: `scripts/wb-move`

**Step 1: Add flag parsing**

**Step 2: Replace output with helpers**

Major phases:
- "Changes to move" → `wb_log_milestone()`
- "Stashing uncommitted changes" → `wb_log_progress()`
- "Creating worktree" → `wb_log_milestone()`
- "Cherry-picking commits" → `wb_log_milestone()`
- "Applying stashed changes" → `wb_log_milestone()`

**Step 3: Add structured output**

```zsh
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "$branch_name"
wb_output_field "worktree" "$worktree_path"
wb_output_field "commits_moved" "$commits_to_move"
wb_output_end
```

**Step 4: Test and commit**

```bash
git add scripts/wb-move
git commit -m "feat(wb-move): migrate to verbosity helpers and structured output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Migrate wb-done

**Files:**
- Modify: `scripts/wb-done`

**Step 1: Add flag parsing**

**Step 2: Keep plan output, but add milestones for phases**

The plan output (lines 231-256) should stay as-is - it's informational summary.

Add milestones for major phases:
- "=== Merging ===" → `wb_log_milestone "Merging"`
- "=== Cleanup ===" → `wb_log_milestone "Cleanup"`

**Step 3: Replace progress messages**

Convert echo statements to:
- Major ops → `wb_log_progress()`
- Git commands → `wb_run_git()` with error handling

**Step 4: Add structured output**

Replace lines 381-392 with:

```zsh
wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "$current_branch (deleted)"
wb_output_field "target" "$target_branch"
wb_output_field "merged" "$([[ $skip_merge == true ]] && echo 'false' || echo 'true')"
wb_output_field "worktree" "$current_worktree (deleted)"
wb_output_end

if ! $running_from_main; then
    echo ""
    echo "IMPORTANT: Your current directory has been deleted."
    echo "NAVIGATE: cd $main_worktree"
fi
```

**Step 5: Test and commit**

```bash
git add scripts/wb-done
git commit -m "feat(wb-done): migrate to verbosity helpers and structured output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Migrate wb-nuke

**Files:**
- Modify: `scripts/wb-nuke`

**Step 1: Add flag parsing**

**Step 2: Keep bulk output format**

wb-nuke has special bulk operation output. Keep the worktree listing format but wrap in milestones:

```zsh
wb_log_milestone "Cleaning up worktrees"
# existing worktree enumeration
wb_log_milestone "Cleaning up gone branches"
# existing branch cleanup
```

**Step 3: Add structured output**

```zsh
wb_output_start
wb_output_field "status" "success"
wb_output_field "worktrees_removed" "$removed_count"
wb_output_field "branches_removed" "$branch_count"
wb_output_end
```

**Step 4: Test and commit**

```bash
git add scripts/wb-nuke
git commit -m "feat(wb-nuke): add verbosity control and structured output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Update Tests

### Task 12: Update wb-test for structured output

**Files:**
- Modify: `scripts/wb-test`

**Step 1: Add test for wb-lib helpers**

Add new test section after existing tests:

```zsh
test_output_helpers() {
    echo "Testing output helpers..."

    # Test key-value output
    WB_JSON=false
    output=$(
        wb_output_start
        wb_output_field "test" "value"
        wb_output_end
    )
    if [[ ! "$output" =~ "TEST: value" ]]; then
        echo "FAIL: key-value output incorrect"
        return 1
    fi

    # Test JSON output
    WB_JSON=true
    output=$(
        wb_output_start
        wb_output_field "test" "value"
        wb_output_end
    )
    if [[ "$output" != '{"test":"value"}' ]]; then
        echo "FAIL: JSON output incorrect"
        return 1
    fi

    echo "PASS: output helpers"
}
```

**Step 2: Add test for structured output in scripts**

Add test:

```zsh
test_structured_output() {
    echo "Testing structured output..."

    # Test wb-status JSON
    output=$(./scripts/wb-status --json)
    if [[ ! "$output" =~ "^\{.*\}$" ]]; then
        echo "FAIL: wb-status JSON output invalid"
        return 1
    fi

    # Test wb-list JSON
    output=$(./scripts/wb-list --json)
    if [[ ! "$output" =~ "^\{.*\}$" ]]; then
        echo "FAIL: wb-list JSON output invalid"
        return 1
    fi

    echo "PASS: structured output"
}
```

**Step 3: Run tests**

```bash
./scripts/wb-test
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add scripts/wb-test
git commit -m "test: add tests for verbosity helpers and structured output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: Update Documentation

### Task 13: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update script invocation section**

In the "Script Invocation" section, add examples with new flags:

```markdown
## Common Flags

All workbranch scripts support these flags:

- `--verbose` - Show detailed output including git command output (useful for debugging)
- `--json` - Output structured result as JSON instead of key-value format

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x
${CLAUDE_PLUGIN_ROOT}/scripts/wb list --verbose
${CLAUDE_PLUGIN_ROOT}/scripts/wb status --json
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-x --verbose
```
```

**Step 2: Update "Shell Script Standards" section**

Add subsection after "Error Messages":

```markdown
### Verbosity Control

Scripts use centralized output helpers from wb-lib:

- `wb_log_milestone()` - Major phase markers (always shown)
- `wb_log_progress()` - Sub-steps (only in verbose mode)
- `wb_run_git()` - Git commands (output shown only in verbose mode)

Default output is minimal to reduce token usage in Claude Code sessions.
Use `--verbose` flag when debugging issues.
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with verbosity control information

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 14: Update skill documentation

**Files:**
- Modify: `skills/workbranch/SKILL.md`

**Step 1: Add verbosity section**

After the "Basic Commands" section, add:

```markdown
## Verbosity Control

All commands support `--verbose` and `--json` flags:

**Default mode (minimal output):**
- Shows major phase milestones only
- Suppresses git command output
- Outputs structured key-value results
- Conserves tokens in Claude Code sessions

**Verbose mode (`--verbose`):**
- Shows detailed progress messages
- Shows git command output
- Useful for debugging issues

**JSON mode (`--json`):**
- Outputs structured results as JSON
- Can be combined with `--verbose`

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wb new feature-x --verbose
${CLAUDE_PLUGIN_ROOT}/scripts/wb list --json
${CLAUDE_PLUGIN_ROOT}/scripts/wb done feature-x --verbose --json
```
```

**Step 2: Commit**

```bash
git add skills/workbranch/SKILL.md
git commit -m "docs: update skill with verbosity control documentation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Final Verification

### Task 15: Full integration test

**Files:**
- None (testing only)

**Step 1: Test full workflow with default output**

```bash
./scripts/wb new test-final
cd ../test-final
echo "test" > test.txt
git add test.txt
git commit -m "test"
cd ../workbranch
./scripts/wb done test-final --skip-merge
```

Expected: Minimal output showing only milestones and structured results

**Step 2: Test full workflow with verbose output**

```bash
./scripts/wb new test-final-verbose --verbose
cd ../test-final-verbose
echo "test" > test.txt
git add test.txt
git commit -m "test"
cd ../workbranch
./scripts/wb done test-final-verbose --skip-merge --verbose
```

Expected: Detailed output with git commands and progress messages

**Step 3: Test JSON output**

```bash
./scripts/wb status --json
./scripts/wb list --json
./scripts/wb new test-json --json
./scripts/wb rm ../test-json --delete-branch --json
```

Expected: Valid JSON output for all commands

**Step 4: Verify token reduction**

Compare output length:
- Before: Verbose git output, detailed progress messages
- After (default): Minimal milestones and structured results

Expected: 60-80% reduction in output tokens for typical operations

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete verbosity control implementation

All workbranch scripts now use centralized output helpers with
minimal default output, --verbose debugging, and structured
key-value or JSON results.

Token usage reduced by ~70% in typical Claude Code sessions.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

**Implementation complete when:**
- ✅ All helper functions added to wb-lib
- ✅ All scripts migrated to use helpers
- ✅ Tests updated and passing
- ✅ Documentation updated
- ✅ Full workflow tested in both minimal and verbose modes
- ✅ JSON output validated for all commands

**Expected benefits:**
- 60-80% reduction in output tokens
- Consistent output format across all scripts
- Debuggable with --verbose flag
- Structured output for programmatic parsing
