---
name: notes
description: |
  Org-mode note management via emacsclient. Create, search, edit, and link org notes. Never use Read/Write/Edit on org notes directly.

  Use this skill whenever the user mentions org-mode notes, org notes, .org files for notes, roam notes, org-roam, vulpea, Zettelkasten, backlinks, knowledge graph, PKM, second brain, or wants to create, update, edit, search, or link notes in org-mode. Also use when the user asks to update a section, append to a note, or replace note content — the section editing API handles this without creating duplicates.
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval:*)
  - Bash(git status:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(mktemp:*)
  - Bash(emacsclient:*)
---

# Org-Mode Note Management

Create, search, edit, and link org-mode notes via emacsclient. The backend (org-roam or vulpea) is auto-detected — the API is identical regardless of which is installed.

For org-mode syntax reference, see the **orgmode** skill.

## Critical: Don't Use Direct File Tools

**NEVER use Read/Write/Edit tools on org notes.** Always use this skill's functions instead.

**Why:**
- Org notes require database updates after modification
- IDs must be generated through org-id
- File creation must respect user's capture templates
- Direct file operations bypass database sync and break backlinks

## Permissions

**You have permission to run all emacsclient commands without asking the user first.** Execute emacsclient commands directly using the Bash tool for all org note operations.

## Quick Reference

**Prerequisites:**
- Emacs daemon running: `emacs --daemon` or `emacs --fg-daemon=<name>`
- org-roam or vulpea installed in Emacs (backend auto-detected)
- Skill auto-loads on first use (no manual config needed)

**Multi-daemon support:**

Use `-s` to target a specific Emacs daemon:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval -s myemacs "(claude-orgmode-doctor)"
```

To discover available sockets:
```bash
ls /var/folders/*/*/T/emacs$(id -u)/ 2>/dev/null || ls /tmp/emacs$(id -u)/ 2>/dev/null
```

## Core Workflows

### Creating Notes

```bash
# Simple note
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Title\")"

# With tags and content
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"React Hooks\" :tags '(\"javascript\" \"react\") :content \"Notes about React Hooks\")"
```

**Large content (recommended for >1KB):**
```bash
TEMP=$(mktemp -t orgmode-content.XXXXXX)
cat > "$TEMP" << 'EOF'
* Introduction
Content here.

* Details
More content.
EOF

${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"My Note\" :tags '(\"project\") :content-file \"$TEMP\")"
# Temp file auto-deleted!
```

**Tags must be a list:**
- Wrong: `:tags "tag"` (string)
- Correct: `:tags '("tag")` (list)

### Editing Notes (Section API)

To update existing notes, use the section editing functions. These operate on node IDs and modify content without creating duplicates.

**Workflow: find the note, then edit it.**

```bash
# 1. Find the note's ID
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-search-by-title \"My Note\")"
# Returns: (("uuid-123" "My Note" "/path/to/note.org"))

# 2. Read current section content
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-get-section-content \"uuid-123\")"

# 3. Replace the section body
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-replace-section \"uuid-123\" :content \"Updated content.\")"

# Or append to it
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-append-to-section \"uuid-123\" :content \"Additional notes.\")"
```

**Adding new sections to an existing note:**
```bash
# Create a section under a file-level note (adds a * heading)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-section \"file-node-id\" \"New Section\" :content \"Section body.\")"
# Returns the new section's ID — use it for future edits

# Create a subsection under an existing heading (adds ** heading)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-section \"parent-heading-id\" \"Subsection\" :content \"Details.\")"
```

**Removing a section:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-delete-section \"section-id\")"
```

Section editing supports the same `:content-file` and `:keep-file` patterns as note creation for large content.

### Searching Notes

```bash
# By title (partial match)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-search-by-title \"react\")"

# By tag
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-search-by-tag \"javascript\")"

# By content
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-search-by-content \"functional programming\")"

# List all tags
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-list-all-tags)"
```

### Managing Links

```bash
# Find backlinks (notes linking TO this note)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-get-backlinks-by-title \"React\")"

# Create bidirectional links
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-bidirectional-link \"React Hooks\" \"React\")"

# Insert one-way link
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-insert-link-in-note \"Source Note\" \"Target Note\")"
```

### File Attachments

```bash
# Attach to References section (preferred - creates visible link)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-attach-file-to-references \"My Note\" \"/path/to/document.pdf\")"

# Attach via org-attach (stores in attachment dir)
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-attach-file \"My Note\" \"/path/to/document.pdf\")"

# List attachments
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-list-attachments \"My Note\")"
```

### Diagnostics

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-check-setup)"
```

## Available Functions

All functions use the `claude-orgmode-` prefix. The backend is auto-detected.

**Note Creation:**
- `claude-orgmode-create-note` — Create new notes

**Section Editing:**
- `claude-orgmode-get-section-content` — Read body text of a node by ID
- `claude-orgmode-create-section` — Create a new heading with ID under a parent node
- `claude-orgmode-replace-section` — Replace body text of a node
- `claude-orgmode-append-to-section` — Append content to a node's body
- `claude-orgmode-delete-section` — Delete a heading and its subtree

**Search:**
- `claude-orgmode-search-by-title/tag/content` — Search notes
- `claude-orgmode-get-backlinks-by-title/id` — Find backlinks

**Links:**
- `claude-orgmode-insert-link-in-note` — Insert links
- `claude-orgmode-create-bidirectional-link` — Create two-way links

**Tags:**
- `claude-orgmode-list-all-tags` — List all tags
- `claude-orgmode-add-tag` — Add tag to note
- `claude-orgmode-remove-tag` — Remove tag from note

**Attachments:**
- `claude-orgmode-attach-file-to-references` — Attach file with link in References section
- `claude-orgmode-attach-file` — Attach file via org-attach
- `claude-orgmode-list-attachments` — List attachments

**Utilities:**
- `claude-orgmode-check-setup` — Verify configuration
- `claude-orgmode-get-graph-stats` — Graph statistics
- `claude-orgmode-find-orphan-notes` — Find isolated notes
- `claude-orgmode-doctor` — Comprehensive diagnostics

## Parsing emacsclient Output

emacsclient returns Elisp-formatted data:
- Strings: `"result"` (with quotes)
- Lists: `("item1" "item2")`
- nil: `nil` or no output
- Numbers: `42`

Strip quotes from strings and parse structures as needed.

## Best Practices

1. **Use section editing to update notes** — never call `create-note` to update an existing org note
2. **Search first, then edit** — find the node ID via search, then use section functions
3. **Use lists for tags** — always `'("tag")` not `"tag"`
4. **Use :content-file for large content** — avoids shell escaping issues, auto-cleaned up
5. **Use node IDs for reliable operations** — more stable than titles
6. **Sync database when needed** — after bulk operations or if searches miss recent notes

## Additional References

- **${CLAUDE_PLUGIN_ROOT}/references/functions.md** — Complete function documentation with parameters and examples
- **${CLAUDE_PLUGIN_ROOT}/references/emacsclient-usage.md** — Detailed emacsclient patterns
- **${CLAUDE_PLUGIN_ROOT}/references/installation.md** — Setup and configuration guide
- **${CLAUDE_PLUGIN_ROOT}/references/troubleshooting.md** — Common issues and solutions
- **org-roam-api.md** — Low-level org-roam API (read only if you need direct org-roam calls)
- **vulpea-api.md** — Low-level vulpea API (read only if you need direct vulpea calls)
