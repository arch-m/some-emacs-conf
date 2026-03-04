;;; keybindings.el --- Global keybindings and key-chords -*- lexical-binding: t; -*-

;;; Commentary:
;; Centralizes global keys and prefix maps so bindings stay consistent.

;;; Code:

(require 'core-bootstrap)

(defun cursor-ai/kill-this-buffer-no-prompt ()
  "Kill the current buffer without asking for confirmation."
  (interactive)
  (kill-buffer (current-buffer)))

;; Backward-compatible alias used by older keybinding references.
(defalias 'my/kill-this-buffer-no-prompt #'cursor-ai/kill-this-buffer-no-prompt)

(defvar hyper-kill-prefix-map nil
  "Prefix map for close/kill actions.")

(defun cursor-ai--bind-global-keys (bindings)
  "Register global key BINDINGS.
Each element is a cons cell: (KBD . COMMAND)."
  (dolist (binding bindings)
    (global-set-key (kbd (car binding)) (cdr binding))))

(defun cursor-ai--key-chord-define-map (keys map &optional fallback feature)
  "Bind KEYS to MAP when available, otherwise use FALLBACK.
When FEATURE is non-nil, retry after FEATURE loads."
  (if (boundp map)
      (key-chord-define-global keys (symbol-value map))
    (when fallback
      (key-chord-define-global keys fallback))
    (when feature
      (with-eval-after-load feature
        (when (boundp map)
          (key-chord-define-global keys (symbol-value map)))))))

(use-package key-chord
  :init
  (key-chord-mode 1)
  (setq key-chord-two-keys-delay 0.05)
  :config
  (dolist (binding '(("tn" . other-window)
                     ("dn" . ace-window)
                     ("dh" . golden-ratio)
                     ("ao" . hide-mode-line-mode)
                     ("sk" . subword-mode)
                     ("sm" . superword-mode)
                     ("xb" . consult-buffer)
                     ("x0" . delete-window)
                     ("x1" . delete-other-windows)
                     ("x2" . split-window-below)
                     ("x3" . split-window-right)
                     ("x4" . ctl-x-4-prefix)
                     ("x5" . ctl-x-5-prefix)
                     ("x6" . 2C-command)
                     ("hk" . describe-key)
                     ("hv" . describe-variable)
                     ("hf" . describe-function)
                     ("hm" . describe-mode)
                     ("km" . toggle-eldoc-combo)
                     ("zx" . repeat)))
    (key-chord-define-global (car binding) (cdr binding)))

  (dolist (spec '(("nw" window-prefix-map nil window)
                  ("xf" find-file-prefix-map find-file files)
                  ("xp" project-prefix-map nil project)
                  ("xa" abbrev-map nil abbrev)
                  ("xr" ctl-x-r-map nil register)
                  ("xt" tab-prefix-map nil tab-bar)
                  ("xn" narrow-map nil narrow)
                  ("xv" vc-prefix-map nil vc)
                  ("xg" magit-prefix-map nil magit)
                  ("zh" dict-prefix-map nil dictionary)))
    (apply #'cursor-ai--key-chord-define-map spec)))

(define-prefix-command 'hyper-kill-prefix-map)

(cursor-ai--bind-global-keys
 '(("C-x C-b" . ibuffer)
   ("s-w" . scratch-buffer)
   ("H-d" . hyper-kill-prefix-map)
   ("H-l" . next-frame)
   ("H-h" . previous-frame)
   ("H-f" . tab-next)
   ("H-b" . tab-previous)
   ("H-n" . next-buffer)
   ("H-p" . previous-buffer)
   ("H-q" . kill-buffer-and-window)
   ("s-q" . cursor-ai/kill-this-buffer-no-prompt)
   ("s-C-q" . kill-some-buffer)
   ("s-n" . narrow-to-defun)
   ("s-e" . widen)
   ("s-j" . webjump)
   ("s-s" . consult-line)
   ("s-r" . consult-ripgrep)))

(dolist (binding '(("t" . tab-close)
                   ("C-t" . tab-close-other)
                   ("w" . delete-frame)
                   ("C-w" . delete-other-frames)))
  (define-key hyper-kill-prefix-map (kbd (car binding)) (cdr binding)))

(setq narrow-to-defun-include-comments t)

(define-key window-prefix-map (kbd "n f") #'tear-off-window)
(define-key window-prefix-map (kbd "n t") #'tab-window-detach)

(provide 'keybindings)

;;; keybindings.el ends here
