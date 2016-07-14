;; tree-promote.el

;; Promote (and demote) a tree for code editing (think org-mode).
;;
;; This snippet is meant for indentation-based languages.


;; As an answer to https://www.reddit.com/r/emacs/comments/4jb8dj/orgmodelike_promotedemote_tree_for_editing/

(defun current-line ()
  "returns the current line."
  ;; http://ergoemacs.org/emacs/elisp_all_about_lines.html
         (let ( (p1 (line-beginning-position))
                (p2 (line-end-position)))
           (buffer-substring-no-properties p1 p2)
           ))

(defun current-line-indentation ()
  "returns the str of the current indentation (spaces)."
  ;; https://github.com/magnars/s.el#s-match-strings-all-regex-string
  (car (car (s-match-strings-all "^\s+" (current-line)) ) ))

(defun my-indent (reg-beg reg-end)
  "Indent a region with spaces (should be replaced with a
   built-in one, but I observed evil's is buggy in some modes, like
   jade-mode."
  (interactive "r")
  (save-excursion
    (replace-regexp "^" "    " nil reg-beg reg-end)))

(defun my-blank-line-p ()
  "Return true if we are on a blank line"
  (equal (line-beginning-position) (line-end-position)))

(defun buffer-mode (buffer-or-string)
  "Returns the major mode associated with a buffer."
  ;; thanks https://stackoverflow.com/questions/2238418/emacs-lisp-how-to-get-buffer-major-mode
  (with-current-buffer buffer-or-string
    major-mode))

(defvar tree-promote-indent-offset 2 "default indentation offset")

(defun beginning-of-line-point ()
  (save-excursion
    (beginning-of-line)
    (point)))

(defun tree-promote-end-of-tree-point ()
  "Get the point of the end of the indentend tree."
  (save-excursion
    (tree-promote-goto-end-of-tree)
    (point)))

