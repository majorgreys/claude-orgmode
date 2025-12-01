# Setup and Installation

## Package Loading

The user must load `org-roam-skill` in their Emacs configuration for this skill to work.

### Doom Emacs

Add to `config.el`:

```elisp
(use-package! org-roam-skill
  :load-path "~/.claude/skills/org-roam-skill")
```

### Vanilla Emacs

Add to `init.el`:

```elisp
(add-to-list 'load-path "~/.claude/skills/org-roam-skill")
(require 'org-roam-skill)
```

### After Installation

1. Restart Emacs or evaluate the configuration
2. All functions are loaded once at startup
3. Verify installation: `emacsclient --eval "(org-roam-doctor)"`

## Function Naming Convention

- Most functions use `org-roam-skill-` prefix
- Diagnostic functions use `org-roam-doctor*` prefix

## Dependencies

This skill requires:
- A running Emacs daemon with org-roam installed and configured
- `emacsclient` available in PATH
- `org-roam-directory` set in Emacs configuration
