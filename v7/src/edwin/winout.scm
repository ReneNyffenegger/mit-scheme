;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/winout.scm,v 1.9 1994/09/08 20:34:04 adams Exp $
;;;
;;;	Copyright (c) 1986, 1989-92 Massachusetts Institute of Technology
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

;;;; Buffer I/O Ports
;;; package: (edwin window-output-port)

(declare (usual-integrations))

(define (with-output-to-current-point thunk)
  (with-output-to-window-point (current-window) thunk))

(define (with-output-to-window-point window thunk)
  (with-output-to-port (window-output-port window) thunk))

(define (window-output-port window)
  (output-port/copy window-output-port-template window))

(define (operation/fresh-line port)
  (if (not (line-start? (window-point (port/state port))))
      (operation/write-char port #\newline)))

(define (operation/write-char port char)
  (let ((window (port/state port)))
    (let ((buffer (window-buffer window))
	  (point (window-point window)))
      (if (and (null? (cdr (buffer-windows buffer)))
	       (line-end? point)
	       (buffer-auto-save-modified? buffer)
	       (or (not (window-needs-redisplay? window))
		   (window-direct-update! window false)))
	  (cond ((and (group-end? point)
		      (char=? char #\newline)
		      (< (1+ (window-point-y window)) (window-y-size window)))
		 (window-direct-output-insert-newline! window))
		((and (not (char=? char #\newline))
		      (not (char=? char #\tab))
		      (let ((image (window-char->image window char)))
			(and (= (string-length image) 1)
			     (char=? (string-ref image 0) char)))
		      ;; above 3 expressions replace (char-graphic? char)
		      (< (1+ (window-point-x window)) (window-x-size window)))
		 (window-direct-output-insert-char! window char))
		(else
		 (region-insert-char! point char)))
	  (region-insert-char! point char)))))

(define (operation/write-string port string)
  (let ((window (port/state port)))
    (let ((buffer (window-buffer window))
	  (point (window-point window)))
      (if (and (null? (cdr (buffer-windows buffer)))
	       (line-end? point)
	       (buffer-auto-save-modified? buffer)
	       (or (not (window-needs-redisplay? window))
		   (window-direct-update! window false))
	       (let loop ((i (- (string-length string) 1)))
		 (or (< i 0)
		     (let ((char  (string-ref string i)))
		       (and (not (char=? char #\newline))
			    (not (char=? char #\tab))
			    (let ((image (window-char->image window char)))
			      (and (= (string-length image) 1)
				   (char=? (string-ref image 0) char)
				   (loop (- i 1))))))))
	       ;; above loop expression replaces
	       ;;(not(string-find-next-char-in-set string char-set:not-graphic))
	       (< (+ (string-length string) (window-point-x window))
		  (window-x-size window)))
	  (window-direct-output-insert-substring! window
						  string
						  0
						  (string-length string))
	  (region-insert-string! point string)))))

(define (operation/flush-output port)
  (let ((window (port/state port)))
    (if (window-needs-redisplay? window)
	(window-direct-update! window false))))

(define (operation/x-size port)
  (window-x-size (port/state port)))

(define (operation/print-self state port)
  (unparse-string state "to window ")
  (unparse-object state (port/state port)))

(define window-output-port-template
  (make-output-port `((FLUSH-OUTPUT ,operation/flush-output)
		      (FRESH-LINE ,operation/fresh-line)
		      (PRINT-SELF ,operation/print-self)
		      (WRITE-CHAR ,operation/write-char)
		      (WRITE-STRING ,operation/write-string)
		      (X-SIZE ,operation/x-size))
		    false))