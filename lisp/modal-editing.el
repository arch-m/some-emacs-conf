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
    (add-hook hook #'cursor-ai--force-evil-emacs-state))
  :bind
  ("s-f" . evil-find-char)
  ("s-F" . evil-find-char-backward)
  ("s-o" . evil-execute-in-normal-state)
  (:map evil-normal-state-map
        ("\\" . 'link-hint-open-link)))

(use-package hideshow
  :hook ((prog-mode . hs-minor-mode)
	 (text-mode . hs-minor-mode)))

(define-prefix-command 's-z-prefix-map)
(global-set-key (kbd "s-z") 's-z-prefix-map)

(use-package goto-chg
  :ensure nil
  :bind (("s-a" . goto-last-change)
         ("s-A" . goto-last-change-reverse)))

(use-package link-hint
  :after (eww)
  :bind
  (:map s-z-prefix-map
        ("a" . link-hint-open-link))
  (:map eww-mode-map
        ("f" . link-hint-open-link))
  (:map help-mode-map
        ("f" . link-hint-open-link))
  (:map package-menu-mode-map
        ("f" . link-hint-open-link)))

(use-package avy
  :config
  (setq avy-keys '(?a ?r ?s ?t ?n ?e ?i ?o))
  :bind
  ("M-z" . avy-goto-char-timer)
  (:map s-z-prefix-map
        ("d" . 'avy-kill-whole-line)
        ("k" . 'avy-kill-region)
        ("R" . 'avy-move-region)
        ("L" . 'avy-kill-ring-save-whole-line)
        ("l" . 'avy-copy-line)
        ("m" . 'avy-move-line)
        ("s" . 'avy-isearch)
        ("r" . 'avy-copy-region)
        ("g" . 'avy-goto-char)
        ("o" . 'avy-goto-char-in-line)))

(use-package avy-zap
  :bind
  ("C-M-z" . avy-zap-to-char)
  ("C-M-Z" . avy-zap-up-to-char))

(provide 'modal-editing)

;;; modal-editing.el ends here
