#| -*-Scheme-*-

$Id: packag.scm,v 14.12 1992/12/07 19:06:51 cph Exp $

Copyright (c) 1988-1992 Massachusetts Institute of Technology

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

;;;; Simple Package Namespace
;;; package: (package)

(declare (usual-integrations))

;;; Kludge -- package objects want to be records, but this file must
;;; be loaded first, before the record package.  The way we solve this
;;; problem is to build the initial packages without an appropriate
;;; record type, then build the record type and clobber it into the
;;; packages.  Thereafter, packages are constructed normally.

(define package-rtd
  false)

(define-integrable (make-package parent name environment)
  (%record package-rtd parent '() name environment))

(define (package? object)
  (and (%record? object)
       (eq? (%record-ref object 0) package-rtd)))

(define-integrable (package/parent package)
  (%record-ref package 1))

(define-integrable (package/children package)
  (%record-ref package 2))

(define-integrable (set-package/children! package children)
  (%record-set! package 2 children))

(define-integrable (package/%name package)
  (%record-ref package 3))

(define-integrable (package/environment package)
  (%record-ref package 4))

(define (finalize-package-record-type!)
  (let ((rtd
	 (make-record-type "package" '(PARENT CHILDREN %NAME ENVIRONMENT))))
    (set! package-rtd rtd)
    (let loop ((package system-global-package))
      (%record-set! package 0 rtd)
      (for-each loop (package/children package)))
    (set-record-type-unparser-method!
     rtd
     (unparser/standard-method 'PACKAGE
       (lambda (state package)
	 (unparse-object state (package/name package)))))))

(define (package/child package name)
  (let loop ((children (package/children package)))
    (and (not (null? children))
	 (if (eq? name (package/%name (car children)))
	     (car children)
	     (loop (cdr children))))))

(define (package/name package)
  (let loop ((package package) (result '()))
    (if (package/parent package)
	(loop (package/parent package) (cons (package/%name package) result))
	result)))

(define (name->package name)
  (let loop ((path name) (package system-global-package))
    (if (null? path)
	package
	(let ((child (package/child package (car path))))
	  (and child
	       (loop (cdr path) child))))))

(define (environment->package environment)
  (and (interpreter-environment? environment)
       (interpreter-environment->package environment)))

(define (interpreter-environment->package environment)
  (and (not (lexical-unreferenceable? environment package-name-tag))
       (let ((package (lexical-reference environment package-name-tag)))
	 (and (package? package)
	      (eq? environment (package/environment package))
	      package))))

(define-integrable package-name-tag
  ((ucode-primitive string->symbol) "#[(package)package-name-tag]"))

(define (find-package name)
  (let loop ((path name) (package system-global-package))
    (if (null? path)
	package
	(loop (cdr path)
	      (or (package/child package (car path))
		  (error "Unable to find package"
			 (list-difference name (cdr path))))))))

(define (list-difference list tail)
  (let loop ((list list))
    (if (eq? list tail)
	'()
	(cons (car list) (loop (cdr list))))))

(define (package/add-child! package name environment)
  (if (package/child package name)
      (error "Package already has child of given name" package name))
  (let ((child (make-package package name environment)))
    (set-package/children! package (cons child (package/children package)))
    (if (not (interpreter-environment->package environment))
	(local-assignment environment package-name-tag child))
    child))

(define system-global-package)

(define system-loader/enable-query?
  false)

(define (package/system-loader filename options load-interpreted?)
  (let ((pathname (->pathname filename)))
    (with-working-directory-pathname (directory-pathname pathname)
      (lambda ()
	(fluid-let ((load/default-types
		     (if (if (eq? load-interpreted? 'QUERY)
			     (and system-loader/enable-query?
				  (prompt-for-confirmation "Load interpreted"))
			     load-interpreted?)
			 '("bin" "scm")
			 load/default-types)))
	  (let ((syntax-table (nearest-repl/syntax-table)))
	    (load (pathname-new-type pathname "bcon")
		  system-global-environment
		  syntax-table false)
	    ((load (pathname-new-type pathname "bldr")
		   system-global-environment
		   syntax-table false)
	     (lambda (filename environment)
	       (load filename environment syntax-table true))
	     options))))))
  ;; Make sure that everything we just loaded is purified.  If the
  ;; program runs before it gets purified, some of its run-time state
  ;; can end up being purified also.
  (flush-purification-queue!))

(define-integrable (package/reference package name)
  (lexical-reference (package/environment package) name))

(define (initialize-package!)
  (set! system-global-package
	(make-package false false system-global-environment))
  (local-assignment system-global-environment
		    package-name-tag
		    system-global-package))