(defun tree-promote--indentation-offset ()
  "Get the current mode's indentation offset. Return an int (for python, it's usually 4)."
  (let ((current-mode (buffer-mode (current-buffer))))
    (cond ((and (equal current-mode 'python-mode)
                (boundp 'python-indent-offset)
                (numberp python-indent-offset))
           python-indent-offset)

          ((and (equal current-mode 'jade-mode)
                (boundp 'jade-tab-width)
                (numberp jade-tab-width))
           jade-tab-width)

          ((and (equal current-mode 'yaml-mode)
                (boundp 'yaml-indent-offset)
                (numberp yaml-indent-offset))
           yaml-indent-offset)

          (t tree-promote-indent-offset))))

(defun tree-promote--on-last-line ()
  (equal (line-number-at-pos) (count-lines (point-min) (point-max))))

(defun tree-promote-goto-end-of-tree ()
  "Go to the end of the indented tree."
  (interactive)
  (let ((goal-column (length (current-line-indentation)))  ;; see next-line doc
        (last-line-reached nil))
    (beginning-of-line-text)
    (next-line)
    (while (and (not last-line-reached)
                (or
                 (my-blank-line-p)
                 (string-equal (char-to-string (following-char)) " ")))
      (if (tree-promote--on-last-line)
          (setq last-line-reached t)
        (next-line)))
    (unless last-line-reached (previous-line))
    (end-of-line)
    ))

(defun tree-promote-goto-parent ()
  ""
  (interactive)
  (beginning-of-line-text)
  (unless (string-equal (current-line-indentation) "")
      (let ((element-regexp "[a-z]"))
        (search-backward-regexp (concat "^"
                                        (s-left (- (length (current-line-indentation))
                                                   (tree-promote--indentation-offset))
                                                (current-line-indentation))
                                        element-regexp))
        (beginning-of-line-text))
  (message "you don't have more parents")
  ))

(defun tree-promote-goto-child ()
  "Go down to the first child (line with greater indentation)."
  (interactive)
  (beginning-of-line-text)
  (let ((element-regexp "[a-z]"))
    (search-forward-regexp (concat "^"
                                   (current-line-indentation)
                                   (s-repeat (tree-promote--indentation-offset) " ")
                                   element-regexp))
    ))

(defun tree-promote-select-end-of-tree ()
  ""
  (interactive)
  (let ((beg (beginning-of-line-point))
        (end (save-excursion
               (tree-promote-goto-end-of-tree)
               (point))))
    (goto-char beg)
    (push-mark)
    (activate-mark)
    (goto-char end)
    ))

(defun tree-promote-end-of-level () ;; OK needs more tests MORE TESTS PLZ
  "Go to the end of this indentation level"
  (interactive)
  (let* ((indentation (current-line-indentation))
         (last-line-reached nil))
    (beginning-of-line-text)
    (next-line)
    (while (not last-line-reached)
      (if (my-blank-line-p)
          (next-line))
      (if (< (length (current-line-indentation))
             (length indentation))
          (setq last-line-reached t)
        (next-line)))

    (beginning-of-line-text)))

(defun tree-promote-end-of-level-point ()
  ""
  (save-excursion
    (tree-promote-end-of-level)
    (previous-line)
    (point)))

(defun tree-promote-indent-end-of-level ()
  ""
  (let ((beg (point))
        (end (tree-promote-end-of-level-point))
        (offset (tree-promote--indentation-offset)))
    (indent-rigidly beg end offset)))

(defun tree-promote-goto-next-sibling () ;; !! already done with yaml next sibling !
  (interactive)
  (call-interactively 'tree-promote-goto-end-of-level)
  ;; go to next char, excluding whitespaces or newline (skip new lines).
  (search-forward-regexp "[^\n ]") (backward-char)
)

(defun tree-promote-select ()
  "Select the tree (useful to visualize.
   Also useful: highlight-indentation-current-column-mode"
  ; use a red hydra to cancel effects instead ?
  (interactive)
  (let ((beg (save-excursion
               (beginning-of-line-text) (point)))
        (end (tree-promote-end-of-tree-point)))
    (goto-char beg)
    (push-mark)
    (activate-mark)
    (goto-char end)
    ))

(defun tree-promote (&optional select)
;; (defun tree-promote (select)
  "Indent the current tree (based on indentation)."
    ;; (interactive "P")
    (interactive)
    (let ((beg (save-excursion
                (beginning-of-line) (point)))
          (end (tree-promote-end-of-tree-point))
          (indentation-level (tree-promote--indentation-offset)))
    (if select
            (call-interactively 'indent-rigidly t (vector beg end)) ;; hey… hydras do the job of repetition !
            (indent-rigidly beg end indentation-level))
          ;; (my-indent beg end))
          ))

(defun tree-promote-indent-end-of-defun ()
  "Indent until the end of the current defun."
  (interactive)
  (let ((beg (beginning-of-line-point))
        (end (save-excursion
               (end-of-defun)
               (point)))
        (indentation-level (tree-promote--indentation-offset)))
    (if (equal beg end)
        ;; case we're at the last defun or in __main__, not a defun.
        (setq end (point-max)))
    (indent-rigidly beg end indentation-level)
    ))

(defun tree-promote-indent-space ()
  "Indent with only a space (specially useful in jade-mode)."
  (interactive)
  (let ((beg (beginning-of-line-point))
        (end (tree-promote-end-of-tree-point))
        (indentation-level (tree-promote--indentation-offset)))
    (save-excursion
      (replace-regexp "^" " " nil beg end))))

(defun tree-promote-demote ()
  "de-indent the current indented tree"
  ;; todo: factorize
  (interactive)
  (let ((beg (save-excursion
               (beginning-of-line) (point)))
        (end (tree-promote-end-of-tree-point))
        (indentation-level (- (tree-promote--indentation-offset))))
    (indent-rigidly beg end indentation-level)))

(defun tree-promote-interactive ()
  "Set the indentation yourself with the arrow keys."
  ;; that's what M-x indent-rigidly without arg does.
  ;; TO FIX
  (interactive)
  (tree-promote t))

(defun tree-promote-comment ()
  (interactive)
  (let ((beg (beginning-of-line-point))
        (end (tree-promote-end-of-tree-point)))
    (setq tree-promote--last-beg beg) ;; re-use to uncomment
    (setq tree-promote--last-end end)
    (comment-region beg end)))

(defun tree-promote-delete ()
  "Delete the current indentated tree."
  (interactive)
  (let ((beg (save-excursion
               (beginning-of-line-text)
               (point)))
        (end (tree-promote-end-of-tree-point)))
    (delete-region beg end)))

(defhydra tree-promote-hydra (:color red :columns 2)
  "tree promote"
  (">" (tree-promote) "Indent")
  ("<" (tree-promote-demote) "De-indent")
  ("E" (tree-promote-indent-end-of-defun) "indent 'til end of defun")
  ("c" (tree-promote-comment) "Comment")
  (")" (tree-promote-indent-end-of-level) "indent until end of level")
  ("D" (tree-promote-delete) "Delete")
  ("s" (tree-promote-select) "Select region")
  ("e" (tree-promote-goto-end-of-tree) "goto end of tree")
  ("u" (tree-promote-goto-parent) "go one parent up")
  ("d" (tree-promote-goto-child) "go down one child")
  ("S" (tree-promote-select-end-of-tree) "select until end of tree")
  ("<SPC>" (tree-promote-indent-space) "indent with a space")
  )

(defalias 'hydra-tree-promote 'tree-promote-hydra)


(global-set-key (kbd "C-c >") 'tree-promote-hydra/body) ;; overrides in python-mode that only indent the current line
