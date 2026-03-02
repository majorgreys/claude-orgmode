# Function Reference

Detailed documentation for all claude-orgmode functions.

## Table of Contents

- [Note Creation](#note-creation)
- [Search Functions](#search-functions)
- [Link Management](#link-management)
- [Tag Management](#tag-management)
- [Attachment Management](#attachment-management)
- [Utility Functions](#utility-functions)
- [Diagnostic Functions](#diagnostic-functions)

## Note Creation

### claude-orgmode-create-note

Create a new org-roam note with auto-detection of template format.

**Signature**: `(claude-orgmode-create-note TITLE &key tags content content-file keep-file)`

**Parameters:**
- `TITLE` (string, required): The note title
- `:tags` (list of strings, optional): Tags as `'("tag1" "tag2")` - **MUST be a list**
- `:content` (string, optional): Initial content (for small/simple content)
- `:content-file` (string, optional): Path to file containing content (for large content)
- `:keep-file` (boolean, optional): If `t`, prevent automatic deletion of `:content-file`

**Examples:**

Basic note:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"My Note\")"
```

With tags and content:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"React Hooks\" :tags '(\"javascript\" \"react\") :content \"Notes about hooks\")"
```

Large content via file:
```bash
TEMP=$(mktemp -t org-roam-content.XXXXXX)
cat > "$TEMP" << 'EOF'
* Section 1
Content here

* Section 2
More content
EOF
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-note \"Large Note\" :content-file \"$TEMP\")"
# Temp file automatically deleted
```

**Content Format:**

Content should be in org-mode format. For markdown conversion or general org-mode formatting, use the `orgmode` skill.

Example workflow:
```bash
# Step 1: Convert markdown to org (orgmode skill)
# Step 2: Create roam note with org content (this skill)
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval \
  "(claude-orgmode-create-note \"Title\" :content \"* Org heading\")"
```

**Automatic Behaviors:**
- Auto-detects filename format from `org-roam-capture-templates`
- Generates proper filenames (timestamp-only, timestamp-slug, or custom)
- Handles head content to avoid #+title duplication
- Sanitizes tags (replaces hyphens with underscores)
- Returns file path of created note

**Common tag mistakes:**
- ❌ `"planning"` (string)
- ✅ `'("planning")` (list with one element)
- ❌ `'planning` (unquoted symbol)
- ✅ `'("tag1" "tag2")` (list with multiple elements)

## Search Functions

### claude-orgmode-search-by-title

Search notes by title (case-insensitive, partial match).

**Signature**: `(claude-orgmode-search-by-title SEARCH-TERM)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-search-by-title \"react\")"
```

**Returns**: List of `(id title file)` tuples.

### claude-orgmode-search-by-tag

Search notes by tag.

**Signature**: `(claude-orgmode-search-by-tag TAG)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-search-by-tag \"javascript\")"
```

**Returns**: List of `(id title file)` tuples.

### claude-orgmode-search-by-content

Search notes by content (full-text search).

**Signature**: `(claude-orgmode-search-by-content SEARCH-TERM)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-search-by-content \"functional programming\")"
```

**Returns**: List of `(id title file)` tuples with matching content.

## Link Management

### claude-orgmode-get-backlinks-by-title

Find notes that link TO the specified note.

**Signature**: `(claude-orgmode-get-backlinks-by-title TITLE)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-get-backlinks-by-title \"React\")"
```

**Returns**: List of `(id title file)` tuples for notes linking to this note.

### claude-orgmode-get-backlinks-by-id

Find notes that link TO the specified note (by ID).

**Signature**: `(claude-orgmode-get-backlinks-by-id NODE-ID)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-get-backlinks-by-id \"abc123-def456\")"
```

### claude-orgmode-create-bidirectional-link

Create links between two notes (both directions).

**Signature**: `(claude-orgmode-create-bidirectional-link TITLE-A TITLE-B)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-create-bidirectional-link \"React Hooks\" \"React\")"
```

Creates:
- Link in "React Hooks" pointing to "React"
- Link in "React" pointing to "React Hooks"

### claude-orgmode-insert-link-in-note

Insert a link in one note pointing to another.

**Signature**: `(claude-orgmode-insert-link-in-note SOURCE-TITLE TARGET-TITLE)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-insert-link-in-note \"My Note\" \"React\")"
```

Adds link to "React" at the end of "My Note".

## Tag Management

### claude-orgmode-list-all-tags

List all unique tags across all notes.

**Signature**: `(claude-orgmode-list-all-tags)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-list-all-tags)"
```

**Returns**: Sorted list of all unique tags.

### claude-orgmode-add-tag

Add a tag to a note.

**Signature**: `(claude-orgmode-add-tag TITLE TAG)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-add-tag \"My Note\" \"important\")"
```

### claude-orgmode-remove-tag

Remove a tag from a note.

**Signature**: `(claude-orgmode-remove-tag TITLE TAG)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-remove-tag \"My Note\" \"draft\")"
```

## Attachment Management

### claude-orgmode-attach-file

Attach a file to a note (copies file to attachment directory).

**Signature**: `(claude-orgmode-attach-file TITLE FILE-PATH)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-attach-file \"My Note\" \"/path/to/document.pdf\")"
```

**Behavior:**
- Copies file to `{org-attach-id-dir}/{node-id}/filename`
- Adds `ATTACH` property to note automatically
- Uses org-mode's standard `org-attach` system

### claude-orgmode-list-attachments

List all attachments for a note.

**Signature**: `(claude-orgmode-list-attachments TITLE)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-list-attachments \"My Note\")"
```

**Returns**: List of attachment filenames.

### get-attachment-path

Get full path to a specific attachment.

**Signature**: `(get-attachment-path TITLE FILENAME)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(get-attachment-path \"My Note\" \"document.pdf\")"
```

### delete-note-attachment

Delete an attachment from a note.

**Signature**: `(delete-note-attachment TITLE FILENAME)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(delete-note-attachment \"My Note\" \"old-file.pdf\")"
```

### get-note-attachment-dir

Get the attachment directory path for a note.

**Signature**: `(get-note-attachment-dir TITLE)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(get-note-attachment-dir \"My Note\")"
```

**Returns**: Path to note's attachment directory.

## Utility Functions

### claude-orgmode-check-setup

Check if org-roam is properly configured.

**Signature**: `(claude-orgmode-check-setup)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-check-setup)"
```

**Returns**: Status message about setup (directory exists, database initialized, etc.).

### claude-orgmode-get-graph-stats

Get statistics about the knowledge graph.

**Signature**: `(claude-orgmode-get-graph-stats)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-get-graph-stats)"
```

**Returns**: Statistics like total notes, total links, tags count, etc.

### claude-orgmode-find-orphan-notes

Find notes with no backlinks or forward links.

**Signature**: `(claude-orgmode-find-orphan-notes)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-find-orphan-notes)"
```

**Returns**: List of `(id title file)` tuples for orphaned notes.

## Diagnostic Functions

### claude-orgmode-doctor

Comprehensive diagnostic check of org-roam setup.

**Signature**: `(claude-orgmode-doctor)`

**Example:**
```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
```

**Checks:**
- Emacs version
- org-roam version
- org-roam directory exists and is accessible
- Database location and status
- Capture templates configuration
- Database schema version

**Returns**: Detailed diagnostic report.

## Parsing emacsclient Output

emacsclient returns Elisp-formatted data:

- **Strings**: `"result"` (with quotes)
- **Lists**: `("item1" "item2" "item3")`
- **nil**: No output or `nil`
- **Numbers**: `42`

You may need to:
- Strip surrounding quotes from strings
- Parse list structures
- Handle nil/empty results

## Best Practices

1. Use `org-roam-node-*` functions for data access
2. Use `org-roam-node-from-title-or-alias` for flexible searching
3. Always check if nodes exist before operations
4. Sync database after creating/modifying notes if needed
5. Leverage org-roam's query functions rather than SQL directly
6. Use `seq-filter` and `mapcar` for list operations
7. Use `:content-file` for large content (automatic cleanup)
8. Always use lists for tags: `'("tag1" "tag2")`
