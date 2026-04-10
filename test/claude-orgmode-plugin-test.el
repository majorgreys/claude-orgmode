;;; claude-orgmode-plugin-test.el --- Plugin integration tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Integration tests that verify the claude-orgmode plugin structure,
;; backend dispatch through the full API, and that the package loads
;; correctly as a plugin would.

;;; Code:

(require 'buttercup)
(require 'claude-orgmode)
(require 'test-helper)

;;; Plugin Structure Tests

(describe "plugin structure"
  (it "marketplace.json exists and is valid"
    (let* ((project-dir (locate-dominating-file
                         (file-name-directory (locate-library "claude-orgmode"))
                         ".claude-plugin"))
           (marketplace (when project-dir
                          (expand-file-name ".claude-plugin/marketplace.json"
                                            project-dir))))
      (expect marketplace :not :to-be nil)
      (expect (file-exists-p marketplace) :to-be t)
      ;; Parse as JSON
      (with-temp-buffer
        (insert-file-contents marketplace)
        (let ((json (json-read-from-string (buffer-string))))
          (expect (cdr (assq 'name json)) :to-equal "claude-orgmode")
          ;; Check skills array references both skills
          (let* ((plugins (cdr (assq 'plugins json)))
                 (first-plugin (aref plugins 0))
                 (skills (cdr (assq 'skills first-plugin))))
            (expect (length skills) :to-equal 2))))))

  (it "all skill directories have SKILL.md"
    (let ((project-dir (locate-dominating-file
                        (file-name-directory (locate-library "claude-orgmode"))
                        "skills")))
      (dolist (skill '("orgmode" "notes"))
        (let ((skill-md (expand-file-name
                         (format "skills/%s/SKILL.md" skill)
                         project-dir)))
          (expect (file-exists-p skill-md) :to-be t)))))

  (it "eval script exists and references correct elisp path"
    (let* ((project-dir (locate-dominating-file
                         (file-name-directory (locate-library "claude-orgmode"))
                         "scripts"))
           (eval-script (expand-file-name "scripts/claude-orgmode-eval"
                                          project-dir)))
      (expect (file-exists-p eval-script) :to-be t)
      ;; Script should reference $PROJECT_DIR/elisp
      (with-temp-buffer
        (insert-file-contents eval-script)
        (expect (buffer-string) :to-match "PROJECT_DIR/elisp"))))

  (it "shared references exist"
    (let ((project-dir (locate-dominating-file
                        (file-name-directory (locate-library "claude-orgmode"))
                        "references")))
      (dolist (ref '("functions.md" "emacsclient-usage.md"
                     "installation.md" "troubleshooting.md"))
        (expect (file-exists-p
                 (expand-file-name (concat "references/" ref) project-dir))
                :to-be t)))))

;;; Package Loading Tests

(describe "package loading"
  (it "all modules are loaded"
    (dolist (feature '(claude-orgmode
                       claude-orgmode-backend
                       claude-orgmode-core
                       claude-orgmode-create
                       claude-orgmode-section
                       claude-orgmode-search
                       claude-orgmode-links
                       claude-orgmode-tags
                       claude-orgmode-attach
                       claude-orgmode-utils
                       claude-orgmode-doctor))
      (expect (featurep feature) :to-be t)))

  (it "all public API functions are defined"
    (dolist (fn '(claude-orgmode-create-note
                  claude-orgmode-search-by-title
                  claude-orgmode-search-by-tag
                  claude-orgmode-search-by-content
                  claude-orgmode-get-node-by-title
                  claude-orgmode-get-backlinks-by-title
                  claude-orgmode-get-backlinks-by-id
                  claude-orgmode-get-forward-links-by-title
                  claude-orgmode-create-bidirectional-link
                  claude-orgmode-insert-link-in-note
                  claude-orgmode-insert-multiple-links
                  claude-orgmode-list-all-tags
                  claude-orgmode-count-notes-by-tag
                  claude-orgmode-get-notes-without-tags
                  claude-orgmode-add-tag
                  claude-orgmode-remove-tag
                  claude-orgmode-attach-file
                  claude-orgmode-list-attachments
                  claude-orgmode-delete-attachment
                  claude-orgmode-get-attachment-path
                  claude-orgmode-get-attachment-dir
                  claude-orgmode-attach-file-to-references
                  claude-orgmode-get-section-content
                  claude-orgmode-create-section
                  claude-orgmode-replace-section
                  claude-orgmode-append-to-section
                  claude-orgmode-delete-section
                  claude-orgmode-check-setup
                  claude-orgmode-get-note-info
                  claude-orgmode-list-recent-notes
                  claude-orgmode-find-orphan-notes
                  claude-orgmode-get-graph-stats
                  claude-orgmode-doctor
                  claude-orgmode-doctor-quick))
      (expect (fboundp fn) :to-be t)))

  (it "all backend dispatch functions are defined"
    (dolist (fn '(claude-orgmode--detect-backend
                  claude-orgmode--backend-org-roam-p
                  claude-orgmode--backend-vulpea-p
                  claude-orgmode--backend-directory
                  claude-orgmode--backend-db-sync
                  claude-orgmode--backend-node-list
                  claude-orgmode--backend-node-id
                  claude-orgmode--backend-node-title
                  claude-orgmode--backend-node-file
                  claude-orgmode--backend-node-tags
                  claude-orgmode--backend-node-aliases
                  claude-orgmode--backend-node-level
                  claude-orgmode--backend-node-from-id
                  claude-orgmode--backend-node-from-title
                  claude-orgmode--backend-get-backlinks
                  claude-orgmode--backend-add-tag
                  claude-orgmode--backend-remove-tag
                  claude-orgmode--backend-create-note
                  claude-orgmode--backend-info))
      (expect (fboundp fn) :to-be t))))

;;; Backend Dispatch Integration Tests (org-roam)

(describe "org-roam backend full workflow"

  (before-each
    (claude-orgmode-test--setup))

  (after-each
    (claude-orgmode-test--teardown))

  (it "check-setup reports org-roam backend"
    (let ((setup (claude-orgmode-check-setup)))
      (expect (plist-get setup :backend) :to-be 'org-roam)
      (expect (plist-get setup :directory-exists) :to-be t)
      (expect (plist-get setup :node-count) :to-be 0)))

  (it "creates note through backend dispatch and finds it"
    (let ((file-path (claude-orgmode-create-note "Backend Test"
                                                  :tags '("test")
                                                  :content "via dispatch")))
      (expect (file-exists-p file-path) :to-be t)
      ;; Verify through backend dispatch search
      (let ((results (claude-orgmode-search-by-title "Backend Test")))
        (expect (length results) :to-equal 1))
      ;; Verify node lookup through backend dispatch
      (let ((node-info (claude-orgmode-get-node-by-title "Backend Test")))
        (expect node-info :not :to-be nil)
        (expect (plist-get node-info :title) :to-equal "Backend Test")
        (expect (plist-get node-info :tags) :to-contain "test"))))

  (it "manages tags through backend dispatch"
    (claude-orgmode-create-note "Tag Test" :tags '("initial"))
    ;; Add tag through backend dispatch
    (claude-orgmode-add-tag "Tag Test" "added")
    (claude-orgmode--backend-db-sync)
    ;; Verify tags
    (let ((tags (claude-orgmode-list-all-tags)))
      (expect tags :to-contain "initial")
      (expect tags :to-contain "added")))

  (it "creates links through backend dispatch"
    (claude-orgmode-create-note "Link Source" :tags '("test"))
    (claude-orgmode-create-note "Link Target" :tags '("test"))
    (claude-orgmode-create-bidirectional-link "Link Source" "Link Target")
    (claude-orgmode--backend-db-sync)
    ;; Verify backlinks through backend dispatch
    (let ((backlinks (claude-orgmode-get-backlinks-by-title "Link Target")))
      (expect (length backlinks) :to-be-greater-than 0)))

  (it "graph stats work through backend dispatch"
    (claude-orgmode-create-note "Stats A" :tags '("test"))
    (claude-orgmode-create-note "Stats B" :tags '("test"))
    (let ((stats (claude-orgmode-get-graph-stats)))
      (expect (plist-get stats :total-notes) :to-equal 2)
      (expect (plist-get stats :unique-tags) :to-be-greater-than 0)))

  (it "backend-info returns correct data"
    (claude-orgmode-create-note "Info Test" :tags '("test"))
    (let ((info (claude-orgmode--backend-info)))
      (expect (plist-get info :backend) :to-be 'org-roam)
      (expect (plist-get info :node-count) :to-equal 1)
      (expect (plist-get info :directory) :to-equal org-roam-directory)))

  (it "doctor-quick returns t for valid setup"
    (expect (claude-orgmode-doctor-quick) :to-be t)))

;;; Vulpea Backend Full Workflow (mocked)

(defvar vulpea-db-sync-directories)
(defvar vulpea-db-location)

(describe "vulpea backend full workflow (mocked)"
  :var (mock-notes next-note-id)

  (before-each
    ;; Simulated in-memory note store
    (setq mock-notes (make-hash-table :test 'equal))
    (setq next-note-id 0)

    ;; Force vulpea backend
    (setq claude-orgmode--backend 'vulpea)

    ;; Mock vulpea note accessors
    (fset 'vulpea-note-id (lambda (note) (plist-get note :id)))
    (fset 'vulpea-note-title (lambda (note) (plist-get note :title)))
    (fset 'vulpea-note-path (lambda (note) (plist-get note :path)))
    (fset 'vulpea-note-tags (lambda (note) (plist-get note :tags)))
    (fset 'vulpea-note-aliases (lambda (note) (plist-get note :aliases)))
    (fset 'vulpea-note-level (lambda (note) (plist-get note :level)))

    ;; Mock vulpea DB functions with in-memory store
    (fset 'vulpea-db-query
          (lambda ()
            (let (notes)
              (maphash (lambda (_k v) (push v notes)) mock-notes)
              notes)))

    (fset 'vulpea-db-get-by-id
          (lambda (id) (gethash id mock-notes)))

    (fset 'vulpea-db-search-by-title
          (lambda (title)
            (let (results)
              (maphash (lambda (_k v)
                         (when (equal (plist-get v :title) title)
                           (push v results)))
                       mock-notes)
              results)))

    (fset 'vulpea-db-sync-full-scan (lambda () t))

    (fset 'vulpea-db-query-links-to (lambda (_id) nil))

    (fset 'vulpea-tags-add
          (lambda (note tag)
            (let* ((id (plist-get note :id))
                   (existing (gethash id mock-notes))
                   (tags (plist-get existing :tags)))
              (unless (member tag tags)
                (plist-put existing :tags (append tags (list tag)))
                (puthash id existing mock-notes)))))

    (fset 'vulpea-tags-remove
          (lambda (note tag)
            (let* ((id (plist-get note :id))
                   (existing (gethash id mock-notes))
                   (tags (plist-get existing :tags)))
              (plist-put existing :tags (remove tag tags))
              (puthash id existing mock-notes))))

    (fset 'vulpea-create
          (lambda (title _meta &rest args)
            (let* ((tags (plist-get args :tags))
                   (body (plist-get args :body))
                   (id (format "vulpea-%d" (cl-incf next-note-id)))
                   (path (format "/tmp/vulpea-test/%s.org" id))
                   (note (list :id id :title title :path path
                               :tags tags :aliases nil :level 0)))
              ;; Write a real file so file-exists-p works
              (make-directory (file-name-directory path) t)
              (with-temp-file path
                (insert (format ":PROPERTIES:\n:ID:       %s\n:END:\n" id))
                (insert (format "#+TITLE: %s\n" title))
                (when tags
                  (insert (format "#+FILETAGS: :%s:\n"
                                  (mapconcat #'identity tags ":"))))
                (when body (insert "\n" body "\n")))
              (puthash id note mock-notes)
              note))))

  (after-each
    (setq claude-orgmode--backend nil)
    ;; Clean up temp files
    (when (file-exists-p "/tmp/vulpea-test/")
      (delete-directory "/tmp/vulpea-test/" t)))

  (it "detects vulpea backend"
    (expect (claude-orgmode--detect-backend) :to-be 'vulpea)
    (expect (claude-orgmode--backend-vulpea-p) :to-be-truthy)
    (expect (claude-orgmode--backend-org-roam-p) :not :to-be-truthy))

  (it "creates note via vulpea-create and finds it by title"
    ;; create-note delegates to vulpea-create when backend is vulpea
    (spy-on 'vulpea-create :and-call-through)
    (let ((result (claude-orgmode--backend-create-note "Vulpea Note"
                                                       :tags '("test")
                                                       :content "body text")))
      ;; vulpea-create was called
      (expect 'vulpea-create :to-have-been-called)
      ;; Returns file path
      (expect result :to-match "/tmp/vulpea-test/")
      (expect (file-exists-p result) :to-be t))

    ;; Find by title through search
    (let ((results (claude-orgmode-search-by-title "Vulpea")))
      (expect (length results) :to-equal 1)))

  (it "searches notes by tag through backend dispatch"
    (claude-orgmode--backend-create-note "Tagged A" :tags '("emacs" "lisp"))
    (claude-orgmode--backend-create-note "Tagged B" :tags '("emacs"))
    (claude-orgmode--backend-create-note "Tagged C" :tags '("python"))

    (let ((results (claude-orgmode-search-by-tag "emacs")))
      (expect (length results) :to-equal 2))

    (let ((results (claude-orgmode-search-by-tag "python")))
      (expect (length results) :to-equal 1)))

  (it "lists all tags through backend dispatch"
    (claude-orgmode--backend-create-note "Note 1" :tags '("alpha" "beta"))
    (claude-orgmode--backend-create-note "Note 2" :tags '("beta" "gamma"))

    (let ((tags (claude-orgmode-list-all-tags)))
      (expect tags :to-contain "alpha")
      (expect tags :to-contain "beta")
      (expect tags :to-contain "gamma")))

  (it "adds and removes tags through backend dispatch"
    (claude-orgmode--backend-create-note "Tag Note" :tags '("original"))
    (let ((note (claude-orgmode--backend-node-from-title "Tag Note")))
      ;; Add tag
      (claude-orgmode--backend-add-tag note "added")
      (let ((updated (claude-orgmode--backend-node-from-id
                      (claude-orgmode--backend-node-id note))))
        (expect (claude-orgmode--backend-node-tags updated)
                :to-contain "added"))

      ;; Remove tag
      (claude-orgmode--backend-remove-tag note "original")
      (let ((updated (claude-orgmode--backend-node-from-id
                      (claude-orgmode--backend-node-id note))))
        (expect (claude-orgmode--backend-node-tags updated)
                :not :to-contain "original"))))

  (it "node accessors work through backend dispatch"
    (claude-orgmode--backend-create-note "Accessor Test"
                                          :tags '("tag1")
                                          :content "test body")
    (let ((node (claude-orgmode--backend-node-from-title "Accessor Test")))
      (expect node :not :to-be nil)
      (expect (claude-orgmode--backend-node-title node) :to-equal "Accessor Test")
      (expect (claude-orgmode--backend-node-id node) :to-match "^vulpea-")
      (expect (claude-orgmode--backend-node-file node) :to-match "\\.org$")
      (expect (claude-orgmode--backend-node-tags node) :to-contain "tag1")
      (expect (claude-orgmode--backend-node-level node) :to-equal 0)))

  (it "graph stats work with vulpea backend"
    (claude-orgmode--backend-create-note "Graph A" :tags '("test"))
    (claude-orgmode--backend-create-note "Graph B" :tags '("test" "extra"))

    (let ((stats (claude-orgmode-get-graph-stats)))
      (expect (plist-get stats :total-notes) :to-equal 2)
      (expect (plist-get stats :unique-tags) :to-be-greater-than 0)))

  (it "find-orphan-notes works with vulpea backend"
    (claude-orgmode--backend-create-note "Orphan A" :tags '("test"))
    (claude-orgmode--backend-create-note "Orphan B" :tags '("test"))

    ;; All notes are orphans (no links in mocked environment)
    (let ((orphans (claude-orgmode-find-orphan-notes)))
      (expect (length orphans) :to-equal 2))))

(provide 'claude-orgmode-plugin-test)
;;; claude-orgmode-plugin-test.el ends here
