;; (setq package-archives '(("gnu-devel" . 
;;                         ("nongnu-devel" . 

(let* ((state-root (expand-file-name "var" user-emacs-directory))
       (elpa-dir (expand-file-name "elpa" state-root)))
  (setq package-user-dir elpa-dir)
  (make-directory package-user-dir t))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
;; and `package-pinned-packages`. Most users will not need or want to do this.
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
;;(add-to-list 'package-archives '("gnu-devel" . "https://elpa.gnu.org/devel/") t)
;;(add-to-list 'package-archives '("nongnu-devel" . "https://elpa.nongnu.org/nongnu-devel/") t)
(package-initialize)

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'core-bootstrap)
(require 'ui-config)
(require 'editing-config)
(require 'tools-config)
(require 'ai-suite)
(require 'modal-editing)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("95ee4d370f4b66ff2287d8075f8fe5f58c4a9b9c1e65d663b15174f1a8c57717"
     "45631691477ddee3df12013e718689dafa607771e7fd37ebc6c6eb9529a8ede5"
     "9b21c848d09ba7df8af217438797336ac99cbbbc87a08dc879e9291673a6a631"
     "d5707b94a82990a5971e3b2b70f66f0bb06a2e9204006a9439c86022831c3df9"
     "de8f2d8b64627535871495d6fe65b7d0070c4a1eb51550ce258cd240ff9394b0"
     default))
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
