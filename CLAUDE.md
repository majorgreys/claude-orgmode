# CLAUDE.md

## What This Is

A Claude Code plugin (claude-orgmode) with two skills:
1. **orgmode** - Pure org-mode syntax and formatting knowledge
2. **notes** - Note management via emacsclient (org-roam and vulpea backends, auto-detected)

The elisp code and eval script are shared; the backend abstraction layer auto-detects org-roam or vulpea.

## Architecture

**Plugin structure:**
- `.claude-plugin/marketplace.json` - Plugin metadata, references both skills
- `skills/orgmode/SKILL.md` - Knowledge-only skill (no tools)
- `skills/notes/SKILL.md` - Note management skill (create, edit, search, link)

**Shared code:**
- `elisp/claude-orgmode.el` - Main package loading all modules
- `elisp/claude-orgmode-backend.el` - Backend auto-detection (org-roam vs vulpea)
- `elisp/claude-orgmode-*.el` - Modular implementations (core, create, section, search, links, tags, attach, utils, doctor)
- `scripts/claude-orgmode-eval` - Auto-load wrapper script

**Shared references:**
- `references/functions.md` - Complete function documentation
- `references/emacsclient-usage.md` - Emacsclient patterns
- `references/installation.md` - Setup and configuration guide
- `references/troubleshooting.md` - Common issues and solutions

**Skill-specific references:**
- `skills/orgmode/references/` - org-syntax.md, properties.md, timestamps.md, links.md, examples.md
- `skills/notes/references/org-roam-api.md` - Org-roam low-level API reference
- `skills/notes/references/vulpea-api.md` - Vulpea low-level API reference

## Auto-Load Architecture

**Wrapper script:** `scripts/claude-orgmode-eval`
- Checks if `claude-orgmode` is loaded in daemon
- Auto-loads from `elisp/` directory on first call
- Subsequent calls use already-loaded package (no overhead)
- Supports `-s`/`--socket` flag for multi-daemon setups (falls back to `EMACS_SOCKET_NAME` env var)

**Usage pattern:**
```bash
# Default (connects to "server" socket)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Title\")"

# Target a specific daemon
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval -s myemacs "(claude-orgmode-create-note \"Title\")"
```

## Key Implementation Details

### Backend Abstraction

`elisp/claude-orgmode-backend.el` auto-detects the active backend:
1. Checks if `org-roam` or `vulpea` feature is already loaded
2. Tries to require `org-roam`, then `vulpea`
3. Caches result in `claude-orgmode--backend` variable

All modules use `claude-orgmode--backend-*` dispatch functions instead of direct org-roam or vulpea calls.

### Note Creation

**`claude-orgmode-create-note`** creates files directly with proper structure (PROPERTIES block, ID, title, filetags). For org-roam, it reads the user's capture templates. For vulpea, it delegates to `vulpea-create`.

**Implementation reference:** `elisp/claude-orgmode-create.el`

### Tag Sanitization

Org tags cannot contain hyphens. All tag functions automatically sanitize:
- `my-tag` → `my_tag`

**Implementation:** `elisp/claude-orgmode-tags.el`

### Attachments

Uses `org-attach` functions via the `claude-orgmode--with-node-context` helper.

**Implementation:** `elisp/claude-orgmode-attach.el`

### Formatting

All file-modifying operations auto-format using `claude-orgmode--format-buffer`.

**Implementation:** `elisp/claude-orgmode-core.el`

### Temp File Handling

- External `:content-file` parameters are automatically deleted after processing
- Only deletes files in temp directories (`/tmp/`, `/var/tmp/`, and `temporary-file-directory`)
- Use `:keep-file t` to prevent deletion

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

### Pre-Commit Checklist

Before committing changes:
1. Run `eldev -C --unstable test` - all tests must pass
2. Run `eldev -C --unstable lint` - no linting errors
3. Add tests for new functionality
4. Update tests if changing existing behavior

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
