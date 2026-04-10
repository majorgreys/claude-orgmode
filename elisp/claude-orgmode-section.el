;;; claude-orgmode-section.el --- Section editing functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for reading and editing sections within notes.
;; A "section" is the body text owned by a single org node — the content
;; between a heading's metadata and the next heading.  For file-level
;; nodes (level 0), the section is the preamble before the first heading.
;; All public functions accept node IDs only (no title fallback).

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'claude-orgmode-core)
(require 'claude-orgmode-backend)

(defun claude-orgmode--file-preamble-bounds ()
  "Return (START . END) for the file-level preamble in the current buffer.
START is after the frontmatter (PROPERTIES drawer + keyword lines + blank
separator).  END is before the first heading or end of buffer."
  (save-excursion
    (goto-char (point-min))
    ;; Skip PROPERTIES drawer
    (when (looking-at-p "[ \t]*:PROPERTIES:")
      (re-search-forward "^[ \t]*:END:" nil t)
      (forward-line 1))
    ;; Skip keyword lines (#+TITLE:, #+FILETAGS:, etc.)
    (while (and (not (eobp)) (looking-at-p "^[ \t]*#\\+[A-Za-z_]+:"))
      (forward-line 1))
    ;; Skip blank lines after keywords (structural separator)
    (while (and (not (eobp)) (looking-at-p "^[ \t]*$"))
      (forward-line 1))
    (let ((start (point))
          (end (or (save-excursion
                     (when (re-search-forward "^\\*+ " nil t)
                       (line-beginning-position)))
                   (point-max))))
      (cons start end))))

(defun claude-orgmode--heading-body-bounds ()
  "Return (START . END) for the heading body at point.
Point must be at a heading line.  START is after the heading's metadata
\(PROPERTIES drawer, planning lines).  END is before the next heading
at any level or end of buffer."
  (save-excursion
    ;; Move past heading line
    (forward-line 1)
    ;; Skip PROPERTIES drawer if present
    (when (and (not (eobp)) (looking-at-p "[ \t]*:PROPERTIES:"))
      (re-search-forward "^[ \t]*:END:" nil t)
      (forward-line 1))
    ;; Skip planning lines (SCHEDULED, DEADLINE, CLOSED)
    (while (and (not (eobp))
                (looking-at-p "^[ \t]*\\(SCHEDULED\\|DEADLINE\\|CLOSED\\):"))
      (forward-line 1))
    (let ((start (point))
          (end (or (save-excursion
                     (when (re-search-forward "^\\*+ " nil t)
                       (line-beginning-position)))
                   (point-max))))
      (cons start end))))

(defun claude-orgmode--section-body-bounds (node)
  "Return (START . END) for the body text of NODE.
For level-0 nodes, returns the preamble bounds.
For heading-level nodes, returns the heading body bounds.
Point must be positioned by `claude-orgmode--with-node-context-by-id'."
  (if (= (claude-orgmode--backend-node-level node) 0)
      (claude-orgmode--file-preamble-bounds)
    (claude-orgmode--heading-body-bounds)))

;;;###autoload
(defun claude-orgmode-get-section-content (node-id)
  "Return the body text of the node identified by NODE-ID.
For level-0 nodes, returns the preamble (between frontmatter and first
heading).  For heading-level nodes, returns content between the heading
metadata and the next heading at any level.
Returns an empty string for nodes with no body text.
Signals an error if NODE-ID is not found."
  (claude-orgmode--with-node-context-by-id
   node-id
   (lambda (node)
     (let* ((bounds (claude-orgmode--section-body-bounds node))
            (start (car bounds))
            (end (cdr bounds))
            (content (buffer-substring-no-properties start end)))
       ;; Trim trailing whitespace but preserve internal structure
       (if (string-match "\\`[ \t\n]*\\'" content)
           ""
         (string-trim-right content))))))

(provide 'claude-orgmode-section)
;;; claude-orgmode-section.el ends here
