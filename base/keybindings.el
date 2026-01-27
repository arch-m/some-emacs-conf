(provide 'keybindings)

(use-package general
  :ensure nil)

(use-package key-chord
  :ensure nil
  :init
  (key-chord-mode 1)
  (setq key-chord-two-keys-delay 0.05)
  :config
  (defun cursor-ai--key-chord-define-map (keys map &optional fallback feature)
    "Bind KEYS to MAP when available, otherwise to FALLBACK if provided.
If FEATURE is non-nil, bind to MAP after FEATURE loads."
    (if (boundp map)
        (key-chord-define-global keys (symbol-value map))
      (when fallback
        (key-chord-define-global keys fallback))
      (when feature
        (with-eval-after-load feature
          (when (boundp map)
            (key-chord-define-global keys (symbol-value map)))))))
  (key-chord-define-global "tn" #'other-window)
  (key-chord-define-global "dn" #'ace-window)
  (key-chord-define-global "dh" #'golden-ratio)
  (key-chord-define-global "ao" #'hide-mode-line-mode)
  (key-chord-define-global "sk" #'subword-mode)
  (key-chord-define-global "sm" #'superword-mode)
  (cursor-ai--key-chord-define-map "nw" 'window-prefix-map nil 'window)
  (cursor-ai--key-chord-define-map "xf" 'find-file-prefix-map #'find-file 'files)
  (cursor-ai--key-chord-define-map "xp" 'project-prefix-map nil 'project)
  (key-chord-define-global "xb" #'consult-buffer)
  (cursor-ai--key-chord-define-map "xa" 'abbrev-map nil 'abbrev)
  (cursor-ai--key-chord-define-map "xr" 'ctl-x-r-map nil 'register)
  (cursor-ai--key-chord-define-map "xt" 'tab-prefix-map nil 'tab-bar)
  (cursor-ai--key-chord-define-map "xn" 'narrow-map nil 'narrow)
  (cursor-ai--key-chord-define-map "xv" 'vc-prefix-map nil 'vc)
  (cursor-ai--key-chord-define-map "xg" 'magit-prefix-map nil 'magit)
  (key-chord-define-global "x0" 'delete-window)
  (key-chord-define-global "x1" 'delete-other-windows)
  (key-chord-define-global "x2" 'split-window-below)
  (key-chord-define-global "x3" 'split-window-right)
  (key-chord-define-global "x4" 'ctl-x-4-prefix)
  (key-chord-define-global "x5" 'ctl-x-5-prefix)
  (key-chord-define-global "x6" '2C-command)
  (key-chord-define-global "hk" 'describe-key)
  (key-chord-define-global "hv" 'describe-variable)
  (key-chord-define-global "hf" 'describe-function)
  (key-chord-define-global "hm" 'describe-mode)
  (key-chord-define-global "km" 'toggle-eldoc-combo)
  (key-chord-define-global "zx" 'repeat)
  (cursor-ai--key-chord-define-map "zh" 'dict-prefix-map nil 'dictionary))

(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "s-w") 'scratch-buffer)

(define-prefix-command 'hyper-kill-prefix-map)
(global-set-key (kbd "H-d") 'hyper-kill-prefix-map)
(global-set-key (kbd "H-l") 'next-frame)
(global-set-key (kbd "H-h") 'previous-frame)
(global-set-key (kbd "H-f") 'tab-next)
(global-set-key (kbd "H-b") 'tab-previous)
(global-set-key (kbd "H-n") 'next-buffer)
(global-set-key (kbd "H-p") 'previous-buffer)
(global-set-key (kbd "H-q") 'kill-buffer-and-window)
(global-set-key (kbd "s-q") #'my/kill-this-buffer-no-prompt)
(global-set-key (kbd "s-C-q") 'kill-some-buffer)
(define-key hyper-kill-prefix-map (kbd "t") #'tab-close)
(define-key hyper-kill-prefix-map (kbd "C-t") #'tab-close-other)
(define-key hyper-kill-prefix-map (kbd "w") #'delete-frame)
(define-key hyper-kill-prefix-map (kbd "C-w") #'delete-other-frames)
(setq narrow-to-defun-include-comments t)
(global-set-key (kbd "s-n") 'narrow-to-defun)
(global-set-key (kbd "s-e") 'widen)

(define-key window-prefix-map (kbd "n f") #'tear-off-window)
(define-key window-prefix-map (kbd "n t") #'tab-window-detach)
