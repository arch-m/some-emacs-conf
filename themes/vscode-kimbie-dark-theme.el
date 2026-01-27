;;; vscode-kimbie-dark-theme.el --- VS Code Kimbie Dark theme -*- lexical-binding: t; -*-
;;; Commentary:
;; Brown-toned theme inspired by VS Code Kimbie Dark.

(deftheme vscode-kimbie-dark "VS Code Kimbie Dark")

(let* ((class '((class color) (min-colors 89)))
       (bg "#221a0f")
       (bg-alt "#131510")
       (fg "#d3af86")
       (fg-strong "#e3b583")
       (fg-dim "#a57a4c")
       (fg-weak "#7c5021")
       (cursor fg)
       (accent "#e3b583")
       (region "#84613d")
       (hl "#5e452b")
       (modeline-fg fg)
       (modeline-bg "#423523")
       (modeline-inactive "#362712")
       ;; Syntax (Kimbie Dark token colors)
       (comment "#a57a4c")
       (string "#889b4a")
       (keyword "#98676a")
       (builtin "#7e602c")
       (type "#f06431")
       (func "#8ab1b0")
       (var "#dc3958")
       (const "#f79a32")
       (number "#f79a32")
       (link "#8ab1b0")
       (warning "#f79a32")
       (error "#dc3958")
       (success "#889b4a"))
  (custom-theme-set-faces
   'vscode-kimbie-dark
   ;; Base
   `(default ((,class (:background ,bg :foreground ,fg))))
   `(cursor  ((,class (:background ,cursor))))
   `(fringe  ((,class (:background ,bg :foreground ,fg-weak))))
   `(vertical-border ((,class (:foreground ,modeline-bg))))
   `(region  ((,class (:background ,region))))
   `(highlight ((,class (:background ,hl))))
   `(shadow  ((,class (:foreground ,fg-weak))))
   `(minibuffer-prompt ((,class (:foreground ,accent :weight bold))))
   `(link ((,class (:foreground ,link :underline t))))
   `(success ((,class (:foreground ,success :weight bold))))
   `(warning ((,class (:foreground ,warning :weight bold))))
   `(error ((,class (:foreground ,error :weight bold))))

   ;; Mode line
   `(mode-line
     ((,class (:foreground ,modeline-fg :background ,modeline-bg
                           :box (:line-width 1 :color ,modeline-bg) :weight semibold))))
   `(mode-line-inactive
     ((,class (:foreground ,fg-dim :background ,modeline-inactive
                           :box (:line-width 1 :color ,modeline-inactive)))))

   ;; Line numbers
   `(line-number ((,class (:foreground ,fg-weak :background ,bg))))
   `(line-number-current-line ((,class (:foreground ,fg-strong :weight bold))))

   ;; Search and parens
   `(isearch        ((,class (:background ,accent :foreground ,bg :weight bold))))
   `(lazy-highlight ((,class (:background ,hl :weight bold))))
   `(show-paren-match    ((,class (:background ,hl :foreground ,fg-strong :weight bold))))
   `(show-paren-mismatch ((,class (:background ,error :foreground ,bg :weight bold))))

   ;; Syntax
   `(font-lock-comment-face       ((,class (:foreground ,comment :slant italic))))
   `(font-lock-doc-face           ((,class (:inherit font-lock-comment-face))))
   `(font-lock-string-face        ((,class (:foreground ,string))))
   `(font-lock-keyword-face       ((,class (:foreground ,keyword :weight semibold))))
   `(font-lock-builtin-face       ((,class (:foreground ,builtin))))
   `(font-lock-type-face          ((,class (:foreground ,type))))
   `(font-lock-constant-face      ((,class (:foreground ,const))))
   `(font-lock-function-name-face ((,class (:foreground ,func))))
   `(font-lock-variable-name-face ((,class (:foreground ,var))))
   `(font-lock-warning-face       ((,class (:foreground ,error :weight bold))))

   ;; Org
   `(org-level-1 ((,class (:weight bold :foreground ,accent))))
   `(org-level-2 ((,class (:weight bold :foreground ,keyword))))
   `(org-level-3 ((,class (:foreground ,func))))
   `(org-code   ((,class (:background ,bg-alt :foreground ,fg-strong))))
   `(org-block  ((,class (:background ,bg-alt))))
   `(org-block-begin-line ((,class (:inherit shadow :background ,bg-alt))))
   `(org-block-end-line   ((,class (:inherit shadow :background ,bg-alt))))
   `(org-link ((,class (:inherit link))))

   ;; Term colors
   `(term ((,class (:background ,bg :foreground ,fg))))
   `(term-color-black  ((,class (:background ,bg :foreground ,bg))))
   `(term-color-red    ((,class (:background ,error :foreground ,error))))
   `(term-color-green  ((,class (:background ,success :foreground ,success))))
   `(term-color-yellow ((,class (:background ,warning :foreground ,warning))))
   `(term-color-blue   ((,class (:background ,link :foreground ,link))))
   `(term-color-magenta ((,class (:background ,keyword :foreground ,keyword))))
   `(term-color-cyan   ((,class (:background ,func :foreground ,func))))
   `(term-color-white  ((,class (:background ,fg :foreground ,fg)))))

  (custom-theme-set-variables
   'vscode-kimbie-dark
   `(ansi-color-names-vector [,bg ,error ,success ,warning ,link ,keyword ,func ,fg])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'vscode-kimbie-dark)
;;; vscode-kimbie-dark-theme.el ends here
