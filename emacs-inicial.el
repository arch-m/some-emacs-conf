(provide 'emacs-inicial)

;;; --- Bootstrap -----------------------------------------------------
(setq inhibit-startup-message t
      use-dialog-box nil
      ring-bell-function #'ignore
      native-comp-async-report-warnings-errors 'silent)

;; UI minimal
(menu-bar-mode -1) (tool-bar-mode -1) (scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(global-hl-line-mode 1)

;; Repos
(unless (package-installed-p 'use-package)
  (package-refresh-contents) (package-install 'use-package))
(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t)

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(setq straight-use-package-by-default t)

(use-package gptel
  :straight t
  :ensure t
  :config
  (gptel-make-ollama "Ollama"             ;Any name of your choosing
    :host "localhost:11434"               ;Where it's running
    :stream t                             ;Stream responses
    :models '(gpt-oss:latest)))

					;  (add-to-list 'gptel-backends 'ollama)
					; (add-to-list 'gptel-backends 'google-gemini)



;;; --- Apariencia estilo VS Code ------------------------------------
(use-package vscode-dark-plus-theme
  :config (load-theme 'vscode-dark-plus t))

(use-package nerd-icons)        ;; instala fuentes con: M-x nerd-icons-install-fonts
(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :custom (doom-modeline-height 18))

;;; --- Paleta, búsqueda y minibuffer modernos -----------------------
(use-package vertico :init (vertico-mode 1))
(use-package orderless
  :custom (completion-styles '(orderless basic)))
(use-package marginalia :init (marginalia-mode 1))
;; (use-package consult
;;   :bind (("C-S-p" . execute-extended-command) ; “Command Palette” VS Code
;;          ("C-c f" . consult-ripgrep)
;;          ("C-c b" . consult-buffer)
;;          ("C-c s" . consult-line)))

;;; --- Explorador y terminal ----------------------------------------
(use-package treemacs
  :bind (("C-c e" . treemacs))
  :config (treemacs-project-follow-mode t))
(use-package vterm :commands vterm
  :bind (("C-`" . vterm)))  ;; como terminal integrada

;;; --- LSP + autocompletado -----------------------------------------
(use-package lsp-mode
  :hook ((prog-mode . lsp-deferred))
  :custom (lsp-completion-provider :capf)
  :commands lsp lsp-deferred)
(use-package lsp-ui :after lsp-mode)
(use-package corfu :init (global-corfu-mode 1))
(use-package cape) ;; si después quieres bridges extra

;;; --- Tree-sitter (Emacs 29+) --------------------------------------
(when (fboundp 'treesit-available-p)
  (use-package treesit-auto
    :custom (treesit-auto-install 'prompt)
    :config (global-treesit-auto-mode)))

;;; --- Formateo en guardado (multi-lenguaje) ------------------------
(use-package apheleia
  :init (apheleia-global-mode +1))

;;; --- Which-key para descubrir atajos -------------------------------
(use-package which-key :init (which-key-mode 1))

;;; --- IA: Chat, Acciones y Ghost-text -------------------------------
;; gptel = chat lateral y acciones. Requires OPENAI_API_KEY

;; COPILOT (ghost-text). Alternativa: codeium.el (ver bloque comentado más abajo)
(use-package copilot
  :hook ((prog-mode . copilot-mode) (text-mode . copilot-mode))
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB"   . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("M-<tab>" . copilot-accept-completion-by-line)))
;; ;; Alternativa: Codeium (si prefieres evitar GitHub)
;; (use-package codeium
;;   :init (add-to-list 'completion-at-point-functions #'codeium-completion-at-point)
;;   :hook (prog-mode . codeium-mode))

;; Prefijo “AI” sin conflictos: C-c a …
(define-prefix-command 'cursor-ai-map)
(global-set-key (kbd "C-c a") 'cursor-ai-map)

;; --- Utilidades IA: panel lateral robusto y prompts curados ---------
(defvar cursor-ai--chat-window-width 84
  "Ancho del panel de chat a la derecha.")

(defun cursor-ai--open-chat ()
  "Abre/recupera un buffer gptel en panel lateral derecho y lo redimensiona."
  (interactive)
  (let ((buf (get-buffer-create "*Cursor-Chat*")))
    (unless (get-buffer-window buf)
      (split-window-right)
      (other-window 1))
    (switch-to-buffer buf)
    (unless (derived-mode-p 'gptel-mode) (gptel))
    ;; Redimensiona a ancho fijo
    (let* ((win (get-buffer-window buf))
           (target (- cursor-ai--chat-window-width (window-width win))))
      (when (window-live-p win)
        (window-resize win target t)))))

(defun cursor-ai--region-or-buffer ()
  "Devuelve (inicio fin texto lang) de la región o del buffer."
  (let* ((use-region (use-region-p))
         (beg (if use-region (region-beginning) (point-min)))
         (end (if use-region (region-end)       (point-max)))
         (text (buffer-substring-no-properties beg end))
         (lang (or (and (boundp 'treesit-language-at) (treesit-language-at (point)))
                   (symbol-name major-mode))))
    (list beg end text lang)))

(defvar cursor-ai-system-prompts
  '((prog-mode . "Eres un asistente de programación. Da respuestas concisas, con código mínimo y correcto. Mantén el estilo del archivo. Si refactorizas, explica por qué en 1-3 viñetas.")
    (text-mode . "Eres un editor técnico. Mejora claridad y corrige gramática sin perder el tono.")
    (t . "Sé útil y directo."))
  "Prompts por modo mayor para IA.")

(defun cursor-ai--system-prompt ()
  (or (cdr (assoc-default major-mode cursor-ai-system-prompts
                          (lambda (mode key) (derived-mode-p key))))
      (cdr (assoc 't cursor-ai-system-prompts))))

(defun cursor-ai--send-with (instruction)
  "Envía región/buffer con INSTRUCTION al panel gptel."
  (interactive)
  (pcase-let ((`(,beg ,end ,text ,lang) (cursor-ai--region-or-buffer)))
    (cursor-ai--open-chat)
    (with-current-buffer "*Cursor-Chat*"
      (setq-local gptel-system-message (cursor-ai--system-prompt))
      (gptel-send
       (format
        (concat
         "### Contexto (%s)\n```%s\n%s\n```\n\n"
         "### Instrucción\n%s\n"
         "Responde con el resultado final en un único bloque de código.")
        (file-name-nondirectory (or (buffer-file-name (current-buffer)) "buffer"))
        (if (string-match "emacs-lisp" (or lang "")) "elisp" lang)
        text instruction)))))

;; Acciones estilo Cursor (Refactor/Explain/Docstring/Test)
(defun cursor-ai-refactor () (interactive)
       (cursor-ai--send-with "Refactoriza sin cambiar comportamiento ni APIs públicas; optimiza legibilidad y complejidad."))

(defun cursor-ai-explain () (interactive)
       (cursor-ai--send-with "Explica el código como notas de revisión en no más de 10 líneas."))

(defun cursor-ai-docstring () (interactive)
       (cursor-ai--send-with "Genera/actualiza docstrings idiomáticas para las funciones presentes."))

(defun cursor-ai-tests () (interactive)
       (cursor-ai--send-with "Propón tests unitarios concisos para el código dado, en el framework estándar del lenguaje."))

;; Aplicar el último bloque de código de la respuesta al punto/selección
(defun cursor-ai-apply-last-code-block ()
  "Copia el último ```bloque``` del chat y reemplaza la región o inserta en punto."
  (interactive)
  (let* ((src (get-buffer "*Cursor-Chat*"))
         (code nil))
    (unless src (user-error "No hay *Cursor-Chat* con respuesta"))
    (with-current-buffer src
      (save-excursion
        (goto-char (point-max))
        (when (re-search-backward "```\\([[:alpha:]-]+\\)?\\([\n\r]+\\)\\(\\(?:.\\|\n\\)*?\\)```" nil t)
          (setq code (match-string-no-properties 3)))))
    (unless code (user-error "No encontré bloque de código en la respuesta"))
    (pcase-let ((`(,beg ,end ,_ ,_) (cursor-ai--region-or-buffer)))
      (delete-region beg end)
      (insert code))))

;; Asignación de teclas (prefijo C-c a …)
(define-key cursor-ai-map (kbd "c") #'cursor-ai--open-chat)           ;; C-c a c
(define-key cursor-ai-map (kbd "r") #'cursor-ai-refactor)             ;; C-c a r
(define-key cursor-ai-map (kbd "e") #'cursor-ai-explain)              ;; C-c a e
(define-key cursor-ai-map (kbd "d") #'cursor-ai-docstring)            ;; C-c a d
(define-key cursor-ai-map (kbd "t") #'cursor-ai-tests)                ;; C-c a t
(define-key cursor-ai-map (kbd "a") #'cursor-ai-apply-last-code-block);; C-c a a
(define-key cursor-ai-map (kbd "g") #'copilot-mode)                   ;; C-c a g (toggle ghost-text)

;; which-key hints
(with-eval-after-load 'which-key
  (which-key-add-keymap-based-replacements
    cursor-ai-map
    "c" "Chat lateral"
    "r" "Refactor (región/buffer)"
    "e" "Explain (región/buffer)"
    "d" "Docstrings"
    "t" "Tests"
    "a" "Aplicar último bloque"
    "g" "Toggle Copilot"))

;;; --- Filtros mínimos de rendimiento --------------------------------
(setq read-process-output-max (* 4 1024 1024)) ; 4MB para LSP

(use-package acp
  :straight (acp :type git :host github :repo "xenodium/acp.el"))

(use-package agent-shell
  :straight (agent-shell :type git :host github :repo "xenodium/agent-shell"))
