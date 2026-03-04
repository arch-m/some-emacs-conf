;;; org-productivity.el --- Org capture + org-ql helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Productivity layer for Comms/agenda workflows.
;; - Standard capture templates
;; - Single agenda file: ~/org/agenda.org
;; - org-ql quick queries for fast retrieval

;;; Code:

(require 'core-bootstrap)

(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :hook ((org-mode . visual-line-mode))
  :init
  (setq org-directory "~/org"
        org-default-notes-file "~/org/inbox.org"
        org-agenda-files '("~/org/agenda.org" "~/org/inbox.org")
        org-log-done 'time
        org-startup-indented t)
  :config
  (dolist (f '("~/org/agenda.org" "~/org/inbox.org"))
    (unless (file-exists-p (expand-file-name f))
      (make-directory (file-name-directory (expand-file-name f)) t)
      (with-temp-buffer
        (insert "#+title: " (file-name-base f) "\n\n")
        (write-file (expand-file-name f)))))

  (setq org-capture-templates
        '(("t" "Tarea rápida (inbox)" entry
           (file+headline "~/org/inbox.org" "Inbox")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)
          ("a" "Agenda evento" entry
           (file+headline "~/org/agenda.org" "Eventos")
           "* %?\nSCHEDULED: %^T\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)
          ("n" "Nota" entry
           (file+headline "~/org/inbox.org" "Notas")
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)
          ("r" "Recordatorio" entry
           (file+headline "~/org/agenda.org" "Recordatorios")
           "* TODO %?\nSCHEDULED: %^T\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)))

  (global-set-key (kbd "C-c c") #'org-capture)
  (global-set-key (kbd "C-c a") #'org-agenda))

(use-package org-ql
  :after org
  :commands (org-ql-search org-ql-view)
  :init
  ;; Consultas rápidas para Comms/productividad
  (defun cursor-ai/org-ql-today ()
    "Mostrar tareas/eventos para hoy."
    (interactive)
    (org-ql-search org-agenda-files
      '(or (todo)
           (scheduled :on today)
           (deadline :on today))
      :title "Hoy"))

  (defun cursor-ai/org-ql-next-7-days ()
    "Mostrar agenda para próximos 7 días."
    (interactive)
    (org-ql-search org-agenda-files
      '(or (scheduled :from today :to +7)
           (deadline :from today :to +7))
      :title "Próximos 7 días"))

  (defun cursor-ai/org-ql-inbox ()
    "Mostrar pendientes en inbox."
    (interactive)
    (org-ql-search "~/org/inbox.org"
      '(or (todo)
           (not (done)))
      :title "Inbox"))

  :bind (("C-c q t" . cursor-ai/org-ql-today)
         ("C-c q w" . cursor-ai/org-ql-next-7-days)
         ("C-c q i" . cursor-ai/org-ql-inbox)))

(provide 'org-productivity)

;;; org-productivity.el ends here
