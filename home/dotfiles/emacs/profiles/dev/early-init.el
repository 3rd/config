;;; early-init.el -*- lexical-binding: t; eval: (view-mode -1); -*-

;; gc defer
(setq gc-cons-threshold most-positive-fixnum)

;; package management
(setq package-enable-at-startup nil)
(advice-add #'package--ensure-init-file :override #'ignore)

;; ui: disable elements
(setq tool-bar-mode nil
      menu-bar-mode nil)
(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode nil))

;; ui: disable frame resize
(setq frame-inhibit-implied-resize t)

;; ignore X resources
(advice-add #'x-apply-session-resources :override #'ignore)
