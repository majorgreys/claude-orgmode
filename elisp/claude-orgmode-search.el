;;; claude-orgmode-search.el --- Search functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for searching notes by title, tag, and content.
;; Supports both org-roam and vulpea backends.

;;; Code:

(require 'seq)
(require 'claude-orgmode-backend)

;;;###autoload
(defun claude-orgmode-search-by-title (search-term)
  "Search notes by SEARCH-TERM in title.
Return a list of (id title file) tuples."
  (mapcar
   (lambda (node)
     (list (claude-orgmode--backend-node-id node)
           (claude-orgmode--backend-node-title node)
           (claude-orgmode--backend-node-file node)))
   (seq-filter
    (lambda (node)
      (string-match-p (regexp-quote search-term)
                      (claude-orgmode--backend-node-title node)))
    (claude-orgmode--backend-node-list))))

;;;###autoload
(defun claude-orgmode-search-by-tag (tag)
  "Search notes by TAG.
Return a list of (id title file tags) tuples."
  (mapcar
   (lambda (node)
     (list (claude-orgmode--backend-node-id node)
           (claude-orgmode--backend-node-title node)
           (claude-orgmode--backend-node-file node)
           (claude-orgmode--backend-node-tags node)))
   (seq-filter
    (lambda (node)
      (member tag (claude-orgmode--backend-node-tags node)))
    (claude-orgmode--backend-node-list))))

;;;###autoload
(defun claude-orgmode-search-by-content (search-term)
  "Search notes by SEARCH-TERM in file content.
Return a list of (id title file) tuples for notes containing the term."
  (let ((results '()))
    (dolist (node (claude-orgmode--backend-node-list))
      (let ((file (claude-orgmode--backend-node-file node)))
        (when (and file (file-exists-p file))
          (with-temp-buffer
            (insert-file-contents file)
            (when (search-forward search-term nil t)
              (push (list (claude-orgmode--backend-node-id node)
                          (claude-orgmode--backend-node-title node)
                          file)
                    results))))))
    (nreverse results)))

;;;###autoload
(defun claude-orgmode-get-node-by-title (title)
  "Get node by exact TITLE or alias.
Return node details as a plist."
  (let ((node (claude-orgmode--backend-node-from-title title)))
    (when node
      (list :id (claude-orgmode--backend-node-id node)
            :title (claude-orgmode--backend-node-title node)
            :file (claude-orgmode--backend-node-file node)
            :tags (claude-orgmode--backend-node-tags node)
            :aliases (claude-orgmode--backend-node-aliases node)))))

(provide 'claude-orgmode-search)
;;; claude-orgmode-search.el ends here
