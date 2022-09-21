;;; init.el -*- lexical-binding: t ; eval: (view-mode -1); -*-

;; security
(setq gnutls-verify-error (getenv "INSECURE")
      tls-checktrust gnutls-verify-error
      tls-program '("gnutls-cli --x509cafile %t -p %p %h"
                    ;; compatibility fallbacks
                    "gnutls-cli -p %p %h"
                    "openssl s_client -connect %h:%p -no_ssl2 -no_ssl3 -ign_eof"))

;; package management
(setq package-enable-at-startup nil)
(setq-default straight-use-package-by-default t)
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
(straight-use-package 'use-package)
(use-package use-package-ensure-system-package :straight t)
(use-package straight :custom (straight-use-package-by-default t))

;; set custom file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(if (file-exists-p custom-file) (load custom-file))

(straight-use-package
  '(org :host github :repo "emacs-straight/org-mode" :local-repo "org"))
(run-with-idle-timer 1 nil (lambda () 
                             (require 'org)
                             (org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
                             ))
