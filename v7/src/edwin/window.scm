;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/window.scm,v 1.153 1991/03/11 01:14:53 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-91 Massachusetts Institute of Technology
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

;;;; Window System

(declare (usual-integrations))

;;;  Based on WINDOW-WIN, designed by RMS.
;;;  See WINOPS.TXT for more information.

;;; The convention of using method names like :FOO is somewhat
;;; arbitrary.  However, methods without the prefix ":" are intended
;;; to be internal (non-public) methods.

;;; Procedural covers are used as the ultimate outside interface to
;;; the window system, since that minimizes dependence on the
;;; syntactic details of the class/object system.

;;; It is assumed in several places that all windows keep the
;;; following instance variables updated: SUPERIOR, X-SIZE, and
;;; Y-SIZE.  Thus these are normally accessed using procedure calls or
;;; instance variable references, rather than the more cumbersome
;;; method invocation.  However, these instance variables are always
;;; set by a method defined on the window itself.

;;; It is assumed in several places that the methods to set a window's
;;; size are called with interrupts disabled.

;;;; Vanilla Window

(define-class vanilla-window ()
  (superior x-size y-size redisplay-flags inferiors))

(define (window-initialize! window window*)
  (%set-window-superior! window window*)
  (set-window-inferiors! window '())
  (%set-window-redisplay-flags! window
				(=> window* :inferior-redisplay-flags window)))

(define (window-kill! window)
  (for-each-inferior-window window (lambda (window) (=> window :kill!))))

(define-integrable (window-superior window)
  (with-instance-variables vanilla-window window () superior))

(define-integrable (%set-window-superior! window window*)
  (with-instance-variables vanilla-window window (window*)
    (set! superior window*)))

(define-integrable (window-x-size window)
  (with-instance-variables vanilla-window window () x-size))

(define-integrable (%set-window-x-size! window x)
  (with-instance-variables vanilla-window window (x) (set! x-size x)))

(define-integrable (window-y-size window)
  (with-instance-variables vanilla-window window () y-size))

(define-integrable (%set-window-y-size! window y)
  (with-instance-variables vanilla-window window (y) (set! y-size y)))

(define-integrable (window-redisplay-flags window)
  (with-instance-variables vanilla-window window () redisplay-flags))

(define-integrable (%set-window-redisplay-flags! window flags)
  (with-instance-variables vanilla-window window (flags)
    (set! redisplay-flags flags)))

(define-integrable (window-inferiors window)
  (with-instance-variables vanilla-window window () inferiors))

(define-integrable (set-window-inferiors! window inferiors*)
  (with-instance-variables vanilla-window window (inferiors*)
    (set! inferiors inferiors*)))

(define (window-root-window window)
  (if (window-superior window)
      (window-root-window (window-superior window))
      window))

(define (set-window-superior! window window*)
  (%set-window-superior! window window*)
  (let ((flags (=> window* :inferior-redisplay-flags window)))
    (%set-window-redisplay-flags! window flags)
    (setup-redisplay-flags! flags)
    (for-each-inferior window
      (lambda (inferior)
	(set-inferior-redisplay-flags! inferior (cons false flags))
	(=> (inferior-window inferior) :set-superior! window)))))

(define (window-size window receiver)
  (receiver (window-x-size window) (window-y-size window)))

(define (set-window-x-size! window x)
  (%set-window-x-size! window x)
  (window-needs-redisplay! window))

(define (set-window-y-size! window y)
  (%set-window-y-size! window y)
  (window-needs-redisplay! window))

(define (set-window-size! window x y)
  (%set-window-x-size! window x)
  (%set-window-y-size! window y)
  (window-needs-redisplay! window))

(define-integrable (window-needs-redisplay? window)
  (car (window-redisplay-flags window)))

(define-integrable (window-needs-redisplay! window)
  (setup-redisplay-flags! (window-redisplay-flags window)))

(define-integrable (window-inferior? window window*)
  (find-inferior? (window-inferiors window) window*))

(define-integrable (window-inferior window window*)
  (find-inferior (window-inferiors window) window*))

(define-integrable (for-each-inferior window procedure)
  (let loop ((inferiors (window-inferiors window)))
    (if (not (null? inferiors))
	(begin
	  (procedure (car inferiors))
	  (loop (cdr inferiors))))))

(define-integrable (for-each-inferior-window window procedure)
  (for-each-inferior window
    (lambda (inferior)
      (procedure (inferior-window inferior)))))

(define (make-inferior window class)
  (let ((window* (make-object class)))
    (let ((inferior
	   (%make-inferior window*
			   false
			   false
			   (cons false (window-redisplay-flags window)))))
      (set-window-inferiors! window (cons inferior (window-inferiors window)))
      (=> window* :initialize! window)
      inferior)))

(define (add-inferior! window window*)
  (let ((inferior
	 (%make-inferior window*
			 false
			 false
			 (cons false (window-redisplay-flags window)))))
    (set-window-inferiors! window (cons inferior (window-inferiors window)))
    (=> window* :set-superior! window)
    inferior))

(define (delete-inferior! window window*)
  (set-window-inferiors! window
			 (let ((inferiors (window-inferiors window)))
			   (delq! (find-inferior inferiors window*)
				  inferiors))))

(define (replace-inferior! window old new)
  (set-inferior-window! (find-inferior (window-inferiors window) old) new)
  (=> new :set-superior! window))

;;; Returns #T if the redisplay finished, #F if aborted.
;;; Notice that the :UPDATE-DISPLAY! operation is assumed to return
;;; the same value.  This is used to control the setting of the
;;; redisplay flags.

(define (window-update-display! window screen x-start y-start xl xu yl yu
				display-style)
  (update-inferiors! (window-inferiors window) screen x-start y-start
		     xl xu yl yu display-style
    (let ((char-ready? (editor-char-ready? current-editor)))
      (lambda (window screen x-start y-start xl xu yl yu display-style)
	(and (or display-style (not (char-ready?)))
	     (=> window :update-display! screen x-start y-start xl xu yl yu
		 display-style))))))

(define (update-inferiors! inferiors screen x-start y-start xl xu yl yu
			   display-style updater)
  (let loop ((inferiors inferiors))
    (if (null? inferiors)
	true
	(and (update-inferior! (car inferiors) screen x-start y-start
			       xl xu yl yu display-style updater)
	     (loop (cdr inferiors))))))

(define (update-inferior! inferior screen x-start y-start xl xu yl yu
			  display-style updater)
  (let ((window (inferior-window inferior))
	(xi (inferior-x-start inferior))
	(yi (inferior-y-start inferior))
	(flags (inferior-redisplay-flags inferior)))
    (and (or (not xi)
	     (not (or display-style (car flags)))
	     (clip-window-region-1 (fix:- xl xi)
				   (fix:- xu xi)
				   (window-x-size window)
	       (lambda (xl xu)
		 (clip-window-region-1 (fix:- yl yi)
				       (fix:- yu yi)
				       (window-y-size window)
		   (lambda (yl yu)
		     (updater window
			      screen (fix:+ x-start xi) (fix:+ y-start yi)
			      xl xu yl yu display-style))))))
	 (begin
	   (set-car! flags false)
	   true))))

(define (clip-window-region-1 al au bs receiver)
  (if (fix:< 0 al)
      (if (fix:< au bs)
	  (if (fix:< al au) (receiver al au) true)
	  (if (fix:< al bs) (receiver al bs) true))
      (if (fix:< au bs)
	  (if (fix:< 0 au) (receiver 0 au) true)
	  (if (fix:< 0 bs) (receiver 0 bs) true))))

(define (salvage-inferiors! window)
  (for-each-inferior-window window (lambda (window) (=> window :salvage!))))

;;;; Standard Methods
;;;  All windows support these operations

(define-method vanilla-window :initialize! window-initialize!)
(define-method vanilla-window :kill! window-kill!)
(define-method vanilla-window :superior window-superior)
(define-method vanilla-window :set-superior! set-window-superior!)
(define-method vanilla-window :x-size window-x-size)
(define-method vanilla-window :set-x-size! set-window-x-size!)
(define-method vanilla-window :y-size window-y-size)
(define-method vanilla-window :set-y-size! set-window-y-size!)
(define-method vanilla-window :size window-size)
(define-method vanilla-window :set-size! set-window-size!)

(define-method vanilla-window (:make-inferior window class)
  (inferior-window (make-inferior window class)))

(define-method vanilla-window :add-inferior! add-inferior!)
(define-method vanilla-window :delete-inferior! delete-inferior!)
(define-method vanilla-window :replace-inferior! replace-inferior!)
(define-method vanilla-window :update-display! window-update-display!)
(define-method vanilla-window :salvage! salvage-inferiors!)

;;;; Operations on Inferiors

(define-method vanilla-window (:inferior-redisplay-flags window window*)
  (inferior-redisplay-flags (find-inferior inferiors window*)))

(define-method vanilla-window (:inferior-needs-redisplay! window window*)
  (inferior-needs-redisplay! (find-inferior inferiors window*)))

(define-method vanilla-window (:inferior-position window window*)
  (inferior-position (find-inferior inferiors window*)))

(define-method vanilla-window (:set-inferior-position! window window* position)
  (set-inferior-position! (find-inferior inferiors window*) position))

(define-method vanilla-window (:inferior-x-start window window*)
  (inferior-x-start (find-inferior inferiors window*)))

(define-method vanilla-window (:set-inferior-x-start! window window* x-start)
  (set-inferior-x-start! (find-inferior inferiors window*) x-start))

(define-method vanilla-window (:inferior-x-end window window*)
  (inferior-x-end (find-inferior inferiors window*)))

(define-method vanilla-window (:set-inferior-x-end! window window* x-end)
  (set-inferior-x-end! (find-inferior inferiors window*) x-end))

(define-method vanilla-window (:inferior-y-start window window*)
  (inferior-y-start (find-inferior inferiors window*)))

(define-method vanilla-window (:set-inferior-y-start! window window* y-start)
  (set-inferior-y-start! (find-inferior inferiors window*) y-start))

(define-method vanilla-window (:inferior-y-end window window*)
  (inferior-y-end (find-inferior inferiors window*)))

(define-method vanilla-window (:set-inferior-y-end! window window* y-end)
  (set-inferior-y-end! (find-inferior inferiors window*) y-end))

(define-method vanilla-window (:inferior-start window window* receiver)
  (inferior-start (find-inferior inferiors window*) receiver))

(define-method vanilla-window (:set-inferior-start! window window* x y)
  (set-inferior-start! (find-inferior inferiors window*) x y))

;;;; Inferiors

(define %inferior-tag
  "inferior")

(define-integrable (%make-inferior window x-start y-start redisplay-flags)
  (vector %inferior-tag window x-start y-start redisplay-flags))

(define-integrable (inferior-window inferior)
  (vector-ref inferior 1))

(define-integrable (set-inferior-window! inferior window)
  (vector-set! inferior 1 window))

(define-integrable (inferior-x-start inferior)
  (vector-ref inferior 2))

(define-integrable (%set-inferior-x-start! inferior x-start)
  (vector-set! inferior 2 x-start))

(define-integrable (inferior-y-start inferior)
  (vector-ref inferior 3))

(define-integrable (%set-inferior-y-start! inferior y-start)
  (vector-set! inferior 3 y-start))

(define-integrable (inferior-redisplay-flags inferior)
  (vector-ref inferior 4))

(define-integrable (set-inferior-redisplay-flags! inferior redisplay-flags)
  (vector-set! inferior 4 redisplay-flags))

(unparser/set-tagged-vector-method! %inferior-tag
  (unparser/standard-method 'INFERIOR
    (lambda (state inferior)
      (unparse-object state (inferior-window inferior))
      (unparse-string state " x,y=(")
      (unparse-object state (inferior-x-start inferior))
      (unparse-string state ",")
      (unparse-object state (inferior-y-start inferior))
      (unparse-string state ")")
      (if (inferior-needs-redisplay? inferior)
	  (unparse-string state " needs-redisplay")))))

(define (inferior-copy inferior)
  (%make-inferior (inferior-window inferior)
		  (inferior-x-start inferior)
		  (inferior-y-start inferior)
		  (inferior-redisplay-flags inferior)))

(define (inferior-start inferior receiver)
  (receiver (inferior-x-start inferior)
	    (inferior-y-start inferior)))

(define (%set-inferior-start! inferior x-start y-start)
  (%set-inferior-x-start! inferior x-start)
  (%set-inferior-y-start! inferior y-start))

(define (set-inferior-x-start! inferior x-start)
  (%set-inferior-x-start! inferior x-start)
  (inferior-needs-redisplay! inferior))

(define (set-inferior-y-start! inferior y-start)
  (%set-inferior-y-start! inferior y-start)
  (inferior-needs-redisplay! inferior))

(define (set-inferior-start! inferior x-start y-start)
  (%set-inferior-start! inferior x-start y-start)
  (inferior-needs-redisplay! inferior))

(define-integrable (%inferior-x-end inferior)
  (fix:+ (inferior-x-start inferior) (inferior-x-size inferior)))

(define-integrable (%inferior-y-end inferior)
  (fix:+ (inferior-y-start inferior) (inferior-y-size inferior)))

(define (inferior-x-end inferior)
  (and (inferior-x-start inferior)
       (%inferior-x-end inferior)))

(define (inferior-y-end inferior)
  (and (inferior-y-start inferior)
       (%inferior-y-end inferior)))

(define (set-inferior-x-end! inferior x-end)
  (set-inferior-x-start! inferior (fix:- x-end (inferior-x-size inferior))))

(define (set-inferior-y-end! inferior y-end)
  (set-inferior-y-start! inferior (fix:- y-end (inferior-y-size inferior))))

(define (inferior-position inferior)
  (and (inferior-x-start inferior)
       (cons (inferior-x-start inferior)
	     (inferior-y-start inferior))))

(define (set-inferior-position! inferior position)
  (if (not position)
      (set-inferior-start! inferior false false)
      (set-inferior-start! inferior (car position) (cdr position))))

(define-integrable (inferior-needs-redisplay? inferior)
  (car (inferior-redisplay-flags inferior)))

(define (inferior-needs-redisplay! inferior)
  (if (and (inferior-x-start inferior) (inferior-y-start inferior))
      (setup-redisplay-flags! (inferior-redisplay-flags inferior))
      (set-car! (inferior-redisplay-flags inferior) false)))

(define (setup-redisplay-flags! flags)
  (let loop ((flags flags))
    (if (not (or (null? flags) (car flags)))
	(begin
	  (set-car! flags true)
	  (loop (cdr flags))))))

(define-integrable (inferior-x-size inferior)
  (window-x-size (inferior-window inferior)))

(define-integrable (%set-inferior-x-size! inferior x)
  (%set-window-x-size! (inferior-window inferior) x))

(define-integrable (set-inferior-x-size! inferior x)
  (=> (inferior-window inferior) :set-x-size! x))

(define-integrable (inferior-y-size inferior)
  (window-y-size (inferior-window inferior)))

(define-integrable (%set-inferior-y-size! inferior y)
  (%set-window-y-size! (inferior-window inferior) y))

(define-integrable (set-inferior-y-size! inferior y)
  (=> (inferior-window inferior) :set-y-size! y))

(define-integrable (inferior-size inferior receiver)
  (window-size (inferior-window inferior) receiver))

(define-integrable (set-inferior-size! inferior x y)
  (=> (inferior-window inferior) :set-size! x y))

(define (find-inferior? inferiors window)
  (let loop ((inferiors inferiors))
    (and (not (null? inferiors))
	 (if (eq? window (inferior-window (car inferiors)))
	     (car inferiors)
	     (loop (cdr inferiors))))))

(define (find-inferior inferiors window)
  (let ((inferior (find-inferior? inferiors window)))
    (if (not inferior)
	(error "window not in inferiors" window))
    inferior))

(define (inferior-containing-coordinates window x y stop-search?)
  (let search ((window window) (x x) (y y))
    (if (stop-search? window)
	(values window x y)
	(let loop ((inferiors (window-inferiors window)))
	  (if (null? inferiors)
	      (values false false false)
	      (let ((inferior (car inferiors)))
		(let ((x-start (inferior-x-start inferior))
		      (y-start (inferior-y-start inferior)))
		  (if (and x-start y-start)
		      (let ((x (fix:- x x-start))
			    (y (fix:- y y-start)))
			(if (and (fix:<= 0 x)
				 (fix:< x (inferior-x-size inferior))
				 (fix:<= 0 y)
				 (fix:< y (inferior-y-size inferior)))
			    (search (inferior-window inferior) x y)
			    (loop (cdr inferiors))))
		      (loop (cdr inferiors))))))))))