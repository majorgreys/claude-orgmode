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
    ;; Assumes PROPERTIES drawer precedes planning lines (org-id/org-roam convention).
    ;; Standard org-mode allows the reverse, but all nodes managed by this plugin
    ;; are created with PROPERTIES first.
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

;;;###autoload
(cl-defun claude-orgmode-create-section (parent-id heading &key content content-file keep-file)
  "Create a new heading under the node identified by PARENT-ID.
HEADING is the heading text (exact match checked for duplicates).
Heading level is auto-detected as parent-level + 1.

CONTENT and CONTENT-FILE work the same as in `claude-orgmode-create-note'.
KEEP-FILE, when non-nil, prevents auto-deletion of CONTENT-FILE.
Returns the new section's node ID string.
Signals an error if HEADING already exists under PARENT-ID."
  (claude-orgmode--with-node-context-by-id
   parent-id
   (lambda (node)
     (let* ((parent-level (claude-orgmode--backend-node-level node))
            (child-level (1+ parent-level))
            (actual-content (cond
                              (content-file (claude-orgmode--read-content-file content-file))
                              (content content)
                              (t nil))))
       (unwind-protect
           (progn
             ;; Check for duplicate heading
             (save-excursion
               (let ((search-end (if (= parent-level 0)
                                     (point-max)
                                   (save-excursion (org-end-of-subtree t) (point)))))
                 (when (= parent-level 0)
                   (goto-char (point-min)))
                 (let ((heading-re (format "^\\*\\{%d\\} " child-level)))
                   (while (re-search-forward heading-re search-end t)
                     (when (equal (org-get-heading t t t t) heading)
                       (error "Heading \"%s\" already exists under this node" heading))))))
             ;; Find insertion point: end of parent's subtree
             (if (= parent-level 0)
                 (goto-char (point-max))
               (org-end-of-subtree t)
               (unless (bolp)
                 (if (eobp)
                     (insert "\n")
                   (forward-char))))
             ;; Ensure we're on a new line
             (unless (bolp) (insert "\n"))
             ;; Insert the heading
             (insert (make-string child-level ?*) " " heading "\n")
             ;; Move to the heading we just inserted
             (forward-line -1)
             ;; Create ID for the new heading
             (let ((new-id (org-id-get-create)))
               ;; Move past the PROPERTIES drawer to insert content
               (save-excursion
                 (forward-line 1)
                 (when (looking-at-p "[ \t]*:PROPERTIES:")
                   (re-search-forward "^[ \t]*:END:" nil t)
                   (forward-line 1))
                 ;; Insert content if provided
                 (when actual-content
                   (insert actual-content)
                   (unless (string-suffix-p "\n" actual-content)
                     (insert "\n"))))
               ;; Format, save, sync
               (claude-orgmode--format-buffer)
               (save-buffer)
               (claude-orgmode--backend-db-sync)
               ;; Return the new ID
               new-id))
         ;; Cleanup temp file
         (when (and content-file
                    (not keep-file)
                    (file-exists-p content-file)
                    (claude-orgmode--looks-like-temp-file content-file))
           (ignore-errors (delete-file content-file))))))))

;;;###autoload
(cl-defun claude-orgmode-replace-section (node-id &key content content-file keep-file)
  "Replace the body text of the node identified by NODE-ID.
CONTENT is the replacement string.  CONTENT-FILE, when non-nil, is read
instead of CONTENT.  KEEP-FILE prevents auto-deletion of CONTENT-FILE.
Operates on the node's own body text only — child headings and their
content are preserved.  Returns NODE-ID."
  (claude-orgmode--with-node-context-by-id
   node-id
   (lambda (node)
     (let* ((actual-content (cond
                              (content-file (claude-orgmode--read-content-file content-file))
                              (content content)
                              (t "")))
            (bounds (claude-orgmode--section-body-bounds node))
            (start (car bounds))
            (end (cdr bounds)))
       (unwind-protect
           (progn
             (delete-region start end)
             (goto-char start)
             (when (and actual-content (not (string-empty-p actual-content)))
               (insert actual-content)
               (unless (string-suffix-p "\n" actual-content)
                 (insert "\n")))
             (claude-orgmode--format-buffer)
             (save-buffer)
             (claude-orgmode--backend-db-sync)
             node-id)
         ;; Cleanup temp file
         (when (and content-file
                    (not keep-file)
                    (file-exists-p content-file)
                    (claude-orgmode--looks-like-temp-file content-file))
           (ignore-errors (delete-file content-file))))))))

(provide 'claude-orgmode-section)
;;; claude-orgmode-section.el ends here
