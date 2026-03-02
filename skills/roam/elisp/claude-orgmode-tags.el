;;; claude-orgmode-tags.el --- Tag management functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for managing tags in notes.
;; Supports both org-roam and vulpea backends.

;;; Code:

(require 'claude-orgmode-core)
(require 'claude-orgmode-backend)
(require 'seq)

;;;###autoload
(defun claude-orgmode-list-all-tags ()
  "Get a list of all unique tags.
Return a sorted list of tag strings."
  (sort
   (delete-dups
    (flatten-list
     (mapcar #'claude-orgmode--backend-node-tags
             (claude-orgmode--backend-node-list))))
   #'string<))

;;;###autoload
(defun claude-orgmode-count-notes-by-tag ()
  "Count how many notes use each tag.
Return an alist of (tag . count) pairs sorted by count descending."
  (let ((tag-counts (make-hash-table :test 'equal)))
    ;; Count occurrences
    (dolist (node (claude-orgmode--backend-node-list))
      (dolist (tag (claude-orgmode--backend-node-tags node))
        (puthash tag (1+ (gethash tag tag-counts 0)) tag-counts)))
    ;; Convert to sorted alist
    (sort
     (let (result)
       (maphash (lambda (tag count)
                  (push (cons tag count) result))
                tag-counts)
       result)
     (lambda (a b) (> (cdr a) (cdr b))))))

;;;###autoload
(defun claude-orgmode-get-notes-without-tags ()
  "Get all notes that have no tags.
Return a list of (id title file) tuples."
  (mapcar
   (lambda (node)
     (list (claude-orgmode--backend-node-id node)
           (claude-orgmode--backend-node-title node)
           (claude-orgmode--backend-node-file node)))
   (seq-filter
    (lambda (node)
      (null (claude-orgmode--backend-node-tags node)))
    (claude-orgmode--backend-node-list))))

;;;###autoload
(defun claude-orgmode-add-tag (title tag)
  "Add TAG to the note with TITLE.
Sanitize TAG by replacing hyphens with underscores.
Return t if successful, nil otherwise."
  (let* ((node (claude-orgmode--backend-node-from-title title))
         (sanitized-tag (claude-orgmode--sanitize-tag tag)))
    (when node
      (claude-orgmode--backend-add-tag node sanitized-tag)
      t)))

;;;###autoload
(defun claude-orgmode-remove-tag (title tag)
  "Remove TAG from the note with TITLE.
Sanitize TAG by replacing hyphens with underscores.
Return t if successful, nil otherwise."
  (let* ((node (claude-orgmode--backend-node-from-title title))
         (sanitized-tag (claude-orgmode--sanitize-tag tag)))
    (when node
      (claude-orgmode--backend-remove-tag node sanitized-tag)
      t)))

(provide 'claude-orgmode-tags)
;;; claude-orgmode-tags.el ends here
