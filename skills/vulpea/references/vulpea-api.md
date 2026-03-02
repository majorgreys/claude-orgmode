# Vulpea API Reference

This document provides a quick reference for commonly used vulpea functions.
Vulpea is an alternative backend to org-roam for managing org-mode notes.

## Note Functions

### Getting Notes

- `(vulpea-db-query)` - Get all notes in the database
- `(vulpea-db-get-by-id ID)` - Get note by ID
- `(vulpea-db-search-by-title TITLE)` - Search notes by title (returns a list)

### Note Properties

- `(vulpea-note-id NOTE)` - Get note ID
- `(vulpea-note-title NOTE)` - Get note title
- `(vulpea-note-path NOTE)` - Get note file path
- `(vulpea-note-tags NOTE)` - Get note tags (list)
- `(vulpea-note-aliases NOTE)` - Get note aliases (list)
- `(vulpea-note-level NOTE)` - Get note heading level (0 for file-level)

### Tag Constraints

**Important**: Org-mode tags cannot contain hyphens (-). When creating or adding tags:
- Invalid: `my-tag`, `web-dev`, `machine-learning`
- Valid: `my_tag`, `web_dev`, `machine_learning`

The `claude-orgmode--sanitize-tag` function automatically replaces hyphens with underscores.

## Database Functions

- `(vulpea-db-sync-full-scan)` - Full database synchronization
- `(vulpea-db-query)` - Query all notes from the database

Example query with filtering:
```elisp
(seq-filter
 (lambda (note)
   (string-match-p "pattern" (vulpea-note-title note)))
 (vulpea-db-query))
```

## Link Functions

### Backlinks

- `(vulpea-db-query-links-to NOTE-ID)` - Get links pointing to NOTE-ID
  - Returns a list of plists, each with a `:source` key containing the source note ID

### Creating Links

Standard org-mode link functions work with vulpea:

```elisp
(org-link-make-string "id:abc-123" "Link Text")
;; Returns: "[[id:abc-123][Link Text]]"
```

## Note Creation

- `(vulpea-create TITLE &optional META &key tags body)` - Create a new note

Example:
```elisp
(let ((note (vulpea-create "New Note" nil
                           :tags '("project" "emacs")
                           :body "Note content here")))
  (vulpea-note-path note))
```

## Tag Functions

- `(vulpea-tags-add NOTE TAG)` - Add TAG to NOTE
- `(vulpea-tags-remove NOTE TAG)` - Remove TAG from NOTE

Example:
```elisp
(let ((note (vulpea-db-get-by-id "some-uuid")))
  (vulpea-tags-add note "new_tag"))
```

## ID Functions

These are standard org-mode functions shared with org-roam:

- `(org-id-uuid)` - Generate a new UUID
- `(org-id-get-create)` - Get or create ID for current entry

## Useful Variables

- `vulpea-db-sync-directories` - List of directories to sync
- `vulpea-db-location` - Path to vulpea database file
- `org-directory` - Fallback directory when `vulpea-db-sync-directories` is unset

## Common Patterns

### Search by Title Pattern

```elisp
(seq-filter
 (lambda (note)
   (string-match-p "pattern" (vulpea-note-title note)))
 (vulpea-db-query))
```

### Get All Tags

```elisp
(delete-dups
 (flatten-list
  (mapcar #'vulpea-note-tags (vulpea-db-query))))
```

### Get Backlink Sources

```elisp
(let* ((note (vulpea-db-get-by-id "target-uuid"))
       (links (vulpea-db-query-links-to (vulpea-note-id note))))
  (mapcar (lambda (link)
            (vulpea-db-get-by-id (plist-get link :source)))
          links))
```

### Read File Contents

```elisp
(let ((note (vulpea-db-get-by-id "some-uuid")))
  (with-temp-buffer
    (insert-file-contents (vulpea-note-path note))
    (buffer-string)))
```

## Differences from Org-roam

| Operation | Org-roam | Vulpea |
|-----------|----------|--------|
| All nodes | `(org-roam-node-list)` | `(vulpea-db-query)` |
| By ID | `(org-roam-node-from-id ID)` | `(vulpea-db-get-by-id ID)` |
| By title | `(org-roam-node-from-title-or-alias T)` | `(car (vulpea-db-search-by-title T))` |
| File path | `(org-roam-node-file N)` | `(vulpea-note-path N)` |
| Backlinks | `(org-roam-backlinks-get N)` | `(vulpea-db-query-links-to ID)` |
| DB sync | `(org-roam-db-sync)` | `(vulpea-db-sync-full-scan)` |
| Add tag | Manual filetags edit | `(vulpea-tags-add N TAG)` |
| Remove tag | Manual filetags edit | `(vulpea-tags-remove N TAG)` |
| Create note | `claude-orgmode-create-note` | `(vulpea-create TITLE ...)` |
