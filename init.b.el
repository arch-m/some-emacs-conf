;; (setq package-archives '(("gnu-devel" . 
;;                         ("nongnu-devel" . 

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
;; and `package-pinned-packages`. Most users will not need or want to do this.
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
;;(add-to-list 'package-archives '("gnu-devel" . "https://elpa.gnu.org/devel/") t)
;;(add-to-list 'package-archives '("nongnu-devel" . "https://elpa.nongnu.org/nongnu-devel/") t)
(package-initialize)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("95ee4d370f4b66ff2287d8075f8fe5f58c4a9b9c1e65d663b15174f1a8c57717" "45631691477ddee3df12013e718689dafa607771e7fd37ebc6c6eb9529a8ede5" "9b21c848d09ba7df8af217438797336ac99cbbbc87a08dc879e9291673a6a631" "d5707b94a82990a5971e3b2b70f66f0bb06a2e9204006a9439c86022831c3df9" "de8f2d8b64627535871495d6fe65b7d0070c4a1eb51550ce258cd240ff9394b0" default))
 '(package-selected-packages
   '(smart-mode-line-powerline-theme smart-mode-line-atom-one-dark-theme smart-mode-line which-key eat evil gptel)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
;; nano-emacs.el --- NANO Emacs (minimal version)     -*- lexical-binding: t -*-

;; Copyright (c) 2025  Nicolas P. Rougier
;; Released under the GNU General Public License 3.0
;; Author: Nicolas P. Rougier <nicolas.rougier@inria.fr>
;; URL: https://github.com/rougier/nano-emacs

;; This is NANO Emacs in 256 lines, without any dependency 
;; Usage (command line):  emacs -Q -l nano.el -[light|dark]

;; --- Speed benchmarking -----------------------------------------------------
(setq init-start-time (current-time))

;; --- Typography stack -------------------------------------------------------
(set-face-attribute 'default nil
                    :height 180 :weight 'light :family "Roboto Mono")
(set-face-attribute 'bold nil :weight 'regular)
(set-face-attribute 'bold-italic nil :weight 'regular)
(set-display-table-slot standard-display-table 'truncation (make-glyph-code ?…))
(set-display-table-slot standard-display-table 'wrap (make-glyph-code ?–))

;; --- Frame / windows layout & behavior --------------------------------------
(setq default-frame-alist
      '((height . 44) (width  . 81) (left-fringe . 0) (right-fringe . 0)
        (internal-border-width . 32) (vertical-scroll-bars . nil)
        (bottom-divider-width . 0) (right-divider-width . 0)
        (undecorated-round . t)))
(modify-frame-parameters nil default-frame-alist)
(setq-default pop-up-windows nil)

;; --- Activate / Deactivate modes --------------------------------------------
(tool-bar-mode -1) (menu-bar-mode -1) (blink-cursor-mode -1)
(global-hl-line-mode 1) (icomplete-mode -1)
(pixel-scroll-precision-mode 1)

;; --- Minibuffer setup -------------------------------------------------------
(defun nano-minibuffer--setup ()
  (set-window-margins nil 3 0)
  (let ((inhibit-read-only t))
    (add-text-properties (point-min) (+ (point-min) 1)
      `(display ((margin left-margin)
                 ,(format "# %s" (substring (minibuffer-prompt) 0 1))))))
  (setq truncate-lines t))
(add-hook 'minibuffer-setup-hook #'nano-minibuffer--setup)

;; --- Speed benchmarking -----------------------------------------------------
(let ((init-time (float-time (time-subtract (current-time) init-start-time)))
      (total-time (string-to-number (emacs-init-time "%f"))))
  (message (concat
    (propertize "Startup time: " 'face 'bold)
    (format "%.2fs " init-time)
    (propertize (format "(+ %.2fs system time)"
                        (- total-time init-time)) 'face 'shadow))))
(require 'evil)
(evil-mode 1)

(sml/setup)
(setq sml/theme 'atom-one-dark)


(load-theme 'nano-light t)
