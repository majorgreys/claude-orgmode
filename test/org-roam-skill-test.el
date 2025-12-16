;;; org-roam-skill-test.el --- Unit tests for org-roam-skill -*- lexical-binding: t; -*-

;;; Commentary:
;; Unit tests for org-roam-skill functions using Buttercup

;;; Code:

(require 'buttercup)
(require 'org-roam-skill)

;;; Tag Sanitization Tests

(describe "org-roam-skill--sanitize-tag"
  (it "replaces hyphens with underscores"
    (expect (org-roam-skill--sanitize-tag "my-tag") :to-equal "my_tag"))

  (it "handles multi-word tags"
    (expect (org-roam-skill--sanitize-tag "multi-word-tag") :to-equal "multi_word_tag"))

  (it "leaves already clean tags unchanged"
    (expect (org-roam-skill--sanitize-tag "already_clean") :to-equal "already_clean")
    (expect (org-roam-skill--sanitize-tag "no_change") :to-equal "no_change")))

;;; Filename Generation Tests

(describe "org-roam-skill--expand-filename"
  (it "generates timestamp-only filenames"
    (let ((org-roam-capture-templates
           '(("d" "default" plain "%?"
              :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
              :unnarrowed t))))
      (let ((filename (org-roam-skill--expand-filename "Test Note")))
        (expect filename :to-match "^[0-9]\\{14\\}\\.org$"))))

  (it "generates timestamp-slug filenames"
    (let ((org-roam-capture-templates
           '(("d" "default" plain "%?"
              :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "${title}")
              :unnarrowed t))))
      (let ((filename (org-roam-skill--expand-filename "Test Note")))
        (expect filename :to-match "^[0-9]\\{14\\}-test_note\\.org$")))))

;;; Time Format Expansion Tests

(describe "org-roam-skill--expand-time-formats"
  (it "expands custom time format %<...>"
    (let ((result (org-roam-skill--expand-time-formats "Date: %<%Y-%m-%d>")))
      (expect result :to-match "Date: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")))

  (it "expands %U inactive timestamp with time"
    (let ((result (org-roam-skill--expand-time-formats "Created: %U")))
      (expect result :to-match "Created: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z] [0-9]\\{2\\}:[0-9]\\{2\\}\\]")))

  (it "expands %u inactive timestamp without time"
    (let ((result (org-roam-skill--expand-time-formats "Date: %u")))
      (expect result :to-match "Date: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z]\\]")))

  (it "expands %T active timestamp with time"
    (let ((result (org-roam-skill--expand-time-formats "Scheduled: %T")))
      (expect result :to-match "Scheduled: <[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z] [0-9]\\{2\\}:[0-9]\\{2\\}>")))

  (it "expands %t active timestamp without time"
    (let ((result (org-roam-skill--expand-time-formats "Deadline: %t")))
      (expect result :to-match "Deadline: <[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z]>")))

  (it "expands multiple time formats in one string"
    (let ((result (org-roam-skill--expand-time-formats "#+date: %<%Y-%m-%d>\n#+created: %U")))
      (expect result :to-match "^#\\+date: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")
      (expect result :to-match "#\\+created: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")))

  (it "leaves text without time formats unchanged"
    (let ((result (org-roam-skill--expand-time-formats "Just plain text")))
      (expect result :to-equal "Just plain text"))))

;;; Doctor Functions Tests

