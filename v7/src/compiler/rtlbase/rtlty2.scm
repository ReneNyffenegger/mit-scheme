#| -*-Scheme-*-

$Id: rtlty2.scm,v 4.12 1993/07/01 03:25:52 gjr Exp $

Copyright (c) 1988-1993 Massachusetts Institute of Technology

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

;;;; Register Transfer Language Type Definitions
;;; package: (compiler)

(declare (usual-integrations))

(define-integrable rtl:expression? pair?)
(define-integrable rtl:expression-type car)
(define-integrable rtl:address-register cadr)
(define-integrable rtl:address-number caddr)
(define-integrable rtl:test-expression cadr)
(define-integrable rtl:invocation-pushed cadr)
(define-integrable rtl:invocation-continuation caddr)

(define-integrable (rtl:set-invocation-continuation! rtl continuation)
  (set-car! (cddr rtl) continuation))

;;;; Locatives

;;; Locatives are used as an intermediate form by the code generator
;;; to build expressions.  Later, when the expressions are inserted
;;; into statements, any locatives they contain are eliminated by
;;; "simplifying" them into sequential instructions using pseudo
;;; registers.

(define-integrable register:environment
  'ENVIRONMENT)

(define-integrable register:stack-pointer
  'STACK-POINTER)

(define-integrable register:dynamic-link
  'DYNAMIC-LINK)

(define-integrable register:value
  'VALUE)

(define-integrable register:int-mask
  'INT-MASK)

(define-integrable register:memory-top
  'MEMORY-TOP)

(define-integrable register:free
  'FREE)

(define-integrable (rtl:interpreter-call-result:access)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:ACCESS))

(define-integrable (rtl:interpreter-call-result:cache-reference)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:CACHE-REFERENCE))

(define-integrable (rtl:interpreter-call-result:cache-unassigned?)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:CACHE-UNASSIGNED?))

(define-integrable (rtl:interpreter-call-result:lookup)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:LOOKUP))

(define-integrable (rtl:interpreter-call-result:unassigned?)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:UNASSIGNED?))

(define-integrable (rtl:interpreter-call-result:unbound?)
  (rtl:make-fetch 'INTERPRETER-CALL-RESULT:UNBOUND?))

;;; "Pre-simplification" locative offsets

(define (rtl:locative-offset? locative)
  (and (pair? locative) (eq? (car locative) 'OFFSET)))

(define-integrable rtl:locative-offset-base cadr)
(define-integrable rtl:locative-offset-offset caddr)

#|
(define (rtl:locative-offset-granularity locative)
  ;; This is kludged up for backward compatibility
  (if (rtl:locative-offset? locative)
      (if (pair? (cdddr locative))
	  (cadddr locative)
	  'OBJECT)
      (error "Not a locative offset" locative)))
|#
(define-integrable rtl:locative-offset-granularity cadddr)

(define-integrable (rtl:locative-byte-offset? locative)
  (eq? (rtl:locative-offset-granularity locative) 'BYTE))

(define-integrable (rtl:locative-float-offset? locative)
  (eq? (rtl:locative-offset-granularity locative) 'FLOAT))

(define-integrable (rtl:locative-object-offset? locative)
  (eq? (rtl:locative-offset-granularity locative) 'OBJECT))

(define-integrable (rtl:locative-offset locative offset)
  (rtl:locative-object-offset locative offset))

(define (rtl:locative-byte-offset locative byte-offset)
  (cond ((rtl:locative-offset? locative)
	 `(OFFSET ,(rtl:locative-offset-base locative)
		  ,(back-end:+
		    byte-offset
		    (cond ((rtl:locative-byte-offset? locative)
			   (rtl:locative-offset-offset locative))
			  ((rtl:locative-object-offset? locative)
			   (back-end:*
			    (rtl:locative-offset-offset locative)
			    address-units-per-object))
			  (else
			   (back-end:*
			    (rtl:locative-offset-offset locative)
			    address-units-per-float))))
		  BYTE))
	((back-end:= byte-offset 0)
	 locative)
	(else
	 `(OFFSET ,locative ,byte-offset BYTE))))

(define (rtl:locative-float-offset locative float-offset)
  (let ((default
	  (lambda ()
	    `(OFFSET ,locative ,float-offset FLOAT))))
    (cond ((rtl:locative-offset? locative)
	   (if (rtl:locative-float-offset? locative)
	       `(OFFSET ,(rtl:locative-offset-base locative)
			,(back-end:+ (rtl:locative-offset-offset locative)
				     float-offset)
			FLOAT)
	       (default)))
	  (else
	   (default)))))

(define (rtl:locative-object-offset locative offset)
  (cond ((back-end:= offset 0) locative)
	((rtl:locative-offset? locative)
	 (if (not (rtl:locative-object-offset? locative))
	     (error "Can't add object offset to non-object offset"
		    locative offset)
	     `(OFFSET ,(rtl:locative-offset-base locative)
		      ,(back-end:+ (rtl:locative-offset-offset locative)
				   offset)
		      OBJECT)))
	(else
	 `(OFFSET ,locative ,offset OBJECT))))

(define (rtl:locative-index? locative)
  (and (pair? locative) (eq? (car locative) 'INDEX)))

(define-integrable rtl:locative-index-base cadr)
(define-integrable rtl:locative-index-offset caddr)
(define-integrable rtl:locative-index-granularity cadddr)

(define-integrable (rtl:locative-byte-index? locative)
  (eq? (rtl:locative-index-granularity locative) 'BYTE))

(define-integrable (rtl:locative-float-index? locative)
  (eq? (rtl:locative-index-granularity locative) 'FLOAT))

(define-integrable (rtl:locative-object-index? locative)
  (eq? (rtl:locative-index-granularity locative) 'OBJECT))

(define (rtl:locative-byte-index locative offset)
  `(INDEX ,locative ,offset BYTE))

(define (rtl:locative-float-index locative offset)
  `(INDEX ,locative ,offset FLOAT))

(define (rtl:locative-object-index locative offset)
  `(INDEX ,locative ,offset OBJECT))

;;; Expressions that are used in the intermediate form.

(define-integrable (rtl:make-address locative)
  `(ADDRESS ,locative))

(define-integrable (rtl:make-environment locative)
  `(ENVIRONMENT ,locative))

(define-integrable (rtl:make-cell-cons expression)
  `(CELL-CONS ,expression))

(define-integrable (rtl:make-fetch locative)
  `(FETCH ,locative))

(define-integrable (rtl:make-typed-cons:pair type car cdr)
  `(TYPED-CONS:PAIR ,type ,car ,cdr))

(define-integrable (rtl:make-typed-cons:vector type elements)
  `(TYPED-CONS:VECTOR ,type ,@elements))

(define-integrable (rtl:make-typed-cons:procedure entry)
  `(TYPED-CONS:PROCEDURE ,entry))

;;; Linearizer Support

(define-integrable (rtl:make-jump-statement label)
  `(JUMP ,label))

(define-integrable (rtl:make-jumpc-statement predicate label)
  `(JUMPC ,predicate ,label))

(define-integrable (rtl:make-label-statement label)
  `(LABEL ,label))

(define-integrable (rtl:negate-predicate expression)
  `(NOT ,expression))

;;; Stack

(define-integrable (stack-locative-offset locative offset)
  (rtl:locative-offset locative (stack->memory-offset offset)))

(define-integrable (stack-push-address)
  (rtl:make-pre-increment (interpreter-stack-pointer)
			  (stack->memory-offset -1)))

(define-integrable (stack-pop-address)
  (rtl:make-post-increment (interpreter-stack-pointer)
			   (stack->memory-offset 1)))