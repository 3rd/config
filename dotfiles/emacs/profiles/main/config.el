(use-package no-littering
  :straight t
  :init
  ;; Keep Chemacs profile directory stable; don't rewrite `user-emacs-directory`.
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  :config
  (setq url-history-file (no-littering-expand-var-file-name "url/history"))
  (when (file-exists-p custom-file)
    (load custom-file nil 'nomessage)))

(add-hook
 'emacs-startup-hook
 (lambda ()
   (message
    "*** Emacs loaded in %s with %d garbage collections."
    (format "%.2f seconds" (float-time
                            (time-subtract after-init-time before-init-time)))
    gcs-done)))

;; (use-package undo-fu)
(use-package evil
  :straight t
  :init
  ;; (setq evil-undo-system 'undo-fu)
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  ;; Free TAB/C-i for local bindings (e.g., Org)
  (setq evil-want-C-i-jump nil)
  (setq evil-want-C-u-delete t)
  (setq evil-want-C-w-delete t)
  (setq evil-want-Y-yank-to-eol t)
  ;; Latency-first cursor motion.
  (setq evil-respect-visual-line-mode nil)
  (setq evil-undo-system 'undo-tree)
  (setq evil-search-module 'evil-search)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  :config
  (evil-mode 1)
  ;; Keep j/k on optimized logical-line motion.
  (evil-global-set-key 'motion "j" 'evil-next-line)
  (evil-global-set-key 'motion "k" 'evil-previous-line)
  ;; Explicit visual-line traversal when needed.
  (evil-global-set-key 'motion "gj" 'evil-next-visual-line)
  (evil-global-set-key 'motion "gk" 'evil-previous-visual-line)
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dashboard-mode 'normal))

(use-package general
  :straight t
  :config
  (general-evil-setup t))

(general-create-definer lib/mapleader
  :keymaps 'override
  :prefix "SPC"
  :states '(normal motion emacs))

(general-create-definer nmap
  :keymaps 'override
  :states '(normal motion emacs))

(general-create-definer imap
  :keymaps 'override
  :states '(insert))

;; emacs
(global-set-key (kbd "C-SPC") nil)

;; evil
(with-eval-after-load 'evil-maps
  ;; remove default mappings
  (define-key evil-normal-state-map (kbd "DEL") nil)
  (define-key evil-normal-state-map (kbd "<C-return>") nil)
  (define-key evil-normal-state-map (kbd "\C-p") nil)
  (define-key evil-normal-state-map (kbd "\C-w") nil)
  (define-key evil-insert-state-map (kbd "\C-w") nil)
  (define-key evil-motion-state-map (kbd "RET") nil)
  (define-key evil-motion-state-map (kbd "\C-f") nil)
  (define-key evil-motion-state-map (kbd "-") nil)
  (define-key evil-motion-state-map (kbd ";") nil)
  (define-key evil-motion-state-map (kbd "\C-w") nil)
  (define-key evil-emacs-state-map (kbd "\C-w") nil)
  ;; free TAB/C-i in normal/motion so org can use them
  (define-key evil-normal-state-map (kbd "TAB") nil)
  (define-key evil-motion-state-map (kbd "TAB") nil)
  (define-key evil-normal-state-map (kbd "<tab>") nil)
  (define-key evil-motion-state-map (kbd "<tab>") nil)
  (define-key evil-normal-state-map (kbd "C-i") nil)
  (define-key evil-motion-state-map (kbd "C-i") nil)
  ;; fix tab
  (define-key evil-insert-state-map (kbd "TAB") 'tab-to-tab-stop)
  )

(global-set-key (kbd "C-?") 'help-command)
(global-set-key (kbd "C-M-?") 'help-command)

(general-def
  :keymaps 'universal-argument-map
  "M-u" 'universal-argument-more)
(general-def
  :keymaps 'override
  :states '(normal motion emacs insert visual)
  "M-u" 'universal-argument)

(setq make-backup-files nil)
(setq auto-save-default nil)
(setq create-lockfiles nil)
(setq backup-inhibited t)

(setq scroll-conservatively 101)
(setq scroll-step 1)
(setq scroll-preserve-screen-position t)
(setq scroll-error-top-bottom t)

(setq mouse-wheel-scroll-amount '(1 ((shift) . 1)))
(setq mouse-wheel-progressive-speed nil)
(setq mouse-wheel-follow-mouse 't)

(setq tab-always-indent nil)
(setq-default default-tab-width 2)
(setq-default tab-width 2)
(setq-default indent-tabs-mode nil)

(setq-default evil-shift-width tab-width)
(setq-default evil-indent-convert-tabs nil)
(setq-default evil-shift-round nil)

(setq warning-minimum-level :warning)
(setq enable-recursive-minibuffers t)
(normal-erase-is-backspace-mode 1)
(setq visible-bell nil)
(setq use-dialog-box nil)
(setq large-file-warning-threshold nil)
(setq vc-follow-symlinks t)
(setq ad-redefinition-action 'accept)
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)
(defalias 'yes-or-no-p 'y-or-n-p)
(setq save-interprogram-paste-before-kill t)
(setq confirm-nonexistent-file-or-buffer nil)
(setq revert-without-query '(".*"))
(setq-default bidi-display-reordering nil)
;; Cursor-motion/scroll performance on wrapped lines.
(setq-default line-move-visual nil)
(setq auto-window-vscroll nil)
(setq fast-but-imprecise-scrolling t)
;; Avoid decoration "twitch" while moving point in heavily styled buffers.
(setq redisplay-skip-fontification-on-input nil)
(setq bidi-inhibit-bpa t)
;; Keep motion responsive while fontification catches up in idle time.
(setq jit-lock-defer-time 0.05)
(setq jit-lock-stealth-time 1.0)
(global-so-long-mode 1)
(setq async-shell-command-buffer 'new-buffer)
(setq shell-command-switch "-ic")
(global-unset-key [(control z)])
(global-unset-key [(control x)(control z)])
(set-frame-parameter (selected-frame) 'fullscreen 'maximized)
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq x-underline-at-descent-line t)

(defun lib/log (string)
  "Print out STRING and calculate length of init."
  (message string)
  (if (not (string= "end" (substring string -3)))
      (setq my/init-audit-message-begin (current-time))
    (message
     "%s seconds"
     (time-to-seconds
      (time-subtract
       (current-time)
       my/init-audit-message-begin))))
  nil)

(defun my/performance-mode-buffer ()
  "Disable expensive visual/runtime features in the current buffer."
  (interactive)
  (setq-local line-move-visual nil)
  (setq-local truncate-lines t)
  (when (bound-and-true-p visual-line-mode) (visual-line-mode -1))
  (when (bound-and-true-p variable-pitch-mode) (variable-pitch-mode -1))
  (when (bound-and-true-p org-indent-mode) (org-indent-mode -1))
  (when (bound-and-true-p org-appear-mode) (org-appear-mode -1))
  (when (bound-and-true-p hl-line-mode) (hl-line-mode -1))
  (when (bound-and-true-p lsp-ui-mode) (lsp-ui-mode -1))
  (message "Performance mode enabled for buffer: %s" (buffer-name)))

(cd "~/brain/wiki")

(use-package alert
  :straight t
  :commands alert
  :config
  (setq alert-default-style 'notifications))

(use-package all-the-icons
  :straight t
  :if (display-graphic-p))
(use-package nerd-icons)

(use-package company
  :straight t
  :init
  (global-company-mode)

  :config
  (setq company-global-modes '(not eshell-mode gud-mode))
  (setq company-minimum-prefix-length 1)
  (setq company-idle-delay 0.08)
  (setq company-require-match nil)
  (setq company-dabbrev-ignore-case nil)
  (setq company-dabbrev-downcase nil)
  (setq company-selection-wrap-around t)
  (setq company-tooltip-align-annotations t)
  (setq company-tooltip-flip-when-above t)
  (setq company-tooltip-limit 20)
  ;; `company-lsp` is deprecated; CAPF is the supported completion path.
  (unless (member 'company-capf company-backends)
    (add-to-list 'company-backends 'company-capf))
  (company-tng-configure-default))

(use-package company-flx
  :straight t
  :after company
  :init
  (company-flx-mode)

  :config
  (setq company-flx-limit 100))

(use-package company-box
  :straight t
  :hook (company-mode . company-box-mode))

(use-package company-org-block
  :straight t
  :custom
  (company-org-block-edit-style 'inline)
  :hook ((org-mode . (lambda ()
                       (setq-local company-backends '(company-org-block))
                       (company-mode +1)))))

(use-package consult
  :straight t
  :demand t
  ;; :bind (("C-s" . consult-line)
  ;;        ("C-M-l" . consult-imenu)
  ;;        ("C-M-j" . persp-switch-to-buffer*)
  ;;        :map minibuffer-local-map
  ;;        ("C-r" . consult-history))
  :custom
  (completion-in-region-function #'consult-completion-in-region)
  (consult-fontify-preserve nil)
  (consult-async-min-input 0)
  (consult-async-refresh-delay 0.1)
  (consult-async-input-throttle 0.1)
  (consult-async-input-debounce 0.1))

;; Used to prioritize commonly used counsel-M-x commands
(use-package amx
  :straight t)

(use-package counsel
  :straight t
  :bind (
         :map counsel-describe-map
         ("M-." . counsel-find-symbol)
         :map ivy-minibuffer-map
         )
  :init
  (require 'amx)
  (counsel-mode)

  :config
  ;; (setq counsel-fzf-cmd "rg --files | fzf -f \"%s\"")

  ;; ivy integration
  (with-eval-after-load 'ivy
    (add-to-list 'ivy-more-chars-alist '(counsel-rg . 0))
    (add-to-list 'ivy-more-chars-alist '(counsel-ag . 0))
    ;; remap M-x
    (global-set-key (kbd "M-x") 'counsel-M-x)))

(use-package evil-nerd-commenter
  :straight t
  :bind ("C-/" . evilnc-comment-or-uncomment-lines))

(use-package doom-themes :straight t)

(use-package evil-surround
  :straight t
  :after evil
  :config
  (global-evil-surround-mode))

(use-package flx
  :straight t
  :after ivy
  :init
  (setq ivy-flx-limit 10000))

(use-package hl-todo
  :straight t
  :hook (prog-mode . hl-todo-mode))

(use-package ivy
  :straight t
  :after counsel
  :custom
  (ivy-initial-inputs-alist nil)
  (ivy-extra-directories nil)
  (ivy-wrap t)
  (ivy-count-format "(%d/%d) ")
  ;; (ivy-use-virtual-buffers t)
  (ivy-use-selectable-prompt t)
  (ivy-height 20)
  (ivy-fixed-height-minibuffer t)
  (ivy-re-builders-alist '((t . ivy--regex-fuzzy)))
  :bind (
         :map ivy-minibuffer-map
         ("C-j" . ivy-next-line)
         ("C-k" . ivy-previous-line)
         :map ivy-switch-buffer-map
         ("C-k" . ivy-previous-line)
         ("C-d" . ivy-switch-buffer-kill)
         :map ivy-reverse-i-search-map
         ("C-k" . ivy-previous-line)
         ("C-d" . ivy-reverse-i-search-kill)
         )
  :config
  ;; close with <esc>
  (define-key ivy-minibuffer-map [escape] 'minibuffer-keyboard-quit)
  (ivy-mode 1)
  )

;; (use-package ivy-rich
;;   :straight t
;;   :after ivy
;;   :config
;;   (ivy-rich-mode 1)
;;   (setcdr (assq t ivy-format-functions-alist) #'ivy-format-function-line))
;; (use-package ivy-rich
;;   :straight t
;;   :after counsel
;;   :init
;;   (ivy-rich-mode 1)
;;   :config
;;   (setq ivy-format-function #'ivy-format-function-line)
;;   (setq ivy-rich-display-transformers-list
;;         (plist-put ivy-rich-display-transformers-list
;;                    'ivy-switch-buffer
;;                    '(:columns
;;                      ((ivy-rich-candidate (:width 40))
;;                       (ivy-rich-switch-buffer-indicators (:width 4 :face error :align right)); return the buffer indicators
;;                       (ivy-rich-switch-buffer-major-mode (:width 12 :face warning))          ; return the major mode info
;;                       (ivy-rich-switch-buffer-project (:width 15 :face success))             ; return project name using `projectile'
;;                       (ivy-rich-switch-buffer-path (:width (lambda (x) (ivy-rich-switch-buffer-shorten-path x (ivy-rich-minibuffer-width 0.3))))))  ; return file path relative to project root or `default-directory' if project is nil
;;                      :predicate
;;                      (lambda (cand)
;;                        (if-let ((buffer (get-buffer cand)))
;;                            ;; Don't mess with EXWM buffers
;;                            (with-current-buffer buffer
;;                              (not (derived-mode-p 'exwm-mode)))))))))
(use-package ivy-rich
  :straight t
  :hook ((ivy-mode counsel-mode) . ivy-rich-mode)
  :custom
  (ivy-virtual-abbreviate 'abbreviate)
  (ivy-rich-path-style 'abbrev)
  :config
  (setcdr (assq t ivy-format-functions-alist) #'ivy-format-function-line))

(use-package json-mode
  :straight t)

(use-package marginalia
  :straight t
  :custom
  (marginalia-annotators '(marginalia-annotators-heavy marginalia-annotators-light nil))
  :init
  (marginalia-mode))

(use-package neotree
  :straight t
  :config
  (setq neo-smart-open t)
  ;; (setq projectile-switch-project-action 'neotree-projectile-action)
  (setq neo-theme (if window-system 'icons 'arrows))
  (evil-define-key 'normal neotree-mode-map (kbd "RET") 'neotree-enter)
  (evil-define-key 'normal neotree-mode-map (kbd "TAB") 'neotree-quick-look)
  (evil-define-key 'normal neotree-mode-map (kbd "q") 'neotree-hide)
  (evil-define-key 'normal neotree-mode-map (kbd "C-v") 'neotree-enter-vertical-split)
  (evil-define-key 'normal neotree-mode-map (kbd "C-s") 'neotree-enter-horizontal-split)
  (evil-define-key 'normal neotree-mode-map (kbd "r") 'neotree-refresh)
  (evil-define-key 'normal neotree-mode-map (kbd "h") 'neotree-hidden-file-toggle)
  )

(nmap "-" (lambda ()
            (interactive)
            (if (eq major-mode 'neotree-mode)
                (select-window (previous-window))
              (neotree-show))
            ))

(use-package org-superstar
  :straight t
  :after org
  :hook (org-mode . org-superstar-mode)
  :custom
  (org-superstar-remove-leading-stars t)
  (org-superstar-prettify-item-bullets nil)
  (org-superstar-headline-bullets-list '("◉" "○" "●" "○" "●" "○" "●")))

(use-package paren
  :straight nil
  :config
  (set-face-attribute 'show-paren-match-expression nil :background "#363e4a")
  (show-paren-mode 1))

(use-package rainbow-delimiters
  :straight t
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package savehist
  :straight nil
  :init
  (setq history-length t)
  (setq history-delete-duplicates t)
  (savehist-mode t))

(use-package smartparens
  :straight t
  :hook (prog-mode . smartparens-mode))

(use-package which-key
  :straight t
  :config
  (setq which-key-idle-delay 0.3)
  (setq which-key-popup-type 'frame)
  (which-key-mode)
  (which-key-setup-side-window-bottom)
  (set-face-attribute 'which-key-local-map-description-face nil :weight 'bold))

(use-package undo-tree
  :straight t
  :init
  (global-undo-tree-mode 1)
  :custom
  (undo-tree-visualizer-timestamps t)
  (undo-tree-visualizer-diff t)
  :config
  )

(eval-after-load 'undo-tree
  '(progn
     (define-key undo-tree-map (kbd "C-/") nil)
     (define-key undo-tree-map (kbd "C-_") nil)
     (define-key undo-tree-map (kbd "C-?") nil)
     (define-key undo-tree-map (kbd "M-_") nil)
     (define-key undo-tree-map (kbd "C-z") 'undo-tree-undo)
     (define-key undo-tree-map (kbd "C-S-z") 'undo-tree-redo)
     )
  )

(use-package projectile
  :straight t
  :custom
  (projectile-indexing-method 'alien)
  ;; (projectile-enable-caching t)
  (projectile-completion-system 'ivy)
  (projectile-track-known-projects-automatically nil)
  (projectile-sort-order 'recentf)
  (projectile-require-project-root nil)
  (projectile-switch-project-action #'projectile-dired)
  :config
  (projectile-mode t)
  )

(use-package counsel-projectile
  :straight t
  :after projectile
  :config
  (counsel-projectile-mode))

(use-package rainbow-mode
  :straight t
  :defer t
  :hook (org-mode
         emacs-lisp-mode
         web-mode
         typescript-mode
         typescript-ts-mode
         js2-mode))

(defun -log (&rest args)
  (interactive)
  (apply #'message "%S" args)
  )

(with-eval-after-load 'doom-themes
  (setq
   doom-themes-padded-modeline 3
   doom-themes-enable-italic t
   doom-themes-enable-bold t)
  (doom-themes-neotree-config)
  (doom-themes-org-config)

  (load-theme 'doom-Iosvkem t)
  )

(use-package minions
  :straight t
  :hook (doom-modeline-mode . minions-mode))

(use-package doom-modeline
  :straight t
  :hook (after-init . doom-modeline-mode)
  :custom-face
  (mode-line ((t (:height 100))))
  (mode-line-inactive ((t (:height 100))))
  :custom
  (doom-modeline-height 15)
  (doom-modeline-bar-width 6)
  (doom-modeline-lsp t)
  (doom-modeline-github nil)
  (doom-modeline-mu4e nil)
  (doom-modeline-irc t)
  (doom-modeline-persp-name nil)
  (doom-modeline-buffer-file-name-style 'truncate-except-project)
  (doom-modeline-major-mode-icon nil)
  (doom-modeline-minor-modes nil)
  (doom-modeline-icon t)
  :config
  (line-number-mode 1)
  (column-number-mode 1)
  )

(set-face-attribute 'default nil :font "BMono" :height 100 :weight 'normal)
(set-face-attribute 'fixed-pitch nil :font "BMono" :height 94 :weight 'normal)
(set-face-attribute 'variable-pitch nil :font "Fira Sans" :height 100 :weight 'normal)

(use-package company-posframe
  :config
  (company-posframe-mode 1))

(bind-key "C-+" 'text-scale-increase)
(bind-key "C--" 'text-scale-decrease)
(bind-key "C-0" 'text-scale-adjust)

(setq inhibit-compacting-font-caches t)

(setq-default prettify-symbols-alist '(("#+BEGIN_SRC" . "*")
                                       ("#+END_SRC" . "―")
                                       ("#+begin_src" . "*")
                                       ("#+end_src" . "―")
                                       (">=" . "≥")
                                       ("=>" . "⇨")))
(setq prettify-symbols-unprettify-at-point 'right-edge)

;; Hook org-mode
(add-hook 'org-mode-hook 'prettify-symbols-mode)

(use-package olivetti
  :straight t
  :init
  (setq olivetti-body-width .8)
  :config
  (defvar my/olivetti-max-buffer-size 300000
    "Do not auto-enable Olivetti for buffers larger than this many chars.")
  (defun my/maybe-enable-olivetti ()
    "Enable `olivetti-mode' for prose buffers when affordable."
    (when (< (buffer-size) my/olivetti-max-buffer-size)
      (olivetti-mode 1)))
  (add-hook 'text-mode-hook #'my/maybe-enable-olivetti)
  )

(dolist (mode '(prog-mode-hook conf-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 1))))

(setq-default show-trailing-whitespace nil)

(defun my/maybe-enable-show-trailing-whitespace ()
  "Enable trailing whitespace highlights only where it is useful."
  (when (and (< (buffer-size) 300000)
             (derived-mode-p 'prog-mode 'conf-mode))
    (setq-local show-trailing-whitespace t)))

(add-hook 'prog-mode-hook #'my/maybe-enable-show-trailing-whitespace)
(add-hook 'conf-mode-hook #'my/maybe-enable-show-trailing-whitespace)

(require 'hl-line)
(defun my/maybe-enable-hl-line ()
  (when (< (buffer-size) 500000)
    (hl-line-mode 1)))
(add-hook 'prog-mode-hook #'my/maybe-enable-hl-line)

(defun my/org-hook ()
  (auto-fill-mode 0)
  ;; Restore Org UX defaults while keeping logical-line motion for speed.
  (variable-pitch-mode 1)
  (visual-line-mode 1)
  (org-indent-mode 1)
  (setq-local line-move-visual nil)
  (setq-local truncate-lines nil)
  (setq-local show-trailing-whitespace nil)
  ;; Let redisplay win over immediate block fontification.
  (setq-local jit-lock-defer-time 0.25)
  (setq-local jit-lock-stealth-time 1.25)
  )
(add-hook 'org-mode-hook #'my/org-hook)

;; evil-org setup
(use-package evil-org
  :straight t
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

;; custom (sane) normal mode indent and outdent
(defun my/evil-org-indent ()
  (interactive)
  (evil-org->
   (org-element-property :begin (org-element-at-point))
   (org-element-property :end (org-element-at-point)) 1)
  )
(defun my/evil-org-outdent ()
  (interactive)
  (evil-org->
   (org-element-property :begin (org-element-at-point))
   (org-element-property :end (org-element-at-point)) -1)
  )

;; evil-org hook
(defun my/evil-org-hook ()
  (nmap "d" 'evil-delete)
  (evil-define-key '(normal) 'evil-org-mode
    (kbd ">") 'my/evil-org-indent
    (kbd "<") 'my/evil-org-outdent
    ))
(add-hook 'evil-org-mode-hook #'my/evil-org-hook)

;; Modern Org cache is significantly faster for many operations.
(setq org-element-use-cache t)
(setq org-startup-indented t)
(setq org-startup-folded t)
(setq org-catch-invisible-edits 'show-and-error)
(setq org-imenu-depth 999)

(setq org-return-follows-link t)
(setq org-ellipsis " ⤵")
(setq org-hide-emphasis-markers t)
(setq org-fontify-done-headline t)
(setq org-fontify-quote-and-verse-blocks t)
(setq org-pretty-entities t)
(setq org-capture-bookmark nil)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path t)
(setq org-list-description-max-indent 5)
(setq org-adapt-indentation nil)

(setq-default org-enforce-todo-dependencies t)
(setq-default org-export-with-todo-keywords nil)

;; blocks
(setq org-hide-block-startup nil)
(setq org-src-fontify-natively t)
(setq org-src-preserve-indentation nil)
(setq org-src-window-setup 'current-window)
(setq org-src-tab-acts-natively t)
(setq org-edit-src-content-indentation 2)

;; Large embedded source blocks are a common Org performance hotspot.
;; Keep native syntax highlighting for normal blocks and degrade gracefully
;; for very large blocks to prevent cursor-motion stalls.
(defvar my/org-src-fontify-max-lines 160
  "Largest Org source block line count to natively fontify.")

(defvar my/org-src-fontify-max-chars 12000
  "Largest Org source block size (chars) to natively fontify.")

(defun my/org-src-fontify--small-enough-p (start end)
  "Return non-nil when block between START and END is cheap to fontify."
  (let ((chars (- end start)))
    (and (<= chars my/org-src-fontify-max-chars)
         (<= (count-lines start end) my/org-src-fontify-max-lines))))

(defun my/org-src-fontify-block-around (orig-fn lang start end)
  "Avoid expensive native fontification for very large Org src blocks."
  (if (my/org-src-fontify--small-enough-p start end)
      (funcall orig-fn lang start end)
    (let ((modified (buffer-modified-p))
          (src-face (nth 1 (assoc-string lang org-src-block-faces t))))
      ;; Keep block readable without a temporary major-mode fontify pass.
      (remove-text-properties start end '(face nil))
      (when (or (facep src-face) (listp src-face))
        (font-lock-append-text-property start end 'face src-face))
      (font-lock-append-text-property start end 'face 'org-block)
      (add-text-properties
       start end
       '(font-lock-fontified t fontified t font-lock-multiline t))
      (set-buffer-modified-p modified))))

(with-eval-after-load 'org-src
  (advice-add 'org-src-font-lock-fontify-block
              :around #'my/org-src-fontify-block-around))

;; cycle
(setq org-cycle-separator-lines -1)
;; org-cycle-emulate-tab nil
;; Keep TAB local to the current heading; don't trigger global cycling
(setq org-cycle-global-at-bob nil)
(setq org-cycle-global-at-eob nil)

;; agenda
(setq calendar-week-start-day 1)

(custom-theme-set-faces
 'user
 '(org-block ((t (:inherit fixed-pitch))))
 '(org-code ((t (:inherit (shadow fixed-pitch)))))
 '(org-document-info-keyword ((t (:inherit (shadow fixed-pitch)))))
 '(org-indent ((t (:inherit (org-hide fixed-pitch)))))
 '(org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch)))))
 '(org-property-value ((t (:inherit fixed-pitch))) t)
 '(org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
 '(org-table ((t (:inherit fixed-pitch))))
 '(org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 0.8))))
 '(org-verbatim ((t (:inherit (shadow fixed-pitch))))))

(set-face-attribute 'org-document-title nil :weight 'bold :height 1.6)
(dolist (face '((org-level-1 . 1.24)
                (org-level-2 . 1.12)
                (org-level-3 . 1.06)
                (org-level-4 . 1.0)
                (org-level-5 . 1.0)
                (org-level-6 . 1.0)
                (org-level-7 . 1.0)
                (org-level-8 . 1.0)))
  (set-face-attribute (car face) nil :weight 'bold :height (cdr face)))

;; remove the background on column views
(set-face-attribute 'org-column nil :background 'unspecified)
(set-face-attribute 'org-column-title nil :background 'unspecified)

(set-fontset-font "fontset-default" nil (font-spec :name "Symbola"))

;; list markers
(font-lock-add-keywords 'org-mode
                        '(("^ *\\([-]\\) "
                           (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))
(font-lock-add-keywords 'org-mode
                        '(("^ *\\([+]\\) "
                           (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "◦"))))))

(setq org-todo-keywords '((sequence
                           "TODO"
                           "NEXT"
                           "BLOCKED"
                           "DONE"
                           )))
(setq org-todo-keyword-faces
      `(
        ("TODO" :foreground ,(doom-color 'yellow) :weight bold)
        ("NEXT" :foreground ,(doom-color 'cyan) :weight bold)
        ("BLOCKED" :foreground ,(doom-color 'red) :weight bold)
        ("DONE" :foreground ,(doom-color 'grey)  :weight bold)
        ))

(setq org-hierarchical-todo-statistics nil)

(defun my/org-checkbox-todo ()
  "Switch header TODO state to DONE when all checkboxes are ticked, to TODO otherwise"
  (let ((todo-state (org-get-todo-state)) beg end)
    (unless (not todo-state)
      (save-excursion
        (org-back-to-heading t)
        (setq beg (point))
        (end-of-line)
        (setq end (point))
        (goto-char beg)
        (if (re-search-forward "\\[\\([0-9]*%\\)\\]\\|\\[\\([0-9]*\\)/\\([0-9]*\\)\\]"
                               end t)
            (if (match-end 1)
                (if (equal (match-string 1) "100%")
                    (unless (string-equal todo-state "DONE")
                      (org-todo 'done))
                  (unless (string-equal todo-state "TODO")
                    (org-todo 'todo)))
              (if (and (> (match-end 2) (match-beginning 2))
                       (equal (match-string 2) (match-string 3)))
                  (unless (string-equal todo-state "DONE")
                    (org-todo 'done))
                (unless (string-equal todo-state "TODO")
                  (org-todo 'todo)))))))))
(add-hook 'org-checkbox-statistics-hook 'my/org-checkbox-todo)

(defun org-summary-todo (n-done n-not-done)
  "Switch entry to DONE when all subentries are done, to TODO otherwise."
  (let (org-log-done org-log-states)   ; turn off logging
    (org-todo (if (= n-not-done 0) "DONE" "TODO"))))

(add-hook 'org-after-todo-statistics-hook 'org-summary-todo)

(setq org-edit-src-content-indentation 0)
(setq org-confirm-babel-evaluate nil)

;; typescript: yarn global add ts-eager typescript ts-node tsconfig-paths
(use-package ob-typescript
  :straight t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   '(
     (emacs-lisp . t)
     (js . t)
     (typescript . t)
     )))

(add-hook 'org-mode-hook (lambda ()
                           (push '("[ ]" .  "󰄱") prettify-symbols-alist)
                           (push '("[X]" . "󰄲" ) prettify-symbols-alist)
                           (push '("[-]" . "⬚" ) prettify-symbols-alist)
                           (prettify-symbols-mode)))

(setq org-capture-templates
      '(
        ("t" "TODO" entry (file "~/brain/wiki/inbox.org") "* TODO %i%?\n")
        ("c" "Consume" entry (file+headline "~/brain/wiki/consume.org" "2021") "* %i%?\n#+SOURCE:\n")
        ))

(setq org-refile-targets (quote ((nil :maxlevel . 9)
                                 (org-agenda-files :maxlevel . 9))))

(use-package org-appear
  :straight t
  :custom
  ;; Do not scan on every motion command.
  (org-appear-trigger 'on-change)
  (org-appear-delay 0.15)
  ;; Reduce post-command churn in large Org files.
  (org-appear-autolinks nil)
  (org-appear-autosubmarkers nil)
  (org-appear-autoentities nil)
  (org-appear-autokeywords nil)
  :hook (org-mode . org-appear-mode))

(dolist (mode '(org-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; (require 'org-variable-pitch)
;; (set-face-attribute 'org-variable-pitch-fixed-face nil :family "BMono")
;; (add-hook 'org-mode-hook 'org-variable-pitch--enable)

(load "org-agenda")
(setq org-agenda-files (directory-files-recursively "~/brain/wiki" "\\.org$"))

;; agenda week: -2d .. +8d
(setq org-agenda-span 10)
(setq org-agenda-start-on-weekday nil)
(setq org-agenda-start-day "-2d")

(defvar my-pre-agenda-frame-configuration nil)
(defun my/org-agenda-open (&optional arg)
  (interactive "p")
  (setq my-pre-agenda-frame-configuration (current-frame-configuration))
  ;; (org-agenda arg "n"))
  (org-agenda arg "a"))
(defun my/org-agenda-quit ()
  (interactive)
  (org-agenda-quit)
  (if my-pre-agenda-frame-configuration
      (set-frame-configuration my-pre-agenda-frame-configuration))
  (setq my-pre-agenda-frame-configuration nil))

(nmap "SPC SPC" 'my/org-agenda-open)
;; (general-define-key :keymaps 'org-agenda-map "SPC SPC" 'my/org-agenda-quit)
(define-key org-agenda-keymap "q" 'my/org-agenda-quit)

(use-package org-roam
  :straight t
  :custom
  (org-roam-directory (file-truename "~/brain/wiki/"))
  (org-roam-completion-everywhere t)
  :config
  (require 'org-roam-dailies)
  (org-roam-db-autosync-mode)
  )

(setq org-roam-capture-templates
      '(("d" "default" plain
         "%?"
         :if-new (file+head "${slug}.org" "#+title: ${title}\n#+date: %U\n")
         :unnarrowed t)))

(setq org-roam-dailies-capture-templates
      '(("d" "default" entry "* %<%I:%M %p>: %?"
         :if-new (file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d>\n#+filetags: :daily:\n"))))

;; https://org-roam.discourse.group/t/filter-org-roam-node-find-insert-using-tags-and-folders/1907
(cl-defun my/org-roam-node--filter-by-tags (node &optional included-tags excluded-tags)
  "Filter org-roam-node by tags."
  (let* ((tags (org-roam-node-tags node))
         (file-path (org-roam-node-file node))
         (rel-file-path (file-relative-name file-path org-roam-directory))
         (parent-dir (file-name-directory rel-file-path))
         (parent-directories
          (if parent-dir
              (split-string (directory-file-name parent-dir) "/" t)
            nil))
         (tags (cl-union tags parent-directories :test #'string=)))
    (if (or
         ;; (and included-tags (cl-notevery (lambda (x) (cl-member x tags :test #'string=)) included-tags))
         (and included-tags (not (cl-intersection included-tags tags :test #'string=)))
         (and excluded-tags (cl-intersection excluded-tags tags :test #'string=))
         ) nil t)))

(cl-defun my/org-roam-node-find (included-tags excluded-tags)
  "Modded org-roam-node-find which filters nodes using tags."
  (interactive)
  (org-roam-node-find nil nil
                      (lambda (node) (my/org-roam-node--filter-by-tags node included-tags excluded-tags))))

(cl-defun my/org-roam-node-insert (included-tags excluded-tags)
  "Modded org-roam-node-insert which filters nodes using tags."
  (interactive)
  (org-roam-node-insert
   (lambda (node) (my/org-roam-node--filter-by-tags node included-tags excluded-tags))))

(use-package org-roam-ui
  :straight (:host github :repo "org-roam/org-roam-ui" :branch "main" :files ("*.el" "out"))
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;; org-local
(defun my/org-map-hook ()
  (evil-define-key 'normal 'evil-org-mode
    (kbd "<C-return>") (lambda () (interactive)
                         (org-insert-heading-after-current)
                         (command-execute 'evil-append)))
  (nmap "C-c n i" (lambda () (interactive) (my/org-roam-node-insert nil '("daily" "captures" "project"))))
  (nmap "C-SPC" 'org-shiftright)
  ;; Use native Org cycling for consistent heading folding behavior.
  ;; Note: Emacs conflates TAB and C-i; bind both locally in Org buffers.
  (evil-define-key '(normal motion) 'evil-org-mode (kbd "TAB") 'org-cycle)
  (evil-define-key '(normal motion) 'evil-org-mode (kbd "<tab>") 'org-cycle)
  (evil-define-key '(normal motion) 'evil-org-mode (kbd "C-i") 'org-cycle)
  (evil-define-key '(normal motion) 'evil-org-mode (kbd "<backtab>") 'org-shifttab)
  ;; Also enforce via org-mode-map directly to avoid minor-mode precedence issues
  (general-define-key
   :states '(normal motion emacs)
   :keymaps 'org-mode-map
   "<tab>" 'org-cycle
   "TAB" 'org-cycle
   "C-i" 'org-cycle
   "<backtab>" 'org-shifttab)
  )
(add-hook 'org-mode-hook #'my/org-map-hook)

;; global
(nmap "C-c a" 'org-agenda)
(nmap "C-c s" 'org-schedule)
(nmap "C-c i" 'org-clock-in)
(nmap "C-c o" 'org-clock-out)
(nmap "C-c c" 'org-capture)
(nmap "C-c r" 'org-refile)
(nmap "C-c z" 'org-archive-subtree-default)
(nmap "M-n" (lambda () (interactive) (my/org-roam-node-find nil '("daily" "captures" "project"))))
(nmap "M-p" (lambda () (interactive) (my/org-roam-node-find '("project") nil)))
(lib/mapleader "dd" 'org-roam-dailies-goto-today)
(lib/mapleader "da" 'org-roam-dailies-capture-today)
(lib/mapleader "dc" 'org-roam-dailies-goto-date)
;; (nmap "M-p" (lambda () (interactive) (counsel-find-file "~/plan")))

(lib/mapleader "q" 'evil-quit)

(with-eval-after-load 'evil-maps
  ;; esc
  (global-set-key (kbd "<escape>") 'keyboard-escape-quit)
  (define-key evil-normal-state-map
    (kbd "<escape>") (lambda ()
                       (interactive)
                       (evil-ex-nohighlight)
                       (evil-force-normal-state)
                       ))
  )

(lib/mapleader "ee" (lambda() (interactive)(find-file "~/.emacs.d/profiles/main/config.org")))

(nmap "C-S-r" (lambda() (interactive)(org-babel-load-file "~/.emacs.d/profiles/main/config.org")))

(lib/mapleader
  :infix "P"
  "" '(:which-key "profiler")
  "s" 'profiler-start
  "e" 'profiler-stop
  "p" 'profiler-report)

(lib/mapleader "?" 'which-key-show-top-level)
(lib/mapleader "tp" 'my/performance-mode-buffer)

(lib/mapleader "p" 'counsel-projectile-switch-project)

;; remove stupid empty state "match", default to prompt instead
(ivy-configure 'counsel-fzf
  :occur #'counsel-fzf-occur
  :unwind-fn #'counsel-delete-process
  :exit-codes '(1 ""))

;; actions
(defun my/counsel-fzf-open-vertical ()
  (interactive)
  (ivy-exit-with-action
   (lambda (candidate)
     (split-window-right)
     (other-window 1)
     (find-file candidate))
   )
  )
(defun my/counsel-fzf-open-horizontal ()
  (interactive)
  (ivy-exit-with-action
   (lambda (candidate)
     (split-window-below)
     (other-window 1)
     (find-file candidate)
     ))
  )

;; register actions (hook)
(defun my/counsel-fzf-hook ()
  (local-set-key (kbd "C-v") #'my/counsel-fzf-open-vertical)
  (local-set-key (kbd "C-s") #'my/counsel-fzf-open-horizontal)
  )
(with-eval-after-load 'ivy
  (setf (alist-get #'counsel-fzf ivy-hooks-alist) #'my/counsel-fzf-hook)
  (setf (alist-get #'counsel-projectile-find-file-dwim ivy-hooks-alist) #'my/counsel-fzf-hook)
  (setf (alist-get #'counsel-projectile-find-file ivy-hooks-alist) #'my/counsel-fzf-hook)
  )

;; map
;; (nmap "C-p" 'counsel-fzf)
(nmap "C-p" 'counsel-projectile-find-file)

;; actions
(defun my/counsel-rg-open-vertical ()
  (interactive)
  (ivy-exit-with-action
   (lambda (candidate)
     (setq candidate (car (split-string candidate ":")))
     (split-window-right)
     (other-window 1)
     (find-file candidate))
   )
  )
(defun my/counsel-rg-open-horizontal ()
  (interactive)
  (ivy-exit-with-action
   (lambda (candidate)
     (setq candidate (car (split-string candidate ":")))
     (split-window-below)
     (other-window 1)
     (find-file candidate)
     ))
  )

;; register actions (hook)
(defun my/counsel-rg-hook ()
  (local-set-key (kbd "C-v") #'my/counsel-rg-open-vertical)
  (local-set-key (kbd "C-s") #'my/counsel-rg-open-horizontal)
  )
(with-eval-after-load 'ivy
  (setf (alist-get #'counsel-rg ivy-hooks-alist) #'my/counsel-rg-hook))

;; map
(nmap "C-f" 'counsel-rg)

(nmap "C-h" 'evil-window-left)
(nmap "C-j" 'evil-window-down)
(nmap "C-k" 'evil-window-up)
(nmap "C-l" 'evil-window-right)

(nmap ";" 'counsel-switch-buffer)

(nmap "DEL" 'mode-line-other-buffer)

(lib/mapleader "l" 'swiper)

(defun my/buffer-save ()
  (interactive)
  (company-abort)
  (save-buffer)
  (evil-normal-state)
  )

(nmap "C-s" 'my/buffer-save)
(imap "C-s" 'my/buffer-save)

(general-define-key
 :states '(insert)
 :keymaps 'override
 "C-s" 'my/buffer-save
 )

(with-eval-after-load 'company
  (define-key company-active-map (kbd "C-s") 'my/buffer-save)
  )

;; (nmap "C-w" 'kill-current-buffer)
(define-key evil-normal-state-map "\C-w" (concat ":bd" (kbd "RET")))

;; https://kundeveloper.com/blog/buffer-files/
(defun my/rename-current-buffer-file ()
  "Renames current buffer and file it is visiting."
  (interactive)
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not (and filename (file-exists-p filename)))
        (error "Buffer '%s' is not visiting a file!" name)
      (let ((new-name (read-file-name "New name: " filename)))
        (if (get-buffer new-name)
            (error "A buffer named '%s' already exists!" new-name)
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil)
          (message "File '%s' successfully renamed to '%s'"
                   name (file-name-nondirectory new-name)))))))

;; https://kundeveloper.com/blog/buffer-files/
(defun my/delete-current-buffer-file ()
  "Removes file connected to current buffer and kills buffer."
  (interactive)
  (let ((filename (buffer-file-name))
        (buffer (current-buffer))
        (name (buffer-name)))
    (if (not (and filename (file-exists-p filename)))
        (ido-kill-buffer)
      (when (yes-or-no-p "Are you sure you want to remove this file? ")
        (delete-file filename)
        (kill-buffer buffer)
        (message "File '%s' successfully removed" filename)))))

;; normal
(with-eval-after-load 'evil-maps
  (define-key evil-normal-state-map (kbd "<") 'evil-shift-left-line)
  (define-key evil-normal-state-map (kbd ">") 'evil-shift-right-line)
  )

;; visual
(defun my/visual-evil-shift-left ()
  (interactive)
  (call-interactively 'evil-shift-left)
  (evil-normal-state)
  (evil-visual-restore))
(defun my/visual-evil-shift-right ()
  (interactive)
  (call-interactively 'evil-shift-right)
  (evil-normal-state)
  (evil-visual-restore))
(general-define-key
 :states '(visual)
 :keymaps 'override
 "<" 'my/visual-evil-shift-left
 ">" 'my/visual-evil-shift-right
 )

(use-package drag-stuff
  :straight t
  :after evil
  :config
  (drag-stuff-global-mode 1)
  (define-key evil-normal-state-map (kbd "M-k") 'drag-stuff-up)
  (define-key evil-normal-state-map (kbd "M-j") 'drag-stuff-down)
  )

(use-package lsp-mode
  :straight t
  :commands lsp lsp-deferred
  :hook (
         (lsp-mode . lsp-enable-which-key-integration))
  :init
  (setq lsp-auto-configure t)
  (setq lsp-idle-delay 1.0)
  (setq lsp-keymap-prefix "C-l")
  (setq lsp-completion-enable t)
  (setq lsp-completion-provider :capf)
  (setq lsp-enable-indentation t)
  (setq lsp-enable-on-type-formatting t)
  (setq lsp-enable-file-watchers nil)
  ;; (setq lsp-auto-guess-root t)
  :custom
  ;; disable features
  (lsp-enable-symbol-highlighting nil)
  (lsp-headerline-breadcrumb-icons-enable t)
  (lsp-headerline-breadcrumb-segments '(project file symbols))
  (lsp-headerline-breadcrumb-enable t)
  (lsp-lens-enable nil)
  (lsp-semantic-tokens-enable nil)
  (lsp-modeline-code-actions-enable nil)
  (lsp-modeline-diagnostics-enable nil)
  (lsp-eldoc-enable-hover nil)
  ;; signature
  (lsp-signature-auto-activate t)
  ;; completion
  (lsp-completion-show-detail t)
  (lsp-completion-show-kind t)
  (lsp-clients-typescript-prefer-use-project-ts-server t)
  ;; vue
  (lsp-vetur-format-default-formatter-css "none")
  (lsp-vetur-format-default-formatter-html "none")
  (lsp-vetur-format-default-formatter-js "none")
  (lsp-vetur-validation-template nil)
  :config
  (setq lsp-enable-which-key-integration t)
  (setq lsp-prefer-flymake nil)
  )

(use-package lsp-ivy :straight t)

(use-package lsp-ui
  :straight t
  :defer t
  :config
  (setq lsp-ui-doc-enable nil
        lsp-ui-doc-use-childframe t
        lsp-ui-doc-position 'at-point
        lsp-ui-doc-include-signature t
        ;; Smoother cursor motion: keep lsp-ui lightweight.
        lsp-ui-sideline-enable nil
        lsp-ui-sideline-show-diagnostics nil
        lsp-ui-sideline-show-code-actions nil
        lsp-ui-flycheck-enable nil
        lsp-ui-flycheck-list-position 'right
        lsp-ui-flycheck-live-reporting nil
        lsp-ui-show-code-actions nil
        lsp-ui-peek-enable t
        lsp-ui-peek-list-width 60
        lsp-ui-peek-peek-height 25)
  :custom-face
  ;; Make the sideline overlays less annoying
  (lsp-ui-sideline-global ((t
                            (:background "444444"))))
  (lsp-ui-sideline-symbol-info ((t
                                 (:foreground "gray45"
                                              :slant italic
                                              :height 0.99))))
  )

;; Emacs 29+ ships native Tree-sitter integration via `*-ts-mode`.
(when (and (boundp 'major-mode-remap-alist)
           (fboundp 'treesit-available-p)
           (treesit-available-p)
           (fboundp 'treesit-language-available-p))
  ;; Only remap when grammar is installed for that language.
  (dolist (entry '((typescript-mode typescript-ts-mode typescript)
                   (js-mode js-ts-mode javascript)
                   (css-mode css-ts-mode css)
                   (json-mode json-ts-mode json)
                   (go-mode go-ts-mode go)
                   (rust-mode rust-ts-mode rust)
                   (yaml-mode yaml-ts-mode yaml)
                   (nix-mode nix-ts-mode nix)))
    (pcase-let ((`(,classic-mode ,ts-mode ,lang) entry))
      (when (and (fboundp ts-mode)
                 (treesit-language-available-p lang))
        (add-to-list 'major-mode-remap-alist
                     (cons classic-mode ts-mode))))))

(when (and (fboundp 'treesit-available-p)
           (treesit-available-p))
  (setq treesit-font-lock-level 2))

(setenv "TSSERVER_LOG_FILE" "/tmp/tsserver.log")

(use-package typescript-mode
  :straight t
  :defer t
  :mode "\\.ts\\'"
  :hook ((typescript-mode . lsp-deferred)
         (typescript-ts-mode . lsp-deferred))
  :init
  (setq typescript-indent-level 2)
  :config
  (when (boundp 'typescript-ts-mode-indent-offset)
    (setq typescript-ts-mode-indent-offset 2)))

(when (fboundp 'tsx-ts-mode)
  (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
  (add-hook 'tsx-ts-mode-hook #'lsp-deferred))

;; (defun my/hooks/tide ()
;;   (tide-setup)
;; )
;; (use-package tide
;;   :straight t
;;   :hook (typescript-mode . my/hooks/tide))

(defvar my/lua-fallback-font-lock-keywords
  (let ((keywords '("and" "break" "do" "else" "elseif" "end" "false"
                    "for" "function" "goto" "if" "in" "local" "nil"
                    "not" "or" "repeat" "return" "then" "true"
                    "until" "while"))
        (builtins '("assert" "collectgarbage" "dofile" "error" "getmetatable"
                    "ipairs" "load" "loadfile" "next" "pairs" "pcall"
                    "print" "rawequal" "rawget" "rawlen" "rawset" "require"
                    "select" "setmetatable" "tonumber" "tostring" "type"
                    "xpcall" "_G" "_VERSION")))
    `((,(regexp-opt keywords 'symbols) . font-lock-keyword-face)
      (,(regexp-opt builtins 'symbols) . font-lock-builtin-face)
      ("\\_<\\([A-Za-z_][A-Za-z0-9_]*\\)\\s-*(" 1 font-lock-function-name-face)))
  "Basic Lua highlighting used when no dedicated Lua mode is available.")

(defvar my/lua-fallback-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?- ". 12b" st)
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?' "\"" st)
    (modify-syntax-entry ?\" "\"" st)
    st)
  "Syntax table for `my/lua-fallback-mode'.")

(define-derived-mode my/lua-fallback-mode prog-mode "Lua*"
  "Fallback Lua mode with basic syntax highlighting."
  :syntax-table my/lua-fallback-mode-syntax-table
  (setq-local font-lock-defaults '(my/lua-fallback-font-lock-keywords))
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local indent-line-function #'indent-relative))

(defun my/lua-mode-dispatch ()
  "Select the best available Lua major mode."
  (interactive)
  (cond
   ((and (fboundp 'treesit-language-available-p)
         (fboundp 'lua-ts-mode)
         (treesit-language-available-p 'lua))
    (lua-ts-mode)
    (when (fboundp 'lsp-deferred)
      (lsp-deferred)))
   ((require 'lua-mode nil t)
    (lua-mode)
    (when (fboundp 'lsp-deferred)
      (lsp-deferred)))
   (t
    (my/lua-fallback-mode))))

(add-to-list 'auto-mode-alist '("\\.lua\\'" . my/lua-mode-dispatch))
(add-to-list 'interpreter-mode-alist '("lua" . my/lua-mode-dispatch))

(if (fboundp 'vue-ts-mode)
    (progn
      (add-to-list 'auto-mode-alist '("\\.vue\\'" . vue-ts-mode))
      (add-hook 'vue-ts-mode-hook #'lsp-deferred))
  (use-package vue-mode
    :straight t
    :mode "\\.vue\\'"
    :hook (vue-mode . lsp-deferred)
    :config
    ;; fix indent https://github.com/AdamNiederer/vue-mode/issues/74
    (add-hook 'vue-mode-hook (lambda () (setq syntax-ppss-table nil)))))
;; (setq prettier-js-args '("--parser vue")))

(use-package helpful
  :straight t
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . helpful-function)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-command] . helpful-command)
  ([remap describe-key] . helpful-key))

;; (dw/leader-key-def
;;   "e"   '(:ignore t :which-key "eval")
;;   "eb"  '(eval-buffer :which-key "eval buffer"))

;; (dw/leader-key-def
;;   :keymaps '(visual)
;;   "er" '(eval-region :which-key "eval region"))

(use-package cider
  :straight t
  :mode "\\.clj[sc]?\\'"
  :config
  (when (fboundp 'evil-collection-cider-setup)
    (evil-collection-cider-setup)))

(use-package slime
  :straight t
  :mode "\\.lisp\\'")

(use-package ccls
  :straight t
  :hook ((c-mode c++-mode objc-mode cuda-mode c-ts-mode c++-ts-mode) .
         (lambda () (require 'ccls) (lsp-deferred))))

(use-package scheme-mode
  :straight nil
  :mode "\\.sld\\'")

(use-package nix-mode
  :straight t
  :mode "\\.nix\\'"
  :hook ((nix-mode . lsp-deferred)
         (nix-ts-mode . lsp-deferred)))

(defun my/go-mode-hook ()
  (unless (string-match-p "\\bgo\\b" compile-command)
    (set (make-local-variable 'compile-command)
         "go build -v && go test -v && go vet"))
  (when (fboundp 'gofmt-before-save)
    (add-hook 'before-save-hook #'gofmt-before-save nil t)))

(use-package go-mode
  :straight t
  :defer t
  :hook ((go-mode . lsp-deferred)
         (go-ts-mode . lsp-deferred)
         (go-mode . my/go-mode-hook)
         (go-ts-mode . my/go-mode-hook))
  :init
  (setq gofmt-command "goimports"))

(use-package rust-mode
  :straight t
  :mode "\\.rs\\'"
  :hook ((rust-mode . lsp-deferred)
         (rust-ts-mode . lsp-deferred)))

(use-package cargo
  :straight t
  :defer t
  :hook ((rust-mode . cargo-minor-mode)
         (rust-ts-mode . cargo-minor-mode)))

(use-package zig-mode
  :after lsp-mode
  :straight t
  :config
  (require 'lsp)
  (add-to-list 'lsp-language-id-configuration '(zig-mode . "zig"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection "/usr/bin/env zls")
    :major-modes '(zig-mode)
    :server-id 'zls)))

(use-package markdown-mode
  :straight t
  :mode "\\.md\\'"
  :config
  (setq markdown-command "marked")
  (defun dw/set-markdown-header-font-sizes ()
    (dolist (face '((markdown-header-face-1 . 1.2)
                    (markdown-header-face-2 . 1.1)
                    (markdown-header-face-3 . 1.0)
                    (markdown-header-face-4 . 1.0)
                    (markdown-header-face-5 . 1.0)))
      (set-face-attribute (car face) nil :weight 'normal :height (cdr face))))

  (defun dw/markdown-mode-hook ()
    (dw/set-markdown-header-font-sizes))

  (add-hook 'markdown-mode-hook 'dw/markdown-mode-hook))

(use-package yaml-mode
  :straight t
  :mode "\\.ya?ml\\'"
  :hook ((yaml-mode . lsp-deferred)
         (yaml-ts-mode . lsp-deferred)))

(nmap "gd" 'xref-find-definitions)
(nmap "gr" 'xref-find-references)
(nmap "gR" 'xref-go-back)
(nmap "K" 'lsp-describe-thing-at-point)
(nmap "gp" 'flycheck-next-error)
(nmap "gP" 'flycheck-previous-error)
(lib/mapleader "r" 'counsel-imenu)
(lib/mapleader "ac" 'lsp-execute-code-action)
(lib/mapleader "er" 'lsp-rename)

(defun my/hooks/on-save ()
  ;; lsp-format-buffer
  (when (bound-and-true-p lsp-mode)
    (lsp-format-buffer))
  ;; lsp-organize-imports (go)
  (when (and (fboundp 'lsp-organize-imports)
             (or (eq major-mode 'go-mode)
                 (eq major-mode 'go-ts-mode)))
    (lsp-organize-imports)))

(add-hook 'before-save-hook 'my/hooks/on-save)

(use-package flycheck
  :straight t
  :defer t
  :hook (lsp-mode . flycheck-mode))

(setq ispell-dictionary "american")

(defun my-american-dict ()
  "Change dictionary to american."
  (interactive)
  (setq ispell-local-dictionary "american")
  (flyspell-mode 1)
  (flyspell-buffer))

(use-package shell-pop
  :straight t
  :init
  (setq shell-pop-full-span t))

(use-package yasnippet
  :straight t
  :commands (yas-minor-mode yas-minor-mode-on)
  :init
  (add-hook 'prog-mode-hook #'yas-minor-mode)
  (add-hook 'restclient-mode-hook #'yas-minor-mode)
  (add-hook 'org-mode-hook #'yas-minor-mode)
  :config
  (setq yas-snippet-dirs
        (cl-union yas-snippet-dirs
                  '("~/.emacs.d/snippets")))
  (yas-reload-all))

(defun csp ()
  (interactive)
  (setq-local entries (mapcar 'car csp/commands))
  (ivy-read "Command: " entries :action (lambda (candidate) (funcall (cdr (assoc candidate csp/commands))))))

(nmap "C-S-p" #'csp)

;; index
(setq csp/commands '(
                     ("Projectile: Switch project" . csp/fn/projectile-switch-project)
                     ("Projectile: Add project" . csp/fn/projectile-add-project)
                     ("Projectile: Remove project" . csp/fn/projectile-remove-project)
                     ("File: Rename" . my/rename-current-buffer-file)
                     ("File: Delete" . my/delete-current-buffer-file)
                     ("Packages: Update all" . straight-pull-all)
                     ("Packages: Freeze versions" . straight-freeze-versions)
                     ("Packages: Reset to frozen versions" . straight-thaw-versions)
                     ))
;; projectile
(defun csp/fn/projectile-switch-project ()
  (interactive)
  (command-execute 'projectile-switch-project)
  )
(defun csp/fn/projectile-add-project ()
  (interactive)
  (command-execute 'projectile-add-known-project)
  )
(defun csp/fn/projectile-remove-project ()
  (interactive)
  (command-execute 'projectile-remove-known-project)
  )
