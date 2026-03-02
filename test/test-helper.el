;;; test-helper.el --- Test utilities for claude-orgmode -*- lexical-binding: t; -*-

;;; Commentary:
;; Shared test fixtures and utilities using Buttercup

;;; Code:

(require 'buttercup)
(require 'org-roam)
(require 'claude-orgmode)

(defvar claude-orgmode-test-directory nil
  "Temporary directory for test database.")

(defun claude-orgmode-test--setup ()
  "Set up temporary org-roam directory for testing."
  (setq claude-orgmode-test-directory (make-temp-file "org-roam-test-" t))
  (setq org-roam-directory claude-orgmode-test-directory
        org-roam-db-location
        (expand-file-name "org-roam.db" claude-orgmode-test-directory))
  ;; Initialize database
  (org-roam-db-sync))

(defun claude-orgmode-test--teardown ()
  "Clean up temporary org-roam directory."
  (when (and claude-orgmode-test-directory
             (file-exists-p claude-orgmode-test-directory))
    ;; Close database connection
    (when (fboundp 'org-roam-db--close)
      (org-roam-db--close))
    ;; Delete temp directory
    (delete-directory claude-orgmode-test-directory t)
    (setq claude-orgmode-test-directory nil)))

(defun claude-orgmode-test--create-test-note (title tags &optional content)
  "Create a test note with TITLE, TAGS, and optional CONTENT.
Returns the file path."
  (create-org-roam-note title tags content))

(defun claude-orgmode-test--count-nodes ()
  "Return the number of nodes in the test database."
  (length (org-roam-node-list)))

(defun claude-orgmode-test--get-note-content (file-path)
  "Get the content of the note at FILE-PATH."
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))

(defun claude-orgmode-test--node-exists-p (title)
  "Check if a node with TITLE exists."
  (not (null (org-roam-node-from-title-or-alias title))))

(provide 'test-helper)
;;; test-helper.el ends here
