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
(add-to-list 'initial-frame-alist '(fullscreen . fullboth))

(use-package vscode-dark-plus-theme)

(use-package nerd-icons)

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :custom
  (doom-modeline-height 18))

(use-package which-key
  :init (which-key-mode 1))

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

(defun cursor-ai--find-managed-window (param)
  "Return the first live window tagged with PARAM."
  (let* ((non-side-windows
          (seq-filter (lambda (win)
                        (and (window-live-p win)
                             (not (window-parameter win 'window-side))))
                      (window-list nil 'nomini)))
         (managed
          (seq-find (lambda (win) (window-parameter win param))
                    non-side-windows)))
    ;; If only one non-side window remains, don't treat it as managed.
    (when (and managed (<= (length non-side-windows) 1))
      (set-window-parameter managed param nil)
      (setq managed nil))
    managed))

(defun cursor-ai--main-non-side-window ()
  "Return the preferred non-side window to keep as primary editing area."
  (or (seq-find (lambda (win)
                  (and (window-live-p win)
                       (not (window-parameter win 'window-side))
                       (not (window-parameter win 'cursor-ai-repl-window))
                       (not (window-parameter win 'cursor-ai-aux-window))))
                (window-list nil 'nomini))
      (seq-find (lambda (win)
                  (and (window-live-p win)
                       (not (window-parameter win 'window-side))))
                (window-list nil 'nomini))
      (selected-window)))

(defun cursor-ai--display-in-managed-bottom-window (buffer alist param default-height)
  "Display BUFFER in a reusable managed bottom window.
ALIST controls `window-height'. PARAM marks the managed window.
DEFAULT-HEIGHT is used when ALIST doesn't provide `window-height'."
  (let ((win (cursor-ai--find-managed-window param))
        (height (or (alist-get 'window-height alist) default-height)))
    (if (window-live-p win)
        (progn
          (set-window-buffer win buffer)
          win)
      (let* ((anchor (cursor-ai--main-non-side-window))
             (total-height (window-total-height anchor))
             (min-height (max window-min-height 8))
             (target-height (max min-height
                                 (min (- total-height min-height)
                                      (floor (* total-height height)))))
             (upper-height (max min-height (- total-height target-height)))
             (new-win (or (ignore-errors
                            (split-window anchor upper-height 'below))
                          anchor)))
        (when (window-live-p new-win)
          (set-window-buffer new-win buffer)
          (set-window-dedicated-p new-win nil)
          (set-window-parameter new-win param t))
        new-win))))

(defun cursor-ai--display-repl-window (buffer alist)
  "Display BUFFER in the managed REPL bottom window."
  (cursor-ai--display-in-managed-bottom-window
   buffer alist 'cursor-ai-repl-window 0.30))

(defun cursor-ai--display-aux-window (buffer alist)
  "Display BUFFER in the managed auxiliary bottom window."
  (cursor-ai--display-in-managed-bottom-window
   buffer alist 'cursor-ai-aux-window 0.26))

(defun cursor-ai--display-fullframe-same-window (buffer _alist)
  "Display BUFFER in the primary non-side window.

When BUFFER is a Magit diff and a with-editor buffer is visible, avoid
maximizing so the commit message window remains available."
  (let* ((magit-diff-target
          (with-current-buffer buffer
            (derived-mode-p 'magit-diff-mode)))
         (with-editor-visible
          (seq-some
           (lambda (window)
             (with-current-buffer (window-buffer window)
               (bound-and-true-p with-editor-mode)))
           (window-list nil 'nomini)))
         (win (or (cursor-ai--main-non-side-window) (selected-window))))
    (when (window-live-p win)
      (set-window-buffer win buffer)
      (set-window-dedicated-p win nil)
      (unless (and magit-diff-target with-editor-visible)
        (delete-other-windows win))
      win)))

(defun cursor-ai--magit-diff-or-ediff-buffer-p (buffer-name _action)
  "Return non-nil when BUFFER-NAME is a Magit diff or Ediff control buffer."
  (when-let ((buffer (get-buffer buffer-name)))
    (with-current-buffer buffer
      (or (derived-mode-p 'magit-diff-mode)
          (eq major-mode 'ediff-meta-mode)
          (string-match-p "\\`\\*\\(?:[Ee]diff\\|magit-diff:\\)" buffer-name)))))

(defun cursor-ai--repl-or-chat-buffer-p (buffer-name _action)
  "Return non-nil when BUFFER-NAME corresponds to a REPL/chat style buffer."
  (when-let ((buffer (get-buffer buffer-name)))
    (with-current-buffer buffer
      (or (derived-mode-p 'comint-mode 'eshell-mode 'shell-mode 'term-mode 'vterm-mode)
          (memq major-mode '(ielm-mode
                             inferior-emacs-lisp-mode
                             inferior-python-mode
                             sql-interactive-mode
                             chatgpt-shell-mode
                             gptel-mode
                             agent-shell-mode))
          (string-match-p
           "\\`\\*\\(Cursor-Chat\\|MCP Tools\\|AI-[^*]*\\|chatgpt.*\\|.* llm .*\\)\\*\\'"
           buffer-name)
          (string-prefix-p "Claude Code Agent @ " buffer-name)))))

;; Vertical monitor defaults:
;; - Sidebars (Treemacs/Dirvish) stay left.
;; - REPLs and diagnostics open in normal bottom windows so `C-x 1` can close them.
(setq display-buffer-alist
      '((cursor-ai--magit-diff-or-ediff-buffer-p
         (cursor-ai--display-fullframe-same-window)
         (reusable-frames . nil)
         (inhibit-switch-frame . t))
        ("\\*\\(Treemacs-.*\\)\\*"
         (display-buffer-reuse-window display-buffer-in-side-window)
         (side . left)
         (slot . 0)
         (window-width . 0.20))
        ("\\*\\(dirvish\\(?:-side\\)?\\)\\*"
         (display-buffer-reuse-window display-buffer-in-side-window)
         (side . left)
         (slot . 1)
         (window-width . 0.24))
        (cursor-ai--repl-or-chat-buffer-p
         (display-buffer-reuse-window cursor-ai--display-repl-window)
         (window-height . 0.30)
         (slot . 0))
        ("\\*\\(Warnings\\|Backtrace\\|Messages\\|Compile-Log\\|compilation\\|Async Shell Command\\|Occur\\|xref\\|grep\\|Help\\|Apropos\\|lsp.*\\|Flymake diagnostics.*\\|Flycheck errors.*\\|Embark Collect.*\\|Completions\\)\\*"
         (display-buffer-reuse-window cursor-ai--display-aux-window)
         (window-height . 0.24)
         (slot . 1))
        ("\\*\\(magit:.*\\|magit-.*\\|\\(?:.*\\)\\s-*revision\\)\\*"
         (display-buffer-reuse-window cursor-ai--display-aux-window)
         (window-height . 0.26)
         (slot . 2))))

(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

(global-auto-revert-mode 1)

(provide 'ui-config)

;;; ui-config.el ends here
