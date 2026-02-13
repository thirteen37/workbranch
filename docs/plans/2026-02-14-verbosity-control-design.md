# Verbosity Control and Structured Output Design

**Date:** 2026-02-14
**Status:** Approved

## Problem Statement

Workbranch scripts produce verbose output that consumes excessive tokens when used by Claude Code. Scripts also lack consistent structured output for programmatic parsing.

**Issues:**
- Token-heavy progress messages and git command output
- Inconsistent output formats across scripts
- No way to debug issues when they occur
- Scripts like wb-new, wb-done output narrative text instead of structured data

## Goals

1. Minimize token usage by default (essential output only)
2. Provide structured output (key-value or JSON) for all commands
3. Support verbose mode for debugging
4. Maintain helpful error messages with actionable guidance

## Design

### Architecture Overview

Add a centralized verbosity layer to `wb-lib` that all scripts use for output control.

**Global variables:**
- `WB_VERBOSE` - boolean, controls verbose output
- `WB_JSON` - boolean, controls JSON vs key-value output

**Output categories:**
1. **Milestone** - Major phases (always shown in default mode)
2. **Progress** - Sub-steps within phases (only in verbose mode)
3. **Git operations** - Command execution (output suppressed by default, shown in verbose)
4. **Structured result** - Final output (always shown, format depends on WB_JSON)

**Helper functions to add to wb-lib:**
- `wb_parse_output_flags()` - Parse --verbose and --json from args
- `wb_log_milestone()` - Log major phase
- `wb_log_progress()` - Log sub-step (verbose only)
- `wb_run_git()` - Execute git with output control
- `wb_output_start()` - Begin structured output section
- `wb_output_field()` - Add key-value or JSON field
- `wb_output_end()` - Finalize and print structured output

### Output Modes

**Default (minimal) mode:**
- Show essential milestones (major phases)
- Suppress git command output
- Show structured result at end

Example:
```
=== Creating worktree ===
=== Running post-create commands ===

STATUS: success
BRANCH: feature-login
WORKTREE: /Users/yuxi/Documents/.worktrees/feature-login
```

**Verbose mode (--verbose):**
- Show milestones AND progress messages
- Show git command output (stdout + stderr)
- Show structured result at end

Example:
```
=== Creating worktree ===
Preparing worktree path...
Preparing worktree (new branch 'feature-login')
HEAD is now at abc1234 Latest commit
Copying config files...
  .env.example -> /path/to/.env.example
=== Running post-create commands ===
  Running: npm install
  added 234 packages...

STATUS: success
BRANCH: feature-login
WORKTREE: /Users/yuxi/Documents/.worktrees/feature-login
```

**JSON mode (--json):**
- Same verbosity rules apply to progress messages
- Structured result output as JSON instead of key-value

Example (minimal):
```
=== Creating worktree ===
=== Running post-create commands ===

{"status":"success","branch":"feature-login","worktree":"/Users/yuxi/Documents/.worktrees/feature-login"}
```

### Helper Function Specifications

#### `wb_parse_output_flags()`

```zsh
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

- Called early in each script's arg parsing
- Sets global WB_VERBOSE and WB_JSON flags
- Returns cleaned args array (without --verbose/--json)

#### `wb_log_milestone()` and `wb_log_progress()`

```zsh
wb_log_milestone() {
    echo "=== $1 ==="
}

wb_log_progress() {
    if $WB_VERBOSE; then
        echo "$1"
    fi
}
```

- Milestone: always shown in default mode (marks major phases)
- Progress: only shown in verbose mode (sub-steps and details)

#### `wb_run_git()`

```zsh
wb_run_git() {
    if $WB_VERBOSE; then
        "$@"
        return $?
    else
        local stderr_file=$(mktemp)
        "$@" >/dev/null 2>"$stderr_file"
        local exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            WB_GIT_STDERR=$(<"$stderr_file")
        fi

        rm -f "$stderr_file"
        return $exit_code
    fi
}
```

- If verbose: show full git output (stdout + stderr)
- If not verbose: suppress output, capture stderr in WB_GIT_STDERR
- Return git's exit code
- Scripts check exit code and provide context-specific error messages

#### Structured Output Functions

```zsh
wb_output_start() {
    if $WB_JSON; then
        WB_OUTPUT_FIELDS=()
    else
        echo ""  # Blank line before output
    fi
}

wb_output_field() {
    local key="$1"
    local value="$2"

    if $WB_JSON; then
        WB_OUTPUT_FIELDS+=("\"$key\":\"$value\"")
    else
        echo "${key^^}: $value"  # Uppercase key
    fi
}

