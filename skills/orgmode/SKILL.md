---
name: orgmode
description: |
  Org-mode syntax and formatting knowledge. Reference docs for headings, lists, links, properties, timestamps, and other org-mode constructs.

  Triggers: org-mode, .org files, org syntax, org formatting, org properties, org timestamps
---

# Org-mode Syntax Skill

Pure org-mode knowledge for writing and formatting `.org` files. No emacsclient or Emacs daemon required.

For org-roam or vulpea note management (creating notes, searching, linking), use the **org-roam** or **vulpea** skills instead.

## Quick Reference

### Headings

```org
* Top-level heading
** Second level
*** Third level
```

### Text Formatting

```org
*bold* /italic/ _underline_ ~code~ =verbatim= +strikethrough+
```

### Lists

```org
- Unordered item
  - Nested item
1. Ordered item
2. Second item
- [ ] Checkbox unchecked
- [X] Checkbox checked
```

### Links

```org
[[https://example.com][Description]]
[[file:path/to/file.org][File link]]
[[id:uuid-here][ID link]]
```

### Properties

```org
:PROPERTIES:
:ID:       some-uuid
:CUSTOM:   value
:END:
```

### Keywords

```org
#+TITLE: Document Title
#+FILETAGS: :tag1:tag2:
#+DATE: [2026-03-01 Sun]
#+AUTHOR: Name
```

### Timestamps

```org
<2026-03-01 Sun>          Active timestamp
[2026-03-01 Sun]          Inactive timestamp
<2026-03-01 Sun 10:00>    With time
SCHEDULED: <2026-03-01 Sun>
DEADLINE: <2026-03-05 Thu>
```

### Source Blocks

```org
#+BEGIN_SRC python
def hello():
    print("Hello")
#+END_SRC
```

### Tables

```org
| Name  | Value |
|-------+-------|
| Alice |    42 |
| Bob   |    17 |
```

## Tag Constraints

Org-mode tags **cannot contain hyphens**. Use underscores instead:
- Invalid: `my-tag`, `web-dev`
- Valid: `my_tag`, `web_dev`

## Detailed References

- **org-syntax.md** - Complete org-mode syntax reference
- **properties.md** - Property drawers, node properties, and inheritance
- **timestamps.md** - Date/time formats, scheduling, deadlines, repeaters
- **links.md** - Internal links, external links, ID links, file links
- **examples.md** - Common formatting patterns and best practices
