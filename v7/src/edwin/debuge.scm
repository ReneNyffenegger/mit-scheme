;;; -*-Scheme-*-
;;;
;;;	$Id: debuge.scm,v 1.51 1995/09/13 03:57:22 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-95 Massachusetts Institute of Technology
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

;;;; Debugging Stuff

(declare (usual-integrations))

(define (debug-save-files)
  (for-each debug-save-buffer
	    (bufferset-buffer-list (editor-bufferset edwin-editor))))

(define (debug-save-buffer buffer)
  (if (and (buffer-modified? buffer)
	   (buffer-writable? buffer)
	   (not (minibuffer? buffer)))
      (let ((pathname
	     (let ((pathname (buffer-pathname buffer)))
	       (cond ((not pathname)
		      (and (y-or-n? "Save buffer "
				    (buffer-name buffer)
				    " (Y or N)? ")
			   ((access prompt-for-expression
				    system-global-environment)
			    "Filename")))
		     ((integer? (pathname-version pathname))
		      (pathname-new-version pathname 'NEWEST))
		     (else
		      pathname)))))
	(if pathname
	    (let* ((pathname (merge-pathnames pathname))
		   (filename (->namestring pathname)))
	      (if (or (not (file-exists? pathname))
		      (y-or-n? "File '"
			       filename
			       "' exists.  Write anyway (Y or N)? "))
		  (begin
		    (newline)
		    (write-string "Writing file '")
		    (write-string filename)
		    (write-string "'")
		    (let ((region (buffer-unclipped-region buffer)))
		      (group-write-to-file
		       (and (ref-variable translate-file-data-on-output
					  (region-group region))
			    (pathname-newline-translation pathname))
		       (region-group region)
		       (region-start-index region)
		       (region-end-index region)
		       filename))
		    (write-string " -- done")
		    (set-buffer-pathname! buffer pathname)
		    (set-buffer-truename! buffer (->truename pathname))
		    (buffer-not-modified! buffer))))))))

(define-command debug-count-marks
  "Show the number of in-use and GC'ed marks for the current buffer."
  ()
  (lambda ()
    (count-marks-group (buffer-group (current-buffer))
		       (lambda (n-existing n-gced)
			 (message "Existing: " (write-to-string n-existing)
				  "; GCed: " (write-to-string n-gced))))))

(define (count-marks-group group receiver)
  (let loop ((marks (group-marks group)) (receiver receiver))
    (if (weak-pair? marks)
	(loop (weak-cdr marks)
	  (lambda (n-existing n-gced)
	    (if (weak-pair/car? marks)
		(receiver (1+ n-existing) n-gced)
		(receiver n-existing (1+ n-gced)))))
	(receiver 0 0))))

(define-command debug-show-standard-marks
  ""
  ()
  (lambda ()
    (with-output-to-temporary-buffer "*standard-marks*"
      (lambda ()
	(let ((buffer-frame (current-window)))
	  (let ((window (car (instance-ref buffer-frame 'text-inferior)))
		(buffer (window-buffer buffer-frame)))
	    (let ((show-mark
		   (lambda (name mark)
		     (write-string
		      (string-pad-right (write-to-string name) 24))
		     (write mark)
		     (newline))))
	      (let ((show-instance
		     (lambda (name)
		       (show-mark name (instance-ref window name)))))
		(show-instance 'point)
		(show-instance 'start-line-mark)
		(show-instance 'start-mark)
		(show-instance 'end-mark)
		(show-instance 'end-line-mark))
	      (let ((group (buffer-group buffer)))
		(show-mark 'group-start-mark (group-start-mark group))
		(show-mark 'group-end-mark (group-end-mark group))
		(show-mark 'group-display-start (group-display-start group))
		(show-mark 'group-display-end (group-display-end group)))
	      (let ((marks (ring-list (buffer-mark-ring buffer))))
		(if (not (null? marks))
		    (begin
		      (write-string "mark-ring\t\t")
		      (write (car marks))
		      (newline)
		      (for-each (lambda (mark)
				  (write-string "\t\t\t")
				  (write mark)
				  (newline))
				(cdr marks))))))))))))

;;;; Object System Debugging

(define (instance-ref object name)
  (let ((entry (assq name (class-instance-transforms (object-class object)))))
    (if (not entry)
	(error "Not a valid instance-variable name:" name))
    (vector-ref object (cdr entry))))

(define (instance-set! object name value)
  (let ((entry (assq name (class-instance-transforms (object-class object)))))
    (if (not entry)
	(error "Not a valid instance-variable name:" name))
    (vector-set! object (cdr entry) value)))

;;;; Screen Trace

(define trace-output '())

(define (debug-tracer . args)
  (set! trace-output (cons args trace-output))
  unspecific)

(define (screen-trace #!optional screen)
  (let ((screen
	 (if (default-object? screen)
	     (begin
	       (if (not edwin-editor)
		   (error "No screen to trace."))
	       (editor-selected-screen edwin-editor))
	     screen)))
    (set! trace-output '())
    (for-each (lambda (window)
		(set-window-debug-trace! window debug-tracer))
	      (screen-window-list screen))
    (set-screen-debug-trace! screen debug-tracer)))

(define (screen-untrace #!optional screen)
  (let ((screen
	 (if (default-object? screen)
	     (begin
	       (if (not edwin-editor)
		   (error "No screen to trace."))
	       (editor-selected-screen edwin-editor))
	     screen)))
    (for-each (lambda (window)
		(set-window-debug-trace! window false))
	      (screen-window-list screen))
    (set-screen-debug-trace! screen false)
    (let ((result trace-output))
      (set! trace-output '())
      (map list->vector (reverse! result)))))