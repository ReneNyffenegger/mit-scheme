;;; -*-Scheme-*-
;;;
;;; $Id: notify.scm,v 1.18 1999/01/02 06:11:34 cph Exp $
;;;
;;; Copyright (c) 1992-1999 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;;; Mode-line notifications (e.g. presence of mail, load average)

(declare (usual-integrations))

(define-variable notify-show-time
  "If true, the notifier displays the current time."
  #t
  boolean?)

(define (notifier:time)
  (let ((time (get-decoded-time)))
    (let ((hour (decoded-time/hour time))
	  (minute (decoded-time/minute time)))
      (string-append (write-to-string
		      (cond ((zero? hour) 12)
			    ((< hour 13) hour)
			    (else (- hour 12))))
		     (if (< minute 10) ":0" ":")
		     (write-to-string minute)
		     (if (< hour 12) "am" "pm")))))

(define-variable notify-show-date
  "If true, the notifier displays the current date."
  #f
  boolean?)

(define (notifier:date)
  (let ((time (get-decoded-time)))
    (string-append (vector-ref
		    '#("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
		    (decoded-time/day-of-week time))
		   (vector-ref
		    '#("??" " Jan " " Feb " " Mar " " Apr " " May " " Jun "
			    " Jul " " Aug " " Sep " " Oct " " Nov " " Dec ")
		    (decoded-time/month time))
		   (write-to-string (decoded-time/day time)))))

(define-variable notify-show-load
  "If true, the notifier displays the load average."
  #f
  boolean?)

(define (notifier:load-average)
  (let ((temporary-buffer (temporary-buffer "*uptime*")))
    (let ((start (buffer-start temporary-buffer)))
      (shell-command #f start #f #f "uptime")
      (let ((result
	     (if (re-search-forward
		  ".*load average:[ ]*\\([0-9.]*\\),"
		  start 
		  (buffer-end temporary-buffer))
		 (extract-string (re-match-start 1)
				 (re-match-end 1))
		 "")))
	(kill-buffer temporary-buffer)
	result))))

(define-variable notify-show-mail
  "If true, the notifier displays your mail status."
  #t
  boolean?)

(define-variable notify-mail-present
  "A string to be displayed in the modeline when mail is present.
Ignored if notify-show-mail is false."
  "Mail"
  string?)

(define-variable notify-mail-not-present
  "A string to be displayed in the modeline when mail is not present.
Ignored if notify-show-mail is false."
  ""
  string?)

(define-variable mail-notify-directory
  "Directory in which MAIL-NOTIFY checks for mail."
  #f
  (lambda (object) (or (not object) (file-directory? object))))

(define (notifier:mail-present)
  (if (not (ref-variable mail-notify-directory))
      (begin
	(guarantee-rmail-variables-initialized)
	(set-variable! mail-notify-directory rmail-spool-directory)))
  (if (let ((pathname
	     (merge-pathnames (ref-variable mail-notify-directory)
			      (current-user-name))))
	(and (file-exists? pathname)
	     (> (file-length pathname) 0)))
      (ref-variable notify-mail-present)
      (ref-variable notify-mail-not-present)))

(define-variable notify-interval
  "How often the notifier updates the modeline, in seconds."
  60
  exact-nonnegative-integer?)

(define notifier-elements
  (list (cons (ref-variable-object notify-show-date) notifier:date)
	(cons (ref-variable-object notify-show-time) notifier:time)
	(cons (ref-variable-object notify-show-load) notifier:load-average)))

(define (notifier:get-string window)
  window
  (string-append-separated notifier-element-string notifier-mail-string))

(define (update-notifier-strings! element mail)
  (set! notifier-element-string element)
  (set! notifier-mail-string mail)
  (global-window-modeline-event!))

(define notifier-element-string "")
(define notifier-mail-string "")
(define mail-notify-hook-installed? #f)
(define current-notifier-thread #f)
(define notifier-thread-registration #f)

(define-command run-notifier
  "Run the notifier.
The notifier maintains a simple display in the modeline,
which can show various things including time, load average, and mail status."
  ()
  (lambda ()
    (if (and (not mail-notify-hook-installed?)
	     (command-defined? rmail))
	(begin
	  (add-event-receiver!
	   (ref-variable rmail-new-mail-hook)
	   (lambda ()
	     (update-notifier-strings!
	      notifier-element-string
	      (if (ref-variable notify-show-mail)
		  (ref-variable notify-mail-not-present)
		  ""))))
	  (set! mail-notify-hook-installed? #t)
	  unspecific))
    ((ref-command kill-notifier))
    (set-variable! global-mode-string `("" ,notifier:get-string))
    (let ((thread
	   (create-thread
	    editor-thread-root-continuation
	    (lambda ()
	      (do () (#f)
		(if notifier-thread-registration
		    (inferior-thread-output! notifier-thread-registration))
		(sleep-current-thread
		 (* 1000 (ref-variable notify-interval))))))))
      (detach-thread thread)
      (set! current-notifier-thread thread)
      (set! notifier-thread-registration
	    (register-inferior-thread! thread notifier)))
    unspecific))

(define (notifier)
  (update-notifier-strings!
   (reduce string-append-separated
	   ""
	   (map (lambda (element)
		  (if (and (car element)
			   (variable-value (car element)))
		      ((cdr element))
		      ""))
		notifier-elements))
   (if (and mail-notify-hook-installed?
	    (ref-variable notify-show-mail))
       (notifier:mail-present)
       ""))
  #t)

(define-command kill-notifier
  "Kill the current notifier, if any."
  ()
  (lambda ()
    (without-interrupts
     (lambda ()
       (if current-notifier-thread
	   (begin
	     (if (not (thread-dead? current-notifier-thread))
		 (signal-thread-event current-notifier-thread
		   (lambda ()
		     (exit-current-thread unspecific))))
	     (set! current-notifier-thread #f)))
       (if notifier-thread-registration
	   (begin
	     (deregister-inferior-thread! notifier-thread-registration)
	     (set! notifier-thread-registration #f)))
       unspecific))
    (set-variable! global-mode-string "")
    (update-notifier-strings! "" "")))