(describe "org-roam-doctor-quick"
  (it "returns status of org-roam setup"
    (let ((org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (expect (org-roam-doctor-quick) :to-be t))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

(describe "check-org-roam-setup"
  (it "returns setup information"
    (let ((org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (let ((setup (org-roam-skill-check-setup)))
              (expect setup :not :to-be nil)
              (expect (plist-get setup :org-roam-loaded) :to-be t)
              (expect (plist-get setup :directory-exists) :to-be t)))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

;;; Org-Roam Syntax Validation Tests

(describe "org-roam-skill--validate-org-syntax"
  (it "validates proper org syntax"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert ":PROPERTIES:\n")
              (insert ":ID:       test-id\n")
              (insert ":END:\n")
              (insert "#+TITLE: Test Note\n")
              (insert "#+FILETAGS: :test:\n"))
            (let ((result (org-roam-skill--validate-org-syntax test-file)))
              (expect (plist-get result :valid) :to-be t)
              (expect (plist-get result :errors) :to-equal nil)))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "detects lowercase keywords"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert ":PROPERTIES:\n")
              (insert ":ID:       test-id\n")
              (insert ":END:\n")
              (insert "#+title: Test Note\n"))
            (let ((result (org-roam-skill--validate-org-syntax test-file)))
              (expect (plist-get result :valid) :to-be nil)
              (expect (length (plist-get result :errors)) :to-be-greater-than 0)))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "detects blank lines in PROPERTIES drawer"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert ":PROPERTIES:\n")
              (insert ":ID:       test-id\n")
              (insert "\n")  ;; Blank line - should be detected
              (insert ":END:\n")
              (insert "#+TITLE: Test Note\n"))
            (let ((result (org-roam-skill--validate-org-syntax test-file)))
              (expect (plist-get result :valid) :to-be nil)
              (expect (car (plist-get result :errors)) :to-match "PROPERTIES drawer contains blank lines")))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "detects headings without space after asterisks"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert ":PROPERTIES:\n")
              (insert ":ID:       test-id\n")
              (insert ":END:\n")
              (insert "#+TITLE: Test Note\n")
              (insert "*Heading without space\n"))
            (let ((result (org-roam-skill--validate-org-syntax test-file)))
              (expect (plist-get result :valid) :to-be nil)
              (expect (car (plist-get result :errors)) :to-match "missing space after asterisks")))
        (when (file-exists-p test-file)
          (delete-file test-file))))))

(describe "org-roam-skill--read-content-file"
  (it "reads content from existing file"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert "Test content from file"))
            (expect (org-roam-skill--read-content-file test-file)
                    :to-equal "Test content from file"))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "signals error for non-existent file"
    (expect (org-roam-skill--read-content-file "/nonexistent/file.org")
            :to-throw 'error))

  (it "handles files with special characters"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert "Content with \"quotes\" and 'apostrophes' and $special chars"))
            (expect (org-roam-skill--read-content-file test-file)
                    :to-match "quotes"))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "handles large files"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (dotimes (i 1000)
                (insert (format "Line %d with content\n" i))))
            (let ((content (org-roam-skill--read-content-file test-file)))
              (expect (length content) :to-be-greater-than 10000)
              (expect content :to-match "Line 999")))
        (when (file-exists-p test-file)
          (delete-file test-file))))))

(describe "org-roam-skill-create-note"
  (it "creates notes with inline content using :content parameter"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (org-roam-capture-templates
            '(("d" "default" plain "%?"
               :target (file+head "%<%Y%m%d%H%M%S>.org" "#+TITLE: ${title}")
               :unnarrowed t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Test Note"
                                                          :tags '("test" "example")
                                                          :content "Test content")))
              (expect (file-exists-p file-path) :to-be t)
              (with-temp-buffer
                (insert-file-contents file-path)
                (let ((content (buffer-string)))
                  (expect (string-match-p "Test content" content) :to-be-truthy)
                  (expect (string-match-p "#\\+\\(?:TITLE\\|title\\):" content) :to-be-truthy)
                  (expect (string-match-p "#\\+\\(?:FILETAGS\\|filetags\\):" content) :to-be-truthy)
                  (expect (string-match-p ":PROPERTIES:" content) :to-be-truthy)
                  (expect (string-match-p ":ID:" content) :to-be-truthy)
                  (expect (string-match-p ":END:" content) :to-be-truthy)))))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "creates notes with content from file using :content-file parameter"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (org-roam-capture-templates
            '(("d" "default" plain "%?"
               :target (file+head "%<%Y%m%d%H%M%S>.org" "#+TITLE: ${title}")
               :unnarrowed t)))
           (content-file (make-temp-file "org-roam-content-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file content-file
              (insert "# Content from File\n\nThis is test content loaded from a temporary file."))
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Test Note From File"
                                                          :tags '("test" "file")
                                                          :content-file content-file)))
              (expect (file-exists-p file-path) :to-be t)
              (with-temp-buffer
                (insert-file-contents file-path)
                (let ((content (buffer-string)))
                  (expect (string-match-p "Content from File" content) :to-be-truthy)
                  (expect (string-match-p "test content loaded from" content) :to-be-truthy)
                  (expect (string-match-p "#\\+\\(?:TITLE\\|title\\):" content) :to-be-truthy)
                  (expect (string-match-p ":test:file:" content) :to-be-truthy)))))
        (when (file-exists-p content-file)
          (delete-file content-file))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "prioritizes :content-file over :content when both provided"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (org-roam-capture-templates
            '(("d" "default" plain "%?"
               :target (file+head "%<%Y%m%d%H%M%S>.org" "#+TITLE: ${title}")
               :unnarrowed t)))
           (content-file (make-temp-file "org-roam-content-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file content-file
              (insert "Content from file should win"))
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Priority Test"
                                                          :content "Inline content"
                                                          :content-file content-file)))
              (expect (file-exists-p file-path) :to-be t)
              (with-temp-buffer
                (insert-file-contents file-path)
                (let ((content (buffer-string)))
                  (expect content :to-match "Content from file should win")
                  (expect content :not :to-match "Inline content")))))
        (when (file-exists-p content-file)
          (delete-file content-file))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "creates notes with uppercase keywords"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (org-roam-capture-templates
            '(("d" "default" plain "%?"
               :target (file+head "%<%Y%m%d%H%M%S>.org" "#+TITLE: ${title}")
               :unnarrowed t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Test Note"
                                                          :tags '("test" "example")
                                                          :content "Test content")))
              (expect (file-exists-p file-path) :to-be t)
              (with-temp-buffer
                (insert-file-contents file-path)
                (let ((content (buffer-string)))
                  ;; Verify uppercase keywords are present
                  (expect (string-match-p "TITLE" content) :to-be-truthy)
                  (expect (string-match-p "FILETAGS" content) :to-be-truthy)
                  ;; Verify proper PROPERTIES drawer
                  (expect (string-match-p "PROPERTIES" content) :to-be-truthy)
                  (expect (string-match-p ":ID:" content) :to-be-truthy)
                  (expect (string-match-p ":END:" content) :to-be-truthy)))))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

