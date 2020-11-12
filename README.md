# polyp.el - Nested modal keybindings

Polyp is a small package which allows the creation of nested
editing modes. This package is inspired by Hydra and takes ideas from modal
keybinding packages like modalka/ryo-modal.

## Usage

It is recommended to configure the package using `use-package`.

~~~ elisp
(use-package polyp
  :config
  ;; Enable the mode-line indicator, showing the currently active mode
  ;; This is optional.
  (polyp-mode))
~~~

Basic example for text scaling. This functionality is already provided
by the text-scale-adjust function built into Emacs. It can easily be
replicated as follows.

~~~ elisp
(defpolyp ~scale
  "=Scale:=  _+_:larger  _-_:smaller  _0_:default"
  (("-" "C--") text-scale-decrease "C-x C--")
  (("+" "C-+") text-scale-increase "C-x C-+" "C-x C-=")
  (("0" "C-0") (text-scale-increase 0) "C-x C-0"))
~~~

As a convention I am using names like `~nav` which begin with a tilde, like the arm of a polyp.

The second argument of the `defpolyp` macro optionally specifies a description.
The description is shown above the mode line, when the mode is active.
The description string can contain highlighting using `_`, `*` and `=`.
Furthermore string interpolation using `%e(expr)` and toggles `%t(expr)` are supported.
After the description keyword arguments can be specified.

~~~
:global-map Keymap used for the global bindings.
:base-map   Base keymap used for the transient bindings.
:bind       Bindings to which this Polyp is bound in the global keymap.
:enter      Action to perform before entering the Polyp.
:quit       Action to perform after quitting the Polyp.
:on         Action to perform when Polyp is activated.
:off        Action to perform when Polyp is deactivated.
:foreign    Specifies the behavior if a foreign key is pressed.
:status     Specifies the status string shown in the mode-line.
~~~

The bindings have the following form, where the `key` is bound to `function` when the mode is active.
Furthermore a binding ca be bound to a `global-key` or can be marked as `:quit`. The `global-key` enters
the mode and if the key of a `:quit` binding is pressed, the mode is left again.

~~~ elisp
("key" function :quit)
("key" function "global-key")
~~~

It is also possible to specify multiple keys.

~~~ elisp
(("key1" "key2") function "global-key1" "global-key2"...)
(("key1" "key2") function :quit)
~~~

Furthermore keys can be redirect to the underlying keymap, see the `~cmd` example.

## Examples

~~~ elisp
(defpolyp ~move-text
 "=Move Text:= _↕_"
 ("<up>" move-text-up "M-<up>")
 ("<down>" move-text-down "M-<down>"))

(defpolyp ~expand-region
  "=Expand:=  _#_:expand  _'_:contract  _0_:reset"
  ("#" er/expand-region)
  ("'" er/contract-region)
  ("0" (er/expand-region 0)))

(defpolyp ~undo
  "=Undo:=  _u_ndo  _r_edo"
  ("u" undo-fu-only-undo "C-x u" "C-_" "C-/" "<undo>")
  ("r" undo-fu-only-redo))

(defpolyp ~bookmark
  "=Bookmark:=  _s_et  _j_ump  _d_elete  _r_ename  _e_dit"
  ("s" bookmark-set-no-overwrite)
  ("j" bookmark-jump)
  ("r" bookmark-rename)
  ("d" bookmark-delete)
  ("e" edit-bookmarks :quit))

(defpolyp ~scale
  "=Scale:=  _+_:larger  _-_:smaller  _0_:default"
  (("-" "C--") text-scale-decrease "C-x C--")
  (("+" "C-+") text-scale-increase "C-x C-+" "C-x C-=")
  (("0" "C-0") (text-scale-increase 0) "C-x C-0"))

