;;; polyp.el --- Nested modal keybindings -*- lexical-binding: t -*-

;; Author: Daniel Mendler
;; Created: 2020
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Package-Requires: ((emacs "26"))
;; Homepage: https://github.com/minad/polyp

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Nested modal keybindings

;;; Code:

(require 'cl-lib)

(defvar display-line-numbers)
(defvar display-fill-column-indicator)
(defvar tab-line-format)
(defvar golden-ratio-mode)

(cl-defstruct (polyp- (:constructor polyp--make) (:copier nil)) name handler prev)

(defvar polyp--window nil
  "Current Polyp window.")

(defvar polyp--update nil
  "Polyp window update status.")

(defvar polyp--active nil
  "Currently active Polyp.")

(defvar polyp-status nil
  "The Polyp status, which is shown in the mode-line if `polyp-mode' is enabled.")

(defgroup polyp nil
  "Polyp customizations."
  :group 'bindings
  :prefix "polyp-")

(defcustom polyp-highlight
  '(("_" . font-lock-function-name-face)
    ("*" . font-lock-constant-face)
    ("=" . font-lock-keyword-face))
  "Highlighting characters and fonts used for the Polyp descriptions."
  :type 'alist
  :group 'polyp)

(defcustom polyp-bind
  'bind-key
  "Function which Polyp uses used to define key bindings."
  :type 'symbol
  :group 'polyp)

(defcustom polyp-mode-line
  '("[" (:propertize polyp-status face warning) "]")
  "Polyp mode line format.
The current Polyp is shown in the mode-line if `polyp-mode' is enabled."
  :type 'sexp
  :group 'polyp)
;;;###autoload (put 'polyp-mode-line 'risky-local-variable t)

(defconst polyp--buffer-name " *polyp*")
(with-eval-after-load 'ace-window (push polyp--buffer-name aw-ignored-buffers))

(defvar polyp-base-map
  (let ((map (make-sparse-keymap)))
    (define-key map [?\C-g] #'polyp--quit)
    (define-key map [?\C-u] #'polyp--universal-argument)
    (define-key map [?u] #'polyp--universal-argument)
    (define-key map [?-] #'polyp--negative-argument)
    (define-key map [kp-subtract] #'polyp--negative-argument)
    (dotimes (n 10)
      (define-key map (vector (intern (format "kp-%s" n))) #'polyp--digit-argument)
      (define-key map (vector (+ ?0 n)) #'polyp--digit-argument))
    map)
  "Keymap used as parent keymap for the transient maps.")

;; The functions `universal-argument', `digit-argument' and `negative-argument' must be
;; replicated for Polyp, since the Emacs functions push their own transient map.
;; This means that the Polyp keys like "u" do not work while the transient map is active.
(defun polyp--universal-argument (arg)
  "Replacement for `universal-argument', to be used inside a Polyp."
  (interactive "P")
  (prefix-command-preserve-state)
  (setq prefix-arg (cond
                    ((consp arg) (list (* 4 (car arg))))
                    ((eq arg '-) '(-4))
                    (t '(4)))))

(defun polyp--digit-argument (arg)
  "Replacement for `digit-argument', to be used inside a Polyp."
  (interactive "P")
  (prefix-command-preserve-state)
  (let* ((char (if (integerp last-command-event)
		   last-command-event
		 (get last-command-event 'ascii-character)))
	 (digit (- (logand char ?\177) ?0)))
    (setq prefix-arg (cond ((integerp arg)
                            (+ (* arg 10)
			       (if (< arg 0) (- digit) digit)))
                           ((eq arg '-)
                            (if (zerop digit) '- (- digit)))
                           (t
                            digit)))))

(defun polyp--negative-argument (arg)
  "Replacement for `negative-argument', to be used inside a Polyp."
  (interactive "P")
  (prefix-command-preserve-state)
  (setq prefix-arg (cond ((integerp arg) (- arg))
                         ((eq arg '-) nil)
                         (t '-))))

;; taken from lv.el
(defun polyp--window-make ()
  "Create Polyp window."
  (with-selected-window
      (setq polyp--window (let ((ignore-window-parameters t))
                            (split-window (frame-root-window) -1 'below)))
    (if (get-buffer polyp--buffer-name)
        (switch-to-buffer polyp--buffer-name 'norecord)
      (switch-to-buffer polyp--buffer-name 'norecord)
      (fundamental-mode)
      (set-window-hscroll polyp--window 0)
      (setq window-size-fixed t
            mode-line-format nil
            header-line-format nil
            tab-line-format nil
            cursor-type nil
            display-line-numbers nil
            display-fill-column-indicator nil)
      (set-window-dedicated-p polyp--window t)
      (set-window-parameter polyp--window 'no-other-window t))))

;; taken from lv.el
(defun polyp--window-show (str)
  "Show STR in Polyp window."
  (let (deactivate-mark golden-ratio-mode)
    (unless (window-live-p polyp--window) (polyp--window-make))
    (with-selected-window polyp--window
      (unless (string= (buffer-string) str)
        (delete-region (point-min) (point-max))
        (insert str)
        (setq-local window-min-height (cl-count ?\n str))
        (setq truncate-lines (> window-min-height 1))
        (let ((window-resize-pixelwise t)
              window-size-fixed)
          (fit-window-to-buffer nil nil 1)))
      (goto-char (point-min)))))

;; taken from lv.el
(defun polyp--window-hide ()
  "Hide Polyp window."
  (when (window-live-p polyp--window)
    (let ((buf (window-buffer polyp--window)))
      (delete-window polyp--window)
      (kill-buffer buf))))

(defmacro polyp--body-off (&rest body)
  "Suspend and restore the active Polyp around BODY."
  (let ((p (gensym)))
    `(let ((,p polyp--active))
       (unwind-protect (progn ,@body)
         (polyp--restore ,p)))))

(defmacro polyp--body-quit (&rest body)
  "Quit the current Polyp and restore the previous Polyp after BODY."
  (let ((p (gensym)))
    `(let ((,p (polyp--prev polyp--active)))
       (unwind-protect (progn ,@body)
         (when ,p (polyp--restore ,p))))))

(defvar polyp--foreign nil)

(defun polyp--foreign (&optional arg)
  "Execute foreign command while active Polyp is off. ARG is the universal argument."
  (interactive "P")
  (polyp--body-off
   (funcall (polyp--name polyp--active) 'off)
   (setq this-command polyp--foreign
         current-prefix-arg arg)
   (call-interactively polyp--foreign)))

(defsubst polyp--valid-keys (keys)
  "Return t if KEYS is part of the Polyp keymap."
  (or
   ;; Always run prefix-help-command.
   (eq this-command prefix-help-command)
   ;; Key found in the Polyp keymap.
   (eq this-command (lookup-key (symbol-value (polyp--name polyp--active)) keys))))

(defun polyp--handler-ignore ()
  "Polyp event handler. Foreign keys are ignored."
  (let ((keys (this-single-command-keys)))
    (unless (polyp--valid-keys keys)
      ;; Ignore command
      (setq this-command #'ignore)
      (message "%s is undefined" (key-description keys)))))

(defun polyp--handler-run ()
  "Polyp event handler. Foreign keys are executed."
  (unless (polyp--valid-keys (this-single-command-keys))
    ;; Suspend current Polyp, run command.
    (setq polyp--foreign this-command
          this-command (and (commandp this-command t) #'polyp--foreign))))

(defun polyp--handler-quit ()
  "Polyp event handler. The Polyp is left on a foreign key press."
  (let ((keys (this-single-command-keys)))
    (unless (polyp--valid-keys keys)
      ;; Quit current Polyp, reexecute command.
      (let ((p (polyp--prev polyp--active)))
        (funcall (polyp--name polyp--active) 'quit)
        (when p (polyp--restore p)))
      (setq this-command #'ignore
            unread-command-events
            (append
             (mapcar (lambda (x) (cons t x))
                     (append (if prefix-arg
                                 ;; HACK: For some reason this-command-keys does not include the prefix, add it manually.
                                 (listify-key-sequence (format "\C-u%s" (prefix-numeric-value prefix-arg))))
                             (listify-key-sequence keys)))
                    unread-command-events)))))

(defun polyp--restore (p)
  "Restore Polyp P."
  (cond
   (polyp--active
    (let ((q polyp--active))
      (while (polyp--prev q)
        (setq q (polyp--prev q)))
      (setf (polyp--prev q) p)))
   (overriding-terminal-local-map
    (let ((n (make-symbol "polyp--restore")))
      (fset n (lambda ()
                (unless overriding-terminal-local-map
                  (remove-hook 'post-command-hook n)
                  (polyp--restore p))))
      (add-hook 'post-command-hook n)))
   (t
    (funcall (polyp--name (setq polyp--active p)) 'on))))

(defun polyp--toggle (flag)
  "Generate a toggle string depending on FLAG."
  (concat "(" (if flag #("•" 0 1 (face success)) " ") ")"))

(defmacro polyp--toggle! (flag)
  "Macro used to generate a toggle for FLAG."
  (if (symbolp flag)
      `(polyp--toggle (and (boundp ',flag) ,flag))
    `(polyp--toggle ,flag)))

(defun polyp--colorize (str)
  "Colorize the string STR according to `polyp-highlight'."
  (let* ((chars (apply #'concat (mapcar #'car polyp-highlight)))
         (regexp (format "\\([%s]\\)\\([^%s]+\\)\\1" chars chars))
         (str (replace-regexp-in-string "\\^\\|^\n" "" str)))
    (save-match-data
      (while (string-match regexp str)
        (setq str (replace-match
                   (propertize (match-string 2 str) 'face
                               (cdr (assoc (match-string 1 str) polyp-highlight)))
                   t nil str))))
    str))

(defun polyp--parse-desc (desc)
  "Parse the description string DESC."
  (let ((str "") fields)
    (setq desc (replace-regexp-in-string "%t(" "%(polyp--toggle! " desc))
    (save-match-data
      (while (string-match "\\(%[^(`]*\\)[(`]" desc)
        (let ((s (match-string 1 desc))
              (r (read-from-string (replace-regexp-in-string "^`" " " (substring desc (match-end 1))))))
          (setq str (concat str (substring desc 0 (match-beginning 0)) "%s")
                desc (substring desc (+ (match-end 1) (cdr r))))
          (push (if (string= s "%") (car r) `(format ,s ,(car r))) fields))))
    (cons (polyp--colorize (concat str desc)) (nreverse fields))))

(defun polyp--bind-keys (map keys cmd)
  "Bind a list of KEYS to CMD in the keymap MAP."
  (mapcar (lambda (k) `(,polyp-bind ,k #',cmd ,map)) keys))

(defun polyp--reject (keys map)
  "Remove all KEYS from property MAP."
  (let ((res))
    (while map
      (if (memq (car map) keys)
          (setq map (cddr map))
        (push (car map) res)
        (setq map (cdr map))))
    (nreverse res)))

(defmacro polyp--call (cmd)
  "Call Polyp function CMD, which can be a symbol, a key string or a sexp."
  (cond
   ((symbolp cmd)
    `(call-interactively (setq this-command #',cmd)))
   ((stringp cmd)
    `(let ((bind (key-binding ,(kbd cmd))))
       (if (commandp bind t)
           (call-interactively (setq this-command bind))
         (setq unread-command-events
               (append
                ',(mapcar (lambda (x) (cons t x)) (listify-key-sequence (kbd cmd)))
                unread-command-events)))))
   (t cmd)))

(defun polyp--quit ()
  "Quit the current Polyp and restore the previous Polyp."
  (interactive)
  (polyp--body-quit
   (funcall (polyp--name polyp--active) 'quit)
   (polyp--call #'keyboard-quit)))

(defun polyp--enter-cmd (name cmd)
  "Generate enter command for Polyp named NAME.
The command CMD is executed after showing the Polyp description."
  `(,(format "Show Polyp `%s' and call `%s'." name cmd)
    (interactive)
    (,name)
    (polyp--body-off
     (,name 'off)
     (polyp--call ,cmd))))

(defun polyp--quit-cmd (name cmd)
  "Generate quit command for Polyp named NAME.
The command CMD is executed after hiding the Polyp description."
  `(,(format "Hide Polyp `%s' and call `%s'." name cmd)
    (interactive)
    (polyp--body-quit
     (,name 'quit)
     (polyp--call ,cmd))))

(defsubst polyp--set-status (status)
  "Set Polyp mode line STATUS."
  (unless (equal polyp-status status)
    (setq polyp-status status)
    (force-mode-line-update t)))

(defun polyp--hook (opts name)
  "Get hook option NAME from OPTS plist."
  (if-let (x (plist-get opts name))
      (if (symbolp x) `((,x)) `(,x))))

;;;###autoload
(defmacro polyp (name &rest body)
  "Define a Polyp with a given NAME.

The description can contain syntax highlighting.

The first argument of the BODY can be an optional description string.

After that, the following keyword arguments can be specified:

- :outer-map Keymap used for the outer bindings.
- :base-map  Base keymap used for the transient bindings.
- :bind      Bindings to which this Polyp is bound in the outer keymap.
- :enter     Action to perform before entering the Polyp.
- :quit      Action to perform after quitting the Polyp.
- :on        Action to perform when Polyp is activated.
- :off       Action to perform when Polyp is deactivated.
- :update    Action to perform after each action, when Polyp is active.
- :handler   Specifies the Polyp handler, which handles foreign keys.
- :status    Specifies the status string shown in the mode-line.
- :which-key Enable which-key popup.

Then a list of key bindings can be given of the form:

    (\"key\" cmd \"outer-key1\" \"outer-key2\"...)
    ((\"key1\" \"key2\") cmd \"outer-key1\" \"outer-key2\"...)
    (\"key\" cmd :quit)
    ((\"key1\" \"key2\") cmd :quit)

The keys are bound to the transient map of the Polyp, while
the outer keys are added to both the transient map and the outer map.
The bindings which specify :quit, quit the polyp."
  (let* ((opts (if (stringp (car body)) (cdr body) body))
         (desc (if (stringp (car body)) (car body)))
         (body (polyp--reject '(:enter :quit :on :off :update :handler :bind :base-map :outer-map :status :which-key) opts))
         (desc-quit '((when polyp--update (polyp--window-hide) (setq polyp--update nil))))
         (desc-update (if desc
                          (pcase-let ((`(,desc . ,fields) (polyp--parse-desc desc)))
                            (if fields
                                `((polyp--window-show (format ,desc ,@fields))
                                  (setq polyp--update ',name))
                              `((unless (eq polyp--update ',name)
                                  (polyp--window-show ,desc)
                                  (setq polyp--update ',name)))))
                        desc-quit))
         (opt-outer-map (or (plist-get opts :outer-map) 'global-map))
         (opt-base-map (or (plist-get opts :base-map) 'polyp-base-map))
         (opt-handler (plist-get opts :handler))
         (opt-which-key (plist-get opts :which-key))
         (opt-update `(,@desc-update ,@(polyp--hook opts :update)))
         (opt-on `((polyp--set-status ,(if (plist-member opts :status)
                                           (plist-get opts :status)
                                         (symbol-name name)))
                   ,@(polyp--hook opts :on)))
         (opt-off `((polyp--set-status nil)
                    ,@(polyp--hook opts :off)))
         (opt-quit `(,@desc-quit
                     ,@(polyp--hook opts :quit)
                     ,@(if opt-which-key '((polyp--which-key-quit)))))
         (opt-enter `(,@(polyp--hook opts :enter)
                      ,@(if opt-which-key '((polyp--which-key-enter)))))
         (opt-bind (plist-get opts :bind))
         (used-names)
         (tmp (gensym)))
    `(progn
       ;; The main function of the Polyp.
       (defun ,name (&optional op)
         ,(format "Polyp `%s'." name)
         (interactive)
         (cl-assert (or (not (eq op 'on)) (and polyp--active (eq (polyp--name polyp--active) ',name))))
         (if (or (eq op 'off) (eq op 'quit))
             (progn
               ,@opt-off
               (internal-pop-keymap ,name 'overriding-terminal-local-map)
               (remove-hook 'pre-command-hook (polyp--handler polyp--active))
               (when (eq op 'quit) ,@opt-quit)
               (setq polyp--active nil))
           (let ((,tmp (polyp--make :name ',name
                                    :handler #',(intern (format "polyp--handler-%s" (or opt-handler 'quit)))
                                    :prev polyp--active)))
             (unless (or (eq op 'on) (and polyp--active (eq (polyp--name polyp--active) ',name)))
               (when polyp--active (funcall (polyp--name polyp--active) 'off))
               (setq polyp--active ,tmp)
               ,@opt-enter
               (setq op 'on)))
           (when (eq op 'on)
             (add-hook 'pre-command-hook (polyp--handler polyp--active))
             (internal-push-keymap ,name 'overriding-terminal-local-map)
             ,@opt-on)
           ,@opt-update))

       ;; Create keymap which inherits from :base-map
       (setq ,name (make-composed-keymap (make-sparse-keymap) ,opt-base-map))

       ;; Bind main keys
       ,@(polyp--bind-keys nil (if (listp opt-bind) opt-bind (list opt-bind)) name)

       ;; Generate code for the bindings
       ,@(mapcan
          (pcase-lambda (`(,keys ,cmd . ,enter))
            ;; Normalize keys
            (setq keys (mapcar (lambda (k) (key-description (kbd k)))
                               (if (listp keys) keys (list keys))))
            (when (stringp cmd) (setq cmd (key-description (kbd cmd))))
            (let ((sym (intern (format "%s/%s" name cmd))))
              ;; Ensure that function name is unique
              (when (memq sym used-names)
                (setq sym (intern (format "%s/%s[%s]" name cmd (car keys)))))
              (push sym used-names)
              `((defun ,sym ()
                  ,@(if (equal enter '(:quit)) (polyp--quit-cmd name cmd) (polyp--enter-cmd name cmd)))
                ,@(unless (equal enter '(:quit))
                    (append (polyp--bind-keys name enter sym)
                            (polyp--bind-keys opt-outer-map enter sym)))
                ,@(polyp--bind-keys name keys sym))))
          body)
       ',name)))
(put 'polyp 'lisp-indent-function 'defun)

;;;###autoload
(define-minor-mode polyp-mode
  "Minor mode which shows the current Polyp in the mode-line."
  :global t
  (if polyp-mode
      (push '(polyp-status ("" polyp-mode-line " ")) mode-line-misc-info)
    (setq mode-line-misc-info (assq-delete-all 'polyp-status mode-line-misc-info))))

(defun polyp-repeat (&optional arg)
  "Repeat last Polyp command. The prefix argument can be overwritten by ARG."
  (interactive "p")
  (setq current-prefix-arg (if (eq arg 1) last-prefix-arg arg)
        this-command last-command)
  (when (eq last-command 'self-insert-command)
    (setq last-command-event (char-before)))
  (let ((n (prefix-numeric-value current-prefix-arg)))
    (if (and current-prefix-arg (/= n 1))
        (message "Repeat %sx %s" n this-command)
      (message "Repeat %s" this-command)))
  (call-interactively this-command))

(defvar which-key-show-transient-maps)
(defvar which-key-persistent-popup)
(defvar polyp--which-key-state nil)

(defsubst polyp--which-key-enter ()
  "Called when Polyp with which-key support is entered."
  (setq polyp--which-key-state (cons which-key-show-transient-maps which-key-persistent-popup)
        which-key-show-transient-maps t
        which-key-persistent-popup t))

(defsubst polyp--which-key-quit ()
  "Called when Polyp with which-key support is quitting."
  (let ((state (pop polyp--which-key-state)))
    (setq which-key-show-transient-maps (car state)
          which-key-persistent-popup (cdr state)))
  (unless polyp--which-key-state (which-key--hide-popup)))

;; TODO is there a better possibility to add a filter to which-key?
;; https://github.com/justbur/emacs-which-key/issues/272
(defun polyp--which-key-get-bindings (fun &optional prefix keymap filter recursive)
  "Polyp advice for `which-key--get-bindings'."
  (when polyp--active
    (setq filter (lambda (x) (not (string-prefix-p "polyp--" (cdr x))))))
  (funcall fun prefix keymap filter recursive))

(with-eval-after-load 'which-key
  (advice-add 'which-key--get-bindings :around #'polyp--which-key-get-bindings))

(provide 'polyp)
;;; polyp.el ends here
