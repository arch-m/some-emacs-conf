;;; editing-config.el --- Completion, tooling and keybindings -*- lexical-binding: t; -*-

;;; Commentary:
;; Houses developer-focused helpers (completion, LSP, editing ergonomics).

;;; Code:

(require 'core-bootstrap)
(require 'subr-x)
(require 'seq)

(declare-function eglot--lookup-mode "eglot")
(declare-function eglot-managed-p "eglot")

(defvar cursor-ai--lsp-preferred-modes
  '(java-mode java-ts-mode csharp-mode csharp-ts-mode)
  "Major modes that should keep using `lsp-mode' instead of `eglot'.")

(defun cursor-ai--lsp-preferred-mode-p ()
  "Return non-nil when the current major mode prefers `lsp-mode'."
  (seq-some (lambda (mode) (derived-mode-p mode))
            cursor-ai--lsp-preferred-modes))

(defun cursor-ai--eglot-supported-mode-p ()
  "Return server definition when `eglot' knows how to handle current mode."
  (when (require 'eglot nil t)
    (when (fboundp 'eglot--lookup-mode)
      (ignore-errors
        (with-no-warnings
          (eglot--lookup-mode major-mode))))))

(defun cursor-ai--maybe-start-eglot ()
  "Start `eglot' for the current buffer when appropriate."
  (unless (cursor-ai--lsp-preferred-mode-p)
    (when (cursor-ai--eglot-supported-mode-p)
      (unless (and (fboundp 'eglot-managed-p)
                   (eglot-managed-p))
        (eglot-ensure)))))

(use-package vertico
  :init (vertico-mode 1))

(use-package orderless
  :custom (completion-styles '(orderless basic)))

(use-package marginalia
  :init (marginalia-mode 1))

(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("C-c s" . consult-line)
         ("C-c g" . consult-git-grep)
         ("C-c r" . consult-ripgrep))
  :hook (completion-list-mode . consult-preview-at-point-mode))

(use-package lsp-mode
  :hook ((java-mode . lsp-deferred)
         (java-ts-mode . lsp-deferred)
         (csharp-mode . lsp-deferred)
         (csharp-ts-mode . lsp-deferred)
         (lsp-mode . lsp-enable-which-key-integration))
  :custom
  (lsp-idle-delay 0.5)
  (lsp-log-io nil)
  (lsp-completion-provider :capf)
  (lsp-enable-file-watchers t)
  (lsp-file-watch-threshold 5000)
  (lsp-headerline-breadcrumb-enable t)
  (lsp-modeline-code-actions-enable t)
  (lsp-modeline-diagnostics-enable t)
  (lsp-enable-symbol-highlighting t)
  (lsp-signature-auto-activate t)
  (lsp-signature-render-documentation t)
  (lsp-lens-enable t)
  (lsp-enable-on-type-formatting t)
  (lsp-enable-indentation t)
  (lsp-enable-snippet t)
  :bind (:map lsp-mode-map
              ("C-c l" . lsp-command-map)
              ("M-." . lsp-find-definition)
              ("M-," . lsp-find-references))
  :commands (lsp lsp-deferred)
  :config
  (let ((lsp-cache (cursor-ai--state-path "lsp")))
    (setq lsp-server-install-dir (expand-file-name "server" lsp-cache)
          lsp-session-file (expand-file-name "session" lsp-cache))))

(use-package lsp-ui
  :after lsp-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-sideline-enable t)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-sideline-show-diagnostics t)
  (lsp-ui-sideline-show-hover t)
  (lsp-ui-sideline-update-mode 'point)
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-position 'at-point)
  (lsp-ui-doc-show-with-cursor t)
  (lsp-ui-doc-show-with-mouse t)
  (lsp-ui-doc-delay 0.5)
  (lsp-ui-peek-enable t)
  (lsp-ui-peek-always-show t)
  (lsp-ui-peek-fontify 'always)
  :bind (:map lsp-ui-mode-map
              ("C-c d" . lsp-ui-doc-show)
              ("C-c i" . lsp-ui-peek-find-implementation)
              ("C-c r" . lsp-ui-peek-find-references)
              ("M-." . lsp-ui-peek-find-definitions)))

(use-package eglot
  :commands (eglot eglot-ensure)
  :init
  (add-hook 'prog-mode-hook #'cursor-ai--maybe-start-eglot))

(use-package completion-preview
  :ensure nil
  :hook ((prog-mode . completion-preview-mode)
         (text-mode . completion-preview-mode))
  :config
  (with-eval-after-load 'copilot
    (defun cursor-ai--copilot-overlay-active-p ()
      (and (bound-and-true-p copilot-mode)
           (copilot--overlay-visible)))

    (defun cursor-ai--completion-preview-clear (&rest _)
      (when completion-preview-active-mode
        (completion-preview-active-mode -1)))

    (defun cursor-ai--completion-preview-suspend (fn &rest args)
      (if (cursor-ai--copilot-overlay-active-p)
          (cursor-ai--completion-preview-clear)
        (apply fn args)))

    (advice-add 'completion-preview--show :around #'cursor-ai--completion-preview-suspend)
    (advice-add 'completion-preview--try-update :around #'cursor-ai--completion-preview-suspend)
    (advice-add 'copilot--display-overlay-completion :before #'cursor-ai--completion-preview-clear)))

(use-package cape
  :commands (cape-yasnippet)
  :init
  (defun cursor-ai--enable-yasnippet-capf ()
    "Expose yasnippet completions via CAPF for completion-preview."
    (add-hook 'completion-at-point-functions #'cape-yasnippet nil 'local))
  (add-hook 'prog-mode-hook #'cursor-ai--enable-yasnippet-capf)
  (add-hook 'text-mode-hook #'cursor-ai--enable-yasnippet-capf))

(when (fboundp 'treesit-available-p)
  (use-package treesit-auto
    :custom (treesit-auto-install 'prompt)
    :config (global-treesit-auto-mode)))

(use-package envrc
  :config
  (envrc-global-mode))

(use-package apheleia
  :init (apheleia-global-mode +1))

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package yasnippet
  :config
  (defun cursor-ai--yas-add-directories (&rest dirs)
    (setq yas-snippet-dirs (or yas-snippet-dirs '()))
    (dolist (dir dirs)
      (when dir
        (let ((entry (if (and (stringp dir) (not (file-name-absolute-p dir)))
                         (expand-file-name dir user-emacs-directory)
                       dir)))
          (setq yas-snippet-dirs
                (delete-dups (append yas-snippet-dirs (list entry))))))))

  (setq yas-snippet-dirs nil)
  (let ((local-snippets (expand-file-name "snippets" user-emacs-directory)))
    (unless (file-directory-p local-snippets)
      (make-directory local-snippets t))
    (cursor-ai--yas-add-directories local-snippets))
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :after yasnippet
  :config
  (yasnippet-snippets-initialize)
  (cursor-ai--yas-add-directories 'yasnippet-snippets-dir))

(defun move-text-up ()
  "Move the current line one position up."
  (interactive)
  (transpose-lines 1)
  (forward-line -2))

(defun move-text-down ()
  "Move the current line one position down."
  (interactive)
  (forward-line 1)
  (transpose-lines 1)
  (forward-line -1))

(global-set-key (kbd "M-<up>") #'move-text-up)
(global-set-key (kbd "M-<down>") #'move-text-down)
(global-set-key (kbd "C-;") #'comment-line)

(defun duplicate-line ()
  "Duplicate the current line preserving cursor column."
  (interactive)
  (let ((column (- (point) (line-beginning-position)))
        (line (let ((s (thing-at-point 'line t)))
                (if s (string-remove-suffix "\n" s) ""))))
    (move-end-of-line 1)
    (newline)
    (insert line)
    (move-beginning-of-line 1)
    (forward-char column)))

(global-set-key (kbd "C-S-d") #'duplicate-line)
(global-set-key (kbd "C-=") #'text-scale-increase)
(global-set-key (kbd "C--") #'text-scale-decrease)

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (setq hl-todo-keyword-faces
        '(("TODO"   . "#FF0000")
          ("FIXME"  . "#FF0000")
          ("DEBUG"  . "#A020F0")
          ("NOTE"   . "#1E90FF"))))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package indent-guide
  :hook (prog-mode . indent-guide-mode)
  :custom
  (indent-guide-char "│"))

(provide 'editing-config)

;;; editing-config.el ends here
