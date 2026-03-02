# CLAUDE.md

## What This Is

A Claude Code plugin (claude-orgmode) enabling interaction with org-roam and vulpea note-taking systems through emacsclient. Communicates with a running Emacs daemon to create, query, and manage notes.

## Architecture

**Core components:**
- `skills/roam/SKILL.md` - Main skill instructions
- `skills/roam/elisp/claude-orgmode.el` - Main package loading all modules
- `skills/roam/elisp/claude-orgmode-*.el` - Modular implementations (core, create, search, links, tags, attach, utils, doctor)
- `skills/roam/scripts/claude-orgmode-eval` - Auto-load wrapper script
- `skills/roam/references/` - Detailed documentation loaded as needed by Claude
- `.claude-plugin/marketplace.json` - Plugin metadata

**References (progressive disclosure):**
- `skills/roam/references/functions.md` - Complete function documentation with parameters and examples
- `skills/roam/references/installation.md` - Setup and configuration guide
- `skills/roam/references/troubleshooting.md` - Common issues and solutions
- `skills/roam/references/org-roam-api.md` - Org-roam API reference
- `skills/roam/references/emacsclient-usage.md` - Detailed emacsclient patterns

**Package loading:**
Package auto-loads on first use via `skills/roam/scripts/claude-orgmode-eval` wrapper - no manual Emacs config needed. All functions use `claude-orgmode-` prefix including diagnostics (`claude-orgmode-doctor*`).

## Auto-Load Architecture

**Wrapper script:** `skills/roam/scripts/claude-orgmode-eval`
- Checks if `claude-orgmode` is loaded in daemon
- Auto-loads from skill directory on first call
- Subsequent calls use already-loaded package (no overhead)
- Single source of truth: skill ships its own elisp code
- Supports `EMACS_SOCKET_NAME` env var for multi-daemon setups

**Benefits:**
- No user configuration needed (simpler installation)
- Skill updates are self-contained (no coordination with Emacs config)
- Always uses the version that ships with the skill
- Works with multiple Emacs configurations (e.g., custom Emacs + Doom)

**Usage pattern:**
```bash
# Default (connects to "server" socket)
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Title\")"

# Target a specific daemon
EMACS_SOCKET_NAME=thbemacs ${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Title\")"
```

## Key Implementation Details

### Note Creation

**`claude-orgmode-create-note`** creates files directly with proper org-roam structure (PROPERTIES block, ID, title, filetags). This is the recommended approach for programmatic note creation, as `org-roam-capture-` is designed for interactive use.

**Auto-detection behavior:**
1. Reads filename format from user's `org-roam-capture-templates`
2. Expands template placeholders: `${slug}`, `${title}`, `%<time-format>`
3. Creates UUID using `org-id-uuid` (standard org-mode function)
4. Detects and applies head content from template to avoid duplication
5. Writes file with proper org-roam structure
6. Syncs database using `org-roam-db-sync`
7. Returns the file path

**Supported template formats:**
- Default org-roam templates (timestamp-slug format)
- Timestamp-only templates (`%<%Y%m%d%H%M%S>.org`)
- Custom templates with any valid placeholders

**Implementation reference:** `skills/roam/elisp/claude-orgmode-create.el:25`

### Node Access Patterns

**Search by title:**
```elisp
(org-roam-node-from-title-or-alias "Note Title")
```
Reference: `skills/roam/elisp/claude-orgmode-search.el:15`

**Access by ID:**
```elisp
(org-roam-node-from-id "node-id-uuid")
```

**Always use accessor functions:**
- `org-roam-node-file` - get file path
- `org-roam-node-id` - get node ID
- `org-roam-node-title` - get title
- Other `org-roam-node-*` accessors as needed

**Linking best practice:**
Use node IDs for linking (stable across file moves) rather than file paths.

### Tag Sanitization

Org tags cannot contain hyphens. All tag functions automatically sanitize:
- `my-tag` → `my_tag`
- `foo-bar-baz` → `foo_bar_baz`

**Implementation:** `skills/roam/elisp/claude-orgmode-tags.el`

### Attachments

Use `org-attach` functions via the `claude-orgmode--with-node-context` helper:

```elisp
(claude-orgmode--with-node-context node-id
  (org-attach-attach source-path nil 'cp))
```

