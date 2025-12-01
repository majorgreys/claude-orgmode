# Implementation Patterns

## Note Creation

### `org-roam-skill-create-note`

Creates files directly with proper org-roam structure (PROPERTIES block, ID, title, filetags). This is the recommended approach for programmatic note creation, as `org-roam-capture-` is designed for interactive use.

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

**Implementation reference:** `org-roam-skill-create.el:25`

## Node Access Patterns

**Search by title:**
```elisp
(org-roam-node-from-title-or-alias "Note Title")
```
Reference: `org-roam-skill-search.el:15`

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

## Attachments

Use `org-attach` functions via the `org-roam-skill--with-node-context` helper:

```elisp
(org-roam-skill--with-node-context node-id
  (org-attach-attach source-path nil 'cp))
```

**Behavior:**
- Files copied to `{org-attach-id-dir}/{node-id}/filename`
- org-attach automatically manages ATTACH property
- See `org-roam-skill-attach.el` for implementation

## Formatting

All file-modifying operations auto-format using `org-roam-skill--format-buffer`:
- Indents org content
- Aligns tables via `org-table-align`
- Ensures consistent formatting

Reference: `org-roam-skill-utils.el`

## Database Operations

**When to sync:**
Sync before queries if data might be stale:
```elisp
(org-roam-db-sync)
```

**Query preferences:**
- Prefer org-roam query functions over direct SQL
- Use `org-roam-db-query` only when necessary
- Check existing functions in `org-roam-skill-search.el` first

## Tag Handling

**Sanitization:**
Org tags cannot contain hyphens (-). All tag functions automatically sanitize:
- `my-tag` → `my_tag`
- `foo-bar-baz` → `foo_bar_baz`

**Implementation:** `org-roam-skill-tags.el`

## Error Handling

Most functions return:
- Success: The expected result (file path, node object, etc.)
- Failure: Error message string or nil

Check return values before using them in subsequent operations.
