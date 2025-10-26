;;; core-bootstrap.el --- Base startup and package system setup -*- lexical-binding: t; -*-

;;; Commentary:
;; Centralises early startup tweaks and package bootstrap logic so the rest of
;; the configuration can assume `use-package' and Straight are ready to go.

;;; Code:

(setq inhibit-startup-message t
      use-dialog-box nil
      ring-bell-function #'ignore
      native-comp-async-report-warnings-errors 'silent)

(defconst cursor-ai-state-directory
  (file-name-as-directory (expand-file-name "var" user-emacs-directory))
  "Root directory for cache, autosave and temporary Emacs data.")

(defun cursor-ai--state-path (&rest segments)
  "Return absolute path inside `cursor-ai-state-directory' for SEGMENTS."
  (let ((path cursor-ai-state-directory))
    (dolist (segment segments path)
      (setq path (expand-file-name segment path)))))

(let* ((cache-root (file-name-as-directory (cursor-ai--state-path "cache")))
       (auto-save-root (file-name-as-directory (cursor-ai--state-path "auto-save")))
       (tmp-root (file-name-as-directory (cursor-ai--state-path "tmp")))
       (eln-root (file-name-as-directory (cursor-ai--state-path "eln-cache"))))
  (dolist (dir (list cursor-ai-state-directory
                     cache-root
                     (file-name-as-directory (expand-file-name "url" cache-root))
                     (file-name-as-directory (cursor-ai--state-path "cache" "eshell"))
                     auto-save-root
                     tmp-root
                     eln-root
                     (file-name-as-directory (cursor-ai--state-path "straight"))
                     (file-name-as-directory (cursor-ai--state-path "elpa"))))
    (make-directory dir t))
  (setq backup-directory-alist `(("." . ,(expand-file-name "backups" cache-root)))
        auto-save-file-name-transforms `((".*" ,auto-save-root t))
        auto-save-list-file-prefix (expand-file-name "sessions-" auto-save-root)
        temporary-file-directory tmp-root
        tramp-persistency-file-name (expand-file-name "tramp" cache-root)
        url-cache-directory (file-name-as-directory (expand-file-name "url" cache-root))
        url-history-file (expand-file-name "url-history" cache-root)
        recentf-save-file (expand-file-name "recentf" cache-root)
        bookmark-default-file (expand-file-name "bookmarks" cache-root)
        transient-history-file (expand-file-name "transient-history.el" cache-root)
        transient-levels-file (expand-file-name "transient-levels.el" cache-root)
        transient-values-file (expand-file-name "transient-values.el" cache-root)
        savehist-file (expand-file-name "savehist" cache-root)
        save-place-file (expand-file-name "places" cache-root)
        eshell-directory-name (file-name-as-directory (cursor-ai--state-path "cache" "eshell")))
  (add-to-list 'native-comp-eln-load-path eln-root :append))

;; Garbage collector and process throughput tweaks improve LSP responsiveness.
(setq read-process-output-max (* 4 1024 1024)
      gc-cons-threshold (* 100 1024 1024))

(setq straight-base-dir (cursor-ai--state-path "straight")
      package-user-dir (cursor-ai--state-path "elpa"))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

(setq use-package-always-ensure t)

;; Straight.el keeps third-party packages in a dedicated directory so the
;; dependency graph is explicit.
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

(provide 'core-bootstrap)

;;; core-bootstrap.el ends here
