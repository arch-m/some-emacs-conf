(provide 'emacs-viber)

;; evil mode emacs configuration
;; start in emacs mode in every buffer
;; use-package



(use-package evil
  :init
  (setq evil-default-state 'emacs)
  :config
  (evil-mode 1))

;; add conf to start emacs in fullscreen

;; Start Emacs in fullscreen mode
(add-to-list 'default-frame-alist '(fullscreen . fullboth))

(add-hook 'window-setup-hook
          (lambda () (toggle-frame-fullscreen)))

(message "emacs")
