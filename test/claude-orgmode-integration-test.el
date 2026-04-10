;;; claude-orgmode-integration-test.el --- Integration tests for claude-orgmode -*- lexical-binding: t; -*-

;;; Commentary:
;; Integration tests for claude-orgmode that test complete workflows using Buttercup

;;; Code:

(require 'buttercup)
(require 'claude-orgmode)
(require 'test-helper)

;;; Integration Test Suite with Shared Setup/Teardown

(describe "claude-orgmode integration tests"

  (before-each
    (claude-orgmode-test--setup))

  (after-each
    (claude-orgmode-test--teardown))

  ;;; Note Creation Tests

  (describe "create-org-roam-note"
    (it "creates a basic note"
      (let ((file-path (claude-orgmode-create-note "Test Note" :tags '("test" "integration"))))
        (expect (file-exists-p file-path) :to-be-truthy)
        (expect (claude-orgmode-test--node-exists-p "Test Note") :to-be-truthy)
        (expect (claude-orgmode-test--count-nodes) :to-equal 1)
        ;; Check file content
        (let ((content (claude-orgmode-test--get-note-content file-path)))
          (expect (string-match-p ":ID:" content) :to-be-truthy)
          (expect (string-match-p "#\\+title: Test Note" content) :to-be-truthy)
          (expect (string-match-p ":test:integration:" content) :to-be-truthy))))

    (it "creates a note with content"
      (let ((file-path (claude-orgmode-create-note "Test Note" :tags '("test") :content "Some content here")))
        (expect (file-exists-p file-path) :to-be-truthy)
        (let ((content (claude-orgmode-test--get-note-content file-path)))
          (expect content :to-match "Some content here"))))

    (it "sanitizes tags with hyphens"
      (let ((file-path (claude-orgmode-create-note "Test Note" :tags '("my-tag" "another-tag"))))
        (let ((content (claude-orgmode-test--get-note-content file-path)))
          (expect (string-match-p ":my_tag:another_tag:" content) :to-be-truthy)
          (expect (string-match-p "my-tag" content) :not :to-be-truthy)))))

  ;;; Search Tests

  (describe "search-notes-by-title"
    (it "finds notes by title"
      (claude-orgmode-create-note "First Note" :tags '("test"))
      (claude-orgmode-create-note "Second Note" :tags '("test"))
      (claude-orgmode-create-note "Another Topic" :tags '("other"))
      (let ((results (claude-orgmode-search-by-title "Note")))
        (expect (length results) :to-equal 2))))

  (describe "search-notes-by-tag"
    (it "finds notes by tag"
      (claude-orgmode-create-note "Note 1" :tags '("test" "project"))
      (claude-orgmode-create-note "Note 2" :tags '("test"))
      (claude-orgmode-create-note "Note 3" :tags '("other"))
      (let ((results (claude-orgmode-search-by-tag "test")))
        (expect (length results) :to-equal 2))))

  (describe "get-node-by-title"
    (it "retrieves node by exact title"
      (claude-orgmode-create-note "Exact Match" :tags '("test"))
      (let ((node (claude-orgmode-get-node-by-title "Exact Match")))
        (expect node :not :to-be nil)
        (expect (plist-get node :title) :to-equal "Exact Match"))))

  (describe "search for nonexistent note"
    (it "returns empty results"
      (claude-orgmode-create-note "Existing Note" :tags '("test"))
      (let ((results (claude-orgmode-search-by-title "Nonexistent")))
        (expect results :to-equal nil))))

  ;;; Link Tests

  (describe "create-bidirectional-link"
    (it "creates links between notes"
      (claude-orgmode-create-note "Source Note" :tags '("test"))
      (claude-orgmode-create-note "Target Note" :tags '("test"))
      (claude-orgmode-create-bidirectional-link "Source Note" "Target Note")
      ;; Sync database to register the link
      (claude-orgmode--backend-db-sync)
      (let ((backlinks (claude-orgmode-get-backlinks-by-title "Target Note")))
        (expect (>= (length backlinks) 1) :to-be-truthy))))

  (describe "get-forward-links"
    (it "retrieves forward links"
      (claude-orgmode-create-note "Source" :tags '("test"))
      (claude-orgmode-create-note "Target" :tags '("test"))
      (claude-orgmode-create-bidirectional-link "Source" "Target")
      (let ((links (claude-orgmode-get-forward-links-by-title "Source")))
        (expect links :not :to-be nil))))

  (describe "backlinks for nonexistent note"
    (it "returns empty list"
      (let ((backlinks (claude-orgmode-get-backlinks-by-title "Nonexistent")))
        (expect backlinks :to-equal nil))))

  ;;; Tag Management Tests

  (describe "list-all-tags"
    (it "lists all unique tags"
      (claude-orgmode-create-note "Note 1" :tags '("tag1" "tag2"))
      (claude-orgmode-create-note "Note 2" :tags '("tag2" "tag3"))
      (let ((tags (claude-orgmode-list-all-tags)))
        (expect (>= (length tags) 3) :to-be-truthy))))

  (describe "count-notes-by-tag"
    (it "counts notes with specific tag"
      (claude-orgmode-create-note "Note 1" :tags '("test"))
      (claude-orgmode-create-note "Note 2" :tags '("test" "other"))
      (claude-orgmode-create-note "Note 3" :tags '("other"))
      (let ((counts (claude-orgmode-count-notes-by-tag)))
        (expect (assoc "test" counts) :not :to-be nil)
        (expect (cdr (assoc "test" counts)) :to-equal 2))))

  (describe "add-tag-to-note"
    (it "adds tag to existing note"
      (let ((file-path (claude-orgmode-create-note "Test Note" :tags '("initial"))))
        (claude-orgmode-add-tag "Test Note" "added")
        (let ((content (claude-orgmode-test--get-note-content file-path)))
          (expect content :to-match ":added:")))))

  (describe "get-notes-without-tags"
    (it "finds untagged notes"
      (claude-orgmode-create-note "Tagged Note" :tags '("tag"))
      (claude-orgmode-create-note "Untagged Note")
      (let ((results (claude-orgmode-get-notes-without-tags)))
        (expect (length results) :to-equal 1))))

  ;;; Utility Function Tests

  (describe "find-orphan-notes"
    (it "finds notes without links"
      (claude-orgmode-create-note "Connected" :tags '("test"))
      (claude-orgmode-create-note "Orphan" :tags '("test"))
      (claude-orgmode-create-note "Another Connected" :tags '("test"))
      (claude-orgmode-create-bidirectional-link "Connected" "Another Connected")
      (let ((orphans (claude-orgmode-find-orphan-notes)))
        (expect (>= (length orphans) 1) :to-be-truthy))))

  (describe "list-recent-notes"
    (it "lists recently created notes"
      (claude-orgmode-create-note "Note 1" :tags '("test"))
      (claude-orgmode-create-note "Note 2" :tags '("test"))
      (claude-orgmode-create-note "Note 3" :tags '("test"))
      (let ((recent (claude-orgmode-list-recent-notes 2)))
        (expect (length recent) :to-equal 2))))

  (describe "get-graph-stats"
    (it "returns graph statistics"
      (claude-orgmode-create-note "Note 1" :tags '("test"))
      (claude-orgmode-create-note "Note 2" :tags '("test"))
      (claude-orgmode-create-bidirectional-link "Note 1" "Note 2")
      (let ((stats (claude-orgmode-get-graph-stats)))
        (expect stats :not :to-be nil)
        (expect (plist-get stats :total-notes) :to-equal 2))))

  ;;; Edge Cases

  (describe "empty database"
    (it "handles empty database gracefully"
      (expect (claude-orgmode-test--count-nodes) :to-equal 0)
      (expect (claude-orgmode-list-all-tags) :to-equal nil)
      (expect (claude-orgmode-search-by-title "anything") :to-equal nil)))

  ;;; Section Editing Tests

  (describe "get-section-content"
    (it "returns preamble for file-level node"
      (let ((test-file (expand-file-name "preamble-test.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       preamble-node-id\n:END:\n")
          (insert "#+TITLE: Preamble Test\n")
          (insert "#+FILETAGS: :test:\n")
          (insert "\nThis is preamble text.\nSecond line.\n")
          (insert "\n* First Heading\nHeading content.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((content (claude-orgmode-get-section-content "preamble-node-id")))
          (expect content :to-match "This is preamble text.")
          (expect content :to-match "Second line.")
          (expect content :not :to-match "First Heading")
          (expect content :not :to-match "TITLE"))))

    (it "returns empty string for file-level node with no preamble"
      (let ((test-file (expand-file-name "no-preamble.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       no-preamble-id\n:END:\n")
          (insert "#+TITLE: No Preamble\n")
          (insert "\n* First Heading\nContent.\n"))
        (claude-orgmode--backend-db-sync)
        (expect (claude-orgmode-get-section-content "no-preamble-id")
                :to-equal "")))

    (it "returns heading body for heading-level node"
      (let ((test-file (expand-file-name "heading-test.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       file-id\n:END:\n")
          (insert "#+TITLE: Heading Test\n\n")
          (insert "* Section One\n")
          (insert ":PROPERTIES:\n:ID:       section-one-id\n:END:\n")
          (insert "Body of section one.\n\n")
          (insert "* Section Two\n")
          (insert ":PROPERTIES:\n:ID:       section-two-id\n:END:\n")
          (insert "Body of section two.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((content (claude-orgmode-get-section-content "section-one-id")))
          (expect content :to-match "Body of section one.")
          (expect content :not :to-match "Section Two"))))

    (it "returns empty string for heading-level node with no body"
      (let ((test-file (expand-file-name "empty-heading.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       eh-file-id\n:END:\n")
          (insert "#+TITLE: Empty Heading Test\n\n")
          (insert "* Empty Section\n")
          (insert ":PROPERTIES:\n:ID:       eh-empty-id\n:END:\n")
          (insert "* Next Section\n")
          (insert ":PROPERTIES:\n:ID:       eh-next-id\n:END:\n")
          (insert "Next body.\n"))
        (claude-orgmode--backend-db-sync)
        (expect (claude-orgmode-get-section-content "eh-empty-id")
                :to-equal "")))

    (it "excludes child heading content"
      (let ((test-file (expand-file-name "nested-test.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       nested-file-id\n:END:\n")
          (insert "#+TITLE: Nested Test\n\n")
          (insert "* Parent\n")
          (insert ":PROPERTIES:\n:ID:       parent-id\n:END:\n")
          (insert "Parent body text.\n\n")
          (insert "** Child\n")
          (insert ":PROPERTIES:\n:ID:       child-id\n:END:\n")
          (insert "Child body text.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((content (claude-orgmode-get-section-content "parent-id")))
          (expect content :to-match "Parent body text.")
          (expect content :not :to-match "Child body text."))))

    (it "errors for nonexistent node ID"
      (expect (claude-orgmode-get-section-content "nonexistent-id")
              :to-throw 'error)))

  ;;; Section Creation Tests

  (describe "create-section"
    (it "creates a heading under a file-level node"
      (let ((test-file (expand-file-name "create-section-file.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       cs-file-id\n:END:\n")
          (insert "#+TITLE: Create Section Test\n"))
        (claude-orgmode--backend-db-sync)
        (let ((new-id (claude-orgmode-create-section "cs-file-id" "New Section"
                                                      :content "Section body.")))
          (expect new-id :not :to-be nil)
          (expect (stringp new-id) :to-be t)
          ;; Verify the heading was created
          (let ((content (claude-orgmode-test--get-note-content test-file)))
            (expect content :to-match "^\\* New Section")
            (expect content :to-match "Section body.")
            (expect content :to-match (regexp-quote new-id))))))

    (it "creates heading at correct level under a heading node"
      (let ((test-file (expand-file-name "create-section-nested.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       cs-nested-file-id\n:END:\n")
          (insert "#+TITLE: Nested Create Test\n\n")
          (insert "* Parent\n")
          (insert ":PROPERTIES:\n:ID:       cs-parent-id\n:END:\n")
          (insert "Parent body.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((new-id (claude-orgmode-create-section "cs-parent-id" "Child Section"
                                                      :content "Child body.")))
          (let ((content (claude-orgmode-test--get-note-content test-file)))
            (expect content :to-match "^\\*\\* Child Section")
            (expect content :to-match "Child body.")))))

    (it "errors on duplicate heading"
      (let ((test-file (expand-file-name "create-section-dup.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       cs-dup-file-id\n:END:\n")
          (insert "#+TITLE: Duplicate Test\n\n")
          (insert "* Existing\n")
          (insert ":PROPERTIES:\n:ID:       cs-existing-id\n:END:\n")
          (insert "Body.\n"))
        (claude-orgmode--backend-db-sync)
        (expect (claude-orgmode-create-section "cs-dup-file-id" "Existing")
                :to-throw 'error)))

    (it "creates section with content from file"
      (let ((test-file (expand-file-name "create-section-cfile.org"
                                          org-roam-directory))
            (content-file (make-temp-file "section-content-" nil ".org")))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       cs-cfile-id\n:END:\n")
          (insert "#+TITLE: Content File Test\n"))
        (with-temp-file content-file
          (insert "Content from temp file."))
        (claude-orgmode--backend-db-sync)
        (claude-orgmode-create-section "cs-cfile-id" "From File"
                                        :content-file content-file)
        (let ((content (claude-orgmode-test--get-note-content test-file)))
          (expect content :to-match "Content from temp file."))
        ;; Temp file should be auto-deleted
        (expect (file-exists-p content-file) :not :to-be-truthy))))

  ;;; Section Replace Tests

  (describe "replace-section"
    (it "replaces heading body content"
      (let ((test-file (expand-file-name "replace-heading.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       rs-file-id\n:END:\n")
          (insert "#+TITLE: Replace Test\n\n")
          (insert "* Section\n")
          (insert ":PROPERTIES:\n:ID:       rs-section-id\n:END:\n")
          (insert "Old content.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((result (claude-orgmode-replace-section "rs-section-id"
                                                       :content "New content.")))
          (expect result :to-equal "rs-section-id")
          (let ((content (claude-orgmode-test--get-note-content test-file)))
            (expect content :to-match "New content.")
            (expect content :not :to-match "Old content.")))))

    (it "replaces file-level preamble"
      (let ((test-file (expand-file-name "replace-preamble.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       rs-preamble-id\n:END:\n")
          (insert "#+TITLE: Preamble Replace\n\n")
          (insert "Old preamble.\n\n")
          (insert "* Heading\nHeading content.\n"))
        (claude-orgmode--backend-db-sync)
        (claude-orgmode-replace-section "rs-preamble-id" :content "New preamble.")
        (let ((content (claude-orgmode-test--get-note-content test-file)))
          (expect content :to-match "New preamble.")
          (expect content :not :to-match "Old preamble.")
          ;; Heading should be preserved
          (expect content :to-match "Heading content."))))

    (it "preserves child headings"
      (let ((test-file (expand-file-name "replace-preserve.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       rp-file-id\n:END:\n")
          (insert "#+TITLE: Preserve Test\n\n")
          (insert "* Parent\n")
          (insert ":PROPERTIES:\n:ID:       rp-parent-id\n:END:\n")
          (insert "Old parent body.\n\n")
          (insert "** Child\n")
          (insert ":PROPERTIES:\n:ID:       rp-child-id\n:END:\n")
          (insert "Child content.\n"))
        (claude-orgmode--backend-db-sync)
        (claude-orgmode-replace-section "rp-parent-id" :content "New parent body.")
        (let ((content (claude-orgmode-test--get-note-content test-file)))
          (expect content :to-match "New parent body.")
          (expect content :not :to-match "Old parent body.")
          ;; Child must be preserved
          (expect content :to-match "Child content."))))

  ;;; Section Append Tests

  (describe "append-to-section"
    (it "appends to heading body"
      (let ((test-file (expand-file-name "append-heading.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       as-file-id\n:END:\n")
          (insert "#+TITLE: Append Test\n\n")
          (insert "* Section\n")
          (insert ":PROPERTIES:\n:ID:       as-section-id\n:END:\n")
          (insert "Existing content.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((result (claude-orgmode-append-to-section "as-section-id"
                                                         :content "Appended text.")))
          (expect result :to-equal "as-section-id")
          (let ((content (claude-orgmode-test--get-note-content test-file)))
            (expect content :to-match "Existing content.")
            (expect content :to-match "Appended text.")))))

    (it "appends before child headings"
      (let ((test-file (expand-file-name "append-before-child.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       abc-file-id\n:END:\n")
          (insert "#+TITLE: Append Before Child\n\n")
          (insert "* Parent\n")
          (insert ":PROPERTIES:\n:ID:       abc-parent-id\n:END:\n")
          (insert "Parent body.\n\n")
          (insert "** Child\n")
          (insert ":PROPERTIES:\n:ID:       abc-child-id\n:END:\n")
          (insert "Child body.\n"))
        (claude-orgmode--backend-db-sync)
        (claude-orgmode-append-to-section "abc-parent-id"
                                           :content "Appended to parent.")
        (let ((content (claude-orgmode-test--get-note-content test-file)))
          (expect content :to-match "Parent body.")
          (expect content :to-match "Appended to parent.")
          ;; Appended text should appear before child heading
          (let ((append-pos (string-match "Appended to parent" content))
                (child-pos (string-match "\\*\\* Child" content)))
            (expect (< append-pos child-pos) :to-be t)))))

    (it "appends to empty section"
      (let ((test-file (expand-file-name "append-empty.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       ae-file-id\n:END:\n")
          (insert "#+TITLE: Append Empty\n\n")
          (insert "* Empty Section\n")
          (insert ":PROPERTIES:\n:ID:       ae-section-id\n:END:\n")
          (insert "* Next Section\n")
          (insert ":PROPERTIES:\n:ID:       ae-next-id\n:END:\n")
          (insert "Next body.\n"))
        (claude-orgmode--backend-db-sync)
        (claude-orgmode-append-to-section "ae-section-id"
                                           :content "Now has content.")
        (let ((content (claude-orgmode-test--get-note-content test-file)))
          (expect content :to-match "Now has content.")
          ;; Content should be under Empty Section, not Next Section
          (let ((new-pos (string-match "Now has content" content))
                (next-pos (string-match "\\* Next Section" content)))
            (expect (< new-pos next-pos) :to-be t)))))))

  ;;; Section Delete Tests

  (describe "delete-section"
    (it "deletes a heading and its subtree"
      (let ((test-file (expand-file-name "delete-section.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       ds-file-id\n:END:\n")
          (insert "#+TITLE: Delete Test\n\n")
          (insert "* Keep This\n")
          (insert ":PROPERTIES:\n:ID:       ds-keep-id\n:END:\n")
          (insert "Keep body.\n\n")
          (insert "* Delete This\n")
          (insert ":PROPERTIES:\n:ID:       ds-delete-id\n:END:\n")
          (insert "Delete body.\n\n")
          (insert "** Delete Child\n")
          (insert ":PROPERTIES:\n:ID:       ds-child-id\n:END:\n")
          (insert "Child body.\n\n")
          (insert "* Also Keep\n")
          (insert ":PROPERTIES:\n:ID:       ds-also-keep-id\n:END:\n")
          (insert "Also keep body.\n"))
        (claude-orgmode--backend-db-sync)
        (let ((result (claude-orgmode-delete-section "ds-delete-id")))
          (expect result :to-equal "ds-delete-id")
          (let ((content (claude-orgmode-test--get-note-content test-file)))
            (expect content :to-match "Keep body.")
            (expect content :to-match "Also keep body.")
            (expect content :not :to-match "Delete body.")
            (expect content :not :to-match "Child body.")
            (expect content :not :to-match "Delete This")))))

    (it "errors when trying to delete a file-level node"
      (let ((test-file (expand-file-name "delete-file-level.org"
                                          org-roam-directory)))
        (with-temp-file test-file
          (insert ":PROPERTIES:\n:ID:       ds-file-level-id\n:END:\n")
          (insert "#+TITLE: File Level Delete\n"))
        (claude-orgmode--backend-db-sync)
        (expect (claude-orgmode-delete-section "ds-file-level-id")
                :to-throw 'error)))

    (it "errors for nonexistent node ID"
      (expect (claude-orgmode-delete-section "ds-nonexistent-id")
              :to-throw 'error))))

(provide 'claude-orgmode-integration-test)
;;; claude-orgmode-integration-test.el ends here
