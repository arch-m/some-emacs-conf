;;; modal-editing.el --- Evil configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Keeps modal editing setup isolated from the rest of the configuration.

;;; Code:

(require 'core-bootstrap)

(defun cursor-ai/delete-other-windows-all (&optional window)
  "Delete all other windows, including side windows.
With WINDOW, keep that one as the only visible window."
  (interactive)
  (let* ((target (or window (selected-window)))
         (windows (window-list nil 'nomini)))
    (dolist (win windows)
      (unless (eq win target)
        (set-window-dedicated-p win nil)
        (ignore-errors (delete-window win))))
    (when (window-live-p target)
      (set-window-dedicated-p target nil)
      (set-window-parameter target 'cursor-ai-repl-window nil)
      (set-window-parameter target 'cursor-ai-aux-window nil)
      (ignore-errors (delete-other-windows target)))))

(defun cursor-ai--force-evil-emacs-state ()
  "Keep REPL-like buffers in `evil-emacs-state'."
  (local-set-key (kbd "C-x 1") #'cursor-ai/delete-other-windows-all)
  (when (fboundp 'evil-emacs-state)
    (evil-emacs-state)))

(defconst cursor-ai-repl-mode-hooks
  '(comint-mode-hook
    eshell-mode-hook
    shell-mode-hook
    term-mode-hook
    vterm-mode-hook
    ielm-mode-hook
    inferior-emacs-lisp-mode-hook
    inferior-python-mode-hook
    sql-interactive-mode-hook
    gptel-mode-hook
    chatgpt-shell-mode-hook
    agent-shell-mode-hook)
  "Hooks where REPL or chat buffers should stay in Emacs state.")

(use-package evil
  :init
  (setq evil-default-state 'emacs)
  :config
  (evil-mode 1)
  (dolist (hook cursor-ai-repl-mode-hooks)
    (add-hook hook #'cursor-ai--force-evil-emacs-state)))

(provide 'modal-editing)

;;; modal-editing.el ends here
