;;; -*-Scheme-*-
;;;
;;;	$Id: autosv.scm,v 1.30 1994/05/04 22:56:50 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-94 Massachusetts Institute of Technology
;;;
;;;	This material was developed by the Scheme project at the
;;;	Massachusetts Institute of Technology, Department of
;;;	Electrical Engineering and Computer Science.  Permission to
;;;	copy this software, to redistribute it, and to use it for any
;;;	purpose is granted, subject to the following restrictions and
;;;	understandings.
;;;
;;;	1. Any copy made of this software must include this copyright
;;;	notice in full.
;;;
;;;	2. Users of this software agree to make their best efforts (a)
;;;	to return to the MIT Scheme project any improvements or
;;;	extensions that they make, so that these may be included in
;;;	future releases; and (b) to inform MIT of noteworthy uses of
;;;	this software.
;;;
;;;	3. All materials developed as a consequence of the use of this
;;;	software shall duly acknowledge such use, in accordance with
;;;	the usual standards of acknowledging credit in academic
;;;	research.
;;;
;;;	4. MIT has made no warrantee or representation that the
;;;	operation of this software will be error-free, and MIT is
;;;	under no obligation to provide any services, by way of
;;;	maintenance, update, or otherwise.
;;;
;;;	5. In conjunction with products arising from the use of this
;;;	material, there shall be no use of the name of the
;;;	Massachusetts Institute of Technology nor of any adaptation
;;;	thereof in any advertising, promotional, or sales literature
;;;	without prior written consent from MIT in each case.
;;;
;;; NOTE: Parts of this program (Edwin) were created by translation
;;; from corresponding parts of GNU Emacs.  Users should be aware that
;;; the GNU GENERAL PUBLIC LICENSE may apply to these parts.  A copy
;;; of that license should have been included along with this file.
;;;

;;;; Auto Save

(declare (usual-integrations))

(define-variable auto-save-visited-file-name
  "True says auto-save a buffer in the file it is visiting, when practical.
Normally auto-save files are written under other names."
  false
  boolean?)

(define-variable auto-save-default
  "True says by default do auto-saving of every file-visiting buffer."
  true
  boolean?)
(variable-permanent-local! (ref-variable-object auto-save-default))

(define-variable auto-save-interval
  "Number of keyboard input characters between auto-saves.
Zero means disable autosaving."
  300
  exact-nonnegative-integer?)

(define-variable delete-auto-save-files
  "True means delete a buffer's auto-save file
when the buffer is saved for real."
  true
  boolean?)

(define-command auto-save-mode
  "Toggle auto-saving of contents of current buffer.
With arg, turn auto-saving on if arg is positive, else off."
  "P"
  (lambda (argument)
    (let ((argument (command-argument-value argument))
	  (buffer (current-buffer)))
      (if (if argument
	      (positive? argument)
	      (not (buffer-auto-save-pathname buffer)))
	  (begin
	    (enable-buffer-auto-save! buffer)
	    (message "Auto Save enabled"))
	  (begin
	    (disable-buffer-auto-save! buffer)
	    (message "Auto Save disabled"))))))

(define-command do-auto-save
  "Auto-save all buffers that need it.
This is all buffers that have auto-saving enabled
and are changed since last auto-saved.
Auto-saving writes the buffer into a file
so that your editing is not lost if the system crashes.
This file is not the file you visited; that changes only when you save."
  ()
  (lambda () (do-auto-save)))

(define (setup-buffer-auto-save! buffer)
  (if (ref-variable auto-save-default)
      (enable-buffer-auto-save! buffer)
      (disable-buffer-auto-save! buffer)))

(define (enable-buffer-auto-save! buffer)
  (let ((pathname
	 (let ((pathname (buffer-pathname buffer)))
	   (if (and pathname (ref-variable auto-save-visited-file-name))
	       pathname
	       (os/auto-save-pathname pathname buffer)))))
    (without-interrupts
     (lambda ()
       (set-buffer-auto-save-pathname! buffer pathname)
       (add-group-microcode-entry (buffer-group buffer)
				  (->namestring pathname))
       (add-kill-buffer-hook buffer auto-save-kill-buffer-hook)))))

(define (disable-buffer-auto-save! buffer)
  (without-interrupts
   (lambda ()
     (set-buffer-auto-save-pathname! buffer false)
     (remove-group-microcode-entry (buffer-group buffer))
     (remove-kill-buffer-hook buffer auto-save-kill-buffer-hook))))

(define (auto-save-kill-buffer-hook buffer)
  (without-interrupts
   (lambda ()
     (remove-group-microcode-entry (buffer-group buffer)))))

(define add-group-microcode-entry)
(define remove-group-microcode-entry)
(let ((index (fixed-objects-vector-slot 'EDWIN-AUTO-SAVE)))
  (set! add-group-microcode-entry
	(lambda (group namestring)
	  (let ((vector (get-fixed-objects-vector)))
	    (let ((alist (vector-ref vector index)))
	      (let ((entry (assq group alist)))
		(if entry
		    (set-cdr! entry namestring)
		    (vector-set! vector
				 index
				 (cons (cons group namestring) alist))))))))
  (set! remove-group-microcode-entry
	(lambda (group)
	  (let ((vector (get-fixed-objects-vector)))
	    (vector-set! vector
			 index
			 (del-assq! group (vector-ref vector index)))))))

(define (delete-auto-save-file! buffer)
  (and (ref-variable delete-auto-save-files)
       (let ((auto-save-pathname (buffer-auto-save-pathname buffer)))
	 (and auto-save-pathname
	      (not (let ((pathname (buffer-pathname buffer)))
		     (and pathname
			  (pathname=? auto-save-pathname pathname))))
	      (delete-file-no-errors auto-save-pathname)))))

(define (rename-auto-save-file! buffer)
  (let ((old-pathname (buffer-auto-save-pathname buffer)))
    (enable-buffer-auto-save! buffer)
    (let ((new-pathname (buffer-auto-save-pathname buffer)))
      (if (and old-pathname
	       new-pathname
	       (not (pathname=? new-pathname old-pathname))
	       (not (let ((pathname (buffer-pathname buffer)))
		      (and pathname
			   (or (pathname=? new-pathname pathname)
			       (pathname=? old-pathname pathname)))))
	       (file-exists? old-pathname))
	  (rename-file old-pathname new-pathname)))))

(define (do-auto-save)
  (let ((buffers
	 (list-transform-positive (buffer-list)
	   (lambda (buffer)
	     (and (buffer-auto-save-pathname buffer)
		  (buffer-auto-save-modified? buffer)
		  (<= (* 10 (buffer-save-length buffer))
		      (* 13 (buffer-length buffer))))))))
    (if (not (null? buffers))
	(begin
	  (temporary-message "Auto saving...")
	  (for-each auto-save-buffer buffers)
	  (temporary-message "Auto saving...done")))))

(define (auto-save-buffer buffer)
  (catch-file-errors
   (lambda ()
     (editor-beep)
     (let ((name (buffer-name buffer)))
       (message "Autosaving...error for " name)
       (sleep-for 500)
       (message "Autosaving...error!for " name)
       (sleep-for 500)
       (message "Autosaving...error for " name)
       (sleep-for 500)))
   (lambda ()
     (write-region (buffer-unclipped-region buffer)
		   (buffer-auto-save-pathname buffer)
		   false)
     (set-buffer-save-length! buffer)
     (set-buffer-auto-saved! buffer))))