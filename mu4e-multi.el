;;; mu4e-multi.el --- Multiple account facilities for mu4e

;; Copyright (C) 2013 Free Software Foundation, Inc.

;; Authors: Fabián Ezequiel Gallina <fgallina@gnu.org>

;; This file is NOT part of mu4e.

;; mu4e-multi.el is free software; you can redistribute it
;; and/or modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.

;; mu4e-multi.el is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with mu4e-multi.el; see the file COPYING. If not,
;; write to the Free Software Foundation, Inc., 51 Franklin St, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; See the README.md file for details on how to install and use this
;; package.

;;; Code:
(require 'cl-lib)
(require 'message)
(require 'mu4e-actions)
(require 'mu4e-headers)
(require 'thingatpt)


(defvar mu4e-multi-last-read-account ""
  "Holds the last selected account from minibuffer.
This is just for `mu4e-multi-minibuffer-read-account' to prompt
always the latest used account as default.")

(defvar mu4e-multi-account-alist nil
  "Alist containing all information of email accounts.
Here's an example for two accounts:

    '((\"account-1\"
       (user-mail-address . \"user1@server.com\")
       (mu4e-sent-folder . \"/account-1/Sent Mail\")
       (mu4e-drafts-folder . \"/account-1/Drafts\")
       (mu4e-refile-folder . \"/account-1/Archive\")
       (mu4e-trash-folder . \"/account-1/Trash\"))
      (\"account-2\"
       (user-mail-address . \"user2@server.com\")
       (mu4e-sent-folder . \"/account-2/Sent Mail\")
       (mu4e-drafts-folder . \"/account-2/Drafts\")
       (mu4e-refile-folder . \"/account-2/Archive\")
       (mu4e-trash-folder . \"/account-2/Trash\")))

The names \"account-1\" and \"account-2\" are used as identifiers
to access an account's data.  IMPORTANT: maildirs must match
their prefix with the identifier given, as in the example
above.")

(defvar mu4e-multi-standard-folders '(mu4e-drafts-folder
                                      mu4e-refile-folder
                                      mu4e-sent-folder
                                      mu4e-trash-folder)
  "List of standard mu4e folders.")

(defun mu4e-multi-account-name-list (&optional account-alist)
  "Return account names from ACCOUNT-ALIST.
When ACCOUNT-ALIST is nil, the value of
`mu4e-multi-account-alist' is used."
  (mapcar #'car (or account-alist mu4e-multi-account-alist)))

(defun mu4e-multi-minibuffer-read-account ()
  "Read account name from minibuffer."
  (let ((account-list (mu4e-multi-account-name-list)))
    (setq
     mu4e-multi-last-read-account
     (completing-read
      (format "Compose with account: (%s) "
              (mapconcat
               #'(lambda (acc)
                   (if (string= acc mu4e-multi-last-read-account)
                       (format "[%s]" acc)
                     acc))
               account-list "/"))
      account-list nil t nil nil mu4e-multi-last-read-account))))

(defun mu4e-multi-get-msg-account (msg &optional account)
  "Get account from MSG.
If no account can be found from MSG then use ACCOUNT as default."
  (let ((maildir (when msg (mu4e-msg-field msg :maildir)))
        (account-list (mu4e-multi-account-name-list)))
    (cond ((and maildir
                (string-match
                 (concat
                  "/\\("
                  (regexp-opt account-list)
                  "\\)/?")
                 maildir))
           (match-string-no-properties 1 maildir))
          ((and account (car (member account account-list)))))))

(defun mu4e-multi-set-folder (folder msg)
  "Set FOLDER using MSG as detection element."
  (let ((varval (assoc
                 folder
                 (cdr
                  (assoc (or (mu4e-multi-get-msg-account msg)
                             mu4e-multi-last-read-account)
                         mu4e-multi-account-alist)))))
    (if varval
        (set (make-local-variable folder) (cdr varval))
      (mu4e-error "Cannot set folder %s, account for MSG %s not detected"
                  folder msg))))

(defmacro mu4e-multi-make-set-folder-fn (folder)
  "Make a setter for FOLDER.
This is just a wrapper over `mu4e-multi-set-folder' and can be
used to set you mu4e-*-folder vars.  Example:

  (setq mu4e-sent-folder
   (mu4e-multi-make-folder-fn mu4e-sent-folder))

Normally used to set `mu4e-sent-folder', `mu4e-drafts-folder',
`mu4e-trash-folder' and `mu4e-refile-folder'."
  `(apply-partially #'mu4e-multi-set-folder ',folder))

(defmacro mu4e-multi-make-mark-for-command (folder)
  "Generate command to mark current message to move to FOLDER.
The command is named after the prefix \"mu4e-multi-mark-for-\"
and what's in between of \"mu4e-\" and \"-folder\" parts of the
FOLDER symbol.  Here's an example on how to use this:

   (mu4e-multi-make-mark-for-command mu4e-hold-folder)
   (define-key 'mu4e-headers-mode-map \"h\" 'mu4e-multi-mark-for-hold)

OR:

   (define-key 'mu4e-headers-mode-map \"h\"
    (mu4e-multi-make-mark-for-command mu4e-hold-folder))"
  (let ((name (mapconcat
               'identity
               (butlast
                (cdr (split-string
                      (symbol-name folder) "-")))
               "-")))
    `(defun ,(intern (format "mu4e-multi-mark-for-%s" name)) ()
       ,(format "Mark message to be moved to `%s'." ',folder)
       (interactive)
       (mu4e-mark-set
        'move
        (cdr (assoc ',folder
                    (cdr (assoc (mu4e-multi-get-msg-account
                                 (mu4e-message-at-point))
                                mu4e-multi-account-alist)))))
       (mu4e-headers-next))))

(defun mu4e-multi-compose-set-account (&optional account)
  "Set the ACCOUNT for composing.
With Optional Argument ACCOUNT, set all variables for that given
identifier, else it tries to retrieve the message in context and
detect ACCOUNT from it."
  (interactive)
  (let* ((msg (or mu4e-compose-parent-message
                  (ignore-errors (mu4e-message-at-point))))
         (account (or account
                      (mu4e-multi-get-msg-account msg)))
         (account-vars (cdr (assoc account mu4e-multi-account-alist))))
    (when account-vars
      (mapc #'(lambda (var)
                (set (make-local-variable (car var)) (cdr var)))
            account-vars))
    (when (memq major-mode '(mu4e-compose-mode message-mode))
      (message-remove-header "from")
      (message-add-header (format "From: %s\n" (message-make-from)))
      (message "Using account %s" account))))

;;;###autoload
(defun mu4e-multi-compose-new ()
  "Start writing a new message.
This is a simple wrapper over `mu4e-compose-new' that asks for an
account to be used to compose the new message."
  (interactive)
  (let ((account (mu4e-multi-minibuffer-read-account)))
    (mu4e-compose-new)
    (mu4e-multi-compose-set-account account)))

(defun mu4e-multi-smtpmail-set-msmtp-account ()
  "Set the account for msmtp.
This function is intended to added in the
`message-send-mail-hook'.  Searches for the account in the
`mu4e-multi-account-alist' variable by matching the email given
in the \"from\" field.  Note that all msmtp accounts should
defined in the ~/.msmtprc file and names should be matching the
keys of the `mu4e-multi-account-alist'."
  (setq message-sendmail-extra-arguments
        (list
         "-a"
         (catch 'exit
           (let* ((from (message-fetch-field "from"))
                  (email (and from
                              (string-match thing-at-point-email-regexp from)
                              (match-string-no-properties 0 from))))
             (if email
                 (cl-dolist (alist mu4e-multi-account-alist)
                   (when (string= email (cdr (assoc 'user-mail-address (cdr alist))))
                     (throw 'exit (car alist))))
               (catch 'exit (mu4e-multi-minibuffer-read-account))))))))

(defun mu4e-multi-enable ()
  "Enable mu4e multiple account setup."
  (setq mu4e-sent-folder (mu4e-multi-make-set-folder-fn mu4e-sent-folder)
        mu4e-drafts-folder (mu4e-multi-make-set-folder-fn mu4e-drafts-folder)
        mu4e-trash-folder (mu4e-multi-make-set-folder-fn mu4e-trash-folder)
        mu4e-refile-folder (mu4e-multi-make-set-folder-fn mu4e-refile-folder))
  (add-hook 'message-mode-hook 'mu4e-multi-compose-set-account))

(defun mu4e-multi-disable ()
  "Disable mu4e multiple account setup."
  (cl-dolist (variable mu4e-multi-standard-folders)
   (let* ((sv (get variable 'standard-value))
          (origval (and (consp sv)
                        (condition-case nil
                            (eval (car sv))
                          (error :help-eval-error)))))
     (when (not (equal (symbol-value variable) origval))
       (set variable origval))))
  (remove-hook 'message-mode-hook 'mu4e-multi-compose-set-account))

(provide 'mu4e-multi)

;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; mu4e-multi.el ends here
