;; load path
; (add-to-list 'load-path "~/.emacs.d/lisp/")
; (let ((default-directory  "~/.emacs.d/lisp/"))
;   (normal-top-level-add-subdirs-to-load-path))

;; setup straight.el package manager
(defvar bootstrap-version)
;; Avoid straight's org override; use the bundled Org from Emacs.
(setq straight-built-in-pseudo-packages '(emacs nadvice python image-mode org))
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; package management utils
(straight-use-package 'use-package)
; (use-package use-package-ensure-system-package :straight t)
(use-package straight :custom (straight-use-package-by-default t))

;; Load configuration from org first; fall back to tangled elisp on failure.
(defun lib/load-main-config ()
  (let* ((config-org (expand-file-name "config.org" user-emacs-directory))
         (config-el (expand-file-name "config.el" user-emacs-directory)))
    (cond
     ;; Fast/stable path: use tangled file when it is up to date.
     ((and (file-exists-p config-el)
           (or (not (file-exists-p config-org))
               (not (file-newer-than-file-p config-org config-el))))
      (load config-el nil 'nomessage))
     ;; If org is newer, tangle+load it; fall back to config.el on failure.
     ((file-exists-p config-org)
      (condition-case err
          (progn
            (require 'org)
            (require 'ob-tangle)
            (org-babel-load-file config-org))
        (error
         (message "Failed to load %s (%s), falling back to %s"
                  config-org
                  (error-message-string err)
                  config-el)
         (load config-el nil 'nomessage))))
     ((file-exists-p config-el)
      (load config-el nil 'nomessage))
     (t
      (message "No config found in %s (expected config.org or config.el)"
               user-emacs-directory)))))

(run-with-idle-timer 1 nil #'lib/load-main-config)
