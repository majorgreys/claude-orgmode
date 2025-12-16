;;; org-roam-skill-core.el --- Core utilities for org-roam-skill -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Core utility functions shared across org-roam-skill modules.

;;; Code:

(require 'org-roam)

(defun org-roam-skill--sanitize-tag (tag)
  "Sanitize TAG by replacing hyphens with underscores.
Org tags cannot contain hyphens."
  (replace-regexp-in-string "-" "_" tag))

(defun org-roam-skill--with-temp-content-file (content function)
  "Execute FUNCTION with CONTENT in a temporary file.
FUNCTION receives the temporary file path as its argument.
The temporary file is automatically cleaned up after execution.
Returns the result of calling FUNCTION."
  (let ((temp-file (make-temp-file "org-roam-skill-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert content))
          (funcall function temp-file))
      ;; Cleanup: delete temp file
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(defun org-roam-skill--looks-like-temp-file (path)
  "Return non-nil if PATH appears to be a temporary file.
Checks for common temp directory patterns to prevent accidental deletion
of important files. Returns nil if PATH is not a string."
  (and (stringp path)
       (or (string-prefix-p "/tmp/" path)
           (string-prefix-p "/var/tmp/" path)
           (string-prefix-p (temporary-file-directory) path))))

(defun org-roam-skill--read-content-file (file-path)
  "Read and return content from FILE-PATH.
Returns the file contents as a string, or signals an error if the file
cannot be read. The caller is responsible for deleting the file after use."
  (unless (file-exists-p file-path)
    (error "Content file does not exist: %s" file-path))
  (unless (file-readable-p file-path)
    (error "Content file is not readable: %s" file-path))
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))

(defun org-roam-skill--validate-org-syntax (file-path)
  "Validate `org-mode' syntax in FILE-PATH.
Returns a plist with validation results:
  :valid - t if all checks pass, nil otherwise
  :errors - list of error messages
Checks include:
  - PROPERTIES drawer structure (no blank lines within)
  - Proper keyword casing (uppercase keywords)
  - Heading format (asterisks followed by space)
  - FILETAGS format"
  (let ((errors '())
        (valid t))
    (with-temp-buffer
      (insert-file-contents file-path)
      (goto-char (point-min))

      ;; Check PROPERTIES drawer structure
      (while (re-search-forward "^[ \t]*:PROPERTIES:" nil t)
        (let ((drawer-start (point))
              (drawer-end (save-excursion
                           (when (re-search-forward "^[ \t]*:END:" nil t)
                             (point)))))
          (when drawer-end
            ;; Check for blank lines within drawer
            (save-excursion
              (goto-char drawer-start)
              (when (re-search-forward "^[ \t]*$" drawer-end t)
                (push "PROPERTIES drawer contains blank lines" errors)
                (setq valid nil))))))

      ;; Check for lowercase keywords that should be uppercase
      ;; Match only lowercase keywords (not UPPERCASE or Mixed)
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+\\([a-z]+\\):" nil t)
        (let ((keyword (match-string 1)))
          (when (member keyword '("title" "filetags" "date" "author"))
            (push (format "Found lowercase keyword '#+%s:' - should be uppercase" keyword)
                  errors)
            (setq valid nil))))

      ;; Check heading format (asterisks must be followed by space)
      ;; Only match actual org headings (not #+keywords)
      (goto-char (point-min))
      (while (re-search-forward "^\\(\\*+\\)\\([^ \t\n*]\\)" nil t)
        (push (format "Heading at line %d missing space after asterisks"
                      (line-number-at-pos))
              errors)
        (setq valid nil)))

    (list :valid valid :errors (nreverse errors))))

(defun org-roam-skill--with-node-context (title-or-id function)
  "Execute FUNCTION with point at the node identified by TITLE-OR-ID.
FUNCTION receives the node as an argument.
Returns the result of FUNCTION."
  (let* ((node (if (and (stringp title-or-id)
                        (string-match-p "^[0-9a-f]\\{8\\}-" title-or-id))
                   (org-roam-node-from-id title-or-id)
                 (org-roam-node-from-title-or-alias title-or-id)))
         (file (when node (org-roam-node-file node)))
         (node-id (when node (org-roam-node-id node))))
    (unless node
      (error "Node not found: %s" title-or-id))
    (unless (file-exists-p file)
      (error "File not found: %s" file))

    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-min))
        ;; Search for the node's ID property
        (if (re-search-forward
             (format ":ID:[ \t]+%s" (regexp-quote node-id)) nil t)
            (progn
              ;; Move to the beginning of the entry
              (org-back-to-heading-or-point-min t)
              (funcall function node))
          (error "Could not locate node in file: %s" title-or-id))))))

(defun org-roam-skill--get-filename-format ()
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

(defun org-roam-skill--expand-filename (title)
  "Generate a filename for TITLE using the user's configured format.
Expand placeholders like %<...>, ${slug}, ${title}, etc."
  (let* ((format-string (org-roam-skill--get-filename-format))
         ;; Create slug manually: lowercase, replace spaces with underscores
         (slug (replace-regexp-in-string " " "_" (downcase title)))
         (timestamp (format-time-string "%Y%m%d%H%M%S"))
         (filename format-string))

    ;; Replace common placeholders
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

(defun org-roam-skill--get-head-content ()
  "Extract head content from user's org-roam capture template.
Return the head template string, or nil if not found."
  (let* ((default-template (assoc "d" org-roam-capture-templates))
         (plist (cdr (cdr (cdr (cdr default-template)))))
         (target (plist-get plist :target)))
    (when (and target (eq (car target) 'file+head))
      ;; Second argument of file+head is the head content
      (nth 2 target))))

(defun org-roam-skill--expand-time-formats (template-string)
  "Expand time format specifiers in TEMPLATE-STRING.
Handles:
- %<format> - custom time format (e.g., %<%Y-%m-%d>)
- %U - inactive timestamp with time [2025-10-23 Thu 15:53]
- %u - inactive timestamp without time [2025-10-23 Thu]
- %T - active timestamp with time <2025-10-23 Thu 15:53>
- %t - active timestamp without time <2025-10-23 Thu>

Returns the expanded string with all time formats replaced."
  (let ((result template-string)
        (case-fold-search nil))  ; Make regex matching case-sensitive
    ;; Expand %<...> custom time formats
    (while (string-match "%<\\([^>]+\\)>" result)
      (let ((time-format (match-string 1 result)))
        (setq result (replace-match
                     (format-time-string time-format)
                     t t result))))

    ;; Expand %U - inactive timestamp with time (order matters: do %U before %u)
    (setq result (replace-regexp-in-string
                 "%U"
                 (format-time-string "[%Y-%m-%d %a %H:%M]")
                 result t t))

    ;; Expand %u - inactive timestamp without time
    (setq result (replace-regexp-in-string
                 "%u"
                 (format-time-string "[%Y-%m-%d %a]")
                 result t t))

    ;; Expand %T - active timestamp with time (order matters: do %T before %t)
    (setq result (replace-regexp-in-string
                 "%T"
                 (format-time-string "<%Y-%m-%d %a %H:%M>")
                 result t t))

    ;; Expand %t - active timestamp without time
    (setq result (replace-regexp-in-string
                 "%t"
                 (format-time-string "<%Y-%m-%d %a>")
                 result t t))

    result))

(provide 'org-roam-skill-core)
;;; org-roam-skill-core.el ends here
