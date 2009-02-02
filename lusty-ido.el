(defun shk-init-lusty-display ()
(lusty-setup-completion-window)
(let ((lusty--active-mode :buffer-explorer))
   (lusty-update-completion-buffer)))

(defun shk-lusty-on-make-buffer-list ()
(when (minibufferp)
   (let ((lusty--active-mode :buffer-explorer))
     (lusty-update-completion-buffer))))

(defadvice ido-exhibit (after shk-lusty-ido-post-command-hook)
(when (minibufferp)
   (let ((lusty--active-mode :buffer-explorer))
     (lusty-update-completion-buffer))))
(ad-deactivate 'ido-exhibit)

(add-hook 'ido-minibuffer-setup-hook 'shk-init-lusty-display)
(add-hook 'ido-make-buffer-list-hook 'shk-lusty-on-make-buffer-list)

(remove-hook 'ido-minibuffer-setup-hook 'shk-init-lusty-display)
(remove-hook 'ido-make-buffer-list-hook 'shk-lusty-on-make-buffer-list)
