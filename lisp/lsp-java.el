;;; lsp-java.el --- Java IDE configuration with Eclipse JDT LS -*- lexical-binding: t; -*-

;;; Commentary:
;; Comprehensive Java development environment using Eclipse JDT Language Server.
;; Provides Eclipse-like features: code completion, debugging, refactoring,
;; testing, project management, and more.

;;; Code:

(require 'core-bootstrap)

;;; LSP Java - Eclipse JDT Language Server integration
(use-package lsp-java
  :after lsp-mode
  :demand t
  :custom
  ;; Server configuration
  (lsp-java-server-install-dir
   (expand-file-name "eclipse.jdt.ls" lsp-server-install-dir))

  ;; Workspace configuration
  (lsp-java-workspace-dir
   (expand-file-name "workspace" (cursor-ai--state-path "lsp-java")))
  (lsp-java-workspace-cache-dir
   (expand-file-name "cache" (cursor-ai--state-path "lsp-java")))

  ;; VM Arguments - Optimized for performance (based on Eclipse defaults)
  (lsp-java-vmargs
   '("-XX:+UseParallelGC"
     "-XX:GCTimeRatio=4"
     "-XX:AdaptiveSizePolicyWeight=90"
     "-Dsun.zip.disableMemoryMapping=true"
     "-Xmx4G"      ;; 4GB max heap (adjust based on your system)
     "-Xms256m"))  ;; 256MB initial heap

  ;; Import/Export settings
  (lsp-java-import-gradle-enabled t)
  (lsp-java-import-maven-enabled t)
  (lsp-java-maven-download-sources t)
  (lsp-java-import-exclusions
   ["**/node_modules/**" "**/.metadata/**" "**/archetype-resources/**" "**/META-INF/maven/**"])

  ;; Code completion settings (Eclipse-like)
  (lsp-java-completion-enabled t)
  (lsp-java-completion-guess-method-arguments t)
  (lsp-java-completion-overwrite nil) ;; Insert instead of overwrite
  (lsp-java-completion-favorite-static-members
   ["org.junit.Assert.*"
    "org.junit.jupiter.api.Assertions.*"
    "org.mockito.Mockito.*"
    "org.mockito.ArgumentMatchers.*"
    "org.hamcrest.Matchers.*"
    "org.hamcrest.CoreMatchers.*"])

  ;; Code lens (show references and implementations like Eclipse)
  (lsp-java-references-code-lens-enabled t)
  (lsp-java-implementations-code-lens-enabled t)

  ;; Formatting
  (lsp-java-format-enabled t)
  (lsp-java-format-on-type-enabled t)
  (lsp-java-format-comments-enabled t)

  ;; Save actions (like Eclipse)
  (lsp-java-save-actions-organize-imports t)

  ;; Auto build (like Eclipse's automatic compilation)
  (lsp-java-autobuild-enabled t)
  (lsp-java-max-concurrent-builds 2)

  ;; Code generation settings (Eclipse-style)
  (lsp-java-code-generation-hash-code-equals-use-java7objects t)
  (lsp-java-code-generation-hash-code-equals-use-instanceof t)
  (lsp-java-code-generation-use-blocks t)
  (lsp-java-code-generation-generate-comments t)
  (lsp-java-code-generation-to-string-template
   "${object.className} [${member.name()}=${member.value}, ${otherMembers}]")

  ;; Signature help (parameter hints like Eclipse)
  (lsp-java-signature-help-enabled t)

  ;; Progress reports
  (lsp-java-progress-reports-enabled t)

  ;; Error severity
  (lsp-java-errors-incomplete-classpath-severity 'warning)
  )

;;; DAP Mode - Debug Adapter Protocol (Eclipse-like debugging)
(use-package dap-mode
  :after lsp-mode
  :commands (dap-mode dap-ui-mode dap-debug)
  :hook ((lsp-mode . dap-mode)
         (lsp-mode . dap-ui-mode))
  :custom
  (dap-auto-configure-mode t)
  (dap-ui-controls-mode t)

  :config
  ;; Enable auto-configuration features
  (dap-auto-configure-mode 1)

  ;; Tooltip on hover
  (tooltip-mode 1)

  ;; UI features (like Eclipse debug perspective)
  (require 'dap-ui)
  (dap-ui-mode 1)

  ;; Controls in the UI
  (dap-ui-controls-mode 1)

  ;; Keybindings for debugging
  (define-key dap-mode-map (kbd "<f5>") #'dap-debug)
  (define-key dap-mode-map (kbd "<f6>") #'dap-next)
  (define-key dap-mode-map (kbd "<f7>") #'dap-step-in)
  (define-key dap-mode-map (kbd "<f8>") #'dap-step-out)
  (define-key dap-mode-map (kbd "<f9>") #'dap-breakpoint-toggle)
  (define-key dap-mode-map (kbd "C-<f5>") #'dap-disconnect))

;;; DAP Java - Java debugging support
(with-eval-after-load 'dap-mode
  (when (require 'dap-java nil t)
    ;; Configure Java debugging templates when available.
    (when (fboundp 'dap-java-setup)
      (dap-java-setup))))

;;; LSP Treemacs - Project explorer integration (Eclipse Package Explorer)
(use-package lsp-treemacs
  :after (lsp-mode treemacs)
  :commands (lsp-treemacs-sync-mode
             lsp-treemacs-symbols
             lsp-treemacs-errors-list
             lsp-treemacs-java-deps-list)
  :custom
  (lsp-treemacs-sync-mode 1)

  :config
  ;; Sync treemacs with project changes
  (lsp-treemacs-sync-mode 1)

  ;; Keybindings
  (define-key lsp-mode-map (kbd "C-c t s") #'lsp-treemacs-symbols)
  (define-key lsp-mode-map (kbd "C-c t e") #'lsp-treemacs-errors-list)
  (define-key lsp-mode-map (kbd "C-c t r") #'lsp-treemacs-references)
  (define-key lsp-mode-map (kbd "C-c t i") #'lsp-treemacs-implementations)
  (define-key lsp-mode-map (kbd "C-c t d") #'lsp-treemacs-java-deps-list))

;;; Company - Code completion backend
(use-package company
  :hook ((java-mode . company-mode)
         (lsp-mode . company-mode))
  :custom
  (company-minimum-prefix-length 1)
  (company-idle-delay 0.1)
  (company-selection-wrap-around t)
  (company-tooltip-align-annotations t)
  (company-tooltip-flip-when-above t)
  (company-show-numbers t) ;; Quick selection with M-<number>

  :bind (:map company-active-map
              ("<tab>" . company-complete-selection)
              ("C-n" . company-select-next)
              ("C-p" . company-select-previous)))

;;; Flycheck - Syntax checking (Eclipse-like error reporting)
(use-package flycheck
  :hook ((java-mode . flycheck-mode)
         (lsp-mode . flycheck-mode))
  :custom
  (flycheck-check-syntax-automatically '(save mode-enabled))
  (flycheck-display-errors-delay 0.3))

;;; Helm LSP - Better navigation (alternative to counsel-lsp)
(use-package helm-lsp
  :after (lsp-mode helm)
  :commands (helm-lsp-workspace-symbol
             helm-lsp-global-workspace-symbol)
  :bind (:map lsp-mode-map
              ("C-c h s" . helm-lsp-workspace-symbol)
              ("C-c h g" . helm-lsp-global-workspace-symbol)))

;;; LSP Java Boot - Spring Boot support
(with-eval-after-load 'lsp-java
  (when (require 'lsp-java-boot nil t)
    (add-hook 'java-mode-hook #'lsp-java-boot-lens-mode)))

;;; LSP Java Test - JUnit test support (Eclipse test runner)
;; Note: lsp-jt is part of lsp-java
(with-eval-after-load 'lsp-java
  (when (require 'lsp-jt nil t)
    ;; Enable test lens mode for inline test running
    (add-hook 'java-mode-hook #'lsp-jt-lens-mode)))

;;; Hydra - Quick access menu for Java commands (like Eclipse quick access)
(use-package hydra
  :after lsp-java
  :config
  (defhydra hydra-lsp-java (:color blue :hint nil)
    "
╔════════════════════════════════════════════════════════════════╗
║                    Java Development Menu                       ║
╠════════════════════════════════════════════════════════════════╣
║ _o_: Organize Imports    _b_: Build Project    _r_: Rename     ║
║ _f_: Format Buffer       _e_: Extract Method   _c_: Extract    ║
║ _g_: Generate Getters    _s_: Generate Setter  _t_: ToString   ║
║ _h_: HashCode & Equals   _m_: Override Methods _i_: Implement  ║
║ _d_: Show Dependencies   _u_: Update Project   _p_: Type Hier  ║
║ _q_: Quit                                                      ║
╚════════════════════════════════════════════════════════════════╝
"
    ("o" lsp-java-organize-imports)
    ("b" lsp-java-build-project)
    ("r" lsp-rename)
    ("f" lsp-format-buffer)
    ("e" lsp-java-extract-method)
    ("c" lsp-java-extract-to-constant)
    ("g" lsp-java-generate-getters-and-setters)
    ("s" lsp-java-generate-getters-and-setters)
    ("t" lsp-java-generate-to-string)
    ("h" lsp-java-generate-equals-and-hash-code)
    ("m" lsp-java-generate-overrides)
    ("i" lsp-java-add-unimplemented-methods)
    ("d" lsp-java-dependency-list)
    ("u" lsp-java-update-project-configuration)
    ("p" lsp-java-type-hierarchy)
    ("q" nil))

  )

;;; Projectile integration - Enhanced with Java awareness
(with-eval-after-load 'projectile
  ;; Add Java-specific project types if not already present
  (projectile-register-project-type 'maven '("pom.xml")
                                    :project-file "pom.xml"
                                    :compile "mvn clean compile"
                                    :test "mvn test"
                                    :run "mvn spring-boot:run"
                                    :test-suffix "Test")

  (projectile-register-project-type 'gradle '("build.gradle" "build.gradle.kts")
                                    :project-file "build.gradle"
                                    :compile "gradle build"
                                    :test "gradle test"
                                    :run "gradle bootRun"
                                    :test-suffix "Test"))

;;; Additional Eclipse-like features

;; Auto-save configuration (like Eclipse auto-save)
(add-hook 'java-mode-hook
          (lambda ()
            (setq-local auto-save-visited-mode t)
            (auto-save-visited-mode 1)))

;; Show trailing whitespace (Eclipse shows this)
(add-hook 'java-mode-hook
          (lambda ()
            (setq show-trailing-whitespace t)))

;; Electric pair mode for auto-closing brackets (Eclipse does this)
(add-hook 'java-mode-hook #'electric-pair-local-mode)

;; Subword mode for camelCase navigation (Eclipse has this)
(add-hook 'java-mode-hook #'subword-mode)

;; Highlight current line in Java files
(add-hook 'java-mode-hook #'hl-line-mode)

;; Display line numbers (Eclipse shows these)
(add-hook 'java-mode-hook #'display-line-numbers-mode)

;;; Custom functions

(defun my/java-run-main ()
  "Run the main class of the current Java project."
  (interactive)
  (let ((project-type (projectile-project-type)))
    (pcase project-type
      ('maven (compile "mvn spring-boot:run"))
      ('gradle (compile "gradle bootRun"))
      (_ (message "Unknown project type. Please configure run command.")))))

(defun my/java-run-tests ()
  "Run all tests in the current Java project."
  (interactive)
  (let ((project-type (projectile-project-type)))
    (pcase project-type
      ('maven (compile "mvn test"))
      ('gradle (compile "gradle test"))
      (_ (message "Unknown project type. Please configure test command.")))))

(defun my/java-mode-setup-keys ()
  "Keybindings for Java buffers."
  (local-set-key (kbd "C-c C-o") #'lsp-java-organize-imports)
  (local-set-key (kbd "C-c C-b") #'lsp-java-build-project)
  (local-set-key (kbd "C-c C-r") #'lsp-rename)
  (local-set-key (kbd "C-c C-f") #'lsp-format-buffer)
  (local-set-key (kbd "C-c j") #'hydra-lsp-java/body)
  (local-set-key (kbd "C-c C-x r") #'my/java-run-main)
  (local-set-key (kbd "C-c C-x t") #'my/java-run-tests)
  (when (fboundp 'lsp-jt-browser)
    (local-set-key (kbd "C-c t t") #'lsp-jt-browser)
    (local-set-key (kbd "C-c t r") #'lsp-jt-report-open)))

(add-hook 'java-mode-hook #'my/java-mode-setup-keys)

;;; Message on successful load
(message "LSP Java configuration loaded successfully. Eclipse-like IDE ready!")

(provide 'lsp-java)

;;; lsp-java.el ends here
