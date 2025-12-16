# Org-roam Agent Skill for Claude Code

A Claude Code Agent Skill that enables Claude to help you manage your org-roam notes through emacsclient commands.

## What is this?

This is a **Claude Code Agent Skill** - a model-invoked capability that automatically activates when you ask Claude Code questions about your org-roam notes. You don't need to learn any commands; just ask naturally:

- "Create a new note about functional programming"
- "Search my notes for anything related to Emacs"
- "Remember this insight: [your idea]"
- "Show me all backlinks to my React note"
- "Link my new note about hooks to my React note"

The skill works with **Claude Code only** (not Claude Desktop, which uses a different skill system).

## What can it do?

- Create new org-roam notes with tags and content
- Search and query your note database
- Find backlinks and connections between notes
- Add tags and metadata to notes
- Insert links between notes
- Analyze your knowledge graph
- Diagnose org-roam setup issues

## Version 2.0 Breaking Changes

**⚠️ Important**: Version 2.0 removes general org-mode formatting functionality. For markdown conversion and general org-mode operations, use the `orgmode` skill.

**What changed:**
- Removed automatic markdown→org conversion
- Removed `:no-format` parameter from `org-roam-skill-create-note`
- Removed `format-org-roam-note` function

**What to do:**
Content should now be in org-mode format. For markdown conversion, use the orgmode skill before creating notes.

See [CHANGELOG.md](CHANGELOG.md) for detailed migration guide.

## Prerequisites

1. **Claude Code** installed and running
2. **Emacs with org-roam installed and configured**
3. **Emacs daemon running**: Start with `emacs --daemon`
4. **emacsclient available**: Should be installed with Emacs
5. **org-roam directory set up**: Your notes directory (e.g., `~/org-roam/` or `~/Documents/org/roam/`)

**The skill auto-loads on first use** - no Emacs configuration needed!

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

**This is optional** - the skill auto-detects your template format and works with either:
- Timestamp-only: `20251019193157.org` (recommended)
- Timestamp-slug: `20251019193157-title-slug.org` (default, also supported)
- Custom formats: The skill will adapt to your template

## Installation

### Step 1: Install the Skill

#### Option 1: Personal Skills (Recommended)

Install globally for all your Claude Code sessions:

```bash
# Clone to your personal skills directory
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/majorgreys/org-roam-skill.git
```

The skill will automatically activate across all projects when you ask org-roam-related questions.

#### Option 2: Project Skills

Install for a specific project only:

```bash
# From your project directory
mkdir -p .claude/skills
cd .claude/skills
git clone https://github.com/majorgreys/org-roam-skill.git
```

The skill only activates when working in that project.

### Step 2: Verify Installation

**Verify Emacs daemon is running:**

```bash
emacsclient --eval "t"
```

Should return `t`. If not, start the daemon:
```bash
emacs --daemon
```

**Run diagnostic to verify org-roam setup:**

```bash
~/.claude/skills/org-roam-skill/scripts/org-roam-eval "(org-roam-doctor)"
```

This auto-loads the skill package and checks your org-roam configuration, database, and templates.

**How it works:**
- The skill includes a wrapper script (`scripts/org-roam-eval`) that auto-loads the package on first use
- No manual Emacs configuration needed
- Package stays in memory after first call (fast subsequent calls)
- Always uses the version that ships with the skill

**Note**: Skills are **model-invoked** - they activate automatically based on what you ask. You don't need to run any commands or mention the skill name. Just ask naturally about your notes!

## Structure

```
org-roam-skill/
├── SKILL.md                          # Main skill instructions
├── CLAUDE.md                         # Developer instructions
├── README.md                         # This file
├── elisp/                            # Emacs Lisp package code
│   ├── org-roam-skill.el             # Main entry point (loads all modules)
│   ├── org-roam-skill-core.el        # Core utilities
│   ├── org-roam-skill-create.el      # Note creation functions
│   ├── org-roam-skill-search.el      # Search and query functions
│   ├── org-roam-skill-links.el       # Link management (backlinks, forward links)
│   ├── org-roam-skill-tags.el        # Tag management
│   ├── org-roam-skill-attach.el      # File attachment via org-attach
│   ├── org-roam-skill-utils.el       # Utility functions (orphans, stats)
│   └── org-roam-skill-doctor.el      # Diagnostic functions
├── scripts/
│   └── org-roam-eval                 # Auto-load wrapper script
├── test/                             # Test suite
│   ├── org-roam-skill-test.el        # Unit tests
│   ├── org-roam-skill-integration-test.el  # Integration tests
│   └── test-helper.el                # Test utilities
└── references/                       # AI documentation
    ├── functions.md                  # Function reference
    ├── installation.md               # Setup guide
    ├── troubleshooting.md            # Common issues
    ├── org-roam-api.md               # Org-roam API reference
    └── emacsclient-usage.md          # Emacsclient patterns
```

## Quick Start

Once installed, simply ask Claude Code natural questions about your notes:

### Example Conversations

**Creating notes:**
- "Create a note about React hooks"
- "Add a note about functional programming with tags 'javascript' and 'learning'"
- "Remember this insight: [paste your idea]"

**Searching notes:**
- "Search my notes for anything about Emacs"
- "Show me all notes tagged with 'javascript'"
- "What notes do I have about React?"

**Managing connections:**
- "Show me all backlinks to my React note"
- "Link my new React Hooks note to my React note"
- "Find orphaned notes in my knowledge base"

**Diagnostics:**
- "Check if my org-roam setup is working correctly"
- "Show me my org-roam configuration"

Claude Code will automatically load the necessary helper scripts and perform the operations using emacsclient.

## How It Works

When you ask Claude Code about your notes, the skill:

1. **Automatically activates** based on keywords in your question (org-roam, notes, backlinks, etc.)
2. **Uses the wrapper script** (`scripts/org-roam-eval`) to communicate with your running Emacs daemon
3. **Auto-loads the package** from `elisp/` on first use (stays in memory for subsequent calls)
4. **Calls functions directly** (already loaded in memory after first call)
5. **Auto-detects your configuration** (filename format, templates, etc.)
6. **Performs operations** using org-roam's built-in functions
7. **Returns results** in a readable format

No manual configuration or command memorization required - just ask naturally! The auto-load wrapper ensures the package is available, and all functions stay in memory for instant operations.

## Troubleshooting

### Daemon not running

If you get connection errors:

```bash
emacs --daemon
```

### org-roam not loaded

Start Emacs normally once to ensure org-roam loads, or add to your init file:

```elisp
(require 'org-roam)
(org-roam-db-autosync-mode)
```

### Database not syncing

Manually sync:

```bash
emacsclient --eval "(org-roam-db-sync)"
```

## Testing

The project includes a comprehensive test suite using Buttercup, following org-roam's testing conventions.

**Install Eldev (first time only):**
```bash
curl -fsSL https://raw.github.com/doublep/eldev/master/webinstall/github-eldev | sh
```

**Run tests:**
```bash
eldev -C --unstable prepare  # Install dependencies (first time only)
eldev -C --unstable test     # Run all tests
eldev -C --unstable lint     # Run linting checks
```

**Prerequisites:**
- [Eldev](https://github.com/doublep/eldev) for dependency management and testing
- See `test/README.md` for detailed testing documentation

## Contributing

Feel free to extend this skill with additional functionality! When contributing:

1. Add tests for new features
2. Ensure all tests pass: `eldev -C --unstable test`
3. Update documentation as needed
4. Follow existing code style

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/code), an AI-powered coding assistant.

## License

This skill is provided as-is for use with Claude Code and org-roam.
