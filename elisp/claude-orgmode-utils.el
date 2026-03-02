;;; claude-orgmode-utils.el --- Utility functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Utility functions including orphan detection and stats.
;; Supports both org-roam and vulpea backends.

;;; Code:

(require 'seq)
(require 'claude-orgmode-backend)

;;;###autoload
(defun claude-orgmode-check-setup ()
  "Check if the note-taking backend is properly set up.
Return a plist with status information."
  (let ((info (claude-orgmode--backend-info)))
    (list :backend (plist-get info :backend)
          :directory (plist-get info :directory)
          :directory-exists (file-exists-p (plist-get info :directory))
          :database-location (plist-get info :database)
          :node-count (plist-get info :node-count))))

;;;###autoload
(defun claude-orgmode-get-note-info (title)
  "Get comprehensive information about a note by TITLE.
Return a formatted string with all note details."
  (let ((node (claude-orgmode--backend-node-from-title title)))
    (if node
        (format
         "Title: %s\nID: %s\nFile: %s\nTags: %s\nAliases: %s\nBacklinks: %d\nLevel: %d"
         (claude-orgmode--backend-node-title node)
         (claude-orgmode--backend-node-id node)
         (claude-orgmode--backend-node-file node)
         (or (claude-orgmode--backend-node-tags node) "none")
         (or (claude-orgmode--backend-node-aliases node) "none")
         (length (claude-orgmode--backend-get-backlinks node))
         (claude-orgmode--backend-node-level node))
      "Note not found")))

;;;###autoload
(defun claude-orgmode-list-recent-notes (n)
  "List the N most recently modified notes.
Return a list of (id title file mtime) tuples."
  (let ((nodes (claude-orgmode--backend-node-list)))
    (mapcar
     (lambda (node)
       (let ((file (claude-orgmode--backend-node-file node)))
         (list (claude-orgmode--backend-node-id node)
               (claude-orgmode--backend-node-title node)
               file
               (when (and file (file-exists-p file))
                 (file-attribute-modification-time
                  (file-attributes file))))))
     (seq-take
      (seq-sort
       (lambda (a b)
         (let ((fa (claude-orgmode--backend-node-file a))
               (fb (claude-orgmode--backend-node-file b)))
           (when (and fa fb (file-exists-p fa) (file-exists-p fb))
             (time-less-p
              (file-attribute-modification-time (file-attributes fb))
              (file-attribute-modification-time (file-attributes fa))))))
       nodes)
      n))))

;;;###autoload
(defun claude-orgmode-find-orphan-notes ()
  "Find notes that have no backlinks and no forward links.
Return a list of (id title file) tuples for orphaned notes."
  (seq-filter
   (lambda (node-info)
     (let* ((node (claude-orgmode--backend-node-from-id (car node-info)))
            (backlinks (claude-orgmode--backend-get-backlinks node))
            (file (claude-orgmode--backend-node-file node))
            (has-forward-links nil))
       ;; Check for forward links
       (when (and file (file-exists-p file))
         (with-temp-buffer
           (insert-file-contents file)
           (goto-char (point-min))
           (when (re-search-forward "\\[\\[id:" nil t)
             (setq has-forward-links t))))
       ;; Return if both are empty
       (and (null backlinks) (not has-forward-links))))
   (mapcar
    (lambda (node)
      (list (claude-orgmode--backend-node-id node)
            (claude-orgmode--backend-node-title node)
            (claude-orgmode--backend-node-file node)))
    (claude-orgmode--backend-node-list))))

;;;###autoload
(defun claude-orgmode-get-graph-stats ()
  "Get statistics about the knowledge graph.
Return a plist with various statistics."
  (let* ((nodes (claude-orgmode--backend-node-list))
         (total-nodes (length nodes))
         (total-links 0)
         (tags (sort
                (delete-dups
                 (flatten-list
                  (mapcar #'claude-orgmode--backend-node-tags nodes)))
                #'string<)))
    (dolist (node nodes)
      (setq total-links (+ total-links
                           (length (claude-orgmode--backend-get-backlinks node)))))
    (list :total-notes total-nodes
          :total-links total-links
          :unique-tags (length tags)
          :average-links-per-note (if (> total-nodes 0)
                                      (/ (float total-links) total-nodes)
                                    0))))

(provide 'claude-orgmode-utils)
;;; claude-orgmode-utils.el ends here