**Behavior:**
- Files copied to `{org-attach-id-dir}/{node-id}/filename`
- org-attach automatically manages ATTACH property
- See `skills/roam/elisp/claude-orgmode-attach.el` for implementation

### Formatting

All file-modifying operations auto-format using `claude-orgmode--format-buffer`:
- Indents org content
- Aligns tables via `org-table-align`
- Ensures consistent formatting

Reference: `skills/roam/elisp/claude-orgmode-core.el`

### Database Operations

**When to sync:**
Sync before queries if data might be stale:
```elisp
(org-roam-db-sync)
```

**Query preferences:**
- Prefer org-roam query functions over direct SQL
- Use `org-roam-db-query` only when necessary
- Check existing functions in `skills/roam/elisp/claude-orgmode-search.el` first

### Diagnostics

- Full check: `emacsclient --eval "(claude-orgmode-doctor)"`
- Quick check: `emacsclient --eval "(claude-orgmode-doctor-quick)"`

### Temp File Handling

- External `:content-file` parameters are automatically deleted after processing
- Only deletes files in temp directories (`/tmp/`, `/var/tmp/`, and `temporary-file-directory`)
- Use `:keep-file t` to prevent deletion (useful for debugging)
- Internal temp files (in elisp) use `make-temp-file` + `unwind-protect` for guaranteed cleanup
- Implementation: `skills/roam/elisp/claude-orgmode-create.el:55-110` (unwind-protect cleanup logic)
- Validation function: `claude-orgmode--looks-like-temp-file` in `skills/roam/elisp/claude-orgmode-core.el:35-42`

### Error Handling

Most functions return:
- Success: The expected result (file path, node object, etc.)
- Failure: Error message string or nil

Check return values before using them in subsequent operations.

## Testing & Development

Uses [Buttercup](https://github.com/jorgenschaefer/emacs-buttercup) for testing and [Eldev](https://github.com/doublep/eldev) for test execution.

**IMPORTANT**: All new functions and significant code changes require tests.

### Quick Commands

```bash
eldev -C --unstable test     # Run all tests
eldev -C --unstable lint     # Run linting checks
eldev -C --unstable prepare  # Install dependencies
eldev -C --unstable clean    # Remove compiled files and cache
```

### Test Structure

**Test files:**
- `test/claude-orgmode-test.el` - Unit tests
- `test/claude-orgmode-integration-test.el` - Integration tests
- `test/test-helper.el` - Test helpers and utilities

### Writing Tests

**Basic test pattern:**
```elisp
(describe "function-name"
  (it "describes what the test does"
    (expect (function-call args) :to-equal expected-result))

  (it "handles edge case"
    (expect (function-call edge-case) :to-match "pattern")))
```

**Common matchers:**
- `:to-equal` - exact equality comparison
- `:to-match` - regex matching
- `:to-be` - identity comparison (use for `t`/`nil`)
- `:to-be-truthy` - truthy value check
- `:to-be-falsy` - falsy value check
- `:not :to-be` - negation

**Testing file operations:**
Always use temporary files and clean up:
```elisp
(let ((temp-file (make-temp-file "test-" nil ".org")))
  (unwind-protect
      (progn
        ;; Test code using temp-file
        (expect (file-exists-p temp-file) :to-be t))
    ;; Cleanup
    (when (file-exists-p temp-file)
      (delete-file temp-file))))
```

### When to Write Tests

**Required for:**
- New public API functions (all `claude-orgmode-*` functions)
- Bug fixes (add regression test)
- Edge cases and error handling
- Helper functions in modules

**Test priorities:**
1. Public API functions - highest priority
2. Core helper functions - high priority
3. Internal utilities - medium priority
4. Simple getters/setters - low priority (optional)

### Pre-Commit Checklist

Before committing changes:
1. Run `eldev -C --unstable test` - all tests must pass
2. Run `eldev -C --unstable lint` - no linting errors
3. Add tests for new functionality
4. Update tests if changing existing behavior
5. Ensure tests are descriptive and clear

## Git Workflow

**Branch-based workflow required:**
1. Create feature branch (never commit to `master`)
2. Make changes with tests (run `eldev -C --unstable test` before commit)
3. Push branch and create PR
4. Wait for approval before merge

**Commit format:**
```
<conventional type>: <summary>

Co-Authored-By: Claude <noreply@anthropic.com>
```
