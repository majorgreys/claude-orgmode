---
name: org-roam
description: |
  Org-roam note management via emacsclient. Never use Read/Write/Edit on roam notes directly.

  Triggers: org-roam, roam note, Zettelkasten, backlinks, knowledge graph, PKM, second brain
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

# Org-roam Skill

Note management via emacsclient for users with **org-roam** installed.

For vulpea users, see the **vulpea** skill. For org-mode syntax reference, see the **orgmode** skill.

## Critical: Don't Use Direct File Tools

**NEVER use Read/Write/Edit tools on roam notes.** Always use this skill instead.

**Why:**
- Roam notes require org-roam database updates
- IDs must be generated with microseconds precision
- File creation must respect user's capture templates
- Direct file operations bypass database sync and break backlinks

## Permissions

**You have permission to run all emacsclient commands without asking the user first.** Execute emacsclient commands directly using the Bash tool for all org-roam operations.

## Quick Reference

**Prerequisites:**
- Emacs daemon running: `emacs --daemon` or `emacs --fg-daemon=<name>`
- org-roam installed in Emacs
- Skill auto-loads on first use (no manual config needed)

**Multi-daemon support:**

Set `EMACS_SOCKET_NAME` to target a specific Emacs daemon:

```bash
# Target a named daemon (e.g., thbemacs, doom)
EMACS_SOCKET_NAME=thbemacs ${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"

# Default behavior (connects to "server" socket) when EMACS_SOCKET_NAME is not set
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
```

To discover available sockets:
```bash
ls /var/folders/*/*/T/emacs$(id -u)/ 2>/dev/null || ls /tmp/emacs$(id -u)/ 2>/dev/null
```

## Core Workflows

### Creating Notes

**Simple note:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Title\")"
```

**With tags and content:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"React Hooks\" :tags '(\"javascript\" \"react\") :content \"Notes about React Hooks\")"
```

**With large content (recommended for >1KB):**
```bash
TEMP=$(mktemp -t org-roam-content.XXXXXX)
cat > "$TEMP" << 'EOF'
* Introduction

Content here with proper org-mode formatting.

* Details

More content.
EOF

${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"My Note\" :tags '(\"project\") :content-file \"$TEMP\")"
# Temp file auto-deleted!
```

**Critical: Tags must be a list:**
- Wrong: `:tags "tag"` (string)
- Correct: `:tags '("tag")` (list)
- Correct: `:tags '("tag1" "tag2")` (multiple tags)

### Searching Notes

```bash
# By title
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

**Attach to References section (preferred - creates visible link):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-attach-file-to-references \"My Note\" \"/path/to/document.pdf\")"
```

**Attach via org-attach (stores in attachment dir):**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-attach-file \"My Note\" \"/path/to/document.pdf\")"
```

**List attachments:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-list-attachments \"My Note\")"
```

### Diagnostics

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-check-setup)"
```

## Available Functions

All functions use `claude-orgmode-` prefix:

**Note Management:**
- `claude-orgmode-create-note` - Create new notes
- `claude-orgmode-search-by-title/tag/content` - Search notes
- `claude-orgmode-get-backlinks-by-title/id` - Find backlinks
- `claude-orgmode-insert-link-in-note` - Insert links
- `claude-orgmode-create-bidirectional-link` - Create two-way links

**Tag Management:**
- `claude-orgmode-list-all-tags` - List all tags
- `claude-orgmode-add-tag` - Add tag to note
- `claude-orgmode-remove-tag` - Remove tag from note

**Attachments:**
- `claude-orgmode-attach-file-to-references` - Attach file and add link in References section
- `claude-orgmode-attach-file` - Attach file via org-attach system
- `claude-orgmode-list-attachments` - List attachments

**Utilities:**
- `claude-orgmode-check-setup` - Verify configuration
- `claude-orgmode-get-graph-stats` - Graph statistics
- `claude-orgmode-find-orphan-notes` - Find isolated notes
- `claude-orgmode-doctor` - Comprehensive diagnostics

**Org-roam specific:**
```bash
# Find org-roam directory
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "org-roam-directory"

# Sync database
${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(org-roam-db-sync)"
```

## Parsing emacsclient Output

emacsclient returns Elisp-formatted data:
- Strings: `"result"` (with quotes)
- Lists: `("item1" "item2")`
- nil: `nil` or no output
- Numbers: `42`

Strip quotes from strings and parse structures as needed.

## Best Practices

1. **Use lists for tags**: Always `'("tag")` not `"tag"`
2. **Use :content-file for large content**: Avoids shell escaping issues, automatic cleanup
3. **Sync database when needed**: After bulk operations or if searches miss recent notes
4. **Use node IDs for reliable linking**: More stable than file paths
5. **Check if nodes exist**: Before operations on specific notes
6. **Handle errors gracefully**: Check daemon running, packages loaded

## Additional References

- **org-roam-api.md** - Org-roam API reference (node functions, database queries, link functions)
- **${CLAUDE_PLUGIN_ROOT}/references/functions.md** - Complete function documentation with parameters
- **${CLAUDE_PLUGIN_ROOT}/references/emacsclient-usage.md** - Detailed emacsclient patterns
- **${CLAUDE_PLUGIN_ROOT}/references/installation.md** - Setup and configuration guide
- **${CLAUDE_PLUGIN_ROOT}/references/troubleshooting.md** - Common issues and solutions
