;; performance
(defvar cpm--file-name-handler-alist file-name-handler-alist)
(defvar default-file-name-handler-alist file-name-handler-alist)
(setq-default frame-title-format nil)
(setq-default frame-inhibit-implied-resize t)
(setq-default inhibit-startup-screen t)
(setq-default inhibit-splash-screen t)
(setq-default inhibit-startup-message t)
(setq file-name-handler-alist nil)
(setq frame-inhibit-implied-resize t)
(setq desktop-restore-forces-onscreen nil)
(setq inhibit-compacting-font-caches t)
(setq load-prefer-newer t)
(setq file-name-handler-alist nil)

;; disable garbage collection during load
; (lexical-let ((old-gc-treshold gc-cons-threshold))
;   (setq gc-cons-threshold most-positive-fixnum)
;   (add-hook 'after-init-hook
;             (lambda () (setq gc-cons-threshold old-gc-treshold))))

(setq initial-scratch-message nil)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(advice-add #'x-apply-session-resources :override #'ignore)

;; disable package.el
(setq package-enable-at-startup nil)
