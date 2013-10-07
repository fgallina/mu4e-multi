# mu4e-multi

Multiple accounts support for mu4e.

## Info

+ Author: Fabián Ezequiel Gallina
+ Contact: fgallina at gnu dot org
+ Project homepage: http://github.com/fgallina/mu4e-multi
+ My Blog: http://www.from-the-cloud.com

Donations welcome!

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=fgallina&url=https://github.com/fgallina/mu4e-multi&title=mu4e-multi&language=en_GB&tags=github&category=software)

## Install

Put `mu4e-multi` where you place all your Emacs Lisp files and
(optionally) byte-compile it. One way to do it is to visit the file
with Emacs and then issue `M-x byte-compile-file`

After that add the following to your `.emacs`:

```emacs-lisp
(add-to-list 'load-path "/folder/containing/file")  ;; if it's not already in `load-path'
(require 'mu4e-multi)
```

## Usage

mu4e-multi just depends on setting the `mu4e-multi-account-alist`
properly and calling `mu4e-multi-enable`.

As an example let's assume you have two email accounts: personal and
work. For handling such accounts mu4e-multi assumes your maildir's
layout is as follows:

```
+ Maildir
+-- personal
+---- Inbox
+---- Sent
...
+-- work
+---- Inbox
+---- Sent
..
```

This is what you'd have in your .emacs:

```emacs-lisp
(require 'mu4e-multi)

(setq mu4e-multi-account-alist
      '(("personal"
         (user-mail-address . "personal@someserver.com")
         (mu4e-drafts-folder . "/personal/Drafts")
         (mu4e-follow-up-folder . "/personal/FollowUp")
         (mu4e-hold-folder . "/personal/Hold")
         (mu4e-refile-folder . "/personal/Archived")
         (mu4e-sent-folder . "/personal/Sent")
         (mu4e-trash-folder . "/personal/Trash"))
        ("work"
         (user-mail-address . "work@someotherserver.com")
         (mu4e-drafts-folder . "/work/Drafts")
         (mu4e-follow-up-folder . "/work/FollowUp")
         (mu4e-hold-folder . "/work/Hold")
         (mu4e-refile-folder . "/work/Archived")
         (mu4e-sent-folder . "/work/Sent")
         (mu4e-trash-folder . "/work/Trash"))))

(mu4e-multi-enable)
```

This alist key is the nickname of the account, which I strongly
recommend that you make it match your maildir's sub-folder as in the
example. For every cons in the alist, its car is the symbol of the
variable to be set for this particular account and its cdr is its new
value.

Calling `mu4e-multi-enable` makes mu4e standard folders to be aware of
the multiple account configuration by setting `mu4e-sent-folder`,
`mu4e-drafts-folder`, `mu4e-trash-folder` and `mu4e-refile-folder` to
a callable that would properly set folders for each account, and will
set a `message-mode-hook` to detect and set the current account
variables based on the email address. If for some reason you wish to
rollback these changes, just call `mu4e-multi-disable`.

### Custom folders and markers

Notice that, in our example, the `mu4e-hold-folder`and
`mu4e-follow-up` folders are not really standard ones, but since I use
the GTD approach on handling emails I needed them.

Now, the thing is that mu4e obviously won't have commands to mark
messages to be moved to such folders, but thanks to mu4e-multi's
`mu4e-multi-make-mark-for-command` macro, you can generate those
commands easily.

```emacs-lisp
;; Creates `mu4e-multi-mark-for-hold' command.
(mu4e-multi-make-mark-for-command mu4e-hold-folder)
;; Creates `mu4e-multi-mark-for-follow-up' command.
(mu4e-multi-make-mark-for-command mu4e-follow-up-folder)
```

Now the only thing left is to add these new commands to the
`mu4e-headers-mode-map`:

```emacs-lisp
(define-key 'mu4e-headers-mode-map "h" 'mu4e-multi-mark-for-hold)
(define-key 'mu4e-headers-mode-map "f" 'mu4e-multi-mark-for-follow-up)
```

### Composing

To compose a new email, mu4e-multi comes with a wrapper over
`mu4e-compose-new` called `mu4e-multi-compose-new` which takes care of
detecting and handling account vars properly when composing new
emails.

It's strongly recommended you use this over `mu4e-compose-new`. This
is how I bind it my local setup:

```emacs-lisp
(global-set-key (kbd "C-x m") 'mu4e-multi-compose-new)
```

### MSMTP integration

mu4e-multi comes with `mu4e-multi-smtpmail-set-msmtp-account`, which
is a function intended to be added to the `message-send-mail-hook` and
which will take care of appending the current account nickname to the
msmtp command.

Note that for this to work properly, all your defined account sections
of your .msmtprc must match your `mu4e-multi-account-alist` account
nicknames.

If you happen to be using msmtp, enable this feature like this:

```emacs-lisp
(add-hook 'message-send-mail-hook 'mu4e-multi-smtpmail-set-msmtp-account)
```

## Requirements

Just mu4e.

NOTE: I haven't tested this in Emacs versions less than 24.x.

## Bug Reports

If you find a bug please report it in the github tracker.

## License

mu4e-multi is free software under the GPL v3, see LICENSE file for
details.
