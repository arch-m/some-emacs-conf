;;; tools-config.el --- Navigation and project tooling -*- lexical-binding: t; -*-

;;; Commentary:
;; Encapsulates project explorers, VCS helpers and terminal integration.

;;; Code:

(require 'core-bootstrap)
(declare-function consult--buffer-state "consult" ())
(declare-function dirvish--find-file-temporarily "dirvish" (name))
(declare-function dirvish-override-dired-mode "dirvish" ())
(declare-function dirvish-peek-mode "dirvish-peek" (&optional arg))
(declare-function dirvish-side-follow-mode "dirvish-side" (&optional arg))
(declare-function dired-get-file-for-visit "dired" (&optional no-error))
(declare-function cursor-ai/delete-other-windows-all "modal-editing" (&optional window))
(declare-function ediff-setup-windows-plain "ediff-wind" ())

(defvar ediff-window-setup-function)

(defvar cursor-ai--dirvish-preview-window nil
  "Window reserved for Dirvish previews triggered from completion UIs.")

(defvar cursor-ai--dirvish-preview-buffer nil
  "Buffer currently displayed in `cursor-ai--dirvish-preview-window'.")

(defvar cursor-ai--dirvish-preview-last nil
  "Remember the last file path rendered in the Dirvish preview window.")

;; Prefer the Straight-installed `transient' over the (usually older) bundled copy.
;; This avoids \"void-function transient--set-layout\" errors when packages such as
;; gptel load their transient menus before Straight has adjusted `load-path'.
(let ((transient-build-dir
       (cursor-ai--state-path "straight" "straight" "build" "transient")))
  (when (file-directory-p transient-build-dir)
    (add-to-list 'load-path transient-build-dir)))

(defun cursor-ai--dirvish-data-fallback (orig dir buffer inhibit-setup)
  "Wrap ORIG to guarantee a basic Dirvish data refresh for DIR in BUFFER.
This guards against `cl-no-applicable-method' when Dirvish generics are missing
specialisations (e.g. on older builds) by running the usual setup hook."
  (condition-case err
      (funcall orig dir buffer inhibit-setup)
    (cl-no-applicable-method
     (when (buffer-live-p buffer)
       (with-current-buffer buffer
         (unless inhibit-setup
           (run-hooks 'dirvish-setup-hook))))
     (message "Dirvish fallback: %s" err)
     nil)))

(defun cursor-ai--ensure-dirvish ()
  "Signal an error when Dirvish is unavailable."
  (unless (require 'dirvish nil 'noerror)
    (user-error "Dirvish no está instalado; instala el paquete antes de usar previsualizaciones")))

(defun cursor-ai--dirvish-preview-clear ()
  "Tear down the active Dirvish preview window and buffer."
  (when (buffer-live-p cursor-ai--dirvish-preview-buffer)
    (kill-buffer cursor-ai--dirvish-preview-buffer))
  (when (window-live-p cursor-ai--dirvish-preview-window)
    (delete-window cursor-ai--dirvish-preview-window))
  (setq cursor-ai--dirvish-preview-window nil
        cursor-ai--dirvish-preview-buffer nil
        cursor-ai--dirvish-preview-last nil))

(defun cursor-ai--dirvish-preview-display (file)
  "Render FILE inside the dedicated Dirvish preview window."
  (cursor-ai--ensure-dirvish)
  (let* ((absolute (expand-file-name file))
         (pair (dirvish--find-file-temporarily absolute))
         (buffer (and (consp pair) (cdr pair))))
    (unless (buffer-live-p buffer)
      (user-error "No se pudo previsualizar el archivo: %s" absolute))
    (unless (equal cursor-ai--dirvish-preview-last absolute)
      (when (and (buffer-live-p cursor-ai--dirvish-preview-buffer)
                 (not (eq cursor-ai--dirvish-preview-buffer buffer)))
        (kill-buffer cursor-ai--dirvish-preview-buffer)))
    (setq cursor-ai--dirvish-preview-buffer buffer
          cursor-ai--dirvish-preview-last absolute)
    (let ((window (if (window-live-p cursor-ai--dirvish-preview-window)
                      cursor-ai--dirvish-preview-window
                    (display-buffer-in-side-window
                     buffer '((side . right)
                              (slot . 0)
                              (window-width . 0.4))))))
      (setq cursor-ai--dirvish-preview-window window)
      (unless (eq (window-buffer window) buffer)
        (set-window-buffer window buffer))
      (set-window-parameter window 'no-other-window t)
      (set-window-dedicated-p window t)
      (with-selected-window window
        (setq-local mode-line-format nil
                    header-line-format nil
                    window-size-fixed 'width
                    truncate-lines t)
        (goto-char (point-min)))
      buffer))

  (defun preview-file (&optional file)
    "Preview FILE using Dirvish' preview pipeline.
When FILE is nil try to infer it from context before prompting."
    (interactive)
    (let ((target (or file
                      (and (derived-mode-p 'dired-mode)
                           (dired-get-file-for-visit))
                      (buffer-file-name)
                      (read-file-name "Previsualizar archivo: " nil nil t)))))
    (cursor-ai--dirvish-preview-display target)))

(defun cursor-ai-close-preview ()
  "Cerrar el panel de previsualización Dirvish activo."
  (interactive)
  (cursor-ai--dirvish-preview-clear))

(defun cursor-ai--consult-buffer-state ()
  "Return a Consult state function that proxies previews through Dirvish."
  (let ((state (consult--buffer-state)))
    (lambda (action cand)
      (pcase action
        ('preview
         (if-let* ((buffer (and cand (get-buffer cand)))
                   (file (buffer-local-value 'buffer-file-name buffer)))
             (progn
               (cursor-ai--dirvish-preview-display file)
               (funcall state action nil))
           (funcall state action cand)))
        ((or 'return 'exit)
         (cursor-ai--dirvish-preview-clear)
         (funcall state action cand))
        (_ (funcall state action cand))))))

(use-package cond-let)

(use-package dirvish
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-mode-line-format '(:left (sort symlink) :right (omit yank index)))
  (dirvish-mode-line-height 12)
  (dirvish-attributes '(file-time file-size vc-state))
  (dirvish-subtree-state-style 'nerd)
  (dirvish-path-separators
   (list "  " "  " " > "))
  (dired-listing-switches "-l --almost-all --human-readable --group-directories-first --no-group")
  (delete-by-moving-to-trash t)
  :config
  (require 'dirvish-peek nil t)
  (require 'dirvish-side nil t)
  (dirvish-peek-mode 1)
  (when (fboundp 'dirvish-side-follow-mode)
    (dirvish-side-follow-mode 1))
  (with-eval-after-load 'consult
    ;; `consult-customize' is a macro; evaluate it at runtime after Consult
    ;; loads so byte-compiled configs do not treat `consult-buffer' as a var.
    (eval '(consult-customize consult-buffer :preview-key 'any))
    (dolist (source '(consult--source-buffer
                      consult--source-hidden-buffer
                      consult--source-project-buffer))
      (when (boundp source)
        (setf (plist-get (symbol-value source) :state)
              #'cursor-ai--consult-buffer-state)))))
(unless (advice-member-p #'cursor-ai--dirvish-data-fallback 'dirvish-data-for-dir)
  (advice-add 'dirvish-data-for-dir :around #'cursor-ai--dirvish-data-fallback))

(use-package treemacs
  :bind (("C-c e" . treemacs)
         ("C-c '" . treemacs-select-window))
  :config
  (setq treemacs-width 35
        treemacs-fringe-indicator-mode 'always-show-even-when-not-dirty
        treemacs-show-hidden-files t)
  (treemacs-follow-mode t)
  (treemacs-filewatch-mode t)
  (treemacs-project-follow-mode t))

(use-package treemacs-nerd-icons
  :after treemacs
  :config (treemacs-load-theme "nerd-icons"))

(use-package treemacs-projectile
  :after (treemacs projectile))

(use-package treemacs-magit
  :after (treemacs magit))

(defun cursor-ai--vterm-fullscreen-advice (&rest _)
  "Keep interactive `vterm' sessions in a single-window layout."
  (when (and (called-interactively-p 'interactive)
             (derived-mode-p 'vterm-mode))
    (if (fboundp 'cursor-ai/delete-other-windows-all)
        (cursor-ai/delete-other-windows-all)
      (delete-other-windows))))

(defun cursor-ai/vterm-fullscreen (&optional arg)
  "Open `vterm' and maximize it to a single window.
Pass ARG to `vterm'."
  (interactive "P")
  (vterm arg)
  (if (fboundp 'cursor-ai/delete-other-windows-all)
      (cursor-ai/delete-other-windows-all)
    (delete-other-windows)))

(use-package vterm
  :commands vterm
  :bind (("C-`" . cursor-ai/vterm-fullscreen))
  :config
  (define-key vterm-mode-map (kbd "C-x 1") #'cursor-ai/delete-other-windows-all)
  (advice-add 'vterm :after #'cursor-ai--vterm-fullscreen-advice))

(use-package projectile
  :init (projectile-mode +1)
  :bind-keymap ("C-c p" . projectile-command-map)
  :bind (("s-p" . projectile-find-file)
         ("C-S-p" . execute-extended-command))
  :config
  (let ((projectile-cache-root (cursor-ai--state-path "cache")))
    (setq projectile-known-projects-file
          (expand-file-name "projectile-projects.eld" projectile-cache-root)
          projectile-cache-file
          (expand-file-name "projectile.cache" projectile-cache-root)))
  (setq projectile-completion-system 'default
        projectile-enable-caching t
        projectile-indexing-method 'alien))

(use-package winner
  :straight nil
  :init
  (winner-mode 1))

(use-package recentf
  :straight nil
  :init
  (setq recentf-max-saved-items 500
        recentf-max-menu-items 50
        recentf-auto-cleanup 'never)
  :config
  (dolist (entry (list (regexp-quote cursor-ai-state-directory)
                       "^/tmp/"
                       "^/sudo:"
                       "^/ssh:"))
    (add-to-list 'recentf-exclude entry))
  (recentf-mode 1)
  (run-at-time nil (* 5 60) #'recentf-save-list))

(use-package savehist
  :straight nil
  :init
  (setq history-length 300
        savehist-additional-variables
        '(kill-ring search-ring regexp-search-ring))
  :config
  (savehist-mode 1))

(use-package saveplace
  :straight nil
  :config
  (save-place-mode 1))

(use-package desktop
  :straight nil
  :init
  (let ((desktop-dir (cursor-ai--state-path "desktop")))
    (make-directory desktop-dir t)
    (setq desktop-dirname desktop-dir
          desktop-path (list desktop-dir)
          desktop-base-file-name "emacs-desktop"
          desktop-base-lock-name "emacs-desktop.lock"
          desktop-load-locked-desktop t
          desktop-save t
          desktop-auto-save-timeout 300
          desktop-restore-eager 5))
  :config
  (desktop-save-mode 1))

(use-package persp-mode
  :init
  (let ((persp-dir (cursor-ai--state-path "persp")))
    (make-directory persp-dir t)
    (setq persp-save-dir persp-dir))
  (persp-mode 1))

(use-package elfeed
  :commands (elfeed)
  :init
  (let ((elfeed-dir (cursor-ai--state-path "elfeed")))
    (make-directory elfeed-dir t)
    (setq elfeed-db-directory elfeed-dir))
  :custom
  (elfeed-feeds
   '(("https://www.smashingmagazine.com/feed/" frontend design)
     ("https://developer.mozilla.org/en-US/blog/rss.xml" frontend web)
     ("https://devblogs.microsoft.com/dotnet/feed/" backend dotnet microsoft)
     ("https://aws.amazon.com/blogs/aws/feed/" infra cloud aws)
     ("https://aws.amazon.com/new/feed/" infra releases aws)
     ("https://k8s.io/docs/reference/issues-security/official-cve-feed/feed.xml"
      infra security kubernetes))))

(use-package webjump
  :straight nil
  :commands (webjump)
  :init
  (defun cursor-ai--register-webjump-sites ()
    "Register custom Webjump shortcuts."
    (dolist (name '("Arch Linux Packages (name)"
                    "Arch Linux Packages (search)"
                    "AUR Packages"
                    "Pacman Packages"))
      (setq webjump-sites (assoc-delete-all name webjump-sites)))
    (dolist (site '(("AUR Packages"
                     . [simple-query
                        "https://aur.archlinux.org/packages"
                        "https://aur.archlinux.org/packages?O=0&K="
                        ""])
                    ("Pacman Packages"
                     . [simple-query
                        "https://archlinux.org/packages/"
                        "https://archlinux.org/packages/?name="
                        ""])))
      (add-to-list 'webjump-sites site t)))
  (if (featurep 'webjump)
      (cursor-ai--register-webjump-sites)
    (with-eval-after-load 'webjump
      (cursor-ai--register-webjump-sites))))

(use-package transient
  :demand t)

(define-prefix-command 'magit-prefix-map)
(define-key magit-prefix-map (kbd "s") #'magit-status)
(define-key magit-prefix-map (kbd "l") #'magit-log)
(define-key magit-prefix-map (kbd "b") #'magit-branch)
(define-key magit-prefix-map (kbd "c") #'magit-commit)
(define-key magit-prefix-map (kbd "d") #'magit-diff)
(define-key magit-prefix-map (kbd "f") #'magit-fetch)
(define-key magit-prefix-map (kbd "p") #'magit-push)
(define-key magit-prefix-map (kbd "P") #'magit-pull)
(define-key magit-prefix-map (kbd "r") #'magit-rebase)
(define-key magit-prefix-map (kbd "m") #'magit-merge)
(define-key magit-prefix-map (kbd "a") #'magit-stage)
(define-key magit-prefix-map (kbd "u") #'magit-unstage)
(define-key magit-prefix-map (kbd "t") #'git-timemachine-toggle)
(define-key magit-prefix-map (kbd "o") #'browse-at-remote)
(define-key magit-prefix-map (kbd "O") #'browse-at-remote-kill)
(define-key magit-prefix-map (kbd "n") #'diff-hl-next-hunk)
(define-key magit-prefix-map (kbd "N") #'diff-hl-previous-hunk)
(define-key magit-prefix-map (kbd "R") #'diff-hl-revert-hunk)

(use-package magit
  :after transient
  :bind (("C-x g" . magit-prefix-map)
         ("C-c v" . magit-status))
  :hook ((magit-status-section-hook . 'magit-insert-tracked-files))
  :config
  (setq magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1)
  (with-eval-after-load 'ediff
    (setq ediff-window-setup-function #'ediff-setup-windows-plain)))

(use-package magit-todos
  :after magit
  :config
  (magit-todos-mode 1))

(use-package forge
  :after magit
  :commands (forge-dispatch forge-pull))

(use-package git-link
  :commands (git-link git-link-commit))

(use-package browse-at-remote
  :straight (browse-at-remote :type git :host github :repo "rmuslimov/browse-at-remote")
  :commands (browse-at-remote browse-at-remote-kill))

(use-package git-timemachine
  :straight (git-timemachine :type git :host github :repo "emacsmirror/git-timemachine")
  :commands (git-timemachine git-timemachine-toggle))

(use-package ghub
  :defer t)

(use-package diff-hl
  :commands (diff-hl-next-hunk diff-hl-previous-hunk diff-hl-revert-hunk)
  :hook ((prog-mode . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode)
         (magit-post-refresh . diff-hl-magit-post-refresh)
	 (flymake-mode . diff-hl-flydiff-mode))
  :custom
  (diff-hl-margin-mode t)
  (diff-hl-side 'right)
  :custom-face
  (diff-hl-insert ((t (:background nil :inherit nil))))
  (diff-hl-delete ((t (:background nil :inherit nil))))
  (diff-hl-change ((t (:background nil :inherit nil)))))

(provide 'tools-config)

;;; tools-config.el ends here
