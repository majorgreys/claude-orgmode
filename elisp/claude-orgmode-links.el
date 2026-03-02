;;; claude-orgmode-links.el --- Link management functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for managing backlinks, forward links, and link insertion.
;; Supports both org-roam and vulpea backends.

;;; Code:

(require 'org)
(require 'claude-orgmode-backend)

;;;###autoload
(defun claude-orgmode-get-backlinks-by-title (title)
  "Get backlinks for a note with TITLE.
Return a list of (id title file) tuples for notes linking to this note."
  (let ((node (claude-orgmode--backend-node-from-title title)))
    (when node
      (mapcar
       (lambda (source-node)
         (list (claude-orgmode--backend-node-id source-node)
               (claude-orgmode--backend-node-title source-node)
               (claude-orgmode--backend-node-file source-node)))
       (claude-orgmode--backend-get-backlinks node)))))

;;;###autoload
(defun claude-orgmode-get-backlinks-by-id (node-id)
  "Get backlinks for a note with NODE-ID.
Return a list of (id title file) tuples for notes linking to this note."
  (let ((node (claude-orgmode--backend-node-from-id node-id)))
    (when node
      (mapcar
       (lambda (source-node)
         (list (claude-orgmode--backend-node-id source-node)
               (claude-orgmode--backend-node-title source-node)
               (claude-orgmode--backend-node-file source-node)))
       (claude-orgmode--backend-get-backlinks node)))))

;;;###autoload
(defun claude-orgmode-get-forward-links-by-title (title)
  "Get forward links (outgoing links) for a note with TITLE.
Return a list of (id title file) tuples for notes this note links to."
  (let* ((node (claude-orgmode--backend-node-from-title title))
         (file (when node (claude-orgmode--backend-node-file node)))
         (links '()))
    (when (and file (file-exists-p file))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward org-link-bracket-re nil t)
          (let* ((link (match-string 1))
                 (target-node (when (string-prefix-p "id:" link)
                                (claude-orgmode--backend-node-from-id
                                 (substring link 3)))))
            (when target-node
              (push (list (claude-orgmode--backend-node-id target-node)
                          (claude-orgmode--backend-node-title target-node)
                          (claude-orgmode--backend-node-file target-node))
                    links))))))
    (nreverse links)))

;;;###autoload
(defun claude-orgmode-get-all-connections-by-title (title)
  "Get all connections (backlinks and forward links) for a note with TITLE.
Return a plist with :backlinks and :forward-links."
  (list :backlinks (claude-orgmode-get-backlinks-by-title title)
        :forward-links (claude-orgmode-get-forward-links-by-title title)))

;;;###autoload
(defun claude-orgmode-insert-link (source-file target-title)
  "Insert a link to TARGET-TITLE note in SOURCE-FILE at the end.
Return the inserted link text."
  (let ((target-node (claude-orgmode--backend-node-from-title target-title)))
    (when target-node
      (with-current-buffer (find-file-noselect source-file)
        (goto-char (point-max))
        (let ((link-text (org-link-make-string
                          (concat "id:" (claude-orgmode--backend-node-id target-node))
                          (claude-orgmode--backend-node-title target-node))))
          (insert "\n" link-text "\n")
          (save-buffer)
          link-text)))))

;;;###autoload
(defun claude-orgmode-insert-link-in-note (source-title target-title)
  "Insert a link to TARGET-TITLE in the note titled SOURCE-TITLE.
Return the inserted link text."
  (let ((source-node (claude-orgmode--backend-node-from-title source-title)))
    (when source-node
      (claude-orgmode-insert-link
       (claude-orgmode--backend-node-file source-node) target-title))))

;;;###autoload
(defun claude-orgmode-create-bidirectional-link (title-a title-b)
  "Create bidirectional links between notes TITLE-A and TITLE-B.
Insert links in both directions."
  (let ((link-a-to-b (claude-orgmode-insert-link-in-note title-a title-b))
        (link-b-to-a (claude-orgmode-insert-link-in-note title-b title-a)))
    (list :a-to-b link-a-to-b :b-to-a link-b-to-a)))

;;;###autoload
(defun claude-orgmode-insert-multiple-links (source-title target-titles)
  "Insert links to multiple TARGET-TITLES in the note titled SOURCE-TITLE.
Return a list of inserted link texts."
  (mapcar
   (lambda (target-title)
     (claude-orgmode-insert-link-in-note source-title target-title))
   target-titles))

(provide 'claude-orgmode-links)
;;; claude-orgmode-links.el ends here
