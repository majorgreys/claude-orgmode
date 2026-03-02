# Emacsclient Usage Guide

This document explains how to use emacsclient with org-roam for this skill.

## Basic Usage

### Testing Connection

Check if Emacs daemon is running:

```bash
emacsclient --eval "t"
```

Expected output: `t`

If this fails, the daemon is not running. Start it with:

```bash
emacs --daemon
```

### Connecting to Named Daemons

When running multiple Emacs configurations, each uses a named socket:

```bash
# Connect to a specific daemon
emacsclient --socket-name myemacs --eval "t"
emacsclient --socket-name server --eval "t"
```

The `claude-orgmode-eval` wrapper reads `EMACS_SOCKET_NAME` to select the socket:

```bash
EMACS_SOCKET_NAME=myemacs ${CLAUDE_PLUGIN_ROOT}/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
```

### Loading Scripts

Load a helper script:

```bash
emacsclient --eval "(load-file \"/path/to/script.el\")"
```

### Calling Functions

Call a function and get results:

```bash
emacsclient --eval "(function-name arg1 arg2)"
```

## Output Parsing

### String Output

emacsclient returns strings with quotes:

```bash
emacsclient --eval "(org-roam-directory)"
# Output: "/Users/user/org-roam"
```

To strip quotes in bash:

```bash
result=$(emacsclient --eval "org-roam-directory")
result=${result//\"/}  # Remove all quotes
```

### List Output

Lists are returned as Elisp data:

```bash
emacsclient --eval "(list-all-tags)"
# Output: ("emacs" "programming" "writing")
```

### Formatting Output

Format output as strings within Elisp:

```bash
emacsclient --eval "(mapcar
  (lambda (node)
    (format \"%s|%s|%s\"
      (org-roam-node-id node)
      (org-roam-node-title node)
      (org-roam-node-file node)))
  (org-roam-node-list))"
```

Output will be a list of formatted strings.

### Pretty Printing

Use `princ` for clean output without quotes:

```bash
emacsclient --eval "(princ (org-roam-directory))"
# Output: /Users/user/org-roam (no quotes)
```

## Common Patterns

### Pattern 1: Load and Execute

```bash
emacsclient --eval "(progn
  (load-file \"scripts/search-notes.el\")
  (search-notes-by-title \"search term\"))"
```

### Pattern 2: Multi-step Operation

```bash
emacsclient --eval "(progn
  (org-roam-db-sync)
  (let ((node (org-roam-node-from-title-or-alias \"Note Title\")))
    (when node
      (org-roam-node-id node))))"
```

### Pattern 3: Iteration with Output

```bash
emacsclient --eval "(dolist (tag (list-all-tags))
  (princ (format \"%s\\n\" tag)))"
```

## Error Handling

### Check if Function Exists

```bash
emacsclient --eval "(fboundp 'org-roam-node-list)"
# Returns: t if function exists, nil otherwise
```

### Check if Feature is Loaded

```bash
emacsclient --eval "(featurep 'org-roam)"
# Returns: t if org-roam is loaded
```

### Try-Catch Pattern

```bash
emacsclient --eval "(condition-case err
  (org-roam-node-from-title-or-alias \"Note\")
  (error (message \"Error: %s\" err)))"
```

## Best Practices

1. **Always require org-roam** if not loaded:
   ```elisp
   (require 'org-roam)
   ```

2. **Sync database before queries**:
   ```elisp
   (org-roam-db-sync)
   ```

3. **Use progn for multiple expressions**:
   ```elisp
   (progn
     (expression-1)
     (expression-2)
     (expression-3))
   ```

4. **Quote strings properly in bash**:
   ```bash
   emacsclient --eval "(function-name \"arg with spaces\")"
   ```

5. **Use absolute paths for loading files**:
   ```bash
   emacsclient --eval "(load-file \"$(pwd)/scripts/create-note.el\")"
   ```

## Debugging

### Enable debug output:

```bash
emacsclient --eval "(setq debug-on-error t)"
```

### Get detailed error messages:

```bash
emacsclient --eval "(condition-case err
  (your-expression)
  (error (format \"Error: %S\" err)))"
```

### Check what functions are available:

```bash
emacsclient --eval "(apropos-command \"org-roam-node\")"
```

## Performance Considerations

- **Daemon stays running**: No startup overhead
- **Keep database in memory**: Faster queries
- **Batch operations**: Load scripts once, call functions multiple times
- **Reuse connections**: emacsclient reuses the daemon connection

## Example: Complete Workflow

```bash
#!/bin/bash

# Load all helper scripts
emacsclient --eval "(progn
  (load-file \"$(pwd)/scripts/create-note.el\")
  (load-file \"$(pwd)/scripts/search-notes.el\")
  (load-file \"$(pwd)/scripts/insert-link.el\"))"

# Sync database
emacsclient --eval "(org-roam-db-sync)"

# Create a note
emacsclient --eval "(create-org-roam-note \"My New Note\" '(\"tag1\" \"tag2\"))"

# Search for related notes
results=$(emacsclient --eval "(search-notes-by-tag \"tag1\")")

# Insert link
emacsclient --eval "(insert-link-in-note-by-title \"My New Note\" \"Existing Note\")"

echo "Done!"
```
