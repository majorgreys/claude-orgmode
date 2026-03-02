# claude-orgmode

A Claude Code plugin for org-mode note management via emacsclient (org-roam + vulpea).

## What is this?

This is a **Claude Code plugin** that automatically activates when you ask Claude Code questions about your org-roam or vulpea notes. You don't need to learn any commands; just ask naturally:

- "Create a new note about functional programming"
- "Search my notes for anything related to Emacs"
- "Remember this insight: [your idea]"
- "Show me all backlinks to my React note"
- "Link my new note about hooks to my React note"

The plugin works with **Claude Code only** (not Claude Desktop, which uses a different skill system).

## What can it do?

- Create new org-roam notes with tags and content
- Search and query your note database
- Find backlinks and connections between notes
- Add tags and metadata to notes
- Insert links between notes
- Analyze your knowledge graph
- Diagnose org-roam setup issues

## Prerequisites

1. **Claude Code** installed and running
2. **Emacs with org-roam (or vulpea) installed and configured**
3. **Emacs daemon running**: Start with `emacs --daemon` or `emacs --fg-daemon=<name>`
4. **emacsclient available**: Should be installed with Emacs
5. **org-roam directory set up**: Your notes directory (e.g., `~/org-roam/` or `~/Documents/org/roam/`)

**The plugin auto-loads on first use** - no Emacs configuration needed!

### Multi-daemon Support

Set `EMACS_SOCKET_NAME` to target a specific Emacs daemon:

```bash
EMACS_SOCKET_NAME=thbemacs claude-orgmode-eval "(claude-orgmode-doctor)"
```

### Optional: Recommended Configuration

For cleaner filenames, you can optionally configure org-roam to use timestamp-only format:

**For Doom Emacs:**
```elisp
(setq org-roam-directory "~/Documents/org/roam/")

(after! org-roam
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
           :unnarrowed t))))
```

**For vanilla Emacs:**
```elisp
(setq org-roam-directory "~/Documents/org/roam/")

(with-eval-after-load 'org-roam
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
           :unnarrowed t))))
```

## Installation

### As a Claude Code Plugin

```bash
claude plugin add majorgreys/claude-orgmode
```

### Manual Installation

```bash
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/majorgreys/claude-orgmode.git
```

### Verify Installation

```bash
emacsclient --eval "t"  # Verify Emacs daemon is running
```

## Structure

```
claude-orgmode/
├── .claude-plugin/
│   └── marketplace.json
├── skills/
│   └── roam/
│       ├── SKILL.md
│       ├── elisp/
│       │   ├── claude-orgmode.el
│       │   ├── claude-orgmode-core.el
│       │   ├── claude-orgmode-create.el
│       │   ├── claude-orgmode-search.el
│       │   ├── claude-orgmode-links.el
│       │   ├── claude-orgmode-tags.el
│       │   ├── claude-orgmode-attach.el
│       │   ├── claude-orgmode-utils.el
│       │   └── claude-orgmode-doctor.el
│       ├── scripts/
│       │   └── claude-orgmode-eval
│       └── references/
├── test/
├── CLAUDE.md
├── Eldev
└── README.md
```

## Testing

```bash
eldev -C --unstable prepare  # Install dependencies (first time only)
eldev -C --unstable test     # Run all tests
eldev -C --unstable lint     # Run linting checks
```

## Version History

### v3.0.0 (Breaking Changes)

- Renamed from `org-roam-skill` to `claude-orgmode`
- Restructured as Claude Code plugin with `.claude-plugin/marketplace.json`
- All function prefixes changed: `org-roam-skill-*` → `claude-orgmode-*`
- Diagnostics renamed: `org-roam-doctor` → `claude-orgmode-doctor`
- Script renamed: `org-roam-eval` → `claude-orgmode-eval`
- Fixed `claude-orgmode--format-buffer` bug (was removed in v2.0 but still called)

### v2.0.0

- Removed general org-mode formatting (use `orgmode` skill instead)
- Added multi-daemon support via `EMACS_SOCKET_NAME`
- Added file attachment support via org-attach and org-download

## License

This plugin is provided as-is for use with Claude Code and org-roam.
