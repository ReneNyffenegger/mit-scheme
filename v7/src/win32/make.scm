#| -*-Scheme-*-

$Id: make.scm,v 1.2 1993/11/10 21:41:48 adams Exp $

Copyright (c) 1993 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. |#

;;;; Win32 subsystem: System Construction

(declare (usual-integrations))

(load "ffimacro")

(package/system-loader "win32" '() 'QUERY)
;((package/reference (find-package '(WIN32))
;		    'INITIALIZE-PACKAGE!))
(add-system! (make-system "Win32" 1 0 '()))


(define (package-initialize package-name procedure-name mandatory?)
  (define (print-name string)
    (display "\n")
    (display string)
    (display " (")
    (let loop ((name package-name))
      (if (not (null? name))
	  (begin
	    (if (not (eq? name package-name))
		(display " "))
	    (display (system-pair-car (car name)))
	    (loop (cdr name)))))
    (display ")"))

  (define (package-reference name)
    (package/environment (find-package name)))

  (let ((env (package-reference package-name)))
    (cond ((not (lexical-unreferenceable? env procedure-name))
	   (print-name "initialize:")
	   (if (not (eq? procedure-name 'INITIALIZE-PACKAGE!))
	       (begin
		 (display " [")
		 (display (system-pair-car procedure-name))
		 (display "]")))
	   ((lexical-reference env procedure-name)))
	  ((not mandatory?)
	   (print-name "* skipping:"))
	  (else
	   ;; Missing mandatory package! Report it and die.
	   (print-name "Package")
	   (display " is missing initialization procedure ")
	   (display (system-pair-car procedure-name))
	   (fatal-error "Could not initialize a required package.")))))


(package-initialize '(win32) 'initialize-protection-list-package! #t)
(package-initialize '(win32) 'initialize-module-package! #t)
(package-initialize '(win32) 'initialize-package! #t)
(package-initialize '(win32) 'init-wf_user! #t)
(package-initialize '(win32 scheme-graphics) 'initialize-package! #t)
(package-initialize '(win32 dib) 'initialize-package! #t)
