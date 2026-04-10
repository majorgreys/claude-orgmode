# claude-orgmode

A Claude Code plugin for org-mode knowledge and note management via emacsclient (org-roam + vulpea).

## What is this?

This is a **Claude Code plugin** with three skills that automatically activate based on context:

- **orgmode** — Org-mode syntax and formatting knowledge (no Emacs daemon needed)
- **org-roam** — Note management for org-roam users via emacsclient
- **vulpea** — Note management for vulpea users via emacsclient

Just ask naturally:

- "Create a new note about functional programming"
- "Search my notes for anything related to Emacs"
- "How do I format a table in org-mode?"
- "Show me all backlinks to my React note"
- "Link my new note about hooks to my React note"

The plugin works with **Claude Code only** (not Claude Desktop, which uses a different skill system).

## What can it do?

**Org-mode knowledge (no Emacs needed):**
- Org-mode syntax, headings, lists, links, tables
- Property drawers, timestamps, scheduling
- Formatting best practices

**Note management (org-roam or vulpea):**
- Create new notes with tags and content
- Search and query your note database
- Find backlinks and connections between notes
- Add tags and metadata to notes
- Insert links between notes
- Analyze your knowledge graph
- Diagnose setup issues

## Prerequisites

1. **Claude Code** installed and running
2. **For org-roam/vulpea skills:** Emacs with org-roam or vulpea installed and configured
3. **Emacs daemon running**: `emacs --daemon` or `emacs --fg-daemon=<name>`
4. **emacsclient available**: Should be installed with Emacs

**The plugin auto-loads on first use** — no Emacs configuration needed!

### Backend Detection

The plugin auto-detects whether to use org-roam or vulpea. When both are loaded (the common case for vulpea users, since vulpea depends on org-roam), **vulpea is preferred**. This ensures notes are created through vulpea's capture system and indexed in its database.

### Multi-daemon Support

Use `-s` to target a specific Emacs daemon:

```bash
claude-orgmode-eval -s myemacs "(claude-orgmode-doctor)"
```

## Installation

### As a Claude Code Plugin

```bash
claude plugin marketplace add majorgreys/claude-orgmode
claude plugin install claude-orgmode@claude-orgmode
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
│   └── marketplace.json          # Plugin metadata (3 skills)
├── elisp/                        # Shared elisp modules
│   ├── claude-orgmode.el         # Main package
│   ├── claude-orgmode-backend.el # Auto-detect org-roam vs vulpea
│   ├── claude-orgmode-core.el
│   ├── claude-orgmode-create.el
│   ├── claude-orgmode-search.el
│   ├── claude-orgmode-links.el
│   ├── claude-orgmode-tags.el
│   ├── claude-orgmode-attach.el
│   ├── claude-orgmode-utils.el
│   └── claude-orgmode-doctor.el
├── scripts/
│   └── claude-orgmode-eval       # Auto-load wrapper script
├── references/                   # Shared reference docs
├── skills/
│   ├── orgmode/                  # Org-mode syntax knowledge
│   │   ├── SKILL.md
│   │   └── references/
│   ├── org-roam/                 # Org-roam note management
│   │   ├── SKILL.md
│   │   └── references/
│   └── vulpea/                   # Vulpea note management
│       ├── SKILL.md
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

### v3.0.2

- Prefer vulpea backend when both org-roam and vulpea are loaded (vulpea depends on org-roam, so both are always present in vulpea setups)

### v3.0.0 (Breaking Changes)

- Renamed from `org-roam-skill` to `claude-orgmode`
- Restructured as Claude Code plugin with `.claude-plugin/marketplace.json`
- All function prefixes changed: `org-roam-skill-*` → `claude-orgmode-*`
- Added backend abstraction layer (auto-detect org-roam vs vulpea)
- Split into three skills: orgmode (knowledge), org-roam (operations), vulpea (operations)
- Moved shared elisp, scripts, and references to project root
- Made `org-download` optional (only needed for `attach-file-to-references`)
- Diagnostics renamed: `org-roam-doctor` → `claude-orgmode-doctor`
- Script renamed: `org-roam-eval` → `claude-orgmode-eval`

### v2.0.0

- Removed general org-mode formatting (use `orgmode` skill instead)
- Added multi-daemon support via `-s` flag (env var `EMACS_SOCKET_NAME` as fallback)
- Added file attachment support via org-attach and org-download

## License

This plugin is provided as-is for use with Claude Code and org-roam/vulpea.
