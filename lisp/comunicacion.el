;;; comunicacion.el --- Configuración para Gmail y Telegram -*- lexical-binding: t; -*-

;;; Commentary:
;; Configuración de clientes de comunicación para Emacs
;; - mu4e para Gmail
;; - telega para Telegram

;;; Code:

(require 'core-bootstrap)

;;;; Gmail - mu4e
;; Cliente de email para Emacs basado en mu (maildir utils)

(use-package mu4e
  :straight nil
  :ensure nil  ;; mu4e viene con mu, se instala externamente
  :defer t
  :config
  ;; Rutas
  (setq mu4e-maildir "~/Mail"
        mu4e-attachment-dir "~/Downloads")

  ;; Configuración de cuentas
  (setq mu4e-contexts
        (list
         ;; Cuenta principal de Gmail
         (make-mu4e-context
          :name "Gmail"
          :match-func
          (lambda (msg)
            (when msg
              (string-prefix-p "/Gmail" (mu4e-message-field msg :maildir))))
          :vars '((user-mail-address . "tu-email@gmail.com")
                  (user-full-name . "Tu Nombre")
                  (mu4e-drafts-folder . "/Gmail/[Gmail]/Drafts")
                  (mu4e-sent-folder . "/Gmail/[Gmail]/Sent Mail")
                  (mu4e-refile-folder . "/Gmail/[Gmail]/All Mail")
                  (mu4e-trash-folder . "/Gmail/[Gmail]/Trash")
                  ;; SMTP para enviar correos
                  (smtpmail-smtp-server . "smtp.gmail.com")
                  (smtpmail-smtp-service . 587)
                  (smtpmail-stream-type . starttls)))))

  ;; Configuración general
  (setq mu4e-get-mail-command "mbsync -a"  ;; o "offlineimap"
        mu4e-update-interval 300            ;; Actualizar cada 5 minutos
        mu4e-compose-format-flowed t
        mu4e-view-show-images t
        mu4e-view-show-addresses t
        mu4e-compose-signature-auto-include nil
        mu4e-view-prefer-html nil)

  ;; Configuración SMTP
  (setq message-send-mail-function 'smtpmail-send-it
        smtpmail-debug-info t)

  ;; Atajos de teclado
  (setq mu4e-maildir-shortcuts
        '(("/Gmail/INBOX" . ?i)
          ("/Gmail/[Gmail]/Sent Mail" . ?s)
          ("/Gmail/[Gmail]/Trash" . ?t)
          ("/Gmail/[Gmail]/All Mail" . ?a)))

  ;; Vista HTML mejorada
  (setq mu4e-html2text-command "w3m -T text/html"
        ;; o usa shr (built-in)
        mu4e-view-use-gnus t)

  ;; Bookmarks personalizados
  (setq mu4e-bookmarks
        '((:name "Inbox" :query "maildir:/Gmail/INBOX" :key ?i)
          (:name "Unread" :query "flag:unread AND NOT flag:trashed" :key ?u)
          (:name "Today" :query "date:today..now" :key ?t)
          (:name "Last 7 days" :query "date:7d..now" :key ?w))))

;; mbsync/isync para sincronizar Gmail
;; Necesitas crear ~/.mbsyncrc con tu configuración

;;;; Telegram - telega
;; Cliente de Telegram para Emacs

(use-package telega
  :defer t
  :commands (telega)
  :config
  ;; Configuración general
  (setq telega-server-libs-prefix "/usr")  ;; Ajusta según tu sistema

  ;; Mostrar avatars
  (setq telega-avatar-workaround-gaps-for '(return t))

  ;; Notificaciones
  (setq telega-notifications-mode t)

  ;; Chat layout
  (setq telega-chat-fill-column 75)

  ;; Emojis
  (setq telega-emoji-use-images t)

  ;; Stickers
  (setq telega-sticker-set-download t)

  ;; Autocompletar usuarios
  (add-hook 'telega-chat-mode-hook
            (lambda ()
              (set (make-local-variable 'company-backends)
                   (append '(telega-company-emoji
                             telega-company-username
                             telega-company-hashtag)
                           (when (telega-chat-bot-p telega-chatbuf--chat)
                             '(telega-company-botcmd))))
              (company-mode 1)))

  ;; Atajos de teclado personalizados
  (define-key telega-msg-button-map (kbd "k") 'telega-msg-delete-marked-or-at-point)
  (define-key telega-msg-button-map (kbd "SPC") 'telega-button-forward))

;; Rainbow mode para Telega (colores en los mensajes)
(use-package rainbow-mode
  :hook (telega-chat-mode . rainbow-mode))

;;;; Configuración de autenticación
;; Para Gmail: necesitas configurar OAuth2 o App Password
;; Crea el archivo ~/.authinfo.gpg con:
;; machine smtp.gmail.com login tu-email@gmail.com password tu-app-password port 587

;; Para Telegram: telega te pedirá tu número de teléfono y código la primera vez

;;;; Keybindings globales
;; Keep communication entry points on C-c C-* so AI/model prefixes under C-c m
;; remain available.
(global-set-key (kbd "C-c C-m") #'mu4e)
(global-set-key (kbd "C-c C-t") #'telega)

(provide 'comunicacion)
;;; comunicacion.el ends here
