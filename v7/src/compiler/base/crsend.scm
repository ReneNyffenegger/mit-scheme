#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/base/crsend.scm,v 1.8 1992/06/12 01:43:04 jinx Exp $

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

;;;; Cross Compiler End
;;; This program does not need the rest of the compiler, but should
;;; match the version of the same name in crstop.scm and toplev.scm

(declare (usual-integrations))

(define (cross-compile-bin-file-end input-string #!optional output-string)
  (compiler-pathnames input-string
		      (and (not (default-object? output-string)) output-string)
		      (make-pathname false false false false "moc" 'NEWEST)
    (lambda (input-pathname output-pathname)
      output-pathname			;ignore
      (cross-compile-scode-end (fasload input-pathname)))))

(define (compiler-pathnames input-string output-string default transform)
  (let ((kernel
	  (lambda (input-string)
	    (let ((input-pathname (merge-pathnames input-string default)))
	      (let ((output-pathname
		     (let ((output-pathname
			    (pathname-new-type input-pathname "com")))
		       (if output-string
			   (merge-pathnames output-string output-pathname)
			   output-pathname))))
		(newline)
		(write-string "Compile File: ")
		(write (enough-namestring input-pathname))
		(write-string " => ")
		(write (enough-namestring output-pathname))
		(fasdump (transform input-pathname output-pathname)
			 output-pathname))))))
    (if (pair? input-string)
	(for-each kernel input-string)
	(kernel input-string))))

(define (cross-compile-scode-end cross-compilation)
  (let ((compile-by-procedures? (vector-ref cross-compilation 0))
	(expression (cross-link-end (vector-ref cross-compilation 1)))
	(others (map cross-link-end (vector-ref cross-compilation 2))))
    (if (null? others)
	expression
	(scode/make-comment
	 (make-dbg-info-vector
	  (let ((all-blocks
		 (list->vector
		  (cons
		   (compiled-code-address->block expression)
		   others))))
	    (if compile-by-procedures?
		(list 'COMPILED-BY-PROCEDURES
		      all-blocks
		      (list->vector others))
		all-blocks)))
	 expression))))

(define-structure (cc-code-block (type vector)
				 (conc-name cc-code-block/))
  (debugging-info false read-only false)
  (bit-string false read-only true)
  (objects false read-only true)
  (object-width false read-only true))

(define-structure (cc-vector (constructor cc-vector/make)
			     (conc-name cc-vector/))
  (code-vector false read-only true)
  (entry-label false read-only true)
  (entry-points false read-only true)
  (label-bindings false read-only true)
  (ic-procedure-headers false read-only true))

(define (cross-link-end object)
  (let ((code-vector (cc-vector/code-vector object)))
    (cross-link/process-code-vector
     (cond ((compiled-code-block? code-vector)
	    code-vector)
	   ((vector? code-vector)
	    (let ((new-code-vector (cross-link/finish-assembly
				    (cc-code-block/bit-string code-vector)
				    (cc-code-block/objects code-vector)
				    (cc-code-block/object-width code-vector))))
	      (set-compiled-code-block/debugging-info!
	       new-code-vector
	       (cc-code-block/debugging-info code-vector))
	      new-code-vector))
	   (else
	    (error "cross-link-end: Unexpected code-vector"
		   code-vector object)))
     object)))

(define (cross-link/process-code-vector code-vector cc-vector)
  (let ((bindings
	 (let ((label-bindings (cc-vector/label-bindings cc-vector)))
	   (map (lambda (label)
		  (cons
		   label
		   (with-absolutely-no-interrupts
		     (lambda ()
		       (let-syntax ((ucode-primitive
				     (macro (name)
				       (make-primitive-procedure name)))
				    (ucode-type
				     (macro (name)
				       (microcode-type name))))
			 ((ucode-primitive PRIMITIVE-OBJECT-SET-TYPE)
			  (ucode-type COMPILED-ENTRY)
			  (make-non-pointer-object
			   (+ (cdr (or (assq label label-bindings)
				       (error "Missing entry point" label)))
			      (object-datum code-vector)))))))))
		(cc-vector/entry-points cc-vector)))))
    (let ((label->expression
	   (lambda (label)
	     (cdr (or (assq label bindings)
		      (error "Label not defined as entry point" label))))))
      (let ((expression (label->expression (cc-vector/entry-label cc-vector))))
	(for-each (lambda (entry)
		    (set-lambda-body! (car entry)
				      (label->expression (cdr entry))))
		  (cc-vector/ic-procedure-headers cc-vector))
	expression))))

(define (cross-link/finish-assembly code-block objects scheme-object-width)
  (let-syntax ((ucode-primitive
		(macro (name)
		  (make-primitive-procedure name)))
	       (ucode-type
		(macro (name)
		  (microcode-type name))))
    (let* ((bl (quotient (bit-string-length code-block)
			 scheme-object-width))
	   (non-pointer-length
	    ((ucode-primitive make-non-pointer-object) bl))
	   (output-block (make-vector (1+ (+ (length objects) bl)))))
      (with-absolutely-no-interrupts
	(lambda ()
	  (vector-set! output-block 0
		       ((ucode-primitive primitive-object-set-type)
			(ucode-type manifest-nm-vector)
			non-pointer-length))))
      (write-bits! output-block
		   ;; After header just inserted.
		   (* scheme-object-width 2)
		   code-block)
      (insert-objects! output-block objects (1+ bl))
      (object-new-type (ucode-type compiled-code-block)
		       output-block))))

(define (insert-objects! v objects where)
  (cond ((not (null? objects))
	 (vector-set! v where (cadar objects))
	 (insert-objects! v (cdr objects) (1+ where)))
	((not (= where (vector-length v)))
	 (error "insert-objects!: object phase error" where))
	(else
	 unspecific)))