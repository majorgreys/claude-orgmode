;;; claude-orgmode-create.el --- Note creation functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for creating notes programmatically (org-roam or vulpea backend).

;;; Code:

(require 'cl-lib)
(require 'org-id)
(require 'claude-orgmode-core)
(require 'claude-orgmode-backend)

(defun claude-orgmode--get-filename-format ()
  "Extract filename format from user's org-roam capture templates.
Return the filename pattern from the default template, or a fallback."
  (let* ((default-template (assoc "d" org-roam-capture-templates))
         ;; Skip key, description, type, template-content to get to plist
         (plist (cdr (cdr (cdr (cdr default-template)))))
         (target (plist-get plist :target)))
    (if (and target (eq (car target) 'file+head))
        ;; Extract first argument of file+head
        (nth 1 target)
      ;; Fallback to timestamp-only if no template found
      "%<%Y%m%d%H%M%S>.org")))

(defun claude-orgmode--expand-filename (title)
  "Generate a filename for TITLE using the user's configured format.
Expand placeholders like %<...>, ${slug}, ${title}, etc."
  (let* ((format-string (claude-orgmode--get-filename-format))
         (slug (replace-regexp-in-string " " "_" (downcase title)))
         (filename format-string))

    ;; Handle %<...> time format
    (when (string-match "%<\\([^>]+\\)>" filename)
      (let ((time-format (match-string 1 filename)))
        (setq filename (replace-regexp-in-string
                       "%<[^>]+>"
                       (format-time-string time-format)
                       filename))))

    ;; Replace ${slug}
    (setq filename (replace-regexp-in-string "\\${slug}" slug filename))

    ;; Replace ${title}
    (setq filename (replace-regexp-in-string "\\${title}" title filename))

    ;; Ensure .org extension
    (unless (string-suffix-p ".org" filename)
      (setq filename (concat filename ".org")))

    filename))

(defun claude-orgmode--get-head-content ()
  "Extract head content from user's org-roam capture template.
Return the head template string, or nil if not found."
  (let* ((default-template (assoc "d" org-roam-capture-templates))
         (plist (cdr (cdr (cdr (cdr default-template)))))
         (target (plist-get plist :target)))
    (when (and target (eq (car target) 'file+head))
      ;; Second argument of file+head is the head content
      (nth 2 target))))

;;;###autoload
(cl-defun claude-orgmode-create-note (title &key tags content content-file keep-file)
  "Create a new note with TITLE, optional TAGS and CONTENT.
With org-roam backend: auto-detects filename format and head content
from capture templates.  With vulpea backend: uses vulpea-create.

TAGS is a list of tag strings.
CONTENT can be provided as a string (small content) or via
CONTENT-FILE path (recommended for large content). If both are
provided, CONTENT-FILE takes priority.

CONTENT FORMAT:
Content should be in `org-mode' format. For markdown conversion or
general `org-mode' formatting operations, use the orgmode skill before
calling this function. This skill focuses on org-roam-specific
operations (note creation, database sync, node linking).

TEMP FILE CLEANUP:
CONTENT-FILE is automatically deleted after processing if it appears
to be a temporary file (in /tmp/ or similar directory). To prevent
deletion, pass KEEP-FILE as t. This eliminates the need for manual
cleanup in shell scripts.

Return the file path of the created note."
  (when (claude-orgmode--backend-vulpea-p)
    ;; Vulpea backend: delegate entirely to vulpea-create
    (let* ((actual-content (cond
                             (content-file (claude-orgmode--read-content-file content-file))
                             (content content)
                             (t nil)))
           (note (vulpea-create title nil :tags tags :body (or actual-content ""))))
      ;; Cleanup temp file
      (when (and content-file (not keep-file) (file-exists-p content-file)
                 (claude-orgmode--looks-like-temp-file content-file))
        (ignore-errors (delete-file content-file)))
      (cl-return-from claude-orgmode-create-note (vulpea-note-path note))))
  ;; Org-roam backend: manual file creation
  (let* ((file-name (claude-orgmode--expand-filename title))
         (file-path (expand-file-name file-name (claude-orgmode--backend-directory)))
         (node-id (org-id-uuid))
         (head-content (claude-orgmode--get-head-content))
         ;; Read content from file if provided, otherwise use content parameter
         (actual-content (cond
                          (content-file (claude-orgmode--read-content-file content-file))
                          (content content)
                          (t nil))))

    (unwind-protect
        (progn
          ;; Create the file with proper org-roam structure
          (with-temp-file file-path
            ;; Insert PROPERTIES block with ID
            (insert ":PROPERTIES:\n")
            (insert (format ":ID:       %s\n" node-id))
            (insert ":END:\n")

            ;; Insert head content if template specifies it
            (when (and head-content (not (string-empty-p head-content)))
              (let* ((expanded-head
                      ;; First expand ${title}
                      (replace-regexp-in-string "\\${title}" title head-content))
                     ;; Then expand time format specifiers
                     (expanded-head (claude-orgmode--expand-time-formats expanded-head)))
                (insert expanded-head)
                (unless (string-suffix-p "\n" expanded-head)
                  (insert "\n"))))

            ;; If head content doesn't include title, add it
            (unless (string-match-p "#\\+\\(?:title\\|TITLE\\):" (or head-content ""))
              (insert (format "#+TITLE: %s\n" title)))

            ;; Insert filetags if provided (sanitize to remove hyphens)
            (when tags
              (let ((sanitized-tags
                     (mapcar #'claude-orgmode--sanitize-tag tags)))
                (insert (format "#+FILETAGS: :%s:\n"
                                (mapconcat (lambda (tag) tag) sanitized-tags ":")))))

            ;; Add blank line after frontmatter
            (insert "\n")

            ;; Insert content if provided (user responsible for `org-mode' formatting)
            (when actual-content
              (insert actual-content)
              (unless (string-suffix-p "\n" actual-content)
                (insert "\n"))))

          ;; Sync database to register the new note
          (claude-orgmode--backend-db-sync)

          ;; Return the file path
          file-path)

      ;; Cleanup: automatically delete temp file unless explicitly kept
      (when (and content-file
                 (not keep-file)
                 (file-exists-p content-file)
                 (claude-orgmode--looks-like-temp-file content-file))
        (condition-case err
            (delete-file content-file)
          (error
           (message "Warning: Could not delete temp file %s: %s"
                   content-file (error-message-string err))))))))

;;;###autoload
(defun claude-orgmode-create-note-with-content (title content &optional tags)
  "Create a new org-roam note with TITLE, CONTENT and optional TAGS.
This is an alias for claude-orgmode-create-note with different arg order.
Return the file path of the created note."
  (claude-orgmode-create-note title :content content :tags tags))

(provide 'claude-orgmode-create)
;;; claude-orgmode-create.el ends here
