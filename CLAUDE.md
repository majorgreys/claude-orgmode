# CLAUDE.md

## What This Is

A Claude Code skill enabling interaction with org-roam note-taking systems through emacsclient. Communicates with a running Emacs daemon to create, query, and manage org-roam notes.

## Architecture

**Core components:**
- `SKILL.md` - Main skill instructions (307 lines, follows skill-creator best practices)
- `elisp/org-roam-skill.el` - Main package loading all modules
- `elisp/org-roam-skill-*.el` - Modular implementations (create, search, links, tags, attach, utils, doctor)
- `scripts/org-roam-eval` - Auto-load wrapper script
- `references/` - Detailed documentation loaded as needed by Claude

**References (progressive disclosure):**
- `references/functions.md` - Complete function documentation with parameters and examples
- `references/installation.md` - Setup and configuration guide
- `references/troubleshooting.md` - Common issues and solutions
- `references/org-roam-api.md` - Org-roam API reference
- `references/emacsclient-usage.md` - Detailed emacsclient patterns

**Package loading:**
Package auto-loads on first use via `scripts/org-roam-eval` wrapper - no manual Emacs config needed. All functions use `org-roam-skill-` prefix except diagnostics (`org-roam-doctor*`).

## Auto-Load Architecture

**Wrapper script:** `scripts/org-roam-eval`
- Checks if `org-roam-skill` is loaded in daemon
- Auto-loads from skill directory on first call
- Subsequent calls use already-loaded package (no overhead)
- Single source of truth: skill ships its own elisp code

**Benefits:**
- No user configuration needed (simpler installation)
- Skill updates are self-contained (no coordination with Emacs config)
- Always uses the version that ships with the skill

**Usage pattern:**
```bash
~/.claude/skills/org-roam-skill/scripts/org-roam-eval "(org-roam-skill-create-note \"Title\")"
```

## Key Implementation Details

### Note Creation

**`org-roam-skill-create-note`** creates files directly with proper org-roam structure (PROPERTIES block, ID, title, filetags). This is the recommended approach for programmatic note creation, as `org-roam-capture-` is designed for interactive use.

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

**Implementation reference:** `elisp/org-roam-skill-create.el:25`

### Node Access Patterns

**Search by title:**
```elisp
(org-roam-node-from-title-or-alias "Note Title")
```
Reference: `elisp/org-roam-skill-search.el:15`

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

**Implementation:** `elisp/org-roam-skill-tags.el`

### Attachments

Use `org-attach` functions via the `org-roam-skill--with-node-context` helper:

```elisp
(org-roam-skill--with-node-context node-id
  (org-attach-attach source-path nil 'cp))
```

**Behavior:**
- Files copied to `{org-attach-id-dir}/{node-id}/filename`
- org-attach automatically manages ATTACH property
- See `elisp/org-roam-skill-attach.el` for implementation

### Formatting

All file-modifying operations auto-format using `org-roam-skill--format-buffer`:
- Indents org content
- Aligns tables via `org-table-align`
- Ensures consistent formatting

Reference: `elisp/org-roam-skill-utils.el`

### Database Operations

**When to sync:**
Sync before queries if data might be stale:
```elisp
(org-roam-db-sync)
```

**Query preferences:**
- Prefer org-roam query functions over direct SQL
- Use `org-roam-db-query` only when necessary
- Check existing functions in `elisp/org-roam-skill-search.el` first

### Diagnostics

- Full check: `emacsclient --eval "(org-roam-doctor)"`
- Quick check: `emacsclient --eval "(org-roam-doctor-quick)"`

### Temp File Handling

- External `:content-file` parameters are automatically deleted after processing
- Only deletes files in temp directories (`/tmp/`, `/var/tmp/`, and `temporary-file-directory`)
- Use `:keep-file t` to prevent deletion (useful for debugging)
- Internal temp files (in elisp) use `make-temp-file` + `unwind-protect` for guaranteed cleanup
- Implementation: `elisp/org-roam-skill-create.el:55-110` (unwind-protect cleanup logic)
- Validation function: `org-roam-skill--looks-like-temp-file` in `elisp/org-roam-skill-core.el:35-42`

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
- `test/org-roam-skill-test.el` - Unit tests
- `test/org-roam-skill-integration-test.el` - Integration tests
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
- New public API functions (all `org-roam-skill-*` functions)
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
1. ✓ Run `eldev -C --unstable test` - all tests must pass
2. ✓ Run `eldev -C --unstable lint` - no linting errors
3. ✓ Add tests for new functionality
4. ✓ Update tests if changing existing behavior
5. ✓ Ensure tests are descriptive and clear

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

## Skill Packaging

**Files included in .skill package:**
- `SKILL.md` (required)
- `elisp/*.el` files (Emacs Lisp code)
- `scripts/org-roam-eval` (auto-load wrapper)
- `references/` (documentation for AI)

**Files excluded from .skill package** (see `.skillignore`):
- `README.md` - Developer/user documentation (not needed for AI agent)
- `CLAUDE.md` - Project-specific development instructions (this file)
- `test/` - Test suite (developer resources)
- `.git/`, `.github/`, `Eldev` - Development tools

**Packaging command:**
```bash
cd ~/dev/majorgreys && zip -r org-roam-skill.skill org-roam-skill/ -x @org-roam-skill/.skillignore
```

## Additional Documentation

**For AI (included in package):**
- `SKILL.md` - Quick reference and core workflows
- `references/functions.md` - Complete function documentation
- `references/installation.md` - Setup guide
- `references/troubleshooting.md` - Common issues
- `references/org-roam-api.md` - Org-roam API reference
- `references/emacsclient-usage.md` - Emacsclient patterns

**For developers (excluded from package):**
- `README.md` - User-facing documentation
- `CLAUDE.md` - This file - comprehensive development guide with implementation patterns and testing details