wb_output_end() {
    if $WB_JSON; then
        echo "{${(j:,:)WB_OUTPUT_FIELDS}}"
    fi
}
```

- Accumulate fields and output at end
- Key-value: outputs immediately (KEY: value format)
- JSON: accumulates and outputs object at end

### Error Handling Strategy

**Division of responsibilities:**

**wb_run_git() handles:**
- Output verbosity control
- Capture stderr when not verbose
- Return git exit code
- Store stderr in WB_GIT_STDERR for script examination

**Scripts handle:**
- Check exit code from wb_run_git()
- Provide context-specific error messages (knows what operation was attempted)
- Decide whether to suggest --verbose based on error clarity

**Example script error handling:**

```zsh
if ! wb_run_git worktree add "$worktree_path" "$branch_name"; then
    if [[ "$WB_GIT_STDERR" =~ "already checked out" ]]; then
        echo "ERROR: Branch already checked out | ACTION: Check 'wb list' for existing worktrees"
    elif [[ "$WB_GIT_STDERR" =~ "not a valid ref" ]]; then
        echo "ERROR: Branch does not exist | ACTION: Check branch name or create with 'git branch $branch_name'"
    else
        echo "ERROR: Failed to create worktree | ACTION: Rerun with --verbose to see git output"
    fi
    exit 1
fi
```

**Error message patterns:**

Clear errors (actionable):
```
ERROR: <specific issue> | ACTION: <how to fix it>
```

Unclear errors (needs debugging):
```
ERROR: <operation failed> | ACTION: Rerun with --verbose to see detailed output
```

### Structured Output Format

**All scripts output structured results:**

**Key-value format (default):**
```
STATUS: success
BRANCH: feature-login
WORKTREE: /path/to/worktree
```

**JSON format (--json flag):**
```json
{"status":"success","branch":"feature-login","worktree":"/path/to/worktree"}
```

**Command-specific fields:**

| Command | Output Fields |
|---------|--------------|
| wb-new | status, branch, worktree |
| wb-rm | status, branch, worktree (deleted) |
| wb-move | status, branch, worktree, commits_moved |
| wb-done | status, branch, target, merged, worktree (deleted) |
| wb-status | location, branch, default_branch, on_default, worktree_path, main_worktree, dirty |
| wb-list | worktrees (array of: path, branch, ahead, behind) |

### Migration Strategy

**Phase 1: Add helpers to wb-lib**
- Implement all helper functions
- Add to wb-lib without breaking existing scripts
- Test helpers in isolation

**Phase 2: Migrate scripts one at a time**

Migration order (simplest to most complex):
1. `wb-status` - Already structured, add verbosity support
2. `wb-list` - Add structured output (currently formatted text)
3. `wb-new` - Replace echo with helpers, add structured result
4. `wb-rm` - Similar to wb-new
5. `wb-move` - Multiple phases, more complex
6. `wb-done` - Most complex, merge logic and phases
7. `wb-nuke` - Bulk operations, special considerations

**Refactoring pattern:**

Before:
```zsh
echo "Creating worktree..."
git worktree add "$path" "$branch" 2>&1
echo "Worktree created successfully."
```

After:
```zsh
wb_log_milestone "Creating worktree"
if ! wb_run_git worktree add "$path" "$branch"; then
    echo "ERROR: Failed to create worktree | ACTION: Check that path is valid"
    exit 1
fi
wb_log_progress "Worktree created successfully"

wb_output_start
wb_output_field "status" "success"
wb_output_field "branch" "$branch"
wb_output_field "worktree" "$path"
wb_output_end
```

**Phase 3: Update tests**
- Update wb-test to verify structured output
- Test both default and verbose modes
- Verify JSON output format

**Phase 4: Update documentation**
- Update CLAUDE.md with new flags
- Update script headers with --verbose and --json options
- Update skill documentation

### Backward Compatibility

**Preserved behavior:**
- Scripts work without flags (default minimal output)
- Error message format unchanged (ERROR: ... | ACTION: ...)
- Exit codes unchanged
- Script invocation unchanged

**New features:**
- `--verbose` flag (optional, explicit opt-in)
- `--json` flag (optional, explicit opt-in)
- Structured output for all commands

## Benefits

1. **Token efficiency**: Minimal output by default reduces Claude Code's token usage
2. **Debuggability**: --verbose provides full details when needed
3. **Consistency**: All scripts use same output format and helpers
4. **Parseability**: Structured output (key-value or JSON) easy to parse
5. **Maintainability**: Centralized logic in wb-lib, easier to update

## Future Enhancements

- `--quiet` flag for absolutely no progress output (structured result only)
- Environment variable `WB_VERBOSE=1` for global verbosity control
- Colored output in verbose mode (if terminal supports it)
- Progress bars for long operations (verbose mode only)
