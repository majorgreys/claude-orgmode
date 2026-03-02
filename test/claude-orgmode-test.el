;;; claude-orgmode-test.el --- Unit tests for claude-orgmode -*- lexical-binding: t; -*-

;;; Commentary:
;; Unit tests for claude-orgmode functions using Buttercup

;;; Code:

(require 'buttercup)
(require 'claude-orgmode)

;;; Tag Sanitization Tests

(describe "claude-orgmode--sanitize-tag"
  (it "replaces hyphens with underscores"
    (expect (claude-orgmode--sanitize-tag "my-tag") :to-equal "my_tag"))

  (it "handles multi-word tags"
    (expect (claude-orgmode--sanitize-tag "multi-word-tag") :to-equal "multi_word_tag"))

  (it "leaves already clean tags unchanged"
    (expect (claude-orgmode--sanitize-tag "already_clean") :to-equal "already_clean")
    (expect (claude-orgmode--sanitize-tag "no_change") :to-equal "no_change")))

;;; Filename Generation Tests

(describe "claude-orgmode--expand-filename"
  (it "generates timestamp-only filenames"
    (let ((org-roam-capture-templates
           '(("d" "default" plain "%?"
              :target (file+head "%<%Y%m%d%H%M%S>.org" "${title}")
              :unnarrowed t))))
      (let ((filename (claude-orgmode--expand-filename "Test Note")))
        (expect filename :to-match "^[0-9]\\{14\\}\\.org$"))))

  (it "generates timestamp-slug filenames"
    (let ((org-roam-capture-templates
           '(("d" "default" plain "%?"
              :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "${title}")
              :unnarrowed t))))
      (let ((filename (claude-orgmode--expand-filename "Test Note")))
        (expect filename :to-match "^[0-9]\\{14\\}-test_note\\.org$")))))

;;; Time Format Expansion Tests

(describe "claude-orgmode--expand-time-formats"
  (it "expands custom time format %<...>"
    (let ((result (claude-orgmode--expand-time-formats "Date: %<%Y-%m-%d>")))
      (expect result :to-match "Date: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")))

  (it "expands %U inactive timestamp with time"
    (let ((result (claude-orgmode--expand-time-formats "Created: %U")))
      (expect result :to-match "Created: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z] [0-9]\\{2\\}:[0-9]\\{2\\}\\]")))

  (it "expands %u inactive timestamp without time"
    (let ((result (claude-orgmode--expand-time-formats "Date: %u")))
      (expect result :to-match "Date: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z]\\]")))

  (it "expands %T active timestamp with time"
    (let ((result (claude-orgmode--expand-time-formats "Scheduled: %T")))
      (expect result :to-match "Scheduled: <[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z] [0-9]\\{2\\}:[0-9]\\{2\\}>")))

  (it "expands %t active timestamp without time"
    (let ((result (claude-orgmode--expand-time-formats "Deadline: %t")))
      (expect result :to-match "Deadline: <[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z]>")))

  (it "expands multiple time formats in one string"
    (let ((result (claude-orgmode--expand-time-formats "#+date: %<%Y-%m-%d>\n#+created: %U")))
      (expect result :to-match "^#\\+date: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")
      (expect result :to-match "#\\+created: \\[[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")))

  (it "leaves text without time formats unchanged"
    (let ((result (claude-orgmode--expand-time-formats "Just plain text")))
      (expect result :to-equal "Just plain text"))))

;;; Doctor Functions Tests

