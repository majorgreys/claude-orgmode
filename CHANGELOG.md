# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-02

### BREAKING CHANGES

**Renamed from org-roam-skill to claude-orgmode**

All function prefixes changed: `org-roam-skill-*` → `claude-orgmode-*`
Script renamed: `org-roam-eval` → `claude-orgmode-eval`
Diagnostics renamed: `org-roam-doctor` → `claude-orgmode-doctor`

### Added

- Backend abstraction layer (auto-detect org-roam vs vulpea)
- Vulpea backend support via `claude-orgmode-backend.el`
- Split into three skills: orgmode (knowledge), org-roam (operations), vulpea (operations)
- Plugin metadata (`.claude-plugin/marketplace.json`)
- Plugin integration tests for both backends
- Vulpea dispatch tests
- Multi-daemon support via `EMACS_SOCKET_NAME`
- File attachment support via org-attach and References section

### Changed

- Moved shared elisp to project root `elisp/`
- Moved shared scripts to project root `scripts/`
- Moved shared references to project root `references/`
- Each skill has its own SKILL.md with appropriate triggers and allowed-tools

## [2.0.0] - 2025-12-15

### BREAKING CHANGES

**Removed general org-mode formatting functionality**

This version removes general org-mode formatting capabilities, establishing
a clear separation of concerns with the orgmode skill.

#### Removed Functions
- `org-roam-skill--detect-format` (internal)
- `org-roam-skill--format-content` (internal)
- `org-roam-skill--format-buffer` (internal)
- `format-org-roam-note` (public API) ⚠️ **BREAKING**

#### Removed Parameters
- `:no-format` parameter from `org-roam-skill-create-note` ⚠️ **BREAKING**

#### Migration Guide

**For automatic markdown→org conversion:**

Before (v1.x):
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/org-roam-eval \
  "(org-roam-skill-create-note \"Title\" :content \"# Markdown\")"
```

After (v2.x):
```bash
# Convert with orgmode skill first
orgmode_content=$(convert-markdown-to-org "# Markdown")

# Then create roam note
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/org-roam-eval \
  "(org-roam-skill-create-note \"Title\" :content \"$orgmode_content\")"
```

**For table formatting:**

Before (v1.x):
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/org-roam-eval \
  "(format-org-roam-note \"Note Title\")"
```

After (v2.x):
```bash
# Use orgmode skill for general formatting
orgmode format-table-in-file "/path/to/note.org"
```

#### Why This Change?

- **Separation of concerns**: Org-roam-skill focuses on org-roam-specific
  operations (database sync, node management, links)
- **Dependency clarity**: General org-mode formatting belongs in orgmode skill
- **Reduced complexity**: ~240 lines removed, clearer scope
- **Better maintainability**: Each skill has a single, clear responsibility

#### What Remains?

Org-roam-skill still handles:
- Note creation with proper org-roam structure (PROPERTIES, ID, FILETAGS)
- Org-roam capture template processing
- Database synchronization
- Node search and linking
- Backlinks and graph management
- Attachments
- Tag management
- Org-roam-specific validation (PROPERTIES drawer structure)

### Dependencies

- **New**: Recommend using `orgmode` skill for general org-mode operations
- No runtime dependency check (documentation-only)

### Changed

- Updated documentation to reference orgmode skill for formatting needs
- Added troubleshooting section for content formatting
- Simplified codebase by ~240 lines

## [1.0.0] - 2025-12-01

Initial release with full org-roam note management capabilities.

### Added

- Note creation with auto-detection of capture template format
- Markdown to org-mode conversion via pandoc
- Node search by title, tag, and ID
- Bidirectional link creation and management
- Backlink retrieval
- Tag management (add, list, count, search)
- Graph statistics and analysis
- Orphan note detection
- Attachment support via org-attach
- Comprehensive test suite with Buttercup
- Auto-loading via wrapper script
- Temp file cleanup for `:content-file` parameter
- Diagnostic commands for troubleshooting
- Full documentation with examples
