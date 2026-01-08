# Troubleshooting Guide

Common issues and solutions for org-roam-skill.

## Connection Issues

### Daemon Not Running

**Symptoms:**
- `emacsclient: can't find socket; have you started the server?`
- Connection refused errors

**Solution:**
```bash
emacs --daemon
```

**Verify:**
```bash
emacsclient --eval "t"
```

Should return `t` without errors.

### Multiple Daemon Instances

**Symptoms:**
- Unpredictable behavior
- Functions not found
- Wrong configuration loaded

**Check running daemons:**
```bash
ps aux | grep "emacs --daemon"
```

**Solution:**
Kill all daemons and restart:
```bash
pkill -f "emacs --daemon"
emacs --daemon
```

## Package Loading Issues

### org-roam-skill Not Loaded

**Symptoms:**
- `emacsclient --eval "(featurep 'org-roam-skill)"` returns `nil`
- Function not found errors

**Solution:**

1. Verify load-path is correct:
   ```bash
   ls ${CLAUDE_PLUGIN_ROOT}/elisp/org-roam-skill.el
   ```

2. Check Emacs configuration has correct path:
   ```elisp
   ;; For Doom (replace <PLUGIN_PATH> with actual plugin location)
   (use-package! org-roam-skill
     :load-path "<PLUGIN_PATH>/elisp")

   ;; For vanilla (replace <PLUGIN_PATH> with actual plugin location)
   (add-to-list 'load-path "<PLUGIN_PATH>/elisp")
   (require 'org-roam-skill)
   ```

   Note: `<PLUGIN_PATH>` is the skill's installation directory. The auto-load
   wrapper (`scripts/org-roam-eval`) handles this automatically—manual Emacs
   configuration is only needed if auto-loading fails.

3. Restart Emacs daemon:
   ```bash
   pkill -f "emacs --daemon"
   emacs --daemon
   ```

4. Verify loaded:
   ```bash
   emacsclient --eval "(featurep 'org-roam-skill)"
   ```

### org-roam Not Loaded

**Symptoms:**
- `org-roam-directory` not defined
- org-roam functions not available

**Verify:**
```bash
emacsclient --eval "(featurep 'org-roam)"
```

**Solution:**

Add to Emacs init:
```elisp
(require 'org-roam)
(org-roam-db-autosync-mode)
```

Restart daemon.

## Database Issues

### Database Not Initialized

**Symptoms:**
- Database file doesn't exist
- Empty query results
- "Database is empty" warnings

**Check database:**
```bash
emacsclient --eval "(file-exists-p org-roam-db-location)"
```

**Solution:**
```bash
emacsclient --eval "(org-roam-db-sync)"
```

Wait for sync to complete (may take time for large note collections).

### Database Out of Sync

**Symptoms:**
- Recently created notes not appearing in searches
- Stale backlinks
- Missing connections

**Solution:**

Force full resync:
```bash
emacsclient --eval "(org-roam-db-sync 'force)"
```

### Database Corruption

**Symptoms:**
- SQL errors
- Crashes when querying
- Incomplete results

**Solution:**

Rebuild database from scratch:
```bash
# Backup first
cp $(emacsclient --eval "org-roam-db-location") ~/org-roam-db-backup.db

# Delete and rebuild
emacsclient --eval "(progn
  (delete-file org-roam-db-location)
  (org-roam-db-sync))"
```

## Note Creation Issues

### Tag Formatting Errors

**Symptoms:**
- `wrong-type-argument` errors
- Tags not applied correctly
- `listp` errors

**Problem:**
Tags passed as string instead of list.

**Wrong:**
```bash
emacsclient --eval "(org-roam-skill-create-note \"Title\" :tags \"tag\")"
```

**Correct:**
```bash
emacsclient --eval "(org-roam-skill-create-note \"Title\" :tags '(\"tag\"))"
```

### Content Escaping Issues

**Symptoms:**
- Shell escaping errors
- Partial content
- Special characters broken

**Solution:**

Use `:content-file` instead of `:content` for complex content:

```bash
TEMP=$(mktemp -t org-roam-content.XXXXXX)
cat > "$TEMP" << 'EOF'
Your content with special characters, quotes, etc.
EOF
emacsclient --eval "(org-roam-skill-create-note \"Title\" :content-file \"$TEMP\")"
```

### Title Duplication

**Symptoms:**
- `#+title:` appears twice in created notes

**Cause:**
Capture template includes `#+title:` in head.

**Solution:**

Use minimal head in template:
```elisp
(setq org-roam-capture-templates
      '(("d" "default" plain "%?"
         :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
         :unnarrowed t)))
```

The `"${title}"` creates the file, org-roam adds `#+title:` automatically.

### Content Not Being Formatted

**Symptoms:**
- Markdown content appears as-is in org-roam notes
- Content is not converted to org-mode format