(defpolyp ~win
  "=Window:=  _0123_  _↔↕_:move  _C-↔↕_:resize  _M-↔↕_:swap  _u_ndo  _r_edo"
  :bind "C-x w"
  ("0"         delete-window)
  ("1"         delete-other-windows)
  ("2"         split-window-below)
  ("3"         split-window-right)
  ("u"         winner-undo)
  ("r"         winner-redo)
  ("<left>"    windmove-left)
  ("<down>"    windmove-down)
  ("<up>"      windmove-up)
  ("<right>"   windmove-right)
  ("C-<up>"    shrink-window)
  ("C-<down>"  enlarge-window)
  ("C-<left>"  shrink-window-horizontally)
  ("C-<right>" enlarge-window-horizontally)
  ("M-<up>"    (buffer-swap 'up))
  ("M-<down>"  (buffer-swap 'down))
  ("M-<left>"  (buffer-swap 'left))
  ("M-<right>" (buffer-swap 'right)))

(defpolyp ~multiple-cursors
  "=Multiple Cursors (%(mc/num-cursors) active)=
 ↑^^            ↓^^            Mark^^              Other^^
──^^─────────────^^────────────────^^───────────────────^^────────────
 _p_   prev     _n_   next     *l* lines           *c* inc chars
 _P_   skip     _N_   skip     *a* all like this   *0* inc numbers
 _M-p_ unmark   _M-n_ unmark   *s* search          _v_ vertical align"
  :bind "C-c m"
  ("n" mc/mark-next-like-this)
  ("N" mc/skip-to-next-like-this)
  ("M-n" mc/unmark-next-like-this)
  ("p" mc/mark-previous-like-this)
  ("P" mc/skip-to-previous-like-this)
  ("M-p" mc/unmark-previous-like-this)
  ("v" mc/vertical-align)
  ("<mouse-1>" mc/add-cursor-on-click)
  (("<down-mouse-1>" "<drag-mouse-1>") ignore)
  ("l" mc/edit-lines :quit)
  ("a" mc/mark-all-like-this :quit)
  ("s" mc/mark-all-in-region-regexp :quit)
  ("c" mc/insert-letters :quit)
  ("0" mc/insert-numbers :quit))

(defpolyp ~cmd
  :bind "C-z"
  :foreign 'run
  :on (setq cursor-type 'hollow)
  :off (setq cursor-type 'box)
  (("z" "C-z") ignore :quit)
  ("SPC" "C-SPC")
  ("_" "C-_")
  ("?" "M-?")
  ("." "M-.")
  ("<tab>" "C-<tab>")
  ("<backtab>" "M-<tab>")
  ("<" "M-<")
  (">" "M->")
  ("," "C-,")
  (";" "C-;")
  (":" "M-:")
  ("!" "M-!")
  ("#" "C-#")
  ("'" "C-'")
  ("A" "M-a")
  ("B" "M-b")
  ("C" "M-c")
  ("D" "M-d")
  ("E" "M-e")
  ("F" "M-f")
  ("G" "M-g")
  ("H" "M-h")
  ("I" "M-i")
  ("J" "M-j")
  ("K" "M-k")
  ("L" "M-l")
  ("M" "M-m")
  ("N" "M-n")
  ("O" "M-o")
  ("P" "M-p")
  ("Q" "M-q")
  ("R" "M-r")
  ("S" "M-s")
  ("T" "M-t")
  ("U" "M-u")
  ("V" "M-v")
  ("W" "M-w")
  ("X" "M-x")
  ("Y" "M-y")
  ("Z" "M-z")
  ("a" "C-a")
  ("b" "C-b")
  ("c" "C-c")
  ("d" "C-d")
  ("e" "C-e")
  ("f" "C-f")
  ("g" "C-g")
  ("h" "C-h")
  ("i" "C-i")
  ("j" "C-j")
  ("k" "C-k")
  ("l" "C-l")
  ("m" "C-m")
  ("n" "C-n")
  ("o" "C-o")
  ("p" "C-p")
  ("q" "C-q")
  ("r" "C-r")
  ("s" "C-s")
  ("t" "C-t")
  ("v" "C-v")
  ("w" "C-w")
  ("x" "C-x")
  ("y" "C-y"))

(defpolyp ~toggles
  "=Toggles=
 ^^View            ^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^Highlight        ^^^^^^^^^^^^^^^^^^^^^^^^^   ^^Edit            ^^^^^^^^^^^^^^^^^^^^^^   ^^Debug
─^^────────────────^^^^^^^^^^^^^^^^^^^^^^^^^^───^^─────────────────^^^^^^^^^^^^^^^^^^^^^^^^^───^^────────────────^^^^^^^^^^^^^^^^^^^^^^───^^─────────────^^^^^^^^^^^^^^^^─
 _vl_ line-num  %t(display-line-numbers-mode)   _hd_ delim      %t(rainbow-delimiters-mode )   _es_ subword   %t(subword-mode         )   _de_ error  %t(debug-on-error )
 _vr_ ruler     %t(ruler-mode               )   _hc_ color      %t(rainbow-mode            )   _ep_ elec-pair %t(electric-pair-mode   )   _ds_ signal %t(debug-on-signal)
 _vm_ minions   %t(minions-mode             )   _hw_ whitespace %t(whitespace-mode         )   _eo_ overwrite %t(overwrite-mode       )
 _vk_ which-key %t(which-key-mode           )   _hl_ line       %t(global-hl-line-mode     )   _ed_ delsel    %t(delete-selection-mode)
 _vo_ outline   %t(outline-minor-mode       )   _ht_ todo       %t(hl-todo-mode            )   _ea_ auto-fill %t(auto-fill-function   )
 _vw_ winner    %t(winner-mode              )   _hp_ parens     %t(show-paren-mode         )
 _vf_ which-fun %t(which-function-mode      )   _hv_ volatile   %t(volatile-highlights-mode)
 ^^                ^^^^^^^^^^^^^^^^^^^^^^^^^^   _hh_ changes    %t(highlight-changes-mode  )"
  :bind "<home>"
  :foreign 'ignore
  ("ea" auto-fill-mode)
  ("ed" delete-selection-mode)
  ("eo" overwrite-mode)
  ("ep" electric-pair-mode)
  ("es" subword-mode)
  ("hc" rainbow-mode)
  ("hd" rainbow-delimiters-mode)
  ("hh" highlight-changes-mode)
  ("hl" global-hl-line-mode)
  ("hp" show-paren-mode)
  ("ht" hl-todo-mode)
  ("hv" volatile-highlights-mode)
  ("hw" whitespace-mode)
  ("vf" which-function-mode)
  ("vk" which-key-mode)
  ("vl" display-line-numbers-mode)
  ("vr" ruler-mode)
  ("vo" outline-minor-mode)
  ("vw" winner-mode)
  ("vm" minions-mode)
  ("de" toggle-de)
  ("ds" toggle-ds)
  ("<home>" ignore :quit))
~~~