;;; Temp File Cleanup Tests

(describe "org-roam-skill--looks-like-temp-file"
  (it "returns t for /tmp/ paths"
    (expect (org-roam-skill--looks-like-temp-file "/tmp/test.org") :to-be-truthy))

  (it "returns t for /var/tmp/ paths"
    (expect (org-roam-skill--looks-like-temp-file "/var/tmp/test.org") :to-be-truthy))

  (it "returns nil for home directory paths"
    (expect (org-roam-skill--looks-like-temp-file "~/test.org") :not :to-be-truthy))

  (it "returns nil for absolute home directory paths"
    (expect (org-roam-skill--looks-like-temp-file (expand-file-name "~/test.org")) :not :to-be-truthy))

  (it "returns nil for non-strings"
    (expect (org-roam-skill--looks-like-temp-file nil) :not :to-be-truthy)
    (expect (org-roam-skill--looks-like-temp-file 123) :not :to-be-truthy)))

(describe "org-roam-skill-create-note with temp file cleanup"
  (it "automatically deletes temp file after note creation"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (temp-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file temp-file
              (insert "Test content"))
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Temp File Test"
                                                         :content-file temp-file)))
              (expect (file-exists-p file-path) :to-be t)
              ;; Temp file should be auto-deleted
              (expect (file-exists-p temp-file) :not :to-be-truthy)))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "preserves temp file when :keep-file is t"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (temp-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file temp-file
              (insert "Test content"))
            (org-roam-db-sync)
            (let ((file-path (org-roam-skill-create-note "Keep File Test"
                                                         :content-file temp-file
                                                         :keep-file t)))
              (expect (file-exists-p file-path) :to-be t)
              ;; Temp file should NOT be deleted when :keep-file is t
              (expect (file-exists-p temp-file) :to-be t)))
        (when (file-exists-p temp-file)
          (delete-file temp-file))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "handles already-deleted files gracefully"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory)))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            ;; Should not throw when file doesn't exist
            (expect (org-roam-skill-create-note "Already Deleted Test"
                                               :content "Direct content")
                    :not :to-throw))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t)))))

  (it "cleans up temp file even if note creation fails"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (temp-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file temp-file
              (insert "Test content"))
            (org-roam-db-sync)
            ;; Simulate failure by using invalid org-roam-capture-templates
            (let ((org-roam-capture-templates nil))
              ;; This should fail, but cleanup should still happen
              (condition-case nil
                  (org-roam-skill-create-note "Failure Test" :content-file temp-file)
                (error nil)))
            ;; Even though note creation failed, temp file should be cleaned up
            (expect (file-exists-p temp-file) :not :to-be-truthy))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

(provide 'org-roam-skill-test)
;;; org-roam-skill-test.el ends here
