;;; modal-editing.el --- Evil configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Keeps modal editing setup isolated from the rest of the configuration.

;;; Code:

(require 'core-bootstrap)

(use-package evil
  :init
  (setq evil-default-state 'emacs)
  :config
  (evil-mode 1))

(provide 'modal-editing)

;;; modal-editing.el ends here
