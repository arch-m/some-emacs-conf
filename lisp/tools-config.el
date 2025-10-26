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

(defvar cursor-ai--dirvish-preview-window nil
  "Window reserved for Dirvish previews triggered from completion UIs.")

(defvar cursor-ai--dirvish-preview-buffer nil
  "Buffer currently displayed in `cursor-ai--dirvish-preview-window'.")

(defvar cursor-ai--dirvish-preview-last nil
  "Remember the last file path rendered in the Dirvish preview window.")

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
    (consult-customize consult-buffer :preview-key 'any)
    (dolist (source '(consult--source-buffer
                      consult--source-hidden-buffer
                      consult--source-project-buffer))
      (when (boundp source)
        (setf (plist-get (symbol-value source) :state)
              #'cursor-ai--consult-buffer-state)))))

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

(use-package vterm
  :commands vterm
  :bind (("C-`" . vterm)))

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

(use-package magit
  :bind (("C-x g" . magit-status)
         ("C-c v" . magit-status))
  :config
  (setq magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1))

(provide 'tools-config)

;;; tools-config.el ends here
