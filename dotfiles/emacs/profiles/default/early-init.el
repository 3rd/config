;;; early-init.el -*- lexical-binding: t; no-byte-compile: t -*-
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(setq package-enable-at-startup nil)
(setq package-quickstart nil)

(setq frame-inhibit-implied-resize t)
(setq inhibit-splash-screen t)
(setq use-file-dialog nil)

(setq comp-deferred-compilation nil)