(describe "claude-orgmode-doctor-quick"
  (it "returns status of org-roam setup"
    (let ((org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (expect (claude-orgmode-doctor-quick) :to-be t))
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
            (let ((setup (claude-orgmode-check-setup)))
              (expect setup :not :to-be nil)
              (expect (plist-get setup :backend) :to-be 'org-roam)
              (expect (plist-get setup :directory-exists) :to-be t)))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

;;; Org-Roam Syntax Validation Tests

(describe "claude-orgmode--validate-org-syntax"
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
            (let ((result (claude-orgmode--validate-org-syntax test-file)))
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
            (let ((result (claude-orgmode--validate-org-syntax test-file)))
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
            (let ((result (claude-orgmode--validate-org-syntax test-file)))
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
            (let ((result (claude-orgmode--validate-org-syntax test-file)))
              (expect (plist-get result :valid) :to-be nil)
              (expect (car (plist-get result :errors)) :to-match "missing space after asterisks")))
        (when (file-exists-p test-file)
          (delete-file test-file))))))

(describe "claude-orgmode--read-content-file"
  (it "reads content from existing file"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert "Test content from file"))
            (expect (claude-orgmode--read-content-file test-file)
                    :to-equal "Test content from file"))
        (when (file-exists-p test-file)
          (delete-file test-file)))))

  (it "signals error for non-existent file"
    (expect (claude-orgmode--read-content-file "/nonexistent/file.org")
            :to-throw 'error))

  (it "handles files with special characters"
    (let ((test-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file test-file
              (insert "Content with \"quotes\" and 'apostrophes' and $special chars"))
            (expect (claude-orgmode--read-content-file test-file)
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
            (let ((content (claude-orgmode--read-content-file test-file)))
              (expect (length content) :to-be-greater-than 10000)
              (expect content :to-match "Line 999")))
        (when (file-exists-p test-file)
          (delete-file test-file))))))

(describe "claude-orgmode-create-note"
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
            (let ((file-path (claude-orgmode-create-note "Test Note"
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
            (let ((file-path (claude-orgmode-create-note "Test Note From File"
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
            (let ((file-path (claude-orgmode-create-note "Priority Test"
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
            (let ((file-path (claude-orgmode-create-note "Test Note"
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

(describe "claude-orgmode--looks-like-temp-file"
  (it "returns t for /tmp/ paths"
    (expect (claude-orgmode--looks-like-temp-file "/tmp/test.org") :to-be-truthy))

  (it "returns t for /var/tmp/ paths"
    (expect (claude-orgmode--looks-like-temp-file "/var/tmp/test.org") :to-be-truthy))

  (it "returns nil for home directory paths"
    (expect (claude-orgmode--looks-like-temp-file "~/test.org") :not :to-be-truthy))

  (it "returns nil for absolute home directory paths"
    (expect (claude-orgmode--looks-like-temp-file (expand-file-name "~/test.org")) :not :to-be-truthy))

  (it "returns nil for non-strings"
    (expect (claude-orgmode--looks-like-temp-file nil) :not :to-be-truthy)
    (expect (claude-orgmode--looks-like-temp-file 123) :not :to-be-truthy)))

(describe "claude-orgmode-create-note with temp file cleanup"
  (it "automatically deletes temp file after note creation"
    (let* ((org-roam-directory (make-temp-file "org-roam-test-" t))
           (org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
           (temp-file (make-temp-file "org-roam-test-" nil ".org")))
      (unwind-protect
          (progn
            (with-temp-file temp-file
              (insert "Test content"))
            (org-roam-db-sync)
            (let ((file-path (claude-orgmode-create-note "Temp File Test"
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
            (let ((file-path (claude-orgmode-create-note "Keep File Test"
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
            (expect (claude-orgmode-create-note "Already Deleted Test"
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
                  (claude-orgmode-create-note "Failure Test" :content-file temp-file)
                (error nil)))
            ;; Even though note creation failed, temp file should be cleaned up
            (expect (file-exists-p temp-file) :not :to-be-truthy))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

;;; Backend Detection Tests

(describe "claude-orgmode--detect-backend"
  (it "detects org-roam when loaded"
    ;; org-roam is loaded in our test environment
    (let ((claude-orgmode--backend nil))
      (expect (claude-orgmode--detect-backend) :to-be 'org-roam)))

  (it "caches the detected backend"
    (let ((claude-orgmode--backend nil))
      (claude-orgmode--detect-backend)
      (expect claude-orgmode--backend :to-be 'org-roam)))

  (it "returns cached value on subsequent calls"
    (let ((claude-orgmode--backend 'org-roam))
      (expect (claude-orgmode--detect-backend) :to-be 'org-roam))))

(describe "claude-orgmode--backend-org-roam-p"
  (it "returns non-nil when backend is org-roam"
    (let ((claude-orgmode--backend 'org-roam))
      (expect (claude-orgmode--backend-org-roam-p) :to-be-truthy)))

  (it "returns nil when backend is vulpea"
    (let ((claude-orgmode--backend 'vulpea))
      (expect (claude-orgmode--backend-org-roam-p) :not :to-be-truthy))))

(describe "claude-orgmode--backend-vulpea-p"
  (it "returns non-nil when backend is vulpea"
    (let ((claude-orgmode--backend 'vulpea))
      (expect (claude-orgmode--backend-vulpea-p) :to-be-truthy)))

  (it "returns nil when backend is org-roam"
    (let ((claude-orgmode--backend 'org-roam))
      (expect (claude-orgmode--backend-vulpea-p) :not :to-be-truthy))))

(describe "claude-orgmode--backend-directory"
  (it "returns org-roam-directory when backend is org-roam"
    (let ((claude-orgmode--backend 'org-roam)
          (org-roam-directory "/test/notes"))
      (expect (claude-orgmode--backend-directory) :to-equal "/test/notes"))))

(describe "claude-orgmode--backend-node-id"
  (it "dispatches to org-roam-node-id for org-roam backend"
    (let ((claude-orgmode--backend 'org-roam)
          (org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            ;; Create a minimal note to get a real node
            (let* ((test-file (expand-file-name "test.org" org-roam-directory)))
              (with-temp-file test-file
                (insert ":PROPERTIES:\n:ID:       test-backend-id\n:END:\n#+TITLE: Backend Test\n"))
              (org-roam-db-sync)
              (let ((node (org-roam-node-from-id "test-backend-id")))
                (when node
                  (expect (claude-orgmode--backend-node-id node)
                          :to-equal "test-backend-id")))))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

(describe "claude-orgmode--backend-node-title"
  (it "dispatches to org-roam-node-title for org-roam backend"
    (let ((claude-orgmode--backend 'org-roam)
          (org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (let* ((test-file (expand-file-name "test.org" org-roam-directory)))
              (with-temp-file test-file
                (insert ":PROPERTIES:\n:ID:       test-title-id\n:END:\n#+TITLE: Title Dispatch Test\n"))
              (org-roam-db-sync)
              (let ((node (org-roam-node-from-id "test-title-id")))
                (when node
                  (expect (claude-orgmode--backend-node-title node)
                          :to-equal "Title Dispatch Test")))))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

(describe "claude-orgmode--backend-info"
  (it "returns backend info plist for org-roam"
    (let ((claude-orgmode--backend 'org-roam)
          (org-roam-directory (make-temp-file "org-roam-test-" t))
          (org-roam-db-location (expand-file-name "org-roam.db"
                                                   (make-temp-file "org-roam-test-" t))))
      (unwind-protect
          (progn
            (org-roam-db-sync)
            (let ((info (claude-orgmode--backend-info)))
              (expect (plist-get info :backend) :to-be 'org-roam)
              (expect (plist-get info :directory) :to-equal org-roam-directory)
              (expect (plist-get info :node-count) :to-be 0)))
        (when (file-exists-p org-roam-directory)
          (delete-directory org-roam-directory t))))))

;;; Vulpea Backend Dispatch Tests (mocked)
;;
;; Since vulpea is not available in the test environment, we mock all
;; vulpea functions and verify that the backend dispatch calls the
;; correct vulpea function when the backend is set to 'vulpea.

;; Declare vulpea variables as special so `let' binds them dynamically
;; (required because this file uses lexical-binding and `boundp' checks
;; the dynamic binding).
(defvar vulpea-db-sync-directories)
(defvar vulpea-db-location)

(describe "vulpea backend dispatch"
  :var (mock-note)

  (before-each
    ;; Create a mock vulpea note (just a plist we can pass around)
    (setq mock-note '(:id "vulpea-uuid-123"
                      :title "Vulpea Test Note"
                      :path "/notes/test.org"
                      :tags ("emacs" "lisp")
                      :aliases ("VTN")
                      :level 0))

    ;; Define mock vulpea functions that return predictable values
    (fset 'vulpea-note-id (lambda (note) (plist-get note :id)))
    (fset 'vulpea-note-title (lambda (note) (plist-get note :title)))
    (fset 'vulpea-note-path (lambda (note) (plist-get note :path)))
    (fset 'vulpea-note-tags (lambda (note) (plist-get note :tags)))
    (fset 'vulpea-note-aliases (lambda (note) (plist-get note :aliases)))
    (fset 'vulpea-note-level (lambda (note) (plist-get note :level)))
    (fset 'vulpea-db-get-by-id (lambda (id) (when (equal id "vulpea-uuid-123") mock-note)))
    (fset 'vulpea-db-search-by-title (lambda (title) (when (equal title "Vulpea Test Note") (list mock-note))))
    (fset 'vulpea-db-query (lambda () (list mock-note)))
    (fset 'vulpea-db-sync-full-scan (lambda () t))
    (fset 'vulpea-tags-add (lambda (note tag) t))
    (fset 'vulpea-tags-remove (lambda (note tag) t))
    (fset 'vulpea-db-query-links-to (lambda (id) nil))
    (fset 'vulpea-create (lambda (title _meta &rest args) mock-note)))

  (describe "claude-orgmode--backend-node-id"
    (it "dispatches to vulpea-note-id"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-id :and-call-through)
        (expect (claude-orgmode--backend-node-id mock-note)
                :to-equal "vulpea-uuid-123")
        (expect 'vulpea-note-id :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-title"
    (it "dispatches to vulpea-note-title"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-title :and-call-through)
        (expect (claude-orgmode--backend-node-title mock-note)
                :to-equal "Vulpea Test Note")
        (expect 'vulpea-note-title :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-file"
    (it "dispatches to vulpea-note-path"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-path :and-call-through)
        (expect (claude-orgmode--backend-node-file mock-note)
                :to-equal "/notes/test.org")
        (expect 'vulpea-note-path :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-tags"
    (it "dispatches to vulpea-note-tags"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-tags :and-call-through)
        (expect (claude-orgmode--backend-node-tags mock-note)
                :to-equal '("emacs" "lisp"))
        (expect 'vulpea-note-tags :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-aliases"
    (it "dispatches to vulpea-note-aliases"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-aliases :and-call-through)
        (expect (claude-orgmode--backend-node-aliases mock-note)
                :to-equal '("VTN"))
        (expect 'vulpea-note-aliases :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-level"
    (it "dispatches to vulpea-note-level"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-note-level :and-call-through)
        (expect (claude-orgmode--backend-node-level mock-note)
                :to-equal 0)
        (expect 'vulpea-note-level :to-have-been-called-with mock-note))))

  (describe "claude-orgmode--backend-node-from-id"
    (it "dispatches to vulpea-db-get-by-id"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-db-get-by-id :and-call-through)
        (expect (claude-orgmode--backend-node-from-id "vulpea-uuid-123")
                :to-equal mock-note)
        (expect 'vulpea-db-get-by-id :to-have-been-called-with "vulpea-uuid-123"))))

  (describe "claude-orgmode--backend-node-from-title"
    (it "dispatches to vulpea-db-search-by-title"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-db-search-by-title :and-call-through)
        (expect (claude-orgmode--backend-node-from-title "Vulpea Test Note")
                :to-equal mock-note)
        (expect 'vulpea-db-search-by-title :to-have-been-called-with "Vulpea Test Note"))))

  (describe "claude-orgmode--backend-node-list"
    (it "dispatches to vulpea-db-query"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-db-query :and-call-through)
        (expect (claude-orgmode--backend-node-list)
                :to-equal (list mock-note))
        (expect 'vulpea-db-query :to-have-been-called))))

  (describe "claude-orgmode--backend-db-sync"
    (it "dispatches to vulpea-db-sync-full-scan"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-db-sync-full-scan :and-call-through)
        (claude-orgmode--backend-db-sync)
        (expect 'vulpea-db-sync-full-scan :to-have-been-called))))

  (describe "claude-orgmode--backend-get-backlinks"
    (it "dispatches to vulpea-db-query-links-to"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-db-query-links-to :and-call-through)
        (expect (claude-orgmode--backend-get-backlinks mock-note)
                :to-equal nil)
        (expect 'vulpea-db-query-links-to :to-have-been-called-with "vulpea-uuid-123"))))

  (describe "claude-orgmode--backend-add-tag"
    (it "dispatches to vulpea-tags-add"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-tags-add :and-call-through)
        (claude-orgmode--backend-add-tag mock-note "new_tag")
        (expect 'vulpea-tags-add :to-have-been-called-with mock-note "new_tag"))))

  (describe "claude-orgmode--backend-remove-tag"
    (it "dispatches to vulpea-tags-remove"
      (let ((claude-orgmode--backend 'vulpea))
        (spy-on 'vulpea-tags-remove :and-call-through)
        (claude-orgmode--backend-remove-tag mock-note "old_tag")
        (expect 'vulpea-tags-remove :to-have-been-called-with mock-note "old_tag"))))

  (describe "claude-orgmode--backend-directory"
    (it "returns vulpea directory from vulpea-db-sync-directories"
      (let ((claude-orgmode--backend 'vulpea)
            (vulpea-db-sync-directories '("/vulpea/notes")))
        (expect (claude-orgmode--backend-directory)
                :to-equal "/vulpea/notes")))

    (it "falls back to org-directory when vulpea-db-sync-directories unbound"
      (let ((claude-orgmode--backend 'vulpea)
            (org-directory "/fallback/org"))
        (when (boundp 'vulpea-db-sync-directories)
          (makunbound 'vulpea-db-sync-directories))
        (expect (claude-orgmode--backend-directory)
                :to-equal "/fallback/org"))))

  (describe "claude-orgmode--backend-info"
    (it "returns vulpea backend info"
      (let ((claude-orgmode--backend 'vulpea)
            (vulpea-db-sync-directories '("/vulpea/notes")))
        (spy-on 'vulpea-db-query :and-return-value (list mock-note))
        (let ((info (claude-orgmode--backend-info)))
          (expect (plist-get info :backend) :to-be 'vulpea)
          (expect (plist-get info :directory) :to-equal "/vulpea/notes")
          (expect (plist-get info :node-count) :to-be 1))))))

(provide 'claude-orgmode-test)
;;; claude-orgmode-test.el ends here
