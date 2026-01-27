;;; ui-config.el --- Visual appearance and frame behaviour -*- lexical-binding: t; -*-

;;; Commentary:
;; Groups UI-related toggles so visual customisation lives in one place.

;;; Code:

(require 'core-bootstrap)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)
(column-number-mode 1)

(add-to-list 'default-frame-alist '(fullscreen . fullboth))
(add-hook 'window-setup-hook (lambda () (toggle-frame-fullscreen)))

(use-package vscode-dark-plus-theme)

(use-package nerd-icons)

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :custom
  (doom-modeline-height 18))

(use-package which-key
  :init (which-key-mode 1))

;;   (key-chord-define-global "dn" #'ace-window)
;;   (key-chord-define-global "dh" #'golden-ratio)
;;   (key-chord-define-global "ao" #'hide-mode-line-mode)
;; TODO agrega  use-package de cada uno


(tab-bar-mode 1)
(setq tab-bar-show 1
      tab-bar-close-button-show nil
      tab-bar-new-button-show nil
      tab-bar-tab-hints t
      tab-bar-format '(tab-bar-format-tabs tab-bar-separator))

(global-set-key (kbd "C-<tab>") #'tab-next)
(global-set-key (kbd "C-S-<tab>") #'tab-previous)

(show-paren-mode 1)
(setq show-paren-delay 0)
(electric-pair-mode 1)

(setq scroll-margin 8
      scroll-step 1
      scroll-conservatively 10000
      scroll-preserve-screen-position 1)

(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

(global-auto-revert-mode 1)

(provide 'ui-config)

;;; ui-config.el ends here
