;;; claude-orgmode-attach.el --- File attachment functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Functions for attaching files to notes using org-attach.
;; Also supports attaching files with links in a References section
;; (requires org-download when using `claude-orgmode-attach-file-to-references').

;;; Code:

(require 'org-attach)
(require 'claude-orgmode-core)
(require 'claude-orgmode-backend)

;;;###autoload
(defun claude-orgmode-attach-file (title-or-id file-path)
  "Attach FILE-PATH to the note identified by TITLE-OR-ID.
Copy the file using org-attach.  Return the attachment directory path."
  (unless (file-exists-p file-path)
    (error "File does not exist: %s" file-path))

  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     ;; Attach the file using org-attach
     (org-attach-attach file-path nil 'cp)
     ;; Format the buffer after attaching (org-attach modifies PROPERTIES)
     (claude-orgmode--format-buffer)
     (save-buffer)
     ;; Return info about the attachment
     (let ((attach-dir (org-attach-dir))
           (filename (file-name-nondirectory file-path)))
       (list :directory attach-dir
             :filename filename
             :full-path (expand-file-name filename attach-dir)
             :node-title (claude-orgmode--backend-node-title node))))))

;;;###autoload
(defun claude-orgmode-list-attachments (title-or-id)
  "List all attachments for the note identified by TITLE-OR-ID.
Return a list of attachment info plists with :filename, :size, and :path."
  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     (let ((attach-dir (org-attach-dir)))
       (if (and attach-dir (file-exists-p attach-dir))
           (mapcar
            (lambda (filename)
              (let ((full-path (expand-file-name filename attach-dir)))
                (list :filename filename
                      :path full-path
                      :size (file-attribute-size
                             (file-attributes full-path))
                      :modified (format-time-string
                                "%Y-%m-%d %H:%M:%S"
                                (file-attribute-modification-time
                                 (file-attributes full-path))))))
            (org-attach-file-list attach-dir))
         nil)))))

;;;###autoload
(defun claude-orgmode-delete-attachment (title-or-id filename)
  "Delete the attachment FILENAME from the note identified by TITLE-OR-ID.
Return t on success, nil if attachment doesn't exist."
  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     (let* ((attach-dir (org-attach-dir))
            (attachments (when attach-dir (org-attach-file-list attach-dir))))
       (if (member filename attachments)
           (progn
             (org-attach-delete-one filename)
             ;; Format the buffer after deleting (may modify PROPERTIES)
             (claude-orgmode--format-buffer)
             (save-buffer)
             t)
         (error "Attachment not found: %s" filename))))))

;;;###autoload
(defun claude-orgmode-get-attachment-path (title-or-id filename)
  "Get the full path to attachment FILENAME for note TITLE-OR-ID.
Return the full path if the attachment exists, nil otherwise."
  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     (let* ((attach-dir (org-attach-dir))
            (full-path (when attach-dir
                        (expand-file-name filename attach-dir))))
       (when (and full-path (file-exists-p full-path))
         full-path)))))

;;;###autoload
(defun claude-orgmode-get-attachment-dir (title-or-id)
  "Get the attachment directory for the note identified by TITLE-OR-ID.
Return the directory path, or nil if no attachments exist."
  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     (org-attach-dir))))

;;;###autoload
(defun claude-orgmode-attach-file-to-references (title-or-id path)
  "Attach file from PATH and insert link in the References section of note TITLE-OR-ID.

Creates or appends to a '* References' section at the end of the file with
a link to the attached file. Works with local files and URLs.

Supports:
- Local file paths: /path/to/file.pdf
- URLs: https://example.com/file.pdf
- Base64 data URIs for images"
  (unless (require 'org-download nil 'noerror)
    (error "Package org-download is required for attach-file-to-references"))
  (claude-orgmode--with-node-context
   title-or-id
   (lambda (node)
     (let ((original-point (point)))
       (condition-case-unless-debug e
           (let* ((raw-uri (url-unhex-string path))
                  (new-path (expand-file-name (org-download--fullname raw-uri)))
                  (_ (if (string-match-p (concat "^" (regexp-opt '("http" "https" "nfs" "ftp" "file")) ":/") path)
                         (url-copy-file raw-uri new-path)
                       (copy-file path new-path)))
                  (rel-path (file-relative-name new-path (file-name-directory (buffer-file-name))))
                  (file-name (file-name-nondirectory new-path)))

             ;; Navigate to end of file and find/create References section
             (goto-char (point-max))

             ;; Try to find existing "* References" section
             (if (re-search-backward "^\\* References" nil t)
                 (end-of-line)
               ;; Create new section if it doesn't exist
               (goto-char (point-max))
               (unless (bolp) (newline))
               (insert "\n* References")
               (end-of-line))

             ;; Append the link
             (newline)
             (insert (format "- [[file:%s][%s]]" rel-path file-name))

             ;; Format and save
             (claude-orgmode--format-buffer)
             (save-buffer)

             ;; Return info
             (list :path new-path
                   :relative-path rel-path
                   :filename file-name
                   :node-title (claude-orgmode--backend-node-title node)))

         (error
          (goto-char original-point)
          (error "Failed to attach file: %s" (error-message-string e))))))))

(provide 'claude-orgmode-attach)
;;; claude-orgmode-attach.el ends here
