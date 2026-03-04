;;; editing-config.el --- Completion, tooling and keybindings -*- lexical-binding: t; -*-

;;; Commentary:
;; Houses developer-focused helpers (completion, LSP, editing ergonomics).

;;; Code:

(require 'core-bootstrap)
(require 'subr-x)
(require 'seq)

(declare-function eglot--lookup-mode "eglot")
(declare-function eglot--guess-contact "eglot")
(declare-function eglot-managed-p "eglot")
(declare-function copilot--overlay-visible "copilot")
(declare-function cape-yasnippet "cape")
(declare-function completion-preview-active-mode "completion-preview" (&optional arg))

(defvar completion-preview-active-mode nil
  "Non-nil when `completion-preview-active-mode' is enabled.")

(defvar cursor-ai--lsp-preferred-modes
  '(java-mode java-ts-mode csharp-mode csharp-ts-mode)
  "Major modes that should keep using `lsp-mode' instead of `eglot'.")

(defconst cursor-ai--language-tool-bin-directories
  (list (expand-file-name "bin" (cursor-ai--state-path "python-tools"))
        (expand-file-name "node_modules/.bin" (cursor-ai--state-path "npm-tools")))
  "Repo-local bin directories searched before the user PATH.")

(defconst cursor-ai--eglot-server-overrides
  `((((js-mode :language-id "javascript")
      (js-ts-mode :language-id "javascript")
      (tsx-ts-mode :language-id "typescriptreact")
      (typescript-ts-mode :language-id "typescript")
      (typescript-mode :language-id "typescript"))
     . cursor-ai--typescript-eglot-contact)
    (((js-json-mode :language-id "json")
      (json-mode :language-id "json")
      (json-ts-mode :language-id "json")
      (jsonc-mode :language-id "jsonc"))
     . cursor-ai--json-eglot-contact)
    ((python-mode python-ts-mode)
     . cursor-ai--python-eglot-contact))
  "Preferred Eglot server entries for web and Python buffers.")

(defconst cursor-ai--apheleia-style-handlers
  '((javascript-mode . prettier-javascript)
    (js-mode . prettier-javascript)
    (js-ts-mode . prettier-javascript)
    (js-json-mode . prettier-json)
    (json-mode . prettier-json)
    (json-ts-mode . prettier-json)
    (python-mode . (ruff-isort ruff))
    (python-ts-mode . (ruff-isort ruff))
    (tsx-ts-mode . prettier-typescript)
    (typescript-mode . prettier-typescript)
    (typescript-ts-mode . prettier-typescript))
  "Formatter pipelines for the requested web and Python modes.")

(defconst cursor-ai--treesit-language-associations
  '(javascript json python tsx typescript)
  "Languages registered in `auto-mode-alist' through `treesit-auto'.")

(defconst cursor-ai--manual-web-file-associations
  '(("\\.cjs\\'" . js-mode)
    ("\\.mjs\\'" . js-mode)
    ("\\.cts\\'" . typescript-mode)
    ("\\.mts\\'" . typescript-mode))
  "Web-related file extensions that need explicit mode associations.")

(defconst cursor-ai--python-eglot-excluded-paths
  ["**/.git"
   "**/.direnv"
   "**/.venv"
   "**/venv"
   "**/env"
   "**/*-env"
   "**/node_modules"
   "**/__pycache__"
   "**/.mypy_cache"
   "**/.pytest_cache"
   "**/.ruff_cache"
   "**/build"
   "**/dist"]
  "Directory globs excluded from basedpyright workspace scanning.")

(defconst cursor-ai--python-eglot-workspace-configuration
  `(:basedpyright.analysis
    (:diagnosticMode "openFilesOnly"
     :exclude ,cursor-ai--python-eglot-excluded-paths))
  "Default Eglot workspace settings for Python buffers.")

(defun cursor-ai--prepend-to-exec-path (dir)
  "Prepend DIR to `exec-path' and PATH when it exists."
  (when (file-directory-p dir)
    (unless (member dir exec-path)
      (push dir exec-path))
    (let ((path-entries (split-string (or (getenv "PATH") "") path-separator t)))
      (unless (member dir path-entries)
        (setenv "PATH"
                (string-join (cons dir path-entries) path-separator))))))

(defun cursor-ai--command-contact (&rest command)
  "Resolve COMMAND into an absolute Eglot contact list, or nil."
  (when-let ((program (executable-find (car command))))
    (cons program (cdr command))))

(defun cursor-ai--typescript-eglot-contact (_interactive _project)
  "Return the Eglot contact for JavaScript and TypeScript buffers."
  (cursor-ai--command-contact "typescript-language-server" "--stdio"))

(defun cursor-ai--json-eglot-contact (_interactive _project)
  "Return the Eglot contact for JSON buffers."
  (or (cursor-ai--command-contact "vscode-json-language-server" "--stdio")
      (cursor-ai--command-contact "vscode-json-languageserver" "--stdio")
      (cursor-ai--command-contact "json-languageserver" "--stdio")))

(defun cursor-ai--python-eglot-contact (_interactive _project)
  "Return the Eglot contact for Python buffers."
  (let ((rass (executable-find "rass"))
        (ruff (executable-find "ruff"))
        (type-server (or (executable-find "basedpyright-langserver")
                         (executable-find "pyright-langserver"))))
    (or (when (and rass ruff type-server)
          (list rass "--" type-server "--stdio" "--" ruff "server"))
        (and type-server (list type-server "--stdio"))
        (when ruff
          (list ruff "server")))))

(defun cursor-ai--apply-eglot-buffer-configuration ()
  "Apply buffer-local Eglot settings before attempting startup."
  (when (and (derived-mode-p 'python-mode 'python-ts-mode)
             (not (local-variable-p 'eglot-workspace-configuration)))
    (setq-local eglot-workspace-configuration
                cursor-ai--python-eglot-workspace-configuration)))

(dolist (dir cursor-ai--language-tool-bin-directories)
  (cursor-ai--prepend-to-exec-path dir))

(defun cursor-ai--lsp-preferred-mode-p ()
  "Return non-nil when the current major mode prefers `lsp-mode'."
  (seq-some (lambda (mode) (derived-mode-p mode))
            cursor-ai--lsp-preferred-modes))

(defun cursor-ai--eglot-supported-mode-p ()
  "Return non-nil when `eglot' can auto-start for current buffer."
  (when (require 'eglot nil t)
    (when (and buffer-file-name
               (not (file-remote-p buffer-file-name))
               (fboundp 'eglot--lookup-mode)
               (fboundp 'eglot--guess-contact))
      (ignore-errors
        (and (with-no-warnings
               (eglot--lookup-mode major-mode))
             (nth 3 (with-no-warnings
                      (eglot--guess-contact))))))))

(defun cursor-ai--maybe-start-eglot ()
  "Start `eglot' for the current buffer when appropriate."
  (unless (cursor-ai--lsp-preferred-mode-p)
    (cursor-ai--apply-eglot-buffer-configuration)
    (when (cursor-ai--eglot-supported-mode-p)
      (unless (and (fboundp 'eglot-managed-p)
                   (eglot-managed-p))
        (condition-case err
            (eglot-ensure)
          (error
           (message "Eglot skipped in %s: %s"
                    major-mode
                    (error-message-string err))))))))

(defun cursor-ai--copilot-overlay-active-p ()
  "Return non-nil when a Copilot completion overlay is visible."
  (and (bound-and-true-p copilot-mode)
       (fboundp 'copilot--overlay-visible)
       (copilot--overlay-visible)))

(defun cursor-ai--completion-preview-clear (&rest _)
  "Disable active completion-preview overlay."
  (when completion-preview-active-mode
    (completion-preview-active-mode -1)))

(defun cursor-ai--completion-preview-suspend (fn &rest args)
  "Run FN with ARGS unless Copilot overlay is currently active."
  (if (cursor-ai--copilot-overlay-active-p)
      (cursor-ai--completion-preview-clear)
    (apply fn args)))

(defun cursor-ai--enable-yasnippet-capf ()
  "Expose yasnippet completions via CAPF for completion-preview."
  (add-hook 'completion-at-point-functions #'cape-yasnippet nil 'local))

(defun cursor-ai--yas-normalize-directory (dir)
  "Resolve DIR to an absolute snippet directory path or nil."
  (let ((value (cond
                ((symbolp dir)
                 (and (boundp dir) (symbol-value dir)))
                (t dir))))
    (when (stringp value)
      (if (file-name-absolute-p value)
          value
        (expand-file-name value user-emacs-directory)))))

(defun cursor-ai--yas-add-directories (&rest dirs)
  "Append snippet DIRS into `yas-snippet-dirs' when they exist."
  (setq yas-snippet-dirs (or yas-snippet-dirs '()))
  (dolist (dir dirs)
    (when-let ((entry (cursor-ai--yas-normalize-directory dir)))
      (unless (member entry yas-snippet-dirs)
        (setq yas-snippet-dirs
              (append yas-snippet-dirs (list entry)))))))

(use-package vertico
  :init (vertico-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode 1))

(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("C-c s" . consult-line)
         ("C-c g" . consult-git-grep)
         ("C-c r" . consult-ripgrep)
	 ("s-r" . consult-ripgrep)
	 ("s-s" . consult-line)))

(use-package embark
  :commands (embark-browse-package-url)
  :bind (("C-." . embark-act)
         ("C-c ." . embark-dwim)
         ("C-h B" . embark-bindings))
  (:map help-map
	("y" . embark-browse-package-url))
  :init
  (setq prefix-help-command 'embark-prefix-help-command))

(use-package embark-consult
  :after (embark consult))

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
  (setq eglot-max-file-watches 30000)
  (add-hook 'prog-mode-hook #'cursor-ai--maybe-start-eglot)
  :config
  (setq eglot-server-programs
        (append cursor-ai--eglot-server-overrides eglot-server-programs)))

(use-package completion-preview
  :ensure nil
  :hook ((prog-mode . completion-preview-mode)
         (text-mode . completion-preview-mode))
  :config
  (with-eval-after-load 'copilot
    (advice-add 'completion-preview--show :around #'cursor-ai--completion-preview-suspend)
    (advice-add 'completion-preview--try-update :around #'cursor-ai--completion-preview-suspend)
    (advice-add 'copilot--display-overlay-completion :before #'cursor-ai--completion-preview-clear)))

(use-package cape
  :commands (cape-yasnippet)
  :init
  (add-hook 'prog-mode-hook #'cursor-ai--enable-yasnippet-capf)
  (add-hook 'text-mode-hook #'cursor-ai--enable-yasnippet-capf))

(when (fboundp 'treesit-available-p)
  (use-package treesit-auto
    :custom (treesit-auto-install 'prompt)
    :config
    (treesit-auto-add-to-auto-mode-alist
     cursor-ai--treesit-language-associations)
    (dolist (entry cursor-ai--manual-web-file-associations)
      (add-to-list 'auto-mode-alist entry))
    (global-treesit-auto-mode)))

(use-package envrc
  :config
  (envrc-global-mode))

(use-package apheleia
  :init (apheleia-global-mode +1)
  :config
  (dolist (entry cursor-ai--apheleia-style-handlers)
    (setf (alist-get (car entry) apheleia-mode-alist)
          (cdr entry))))

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package yasnippet
  :config
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

(defvar cursor-ai--spell-checker-candidates
  '("hunspell" "aspell" "ispell")
  "Spell checker executables checked in priority order.")

(defconst cursor-ai--hunspell-dictionary-directories
  '("/usr/share/hunspell"
    "/usr/share/myspell"
    "/usr/share/myspell/dicts"
    "/usr/local/share/hunspell")
  "Common directories searched for Hunspell dictionaries.")

(defun cursor-ai--hunspell-dictionaries ()
  "Return available Hunspell dictionary names based on `.aff' files."
  (let ((dirs (append (split-string (or (getenv "DICPATH") "") ":" t)
                      cursor-ai--hunspell-dictionary-directories)))
    (delete-dups
     (apply #'append
            (mapcar
             (lambda (dir)
               (when (file-directory-p dir)
                 (mapcar #'file-name-base
                         (file-expand-wildcards
                          (expand-file-name "*.aff" dir)))))
             dirs)))))

(defun cursor-ai--aspell-dictionaries ()
  "Return dictionary names reported by Aspell."
  (when-let ((aspell (executable-find "aspell")))
    (with-temp-buffer
      (when (zerop (call-process aspell nil t nil "dump" "dicts"))
        (split-string (buffer-string) "\n" t "[[:space:]]+")))))

(defun cursor-ai--spell-checker-dictionaries (program)
  "Return available dictionaries for PROGRAM.
Returns `:unknown' when PROGRAM does not expose a dictionary list API."
  (pcase program
    ("hunspell" (cursor-ai--hunspell-dictionaries))
    ("aspell" (cursor-ai--aspell-dictionaries))
    (_ :unknown)))

(defun cursor-ai--dictionary-language (dictionary)
  "Extract language code from DICTIONARY name."
  (car (split-string dictionary "[_-]" t)))

(defun cursor-ai--select-dictionary (program)
  "Choose a dictionary for PROGRAM honoring locale and availability."
  (let* ((available (cursor-ai--spell-checker-dictionaries program))
         (preferred (or (getenv "DICTIONARY")
                        (cursor-ai--locale-dictionary)))
         (preferred-lang (and preferred
                              (cursor-ai--dictionary-language preferred))))
    (if (eq available :unknown)
        preferred
      (or (and preferred (member preferred available) preferred)
          (and preferred-lang
               (seq-find (lambda (entry)
                           (string= (cursor-ai--dictionary-language entry)
                                    preferred-lang))
                         available))
          (car available)))))

(defun cursor-ai--spell-checker-program ()
  "Return first available spell checker executable with dictionaries."
  (seq-find
   (lambda (program)
     (and (executable-find program)
          (let ((dicts (cursor-ai--spell-checker-dictionaries program)))
            (or (eq dicts :unknown) (consp dicts)))))
   cursor-ai--spell-checker-candidates))

(defun cursor-ai--locale-dictionary ()
  "Return dictionary inferred from locale variables, or nil."
  (seq-some
   (lambda (env-var)
     (when-let* ((raw-locale (getenv env-var))
                 (locale (replace-regexp-in-string "\\..*$" "" raw-locale))
                 ((string-match-p "^[[:alpha:]]+_[[:alpha:]]+$" locale)))
       locale))
   '("LC_ALL" "LC_MESSAGES" "LANG")))

(defun cursor-ai--spell-checker-ready-p ()
  "Return non-nil when `ispell-program-name' points to an executable."
  (and (stringp ispell-program-name)
       (executable-find ispell-program-name)))

(defun cursor-ai--minor-mode-enabling-p (mode arg)
  "Return non-nil when MODE would be enabled with ARG."
  (cond
   ((or (null arg) (eq arg 'toggle))
    (not (and (boundp mode) (symbol-value mode))))
   ((numberp arg)
    (> arg 0))
   (t
    (not (memq arg '(nil 0 -1))))))

(defun cursor-ai--flyspell-guard (orig &rest args)
  "Call ORIG with ARGS, but avoid enabling Flyspell without a checker."
  (let ((arg (car args)))
    (if (and (cursor-ai--minor-mode-enabling-p 'flyspell-mode arg)
             (not (cursor-ai--spell-checker-ready-p)))
        (progn
          (message "Flyspell skipped: no configured spell checker/dictionary.")
          nil)
      (apply orig args))))

(defun cursor-ai--maybe-enable-flyspell ()
  "Enable `flyspell-mode' in text buffers when checker is available."
  (when (cursor-ai--spell-checker-ready-p)
    (flyspell-mode 1)))

(defun cursor-ai--maybe-enable-flyspell-prog ()
  "Enable comment/string spell checking in programming buffers."
  (when (cursor-ai--spell-checker-ready-p)
    (flyspell-prog-mode)))

(use-package ispell
  :straight nil
  :custom
  (ispell-silently-savep t)
  (ispell-personal-dictionary
   (expand-file-name "ispell-personal.dict" (cursor-ai--state-path "cache")))
  :config
  (if-let ((program (cursor-ai--spell-checker-program)))
      (progn
        (setq ispell-program-name program)
        (when-let ((dictionary (cursor-ai--select-dictionary program)))
          (setq ispell-dictionary dictionary)))
    (setq ispell-program-name nil
          ispell-dictionary nil)
    (display-warning
     'cursor-ai
     "No Hunspell/Aspell dictionaries found; install one to enable Flyspell."
     :warning)))

(use-package flyspell
  :straight nil
  :after ispell
  :hook ((text-mode . cursor-ai--maybe-enable-flyspell)
         (prog-mode . cursor-ai--maybe-enable-flyspell-prog))
  :custom
  (flyspell-issue-message-flag nil)
  (flyspell-issue-welcome-flag nil)
  :config
  (advice-add 'flyspell-mode :around #'cursor-ai--flyspell-guard))

(defun cursor-ai/move-text-up ()
  "Move the current line one position up."
  (interactive)
  (transpose-lines 1)
  (forward-line -2))

(defun cursor-ai/move-text-down ()
  "Move the current line one position down."
  (interactive)
  (forward-line 1)
  (transpose-lines 1)
  (forward-line -1))

(defalias 'move-text-up #'cursor-ai/move-text-up)
(defalias 'move-text-down #'cursor-ai/move-text-down)

(global-set-key (kbd "M-<up>") #'cursor-ai/move-text-up)
(global-set-key (kbd "M-<down>") #'cursor-ai/move-text-down)
(global-set-key (kbd "C-;") #'comment-line)

(defun cursor-ai/duplicate-line ()
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

(defalias 'duplicate-line #'cursor-ai/duplicate-line)

(global-set-key (kbd "C-S-d") #'cursor-ai/duplicate-line)
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
