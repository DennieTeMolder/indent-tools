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

(defun my-blank-line ()
  (equal (line-beginning-position) (line-end-position)))

(defun tree-promote-goto-end-of-tree ()
  "Go to the end of the indented tree."
  (interactive)
  (let ((goal-column (length (current-line-indentation)))) ;; see next-line doc
    (beginning-of-line-text)
    (next-line)
    (while (or  (my-blank-line)
                (string-equal (char-to-string (following-char)) " "))
      (next-line))
    (previous-line)
    (end-of-line)
    ))

(defun tree-promote-end-of-tree-point ()
  "Get the point of the end of the indentend tree."
  (save-excursion
    (tree-promote-goto-end-of-tree)
    (point)))

(defun tree-promote (&optional select)
;; (defun tree-promote (select)
  "Indent the current tree (based on indentation)."
    ;; (interactive "P")
    (interactive)
    (let ((beg (save-excursion
                (beginning-of-line) (point)))
        (end (tree-promote-end-of-tree-point)))
    (if select
          (call-interactively 'indent-rigidly (vector beg end))
        (indent-rigidly beg end 2))
      ;; (my-indent beg end))
      ))

(defun tree-promote-interactive ()
  "Set the indentation yourself with the arrow keys."
  ;; that's what M-x indent-rigidly without arg does.
  ;; TO FIX
  (interactive)
  (tree-promote t))

(defun tree-promote-comment ()
  (interactive)
  (let ((beg (save-excursion
               (beginning-of-line-text)
               (point)))
        (end (tree-promote-end-of-tree-point)))
    (comment-region beg end)))

(defun tree-promote-delete ()
  "Delete the current indentated tree."
  (interactive)
  (let ((beg (save-excursion
               (beginning-of-line-text)
               (point)))
        (end (tree-promote-end-of-tree-point)))
    (delete-region beg end)))

(defhydra tree-promote-hydra (:color red :columns 1)
  "tree promote"
  (">" (tree-promote) "Indent")
  ("c" (tree-promote-comment) "Comment")
  ("d" (tree-promote-delete) "Delete")
  )

(defalias 'hydra-tree-promote 'tree-promote-hydra)


(global-set-key (kbd "C-c >") 'tree-promote) ;; overrides in python-mode that only indent the current line