**Explanation:**
As of v2.0, this skill no longer performs automatic markdown→org conversion. This is intentional to maintain separation of concerns.

**Solution:**

Use the `orgmode` skill for general org-mode formatting before creating roam notes:

```bash
# Step 1: Convert markdown to org (orgmode skill)
# Step 2: Create roam note with org content (this skill)
${CLAUDE_PLUGIN_ROOT}/scripts/org-roam-eval \
  "(org-roam-skill-create-note \"Title\" :content \"* Org content\")"
```

This skill focuses on org-roam-specific operations (note creation, database sync, node linking). For general org-mode formatting, use the `orgmode` skill.

## Search Issues

### No Results Found

**Symptoms:**
- Search returns empty even for known notes
- Backlinks not appearing

**Solutions:**

1. Sync database:
   ```bash
   emacsclient --eval "(org-roam-db-sync)"
   ```

2. Check search term case (searches are case-insensitive):
   ```bash
   emacsclient --eval "(org-roam-skill-search-by-title \"react\")"
   ```

3. Verify note exists:
   ```bash
   emacsclient --eval "(org-roam-node-list)"
   ```

### Partial Matches Not Working

**Symptoms:**
- Only exact title matches work
- Substring searches fail

**Note:**
`org-roam-skill-search-by-title` does partial matching by default. If not working, check database is synced.

## Link Issues

### Backlinks Not Appearing

**Symptoms:**
- Created links don't show as backlinks
- Connection missing in graph

**Solutions:**

1. Ensure link uses ID format:
   ```org
   [[id:node-uuid][Description]]
   ```

2. Sync database after creating links:
   ```bash
   emacsclient --eval "(org-roam-db-sync)"
   ```

3. Verify link was actually inserted:
   ```bash
   emacsclient --eval "(org-roam-skill-get-backlinks-by-title \"Target Note\")"
   ```

### Bidirectional Links Only Go One Way

**Symptoms:**
- Only one direction of link created
- Asymmetric connections

**Check:**
Both notes should have links. Verify manually:
```bash
# Open both notes
emacsclient --eval "(find-file (org-roam-node-file (org-roam-node-from-title-or-alias \"Note A\")))"
emacsclient --eval "(find-file (org-roam-node-file (org-roam-node-from-title-or-alias \"Note B\")))"
```

Look for `id:` links in both files.

## Performance Issues

### Slow Queries

**Symptoms:**
- Searches take seconds
- Database sync is slow

**Solutions:**

1. Check database size:
   ```bash
   ls -lh $(emacsclient --eval "org-roam-db-location")
   ```

2. For large databases, use specific searches:
   - Use title search instead of content search when possible
   - Use tag filters to narrow results

3. Keep daemon running (avoid repeated startup overhead)

### Memory Usage

**Symptoms:**
- High memory usage
- Daemon crashes

**Solution:**

Restart daemon periodically:
```bash
pkill -f "emacs --daemon"
emacs --daemon
```

## Permission Issues

### Cannot Write to Org-roam Directory

**Symptoms:**
- "Permission denied" when creating notes
- Cannot create files

**Check permissions:**
```bash
ls -ld $(emacsclient --eval "org-roam-directory")
```

**Solution:**
```bash
chmod 755 ~/Documents/org/roam
```

### Database Not Writable

**Symptoms:**
- Cannot sync database
- Read-only database errors

**Check:**
```bash
ls -l $(emacsclient --eval "org-roam-db-location")
```

**Fix:**
```bash
chmod 644 $(emacsclient --eval "org-roam-db-location")
```

## Diagnostic Commands

### Full System Check

Run comprehensive diagnostic:
```bash
emacsclient --eval "(org-roam-doctor)"
```

Checks:
- Emacs version
- org-roam version
- Directory exists and accessible
- Database status
- Template configuration

### Check Package Status

```bash
# Check org-roam-skill loaded
emacsclient --eval "(featurep 'org-roam-skill)"

# Check org-roam loaded
emacsclient --eval "(featurep 'org-roam)"

# Check database exists
emacsclient --eval "(file-exists-p org-roam-db-location)"

# Check directory configured
emacsclient --eval "org-roam-directory"
```

### Get System Info

```bash
# Emacs version
emacsclient --eval "(emacs-version)"

# org-roam version
emacsclient --eval "(pkg-info-version-info 'org-roam)"

# Database path
emacsclient --eval "org-roam-db-location"

# Capture templates
emacsclient --eval "org-roam-capture-templates"
```

## Getting Help

If issues persist:

1. **Run diagnostic**: `emacsclient --eval "(org-roam-doctor)"`
2. **Check logs**: Look for errors in `*Messages*` buffer
3. **Verify setup**: Ensure all prerequisites are met (see references/installation.md)
4. **Restart daemon**: Often resolves transient issues
5. **Check org-roam documentation**: Many issues are org-roam specific, not skill specific
