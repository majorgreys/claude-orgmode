;;; org-roam-skill.el --- Claude Code skill for org-roam note management -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Tahir Butt
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.2") (org-roam "2.0.0"))
;; Keywords: outlines convenience
;; URL: https://github.com/majorgreys/org-roam-skill

;;; Commentary:

;; This package provides functions for programmatic org-roam note management,
;; designed to work with Claude Code via emacsclient.
;;
;; Key features:
;; - Create notes with automatic template detection
;; - Search and query notes
;; - Manage backlinks and connections
;; - Tag management
;; - File attachments via org-attach
;; - Diagnostic tools
;;
;; Usage:
;; Add to your Emacs configuration:
;;   (require 'org-roam-skill)
;;
;; Then use emacsclient to call functions:
;;   emacsclient --eval "(org-roam-skill-create-note \"Title\" '(\"tag\"))"

;;; Code:

(require 'org-roam)

;; Load all modules
(require 'org-roam-skill-core)
(require 'org-roam-skill-create)
(require 'org-roam-skill-search)
(require 'org-roam-skill-links)
(require 'org-roam-skill-tags)
(require 'org-roam-skill-attach)
(require 'org-roam-skill-utils)
(require 'org-roam-skill-doctor)

(provide 'org-roam-skill)
;;; org-roam-skill.el ends here
