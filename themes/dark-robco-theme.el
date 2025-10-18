;;; robco-terminal-theme.el --- Fallout/RobCo CRT green -*- lexical-binding: t; -*-
;;; Commentary:
;; Verde fósforo sobre negro, minimalista y legible.

(deftheme robco-terminal "Fallout/RobCo CRT green")

(let* ((class '((class color) (min-colors 89)))
       (bg        "#000000")
       (fg        "#33ff66")   ;; texto principal
       (fg-strong "#66ff99")   ;; acentos
       (fg-dim    "#1ea34a")   ;; atenuados
       (fg-weak   "#0f6a33")   ;; muy atenuados
       (cursor    "#7CFC00")
       (region    "#003d20")
       (hl        "#004d26")
       (modeline-fg bg)
       (modeline-bg fg)
       (modeline-inactive "#001a0e"))
  (custom-theme-set-faces
   'robco-terminal
   ;; Base
   `(default ((,class (:background ,bg :foreground ,fg))))
   `(cursor  ((,class (:background ,cursor))))
   `(fringe  ((,class (:background ,bg :foreground ,fg-weak))))
   `(vertical-border ((,class (:foreground ,fg-weak))))
   `(region  ((,class (:background ,region))))
   `(highlight ((,class (:inverse-video t))))
   `(shadow  ((,class (:foreground ,fg-weak))))
   `(minibuffer-prompt ((,class (:foreground ,fg-strong :weight bold))))
   `(link ((,class (:foreground ,fg-strong :underline t))))
   `(success ((,class (:foreground ,fg-strong :weight bold))))
   `(warning ((,class (:foreground ,fg-strong :underline t))))
   `(error ((,class (:foreground ,fg-strong :inverse-video t :weight bold))))

   ;; Mode line
   `(mode-line
     ((,class (:foreground ,modeline-fg :background ,modeline-bg
                           :box (:line-width 1 :color ,fg) :weight semibold))))
   `(mode-line-inactive
     ((,class (:foreground ,fg-weak :background ,modeline-inactive
                           :box (:line-width 1 :color ,fg-weak)))))

   ;; Números de línea
   `(line-number ((,class (:foreground ,fg-weak :background ,bg))))
   `(line-number-current-line ((,class (:foreground ,fg :weight bold))))

   ;; Búsqueda y paréntesis
   `(isearch        ((,class (:background ,fg :foreground ,bg :weight bold))))
   `(lazy-highlight ((,class (:background ,hl :weight bold))))
   `(show-paren-match    ((,class (:weight bold :underline t))))
   `(show-paren-mismatch ((,class (:background ,bg :foreground ,fg-strong
                                               :inverse-video t :weight bold))))

   ;; Sintaxis
   `(font-lock-comment-face       ((,class (:foreground ,fg-weak :slant italic))))
   `(font-lock-doc-face           ((,class (:inherit font-lock-comment-face))))
   `(font-lock-string-face        ((,class (:foreground ,fg-dim))))
   `(font-lock-keyword-face       ((,class (:foreground ,fg :weight semibold))))
   `(font-lock-builtin-face       ((,class (:foreground ,fg))))
   `(font-lock-type-face          ((,class (:foreground ,fg))))
   `(font-lock-constant-face      ((,class (:foreground ,fg))))
   `(font-lock-function-name-face ((,class (:foreground ,fg))))
   `(font-lock-variable-name-face ((,class (:foreground ,fg))))
   `(font-lock-warning-face       ((,class (:foreground ,fg-strong :underline t))))

   ;; Org
   `(org-level-1 ((,class (:weight bold :foreground ,fg-strong))))
   `(org-level-2 ((,class (:weight bold :foreground ,fg))))
   `(org-level-3 ((,class (:foreground ,fg))))
   `(org-code   ((,class (:background ,hl :foreground ,fg))))
   `(org-block  ((,class (:background ,hl))))
   `(org-block-begin-line ((,class (:inherit shadow :background ,hl))))
   `(org-block-end-line   ((,class (:inherit shadow :background ,hl))))
   `(org-link ((,class (:inherit link))))

   ;; ANSI/term: todo verdoso para look monocromo
   `(term ((,class (:background ,bg :foreground ,fg))))
   `(term-color-black  ((,class (:background ,bg :foreground ,bg))))
   `(term-color-green  ((,class (:background ,fg :foreground ,fg))))
   `(term-color-white  ((,class (:background ,fg-strong :foreground ,fg-strong))))
   ;; el resto reusa verde
   `(term-color-red    ((,class (:background ,fg :foreground ,fg))))
   `(term-color-yellow ((,class (:background ,fg :foreground ,fg))))
   `(term-color-blue   ((,class (:background ,fg :foreground ,fg))))
   `(term-color-magenta ((,class (:background ,fg :foreground ,fg))))
   `(term-color-cyan   ((,class (:background ,fg :foreground ,fg)))))

  (custom-theme-set-variables
   'robco-terminal
   `(ansi-color-names-vector [,bg ,fg-weak ,fg ,fg ,fg ,fg ,fg ,fg])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'robco-terminal)
;;; robco-terminal-theme.el ends here
