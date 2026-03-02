;;; claude-orgmode-backend.el --- Backend abstraction for org-roam/vulpea -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Backend abstraction layer that auto-detects whether org-roam or vulpea
;; is loaded and dispatches operations accordingly.  Both org-roam and
;; vulpea are optional dependencies — at least one must be available.

;;; Code:

(require 'cl-lib)

(defvar claude-orgmode--backend nil
  "Cached backend type.  One of `org-roam' or `vulpea', or nil if not yet detected.")

(defun claude-orgmode--detect-backend ()
  "Detect and return the active backend.
Returns `org-roam' or `vulpea'.  Signals an error if neither is available.
Result is cached in `claude-orgmode--backend'."
  (or claude-orgmode--backend
      (setq claude-orgmode--backend
            (cond
             ((featurep 'org-roam) 'org-roam)
             ((featurep 'vulpea) 'vulpea)
             ;; Try to load one
             ((require 'org-roam nil 'noerror) 'org-roam)
             ((require 'vulpea nil 'noerror) 'vulpea)
             (t (error "Neither org-roam nor vulpea is available"))))))

(defun claude-orgmode--backend-org-roam-p ()
  "Return non-nil if the active backend is org-roam."
  (eq (claude-orgmode--detect-backend) 'org-roam))

(defun claude-orgmode--backend-vulpea-p ()
  "Return non-nil if the active backend is vulpea."
  (eq (claude-orgmode--detect-backend) 'vulpea))

;;; Directory

(defun claude-orgmode--backend-directory ()
  "Return the notes directory for the active backend."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam org-roam-directory)
    ('vulpea (car (if (boundp 'vulpea-db-sync-directories)
                      vulpea-db-sync-directories
                    (list org-directory))))))

;;; Database sync

(defun claude-orgmode--backend-db-sync ()
  "Sync the database for the active backend."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-db-sync))
    ('vulpea (vulpea-db-sync-full-scan))))

;;; Node/note list

(defun claude-orgmode--backend-node-list ()
  "Return all nodes/notes as a list.
Each element is a backend-specific object (org-roam-node or vulpea-note)."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-list))
    ('vulpea (vulpea-db-query))))

;;; Accessors — unified interface for node/note properties

(defun claude-orgmode--backend-node-id (node)
  "Return the ID of NODE."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-id node))
    ('vulpea (vulpea-note-id node))))

(defun claude-orgmode--backend-node-title (node)
  "Return the title of NODE."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-title node))
    ('vulpea (vulpea-note-title node))))

(defun claude-orgmode--backend-node-file (node)
  "Return the file path of NODE."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-file node))
    ('vulpea (vulpea-note-path node))))

(defun claude-orgmode--backend-node-tags (node)
  "Return the tags of NODE as a list of strings."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-tags node))
    ('vulpea (vulpea-note-tags node))))

(defun claude-orgmode--backend-node-aliases (node)
  "Return the aliases of NODE as a list of strings."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-aliases node))
    ('vulpea (vulpea-note-aliases node))))

(defun claude-orgmode--backend-node-level (node)
  "Return the heading level of NODE (0 = file-level)."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-level node))
    ('vulpea (vulpea-note-level node))))

;;; Lookup

(defun claude-orgmode--backend-node-from-id (id)
  "Get a node/note by ID.  Return nil if not found."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-from-id id))
    ('vulpea (vulpea-db-get-by-id id))))

(defun claude-orgmode--backend-node-from-title (title)
  "Get a node/note by exact TITLE or alias.  Return nil if not found."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam (org-roam-node-from-title-or-alias title))
    ('vulpea (car (vulpea-db-search-by-title title)))))

;;; Backlinks

(defun claude-orgmode--backend-get-backlinks (node)
  "Return backlink source nodes/notes for NODE.
Returns a list of backend-specific node/note objects."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam
     (mapcar #'org-roam-backlink-source-node
             (org-roam-backlinks-get node)))
    ('vulpea
     (let ((links (vulpea-db-query-links-to (vulpea-note-id node))))
       (mapcar (lambda (link)
                 (vulpea-db-get-by-id (plist-get link :source)))
               links)))))

;;; Tags

(defun claude-orgmode--backend-add-tag (node tag)
  "Add TAG to NODE."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam
     (let ((file (org-roam-node-file node)))
       (with-current-buffer (find-file-noselect file)
         (save-excursion
           (goto-char (point-min))
           (if (re-search-forward "^#\\+\\(?:filetags\\|FILETAGS\\):" nil t)
               (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
                 (unless (string-match-p (concat ":" tag ":") line)
                   (end-of-line)
                   (insert ":" tag ":")))
             (when (re-search-forward "^#\\+\\(?:title\\|TITLE\\):" nil t)
               (forward-line 1)
               (insert "#+FILETAGS: :" tag ":\n")))
           (save-buffer)
           (org-roam-db-sync)))))
    ('vulpea
     (vulpea-tags-add node tag))))

(defun claude-orgmode--backend-remove-tag (node tag)
  "Remove TAG from NODE."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam
     (let ((file (org-roam-node-file node)))
       (with-current-buffer (find-file-noselect file)
         (save-excursion
           (goto-char (point-min))
           (when (re-search-forward "^#\\+\\(?:filetags\\|FILETAGS\\):" nil t)
             (let ((line-end (line-end-position)))
               (while (re-search-forward (concat ":" tag ":") line-end t)
                 (replace-match ":" nil nil)))
             ;; Clean up any double colons left from removal
             (beginning-of-line)
             (while (re-search-forward "::" (line-end-position) t)
               (replace-match ":" nil nil))
             (save-buffer)
             (org-roam-db-sync))))))
    ('vulpea
     (vulpea-tags-remove node tag))))

;;; Note creation

(cl-defun claude-orgmode--backend-create-note (title &key tags content)
  "Create a new note with TITLE, optional TAGS and CONTENT.
Returns the file path of the created note."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam
     ;; Delegate to the main create function
     (require 'claude-orgmode-create)
     (claude-orgmode-create-note title :tags tags :content content))
    ('vulpea
     (let ((note (vulpea-create title nil
                                :tags tags
                                :body (or content ""))))
       (vulpea-note-path note)))))

;;; Backend info (for diagnostics)

(defun claude-orgmode--backend-info ()
  "Return a plist describing the active backend."
  (pcase (claude-orgmode--detect-backend)
    ('org-roam
     (list :backend 'org-roam
           :directory org-roam-directory
           :database org-roam-db-location
           :node-count (length (org-roam-node-list))))
    ('vulpea
     (list :backend 'vulpea
           :directory (claude-orgmode--backend-directory)
           :database (if (boundp 'vulpea-db-location)
                         vulpea-db-location
                       "default")
           :node-count (length (vulpea-db-query))))))

(provide 'claude-orgmode-backend)
;;; claude-orgmode-backend.el ends here
