;;; ai-suite.el --- AI-assisted workflows and integrations -*- lexical-binding: t; -*-

;;; Commentary:
;; Collects AI-centric helpers (chat, ghost text, agents, hydras) in a single
;; module so the rest of the configuration stays focused on core editing.

;;; Code:

(require 'core-bootstrap)
(require 'subr-x)
(require 'projectile nil t)
(require 'seq)

(use-package gptel
  :config
  (require 'auth-source nil t)
  (setq gptel-api-key
        (or (getenv "OPENAI_API_KEY")
            (when-let* ((secret (car (auth-source-search :max 1
                                                         :host "api.openai.com"
                                                         :user "apikey"))))
              (let ((value (plist-get secret :secret)))
                (if (functionp value) (funcall value) value)))))
  (setq gptel-model 'gpt-5.2)
  
  (unless gptel-api-key
    (message "gptel: missing OPENAI_API_KEY. Set an env var or auth-source entry."))
  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '(gpt-oss:latest)))

(use-package copilot
  :hook ((prog-mode . copilot-mode)
         (text-mode . copilot-mode))
  :custom
  (copilot-enable-predicates '(cursor-ai--copilot-typing-state-p
                               copilot--buffer-changed
                               cursor-ai--copilot-input-sufficient-p))
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB"   . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("M-<tab>" . copilot-accept-completion-by-line)))

(defun cursor-ai--copilot-input-sufficient-p ()
  "Return t when current line has more than three non-whitespace chars before point."
  (let ((content (string-trim
                  (buffer-substring-no-properties
                   (line-beginning-position) (point)))))
    (> (length content) 3)))

(defun cursor-ai--copilot-typing-state-p ()
  "Allow Copilot suggestions while actively typing."
  (if (bound-and-true-p evil-local-mode)
      (memq evil-state '(insert emacs))
    t))

(define-prefix-command 'cursor-ai-map)
(global-set-key (kbd "C-c A") #'cursor-ai-map)

(define-prefix-command 'cursor-ai-shell-map)

(declare-function agent-shell "agent-shell" (&optional new-shell))
(declare-function agent-shell-toggle "agent-shell" ())
(declare-function agent-shell-interrupt "agent-shell" ())
(declare-function agent-shell-view-traffic "agent-shell" ())
(declare-function agent-shell-view-acp-logs "agent-shell" ())
(declare-function agent-shell-reset-logs "agent-shell" ())
(declare-function agent-shell-project-buffers "agent-shell" ())
(declare-function agent-shell-insert "agent-shell" (&rest args))
(declare-function agent-shell-add-region "agent-shell" ())
(declare-function chatgpt-shell-start "chatgpt-shell"
                  (&optional no-focus new-session ignore-as-primary model-version system-prompt))
(declare-function chatgpt-shell-send-region "chatgpt-shell" (&optional review))

;; Declared for byte-compilation and dynamic let-binding before chatgpt-shell loads.
(defvar chatgpt-shell-model-version nil)

(defun cursor-ai--ensure-agent-shell ()
  "Ensure there's an agent-shell ready for the current project.
Returns the selected shell buffer name."
  (unless (require 'agent-shell nil t)
    (user-error "agent-shell no está instalado; revisa tu configuración"))
  (or (seq-first (agent-shell-project-buffers))
      (progn
        (call-interactively #'agent-shell)
        (or (seq-first (agent-shell-project-buffers))
            (user-error "No se inició ningún agent-shell para este proyecto")))))

(defun cursor-ai--default-ai-input ()
  "Return sensible default prompt text based on context."
  (cond
   ((use-region-p)
    (buffer-substring-no-properties (region-beginning) (region-end)))
   ((derived-mode-p 'prog-mode)
    (when-let ((thing (thing-at-point 'defun t)))
      (string-trim thing)))
   (t nil)))

(defun acp-prompt (prompt &optional keep-open)
  "Enviar PROMPT al agent-shell activo.
Con prefijo KEEP-OPEN, solo inserta el texto en el shell sin enviarlo."
  (interactive
   (list (read-string "Prompt ACP: " (cursor-ai--default-ai-input))
         current-prefix-arg))
  (let ((shell (cursor-ai--ensure-agent-shell)))
    (agent-shell-insert :text prompt :submit (not keep-open))
    (message "Prompt enviado a agent-shell (%s)%s"
             shell
             (if keep-open " (sin ejecutar)" ""))))

(defun acp-insert (text &optional submit)
  "Insertar TEXT en agent-shell y, opcionalmente, enviarlo.
Con prefijo SUBMIT, envía inmediatamente el contenido."
  (interactive
   (list (read-string "Insertar en agent-shell: " (cursor-ai--default-ai-input))
         current-prefix-arg))
  (let ((shell (cursor-ai--ensure-agent-shell)))
    (agent-shell-insert :text text :submit submit)
    (message "Texto insertado en agent-shell (%s)%s"
             shell
             (if submit " y enviado" ""))))

(defun acp-on-region ()
  "Adjuntar la región activa al agent-shell del proyecto."
  (interactive)
  (cursor-ai--ensure-agent-shell)
  (agent-shell-add-region)
  (message "Región enviada al agent-shell"))

(defvar cursor-ai--chat-window-width 84
  "Width for the AI chat window on the right.")

(defconst cursor-ai--chat-buffer-name "*Cursor-Chat*"
  "Buffer name used for the persistent AI chat window.")

(defun cursor-ai--open-chat ()
  "Open a persistent gptel chat window on the right."
  (interactive)
  (let ((buf (gptel cursor-ai--chat-buffer-name nil nil nil)))
    (unless (get-buffer-window buf)
      (condition-case nil
          (progn
            (split-window-right)
            (other-window 1))
        (error (display-buffer buf))))
    (switch-to-buffer buf)
    (let* ((win (get-buffer-window buf))
           (target (- cursor-ai--chat-window-width (window-width win))))
      (when (window-live-p win)
        (condition-case nil
            (window-resize win target t)
          (error nil))))))

(defun cursor-ai--region-or-buffer ()
  "Return (beg end text lang) for active region or whole buffer."
  (let* ((use-region (use-region-p))
         (beg (if use-region (region-beginning) (point-min)))
         (end (if use-region (region-end)       (point-max)))
         (text (buffer-substring-no-properties beg end))
         (lang (or (and (fboundp 'treesit-language-at)
                        (treesit-language-at (point)))
                   (symbol-name major-mode))))
    (list beg end text lang)))

(defvar cursor-ai-system-prompts
  '((prog-mode . "Eres un asistente de programación. Da respuestas concisas, con código mínimo y correcto. Mantén el estilo del archivo. Si refactorizas, explica por qué en 1-3 viñetas.")
    (text-mode . "Eres un editor técnico. Mejora claridad y corrige gramática sin perder el tono.")
    (t . "Sé útil y directo."))
  "Prompts por modo mayor para IA.")

(defun cursor-ai--system-prompt ()
  (or (assoc-default major-mode cursor-ai-system-prompts
                     (lambda (_mode key) (derived-mode-p key)))
      (cdr (assoc 't cursor-ai-system-prompts))))

(defun cursor-ai--send-with (instruction)
  "Send region or buffer with INSTRUCTION to the AI chat."
  (interactive)
  (let* ((source-file (buffer-file-name))
         (source-name (or (and source-file (file-name-nondirectory source-file))
                          (buffer-name))))
    (pcase-let ((`(_ _ ,text ,lang) (cursor-ai--region-or-buffer)))
      (cursor-ai--open-chat)
      (with-current-buffer cursor-ai--chat-buffer-name
        (setq-local gptel-system-message (cursor-ai--system-prompt))
        (gptel-send
         (format
          (concat
           "### Contexto (%s)\n```%s\n%s\n```\n\n"
           "### Instrucción\n%s\n"
           "Responde con el resultado final en un único bloque de código.")
          source-name
          (if (string-match "emacs-lisp" (or lang "")) "elisp" lang)
          text instruction))))))

(defun cursor-ai-refactor ()
  "Refactor current region or buffer."
  (interactive)
  (cursor-ai--send-with "Refactoriza sin cambiar comportamiento ni APIs públicas; optimiza legibilidad y complejidad."))

(defun cursor-ai-explain ()
  "Explain current region or buffer."
  (interactive)
  (cursor-ai--send-with "Explica el código como notas de revisión en no más de 10 líneas."))

(defun cursor-ai-docstring ()
  "Generate docstrings for current region or buffer."
  (interactive)
  (cursor-ai--send-with "Genera/actualiza docstrings idiomáticas para las funciones presentes."))

(defun cursor-ai-tests ()
  "Generate tests for current region or buffer."
  (interactive)
  (cursor-ai--send-with "Propón tests unitarios concisos para el código dado, en el framework estándar del lenguaje."))

(defun cursor-ai-apply-last-code-block ()
  "Apply the last ```code``` block from the chat to the buffer."
  (interactive)
  (let* ((src (get-buffer cursor-ai--chat-buffer-name))
         (code nil))
    (unless src (user-error "No hay %s con respuesta" cursor-ai--chat-buffer-name))
    (with-current-buffer src
      (save-excursion
        (goto-char (point-max))
        (when (re-search-backward "```\\([[:alpha:]-]+\\)?\\([\n\r]+\\)\\(\\(?:.\\|\n\\)*?\\)```" nil t)
          (setq code (match-string-no-properties 3)))))
    (unless code (user-error "No encontré bloque de código en la respuesta"))
    (pcase-let ((`(,beg ,end ,_ ,_) (cursor-ai--region-or-buffer)))
      (delete-region beg end)
      (insert code))))

(defun cursor-ai-chatgpt-shell-send-buffer (&optional review)
  "Send whole buffer to `chatgpt-shell'.
With prefix REVIEW, prompt before submitting."
  (interactive "P")
  (save-restriction
    (widen)
    (if (= (point-min) (point-max))
        (user-error "El buffer está vacío")
      (save-excursion
        (goto-char (point-min))
        (push-mark (point-max) t t)
        (let ((mark-active t)
              (transient-mark-mode t))
          (cursor-ai-chatgpt-shell-send-region review))))))

(defun cursor-ai-chatgpt-shell (&optional new-session)
  "Start `chatgpt-shell' using a supported model.
With prefix NEW-SESSION, start a separate session."
  (interactive "P")
  (let ((model (or (cursor-ai--chatgpt-shell-default-model)
                   chatgpt-shell-model-version)))
    (chatgpt-shell-start nil new-session nil model)))

(defun cursor-ai-chatgpt-shell-send-region (&optional review)
  "Send active region to `chatgpt-shell' using a supported model.
With prefix REVIEW, allow prompt editing before sending."
  (interactive "P")
  (unless (use-region-p)
    (user-error "No hay región activa"))
  (let ((chatgpt-shell-model-version
         (or (cursor-ai--chatgpt-shell-default-model)
             chatgpt-shell-model-version)))
    (chatgpt-shell-send-region review)))

(defun cursor-ai--chatgpt-shell-default-model ()
  "Return a sensible model version available in `chatgpt-shell-models'."
  (let* ((models (and (boundp 'chatgpt-shell-models) chatgpt-shell-models))
         (versions (delq nil (mapcar (lambda (model) (alist-get :version model))
                                     models)))
         (preferred (seq-find (lambda (model) (member model versions))
                              '("gpt-5-mini" "gpt-5" "gpt-5.1" "gpt-4.1-mini"
                                "gpt-4o-mini")))
         (openai-model (seq-find (lambda (model)
                                   (string= (or (alist-get :provider model) "")
                                            "OpenAI"))
                                 models)))
    (or preferred
        (and openai-model (alist-get :version openai-model))
        (car versions))))

(define-key cursor-ai-map (kbd "c") #'cursor-ai--open-chat)
(define-key cursor-ai-map (kbd "r") #'cursor-ai-refactor)
(define-key cursor-ai-map (kbd "e") #'cursor-ai-explain)
(define-key cursor-ai-map (kbd "d") #'cursor-ai-docstring)
(define-key cursor-ai-map (kbd "t") #'cursor-ai-tests)
(define-key cursor-ai-map (kbd "a") #'cursor-ai-apply-last-code-block)
(define-key cursor-ai-map (kbd "g") #'copilot-mode)
;; Shell actions hang off C-c A s to avoid collisions with editing/search keys.
(define-key cursor-ai-map (kbd "s") #'cursor-ai-shell-map)

(with-eval-after-load 'which-key
  (which-key-add-keymap-based-replacements
    cursor-ai-map
    "c" "Chat lateral"
    "r" "Refactor (región/buffer)"
    "e" "Explain (región/buffer)"
    "d" "Docstrings"
    "t" "Tests"
    "a" "Aplicar último bloque"
    "g" "Toggle Copilot"
    "s" "Agent-shell actions"
    "p" "Enviar prompt (agent-shell)"
    "i" "Insertar en agent-shell"
    "o" "Enviar región a agent-shell")
  (which-key-add-keymap-based-replacements
    cursor-ai-shell-map
    "a" "Abrir agent-shell"
    "t" "Toggle agent-shell"
    "i" "Interrumpir"
    "v" "Ver tráfico"
    "l" "Ver logs ACP"
    "r" "Resetear logs")
  (which-key-add-key-based-replacements
    "C-c i" "AI Menu"
    "C-c A" "AI Actions"
    "C-c m" "AI Models"
    "C-c A C" "ChatGPT"))

(use-package acp
  :straight (acp :type git :host github :repo "xenodium/acp.el")
  :commands (acp-prompt acp-insert acp-on-region)
  :bind (:map cursor-ai-map
              ("p" . acp-prompt)
              ("i" . acp-insert)
              ("o" . acp-on-region)))

(use-package agent-shell
  :straight (agent-shell :type git :host github :repo "xenodium/agent-shell")
  :commands (agent-shell agent-shell-toggle agent-shell-interrupt
                         agent-shell-view-traffic agent-shell-view-acp-logs
                         agent-shell-reset-logs)
  :init
  (define-key cursor-ai-shell-map (kbd "a") #'agent-shell)
  (define-key cursor-ai-shell-map (kbd "t") #'agent-shell-toggle)
  (define-key cursor-ai-shell-map (kbd "i") #'agent-shell-interrupt)
  (define-key cursor-ai-shell-map (kbd "v") #'agent-shell-view-traffic)
  (define-key cursor-ai-shell-map (kbd "l") #'agent-shell-view-acp-logs)
  (define-key cursor-ai-shell-map (kbd "r") #'agent-shell-reset-logs))

(use-package ellama
  :straight (ellama :type git :host github :repo "s-kostyaev/ellama")
  :init
  (setopt ellama-language "Spanish")
  (require 'llm-ollama)
  (setopt ellama-provider
          (make-llm-ollama
           :chat-model "gpt-oss:latest"
           :embedding-model "nomic-embed-text"
           :host "localhost"
           :port 11434))
  :bind (("C-c m c" . ellama-chat)
         ("C-c m a" . ellama-ask-about)
         ("C-c m l" . ellama-ask-line)
         ("C-c m s" . ellama-ask-selection)
         ("C-c m d" . ellama-define-word)
         ("C-c m i" . ellama-improve-wording)
         ("C-c m g" . ellama-improve-grammar)
         ("C-c m w" . ellama-complete)
         ("C-c m r" . ellama-code-review)
         ("C-c m x" . ellama-code-add)))

(use-package chatgpt-shell
  :straight (chatgpt-shell :type git :host github :repo "xenodium/chatgpt-shell")
  :init
  (defun cursor-ai--chatgpt-shell-recover-variables (orig &rest args)
    "Recover from corrupted chatgpt-shell variables file."
    (condition-case err
        (apply orig args)
      ((end-of-file invalid-read-syntax)
       (when (boundp 'chatgpt-shell-root-path)
         (let ((vars-file (expand-file-name ".chatgpt-shell.el" chatgpt-shell-root-path)))
           (when (file-exists-p vars-file)
             (rename-file vars-file (concat vars-file ".bak") t))))
       (when (fboundp 'chatgpt-shell--save-variables)
         (chatgpt-shell--save-variables))
       (message "chatgpt-shell: variables corrupt, regenerating (%s)" err))))
  (advice-add 'chatgpt-shell--load-variables :around
              #'cursor-ai--chatgpt-shell-recover-variables)
  (let ((chatgpt-shell-state-dir
         (file-name-as-directory (cursor-ai--state-path "cache" "chatgpt-shell"))))
    (make-directory chatgpt-shell-state-dir t)
    (setq shell-maker-root-path chatgpt-shell-state-dir))
  :bind (("C-c A C-s" . cursor-ai-chatgpt-shell)
         ("C-c A C-r" . cursor-ai-chatgpt-shell-send-region)
         ("C-c A C-b" . cursor-ai-chatgpt-shell-send-buffer))
  :config
  (setq chatgpt-shell-openai-key gptel-api-key)
  (when-let ((model (cursor-ai--chatgpt-shell-default-model)))
    (setq chatgpt-shell-model-version model)))

(use-package org-ai
  :straight (org-ai :type git :host github :repo "rksm/org-ai")
  :hook (org-mode . org-ai-mode)
  :bind (:map org-mode-map
              ("C-c M-a" . org-ai-prompt)
              ("C-c M-s" . org-ai-summarize)
              ("C-c M-r" . org-ai-refactor-code))
  :config
  (setq org-ai-default-chat-model "gpt-4")
  (org-ai-global-mode))

(use-package mcp-server
  :straight (:type git :host github :repo "rhblind/emacs-mcp-server"
		   :files ("*.el" "tools/*.el" "mcp-wrapper.py" "mcp-wrapper.sh"))
  :config
  (setq mcp-server-socket-directory "~/.emacs.d/.local/cache/")

  ;; Modo Permisivo: Control total al LLM (INSEGURO - Solo para desarrollo)
  ;; Desactiva todos los prompts de seguridad
  (setq mcp-server-security-prompt-for-permissions nil)

  ;; Mueve todas las funciones peligrosas a permitidas sin preguntar
  (setq mcp-server-security-allowed-dangerous-functions
        '(browse-url call-process copy-file delete-directory delete-file
		     dired eval find-file find-file-literally find-file-noselect
		     getenv insert-file-contents kill-emacs load make-directory
		     process-environment rename-file require save-buffers-kill-emacs
		     save-buffers-kill-terminal save-current-buffer server-force-delete
		     server-start set-buffer set-file-modes set-file-times shell-command
		     shell-command-to-string shell-environment start-process
		     switch-to-buffer url-retrieve url-retrieve-synchronously view-file
		     with-current-buffer write-region))

  ;; Vacía la lista de funciones peligrosas (todas están en allowed ahora)
  (setq mcp-server-security-dangerous-functions nil)

  ;; Minimiza archivos sensibles (solo los más críticos)
  (setq mcp-server-security-sensitive-file-patterns
        '("~/.ssh/id_rsa" "~/.gnupg/secring.gpg"))

  (add-hook 'emacs-startup-hook #'mcp-server-start-unix))

(defvar mcp-servers
  '((filesystem . (:command "npx" :args ("-y" "@modelcontextprotocol/server-filesystem" "/")))
    (git . (:command "npx" :args ("-y" "@modelcontextprotocol/server-git")))
    (github . (:command "npx" :args ("-y" "@modelcontextprotocol/server-github")))
    (brave-search . (:command "npx" :args ("-y" "@modelcontextprotocol/server-brave-search")))
    (postgres . (:command "npx" :args ("-y" "@modelcontextprotocol/server-postgres"))))
  "Lista de servidores MCP disponibles.")

(defun mcp-start-server (server-name)
  "Start an MCP server by name."
  (interactive
   (list (intern (completing-read "MCP Server: "
                                  (mapcar #'car mcp-servers)))))
  (let* ((server-config (alist-get server-name mcp-servers))
         (command (plist-get server-config :command))
         (args (plist-get server-config :args)))
    (message "Starting MCP server: %s" server-name)
    (apply #'start-process (format "mcp-%s" server-name)
           (format "*mcp-%s*" server-name)
           command
           args)))

(defun mcp-list-tools ()
  "Display available MCP tools."
  (interactive)
  (with-current-buffer (get-buffer-create "*MCP Tools*")
    (erase-buffer)
    (insert "# MCP Available Tools\n\n")
    (dolist (server mcp-servers)
      (insert (format "## %s\n" (car server))))
    (display-buffer (current-buffer))))

(defun gptel-with-mcp (prompt &optional context)
  "Send PROMPT to gptel with optional CONTEXT."
  (interactive "sPrompt: ")
  (let ((full-prompt
         (concat
          (when context (format "Context: %s\n\n" context))
          prompt
          "\n\nUse available MCP tools if needed.")))
    (gptel-send full-prompt)))

(global-set-key (kbd "C-c m m") #'mcp-start-server)
(global-set-key (kbd "C-c m t") #'mcp-list-tools)
(global-set-key (kbd "C-c m q") #'gptel-with-mcp)

(defun ai-get-project-context ()
  "Gather lightweight project context for prompts."
  (let* ((project (project-current))
         (root (when project (project-root project)))
         (git-branch (when root
                       (with-temp-buffer
                         (when (zerop (call-process "git" nil t nil "branch" "--show-current"))
                           (string-trim (buffer-string))))))
         (context (format "Project: %s\nBranch: %s\n"
                          (or root "No project")
                          (or git-branch "No git"))))
    context))

(defun ai-analyze-project ()
  "Request a high-level project analysis from the AI."
  (interactive)
  (let ((context (ai-get-project-context))
        (files (when (fboundp 'projectile-current-project-files)
                 (projectile-current-project-files))))
    (gptel-with-mcp
     (format "Analiza este proyecto:\n%s\nArchivos principales: %s"
             context
             (if files
                 (string-join (seq-take files 10) ", ")
               "No files available")))))

(defun ai-agent-task (task)
  "Run TASK via agent-shell with project context."
  (interactive "sTask: ")
  (let ((context (ai-get-project-context))
        (buffer (get-buffer-create "*AI Agent Task*")))
    (with-current-buffer buffer
      (erase-buffer)
      (insert (format "=== AI Agent Task ===\n\nTask: %s\n\nContext:\n%s\n\nExecuting...\n"
                      task context)))
    (display-buffer buffer)
    (cursor-ai--ensure-agent-shell)
    (agent-shell-insert
     :text (format "Task: %s\nContext: %s\n\nYou have access to: bash, python, file operations, web search. Complete the task step by step."
                   task context)
     :submit t)))

(defun ai-code-architect (feature)
  "Ask the AI to design an architecture for FEATURE."
  (interactive "sFeature to design: ")
  (let ((context (ai-get-project-context)))
    (gptel-send
     (format "Actúa como arquitecto de software. Diseña la arquitectura para:\n\nFeature: %s\n\nProyecto:\n%s\n\nProvee:\n1. Estructura de archivos\n2. Componentes principales\n3. Flujo de datos\n4. Consideraciones de seguridad/performance"
             feature context))))

(defun ai-debug-assistant ()
  "Send surrounding code and warnings to AI for debugging help."
  (interactive)
  (let* ((error-buffer (get-buffer "*Warnings*"))
         (error-text (when error-buffer
                       (with-current-buffer error-buffer
                         (buffer-substring-no-properties (point-min) (point-max)))))
         (current-code (buffer-substring-no-properties
                        (max (point-min) (- (point) 500))
                        (min (point-max) (+ (point) 500)))))
    (cursor-ai--open-chat)
    (with-current-buffer "*Cursor-Chat*"
      (gptel-send
       (format "Ayúdame a debuggear:\n\nCódigo actual:\n```\n%s\n```\n\nErrores:\n%s\n\nExplica el problema y sugiere solución."
               current-code
               (or error-text "No errors in buffer"))))))

(defun ai-multi-agent-review ()
  "Run three specialised reviews (security, performance, best practices)."
  (interactive)
  (let ((code (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-substring-no-properties (point-min) (point-max)))))
    (save-excursion
      (cursor-ai--open-chat)
      (with-current-buffer "*Cursor-Chat*"
        (gptel-send
         (format "Revisar SOLO seguridad:\n```\n%s\n```\n\nBusca vulnerabilidades, injection, XSS, etc."
                 code)))
      (let ((perf-buf (get-buffer-create "*AI-Performance-Review*")))
        (with-current-buffer perf-buf
          (gptel-send
           (format "Revisar SOLO performance:\n```\n%s\n```\n\nOptimizaciones, complejidad, memory leaks."
                   code))
          (display-buffer perf-buf)))
      (let ((bp-buf (get-buffer-create "*AI-BestPractices-Review*")))
        (with-current-buffer bp-buf
          (gptel-send
           (format "Revisar SOLO best practices:\n```\n%s\n```\n\nPatrones, nomenclatura, estructura."
                   code))
          (display-buffer bp-buf))))))

(defun ai-generate-comprehensive-tests ()
  "Ask AI to propose comprehensive tests for the buffer."
  (interactive)
  (let* ((code (buffer-substring-no-properties (point-min) (point-max)))
         (filename (buffer-file-name))
         (lang (file-name-extension (or filename ""))))
    (gptel-send
     (format "Genera tests comprehensivos para:\n\nFile: %s\n\n```%s\n%s\n```\n\nIncluye:\n- Unit tests\n- Integration tests\n- Edge cases\n- Mocks necesarios\n\nUsa el framework estándar para %s"
             filename lang code lang))))

(defun ai-search-docs-and-ask (query)
  "Search local docs with QUERY and feed the results to GPT."
  (interactive "sQuery: ")
  (let* ((rg-bin (executable-find "rg"))
         (project-root (when (and (fboundp 'projectile-project-p)
                                  (projectile-project-p))
                         (projectile-project-root))))
    (unless project-root
      (user-error "ai-search-docs-and-ask: no estás en un proyecto Projectile"))
    (unless rg-bin
      (user-error "ai-search-docs-and-ask: no se encontró rg en PATH"))
    (let ((search-results
           (with-temp-buffer
             (call-process rg-bin nil t nil "-i" "-m" "5" query project-root)
             (buffer-string))))
      (gptel-send
       (format "Pregunta: %s\n\nContexto de la documentación:\n```\n%s\n```\n\nResponde basándote en este contexto."
               query search-results)))))

(use-package hydra)

(defhydra hydra-ai-menu (:color blue :hint nil)
  "
^Chat/Interacción^         ^Code Actions^           ^Análisis^              ^Tools/Agentes^
^^^^^^^^---------------------------------------------------------------------------------------
_c_: Cursor Chat           _r_: Refactor            _p_: Analyze Project    _m_: Start MCP Server
_e_: Ellama Chat           _d_: Docstring           _v_: Multi-Agent Review _s_: Agent Shell
_g_: ChatGPT Shell         _t_: Generate Tests      _b_: Debug Assistant    _a_: Agent Task
_o_: Org-AI                _i_: Improve Code        _h_: Search Docs+Ask    _l_: List MCP Tools
^^                         _x_: Code Architect      ^^                      _q_: GPTel with MCP
^^                         _n_: Apply Last Block    ^^                      ^^
"
  ("c" cursor-ai--open-chat)
  ("e" ellama-chat)
  ("g" chatgpt-shell)
  ("o" org-ai-prompt)
  ("r" cursor-ai-refactor)
  ("d" cursor-ai-docstring)
  ("t" ai-generate-comprehensive-tests)
  ("i" ellama-improve-wording)
  ("x" ai-code-architect)
  ("n" cursor-ai-apply-last-code-block)
  ("p" ai-analyze-project)
  ("v" ai-multi-agent-review)
  ("b" ai-debug-assistant)
  ("h" ai-search-docs-and-ask)
  ("m" mcp-start-server)
  ("s" agent-shell)
  ("a" ai-agent-task)
  ("l" mcp-list-tools)
  ("q" gptel-with-mcp)
  ("SPC" nil "quit" :color pink))

(global-set-key (kbd "C-c i") #'hydra-ai-menu/body)

(provide 'ai-suite)

;;; ai-suite.el ends here
