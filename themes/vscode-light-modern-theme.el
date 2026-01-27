;;; vscode-light-modern-theme.el --- VS Code Light Modern theme -*- lexical-binding: t; -*-
;;; Commentary:
;; White-toned theme inspired by VS Code Default Light Modern + Light+ tokens.

(deftheme vscode-light-modern "VS Code Light Modern")

(let* ((class '((class color) (min-colors 89)))
       (bg "#FFFFFF")
       (fg "#3B3B3B")
       (fg-strong "#000000")
       (fg-dim "#6E7681")
       (fg-weak "#8B949E")
       (cursor fg-strong)
       (accent "#005FB8")
       (region "#ADD6FF")
       (hl "#F2F2F2")
       (modeline-fg fg)
       (modeline-bg "#F8F8F8")
       (modeline-inactive "#E5E5E5")
       ;; Syntax (Light+ token colors)
       (comment "#008000")
       (string "#A31515")
       (keyword "#AF00DB")
       (builtin "#0070C1")
       (type "#267F99")
       (func "#795E26")
       (var "#001080")
       (const "#0070C1")
       (number "#098658")
       (link "#0451A5")
       (warning "#BB8009")
       (error "#F85149")
       (success "#2EA043"))
  (custom-theme-set-faces
   'vscode-light-modern
   ;; Base
   `(default ((,class (:background ,bg :foreground ,fg))))
   `(cursor  ((,class (:background ,cursor))))
   `(fringe  ((,class (:background ,bg :foreground ,fg-weak))))
   `(vertical-border ((,class (:foreground ,modeline-inactive))))
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
                           :box (:line-width 1 :color ,modeline-inactive) :weight semibold))))
   `(mode-line-inactive
     ((,class (:foreground ,fg-dim :background ,modeline-inactive
                           :box (:line-width 1 :color ,modeline-inactive)))))

   ;; Line numbers
   `(line-number ((,class (:foreground ,fg-dim :background ,bg))))
   `(line-number-current-line ((,class (:foreground ,accent :weight bold))))

   ;; Search and parens
   `(isearch        ((,class (:background ,accent :foreground ,bg :weight bold))))
   `(lazy-highlight ((,class (:background ,region :weight bold))))
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
   `(org-code   ((,class (:background ,hl :foreground ,fg-strong))))
   `(org-block  ((,class (:background ,hl))))
   `(org-block-begin-line ((,class (:inherit shadow :background ,hl))))
   `(org-block-end-line   ((,class (:inherit shadow :background ,hl))))
   `(org-link ((,class (:inherit link))))

   ;; Term colors
   `(term ((,class (:background ,bg :foreground ,fg))))
   `(term-color-black  ((,class (:background ,bg :foreground ,bg))))
   `(term-color-red    ((,class (:background ,error :foreground ,error))))
   `(term-color-green  ((,class (:background ,success :foreground ,success))))
   `(term-color-yellow ((,class (:background ,warning :foreground ,warning))))
   `(term-color-blue   ((,class (:background ,link :foreground ,link))))
   `(term-color-magenta ((,class (:background ,keyword :foreground ,keyword))))
   `(term-color-cyan   ((,class (:background ,type :foreground ,type))))
   `(term-color-white  ((,class (:background ,fg :foreground ,fg)))))

  (custom-theme-set-variables
   'vscode-light-modern
   `(ansi-color-names-vector [,bg ,error ,success ,warning ,link ,keyword ,type ,fg])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'vscode-light-modern)
;;; vscode-light-modern-theme.el ends here
