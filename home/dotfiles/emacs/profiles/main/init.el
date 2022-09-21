;; load path
(add-to-list 'load-path "~/.emacs.d/lisp/")
(let ((default-directory  "~/.emacs.d/lisp/"))
  (normal-top-level-add-subdirs-to-load-path))

;; setup straight.el package manager
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; package management utils
(straight-use-package 'use-package)
(use-package use-package-ensure-system-package :straight t)
(use-package straight :custom (straight-use-package-by-default t))

;; load org and configuration
(straight-use-package
  '(org :host github :repo "emacs-straight/org-mode" :local-repo "org"))

(run-with-idle-timer 1 nil (lambda () 
                             (require 'org)
                             (org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
                             ))
