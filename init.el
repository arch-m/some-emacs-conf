;;; init.el --- Main entry point for this Emacs config -*- lexical-binding: t; -*-

;;; Commentary:
;; Sets local load paths, bootstraps package/runtime state, and then loads each
;; feature module in dependency order.

;;; Code:

(dolist (dir '("lisp" "base"))
  (add-to-list 'load-path (expand-file-name dir user-emacs-directory)))

(add-to-list 'custom-theme-load-path
             (expand-file-name "themes" user-emacs-directory))

(defconst cursor-ai-openai-env-file
  (expand-file-name "agent/openai-env.el" user-emacs-directory)
  "Local file that sets sensitive env vars like `OPENAI_API_KEY'.")

(when (file-readable-p cursor-ai-openai-env-file)
  ;; Load local secrets before AI modules initialize.
  (load cursor-ai-openai-env-file nil 'nomessage))

(require 'core-bootstrap)

(defconst cursor-ai-modules
  '(ui-config
    editing-config
    tools-config
    org-productivity
    ai-suite
    modal-editing
    comunicacion
    lsp-java
    keybindings)
  "Configuration modules loaded from `init.el'.")

(dolist (module cursor-ai-modules)
  (require module))

(load-theme 'vscode-light-modern t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("cbd85ab34afb47003fa7f814a462c24affb1de81ebf172b78cb4e65186ba59d2"
     "2c6bb1f19a443598c5a665f2c3897900e0673a86660a4f162d96de3c2fc46548"
     "993aac313027a1d6e70d45b98e121492c1b00a0daa5a8629788ed7d523fe62c1"
     "95ee4d370f4b66ff2287d8075f8fe5f58c4a9b9c1e65d663b15174f1a8c57717"
     "45631691477ddee3df12013e718689dafa607771e7fd37ebc6c6eb9529a8ede5"
     "9b21c848d09ba7df8af217438797336ac99cbbbc87a08dc879e9291673a6a631"
     "d5707b94a82990a5971e3b2b70f66f0bb06a2e9204006a9439c86022831c3df9"
     "de8f2d8b64627535871495d6fe65b7d0070c4a1eb51550ce258cd240ff9394b0"
     default))
 '(delete-by-moving-to-trash nil nil nil "Customized with use-package dirvish")
 '(package-selected-packages nil)
 '(safe-local-variable-values
   '((eval progn
	   (setq-local copilot-install-dir
		       (expand-file-name "~/.cache/copilot"))))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(provide 'init)

;;; init.el ends here
