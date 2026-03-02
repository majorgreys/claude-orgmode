;;; claude-orgmode-doctor.el --- Diagnostic functions -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026

;; Author: Tahir Butt
;; Keywords: outlines convenience

;;; Commentary:
;; Diagnostic functions for checking backend setup and configuration.
;; Supports both org-roam and vulpea backends.

;;; Code:

(require 'org-id)
(require 'claude-orgmode-backend)

;;;###autoload
(defun claude-orgmode-doctor ()
  "Run diagnostic check on the active backend.
Returns a detailed report of the configuration status."
  (let ((checks '())
        (errors '())
        (warnings '())
        (backend (claude-orgmode--detect-backend)))

    ;; Check 1: Backend detected
    (push (format "✓ Backend: %s" backend) checks)

    (pcase backend
      ('org-roam
       ;; org-roam specific checks
       (if (featurep 'org-roam)
           (push "✓ org-roam is loaded" checks)
         (push "✗ org-roam is NOT loaded" errors))

       (if (and (boundp 'org-roam-directory)
                org-roam-directory
                (file-directory-p org-roam-directory))
           (push (format "✓ Notes directory exists: %s" org-roam-directory) checks)
         (push (format "✗ Notes directory not found: %s"
                       (if (boundp 'org-roam-directory) org-roam-directory "NOT SET"))
               errors))

       (when (and (boundp 'org-roam-directory)
                  org-roam-directory
                  (file-directory-p org-roam-directory))
         (if (file-writable-p org-roam-directory)
             (push "✓ Notes directory is writable" checks)
           (push (format "✗ Notes directory is NOT writable: %s" org-roam-directory) errors)))

       (if (and (boundp 'org-roam-db-location)
                org-roam-db-location
                (file-exists-p org-roam-db-location))
           (push (format "✓ Database exists: %s" org-roam-db-location) checks)
         (push (format "⚠ Database not found (will be created on first sync): %s"
                       (if (boundp 'org-roam-db-location) org-roam-db-location "NOT SET"))
               warnings))

       ;; Capture templates
       (if (and (boundp 'org-roam-capture-templates)
                org-roam-capture-templates)
           (push (format "✓ Capture templates configured (%d template(s))"
                         (length org-roam-capture-templates)) checks)
         (push "⚠ org-roam-capture-templates not configured" warnings))

       ;; Autosync
       (if (and (boundp 'org-roam-db-autosync-mode)
                org-roam-db-autosync-mode)
           (push "✓ Database autosync mode enabled" checks)
         (push "⚠ Database autosync mode not enabled" warnings)))

      ('vulpea
       ;; vulpea specific checks
       (if (featurep 'vulpea)
           (push "✓ vulpea is loaded" checks)
         (push "✗ vulpea is NOT loaded" errors))

       (let ((dir (claude-orgmode--backend-directory)))
         (if (and dir (file-directory-p dir))
             (push (format "✓ Notes directory exists: %s" dir) checks)
           (push (format "✗ Notes directory not found: %s" (or dir "NOT SET")) errors))

         (when (and dir (file-directory-p dir))
           (if (file-writable-p dir)
               (push "✓ Notes directory is writable" checks)
             (push (format "✗ Notes directory is NOT writable: %s" dir) errors))))

       ;; Autosync
       (if (and (boundp 'vulpea-db-autosync-mode)
                vulpea-db-autosync-mode)
           (push "✓ Database autosync mode enabled" checks)
         (push "⚠ Database autosync mode not enabled" warnings))))

    ;; Backend-agnostic checks
    (condition-case err
        (let ((node-count (length (claude-orgmode--backend-node-list))))
          (push (format "✓ Can query database (%d note(s) found)" node-count) checks))
      (error (push (format "✗ Error querying database: %s" (error-message-string err)) errors)))

    ;; Required functions
    (if (fboundp 'org-id-uuid)
        (push "✓ org-id-uuid available" checks)
      (push "✗ org-id-uuid NOT available" errors))

    ;; Generate report
    (with-temp-buffer
      (insert "==================================================\n")
      (insert "       CLAUDE-ORGMODE DIAGNOSTIC REPORT\n")
      (insert "==================================================\n\n")

      (insert (format "Backend: %s\n" backend))
      (insert (format "Total checks: %d\n" (+ (length checks) (length warnings) (length errors))))
      (insert (format "Passed: %d\n" (length checks)))
      (insert (format "Warnings: %d\n" (length warnings)))
      (insert (format "Errors: %d\n\n" (length errors)))

      (cond
       ((> (length errors) 0)
        (insert "Status: ✗ FAILED - Critical issues found\n\n"))
       ((> (length warnings) 0)
        (insert "Status: ⚠ WARNING - Setup works but has recommendations\n\n"))
       (t
        (insert "Status: ✓ PASSED - properly configured\n\n")))

      (when checks
        (insert "PASSED CHECKS:\n")
        (insert "----------------------------------------\n")
        (dolist (check (nreverse checks))
          (insert (format "%s\n" check)))
        (insert "\n"))

      (when warnings
        (insert "WARNINGS:\n")
        (insert "----------------------------------------\n")
        (dolist (warning (nreverse warnings))
          (insert (format "%s\n" warning)))
        (insert "\n"))

      (when errors
        (insert "ERRORS:\n")
        (insert "----------------------------------------\n")
        (dolist (error (nreverse errors))
          (insert (format "%s\n" error)))
        (insert "\n"))

      (insert "CONFIGURATION DETAILS:\n")
      (insert "----------------------------------------\n")
      (insert (format "Emacs version: %s\n" emacs-version))
      (let ((info (claude-orgmode--backend-info)))
        (insert (format "Directory: %s\n" (plist-get info :directory)))
        (insert (format "Database: %s\n" (plist-get info :database))))
      (insert "\n")
      (insert "==================================================\n")

      (buffer-string))))

;;;###autoload
(defun claude-orgmode-doctor-and-print ()
  "Run diagnostic and print the report.
Use this function when calling from emacsclient."
  (let ((report (claude-orgmode-doctor)))
    (message "%s" report)
    report))

;;;###autoload
(defun claude-orgmode-doctor-quick ()
  "Quick diagnostic check - return t if setup is OK, nil otherwise."
  (condition-case nil
      (let ((dir (claude-orgmode--backend-directory)))
        (and dir
             (file-directory-p dir)
             (file-writable-p dir)
             (progn (claude-orgmode--backend-node-list) t)))
    (error nil)))

(provide 'claude-orgmode-doctor)
;;; claude-orgmode-doctor.el ends here
