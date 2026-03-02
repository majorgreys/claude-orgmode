# Installation and Setup

Simple installation guide for claude-orgmode.

## Prerequisites

You need:
1. **Emacs with org-roam installed and configured**
2. **Emacs daemon running**: `emacs --daemon` or `emacs --fg-daemon=<name>`
3. **org-roam directory set up**: Your notes directory (e.g., `~/org-roam/` or `~/Documents/org/roam/`)
4. **org-roam database initialized**

That's it! No manual package loading or configuration needed.

## How Auto-Loading Works

The skill includes a wrapper script at `scripts/claude-orgmode-eval` that:
1. Checks if `claude-orgmode` package is loaded
2. If not, automatically loads it from the skill directory
3. Executes your elisp expression
4. On subsequent calls, package is already in memory (fast!)

You don't need to modify your Emacs configuration at all.

## Verification

### Check Emacs daemon is running

```bash
emacsclient --eval "t"
```

Should return `t`. If not, start the daemon:
```bash
emacs --daemon
```

For named daemons, specify the socket:
```bash
emacsclient --socket-name thbemacs --eval "t"
```

### Check org-roam is installed

```bash
emacsclient --eval "(featurep 'org-roam)"
```

Should return `t`. If not, install org-roam in Emacs.

### Find your org-roam directory

```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "org-roam-directory"
```

Returns your configured org-roam directory path.

### Run diagnostic

```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
```

This checks your org-roam configuration, database, and templates.

## Optional: Recommended org-roam Configuration

For cleaner filenames, configure org-roam to use timestamp-only format.

### For Doom Emacs

Add to `~/.doom.d/config.el`:

```elisp
(setq org-roam-directory "~/Documents/org/roam/")

(after! org-roam
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
           :unnarrowed t))))
```

### For Vanilla Emacs

Add to `~/.emacs.d/init.el`:

```elisp
(setq org-roam-directory "~/Documents/org/roam/")

(with-eval-after-load 'org-roam
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
           :unnarrowed t))))
```

### Why This is Optional

- Creates files like `20251019193157.org` (clean)
- Instead of `20251019193157-title-slug.org` (default)
- **The skill auto-detects your template format**
- Works with both formats automatically

### Note on Title Duplication

The `"${title}"` in the template prevents #+title duplication, as org-roam adds it automatically.

## Multi-Daemon Setup

If you run multiple Emacs configurations (e.g., custom Emacs and Doom Emacs), each can run as a named daemon with its own socket:

```bash
# Start named daemons
emacs --init-directory ~/.config/thbemacs --fg-daemon=thbemacs
emacs --init-directory ~/.config/doom --fg-daemon=doom
```

Set `EMACS_SOCKET_NAME` to target a specific daemon with `claude-orgmode-eval`:

```bash
# Target thbemacs
EMACS_SOCKET_NAME=thbemacs ${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"

# Target doom
EMACS_SOCKET_NAME=doom ${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(claude-orgmode-doctor)"
```

To discover available sockets:

```bash
# macOS
ls /var/folders/*/*/T/emacs$(id -u)/ 2>/dev/null

# Linux
ls /run/user/$(id -u)/emacs/ 2>/dev/null || ls /tmp/emacs$(id -u)/ 2>/dev/null
```

Each daemon loads `claude-orgmode` independently on first use. They may have different org-roam directories and databases.

## Common Setup Issues

### Daemon not running

```bash
emacs --daemon
```

### org-roam not installed

Install org-roam package in Emacs. For Doom:
```elisp
;; In packages.el
(package! org-roam)
```

For vanilla Emacs, use package-install or your preferred package manager.

### org-roam not loaded

Ensure org-roam loads on startup:

```elisp
(require 'org-roam)
(org-roam-db-autosync-mode)
```

### Database not initialized

Manually sync:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/roam/scripts/claude-orgmode-eval "(org-roam-db-sync)"
```

## Upgrading the Skill

When the skill is updated, simply pull the latest version. No configuration changes needed since the package auto-loads from the skill directory.

The auto-load mechanism ensures you're always using the version of `claude-orgmode` that ships with the skill, not a separately installed version.
