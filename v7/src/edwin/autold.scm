;;; -*-Scheme-*-
;;;
;;;$Id: autold.scm,v 1.54 1999/01/02 06:11:34 cph Exp $
;;;
;;; Copyright (c) 1986, 1989-1999 Massachusetts Institute of Technology
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

;;;; Autoloads for Edwin

(declare (usual-integrations))

;;;; Definitions

(define (make-autoloading-procedure library-name get-procedure)
  (letrec ((apply-hook
	    (make-apply-hook
	     (lambda arguments
	       ((ref-command load-library) library-name 'NO-WARN)
	       (let ((procedure (get-procedure)))
		 (set-apply-hook-procedure! apply-hook procedure)
		 (apply procedure arguments)))
	     (cons autoloading-procedure-tag library-name))))
    apply-hook))

(define autoloading-procedure-tag "autoloading-procedure-tag")

(define (autoloading-procedure? object)
  (and (apply-hook? object)
       (eq? autoloading-procedure-tag (car (apply-hook-extra object)))))

(define-integrable (autoloading-procedure/library-name procedure)
  (cdr (apply-hook-extra procedure)))

(define (define-autoload-procedure name package library-name)
  (let ((environment (->environment package)))
    (local-assignment environment
		      name
		      (make-autoloading-procedure
		       library-name
		       (lambda () (lexical-reference environment name))))))

(define (define-autoload-major-mode name super-mode-name display-name
	  library-name description)
  (define mode
    (make-mode name true display-name
	       (and super-mode-name (->mode super-mode-name))
	       description
	       (make-autoloading-procedure library-name
					   (lambda ()
					     (mode-initialization mode)))))
  (local-assignment (->environment '(EDWIN))
		    (mode-name->scheme-name name)
		    mode)
  name)

(define (define-autoload-minor-mode name display-name library-name description)
  (define mode
    (make-mode name false display-name false description
	       (make-autoloading-procedure library-name
					   (lambda ()
					     (mode-initialization mode)))))
  (local-assignment (->environment '(EDWIN))
		    (mode-name->scheme-name name)
		    mode)
  name)

(define (autoloading-mode? mode)
  (autoloading-procedure? (mode-initialization mode)))

(define (define-autoload-command name library-name description)
  (define command
    (make-command name description '()
		  (make-autoloading-procedure library-name
					      (lambda ()
						(command-procedure command)))))
  (local-assignment (->environment '(EDWIN))
		    (command-name->scheme-name name)
		    command)
  name)

(define (autoloading-command? command)
  (autoloading-procedure? (command-procedure command)))

(define (guarantee-command-loaded command)
  (let ((procedure (command-procedure command)))
    (if (autoloading-procedure? procedure)
	((ref-command load-library)
	 (autoloading-procedure/library-name procedure)
	 'NO-WARN))))

;;;; Libraries

(define known-libraries
  '())

(define (define-library name . entries)
  (let ((entry (assq name known-libraries)))
    (if entry
	(set-cdr! entry entries)
	(set! known-libraries
	      (cons (cons name entries)
		    known-libraries))))
  name)

(define loaded-libraries
  '())

(define (library-loaded? name)
  (memq name loaded-libraries))

(define library-load-hooks
  '())

(define (add-library-load-hook! name hook)
  (if (library-loaded? name)
      (hook)
      (let ((entry (assq name library-load-hooks)))
	(if entry
	    (append! entry (list hook))
	    (set! library-load-hooks
		  (cons (list name hook)
			library-load-hooks))))))

(define (run-library-load-hooks! name)
  (let ((entry (assq name library-load-hooks)))
    (define (loop)
      (if (null? (cdr entry))
	  (set! library-load-hooks (delq! entry library-load-hooks))
	  (let ((hook (cadr entry)))
	    (set-cdr! entry (cddr entry))
	    (hook)
	    (loop))))
    (if entry (loop))))

;;;; Loading

(define-command load-library
  "Load the Edwin library NAME.
Second arg FORCE? controls what happens if the library is already loaded:
 'NO-WARN means do nothing,
 false means display a warning message in the minibuffer,
 anything else means load it anyway.
Second arg is prefix arg when called interactively."
  (lambda ()
    (list
     (prompt-for-alist-value "Load library"
			     (map (lambda (library)
				    (cons (symbol->string (car library))
					  (car library)))
				  known-libraries))
     (command-argument)))
  (lambda (name force?)
    (load-edwin-library name force? true)))

(define (load-edwin-library name #!optional force? interactive?)
  (let ((force? (if (default-object? force?) false force?))
	(interactive? (if (default-object? interactive?) false interactive?)))
    (let ((do-it
	   (lambda (library)
	     (let ((directory (edwin-binary-directory)))
	       (for-each
		(lambda (entry)
		  (load (merge-pathnames (car entry) directory)
			(cadr entry)
			edwin-syntax-table
			(or (null? (cddr entry)) (caddr entry))))
		(cdr library)))
	     (if (not (memq (car library) loaded-libraries))
		 (set! loaded-libraries
		       (cons (car library) loaded-libraries)))
	     (run-library-load-hooks! (car library)))))
      (let ((do-it
	     (lambda ()
	       (let ((library (assq name known-libraries)))
		 (if (not library)
		     (error "Unknown library name:" name))
		 (if interactive?
		     (with-output-to-transcript-buffer
		      (lambda ()
			(bind-condition-handler (list condition-type:error)
			    evaluation-error-handler
			  (lambda ()
			    (fluid-let ((load/suppress-loading-message? true))
			      (message "Loading " (car library) "...")
			      (do-it library)
			      (append-message "done"))))))
		     (do-it library))))))
	(cond ((not (library-loaded? name))
	       (do-it))
	      ((not force?)
	       (if interactive? (message "Library already loaded: " name)))
	      ((not (eq? force? 'NO-WARN))
	       (do-it)))))))

(define-command load-file
  "Load the Edwin binary file FILENAME.
Second arg PURIFY? means purify the file's contents after loading;
 this is the prefix arg when called interactively."
  "fLoad file\nP"
  (lambda (filename purify?)
    (temporary-message "Loading " filename "...")
    (load-edwin-file filename '(EDWIN) purify?)
    (append-message "done")))

(define (load-edwin-file filename environment purify?)
  (with-output-to-transcript-buffer
   (lambda ()
     (bind-condition-handler (list condition-type:error)
	 evaluation-error-handler
       (lambda ()
	 (fluid-let ((load/suppress-loading-message? true))
	   (load filename environment edwin-syntax-table purify?)))))))