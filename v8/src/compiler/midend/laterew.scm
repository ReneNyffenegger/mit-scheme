#| -*-Scheme-*-

$Id: laterew.scm,v 1.3 1995/02/21 05:32:05 adams Exp $

Copyright (c) 1994 Massachusetts Institute of Technology

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

;;;; Late generic arithmetic rewrite
;;; package: (compiler midend)

(declare (usual-integrations))

(define (laterew/top-level program)
  (laterew/expr program))

(define-macro (define-late-rewriter keyword bindings . body)
  (let ((proc-name (symbol-append 'LATEREW/ keyword)))
    (call-with-values
     (lambda () (%matchup bindings '(handler) '(cdr form)))
     (lambda (names code)
       `(define ,proc-name
	  (let ((handler (lambda ,names ,@body)))
	    (named-lambda (,proc-name form)
	      (laterew/remember ,code form))))))))

(define-late-rewriter LOOKUP (name)
  `(LOOKUP ,name))

(define-late-rewriter LAMBDA (lambda-list body)
  `(LAMBDA ,lambda-list
     ,(laterew/expr body)))

(define-late-rewriter LET (bindings body)
  `(LET ,(lmap (lambda (binding)
		 (list (car binding)
		       (laterew/expr (cadr binding))))
	       bindings)
     ,(laterew/expr body)))

(define-late-rewriter LETREC (bindings body)
  `(LETREC ,(lmap (lambda (binding)
		    (list (car binding)
			  (laterew/expr (cadr binding))))
		  bindings)
     ,(laterew/expr body)))

(define-late-rewriter QUOTE (object)
  `(QUOTE ,object))

(define-late-rewriter DECLARE (#!rest anything)
  `(DECLARE ,@anything))

(define-late-rewriter BEGIN (#!rest actions)
  `(BEGIN ,@(laterew/expr* actions)))

(define-late-rewriter IF (pred conseq alt)
  `(IF ,(laterew/expr pred)
       ,(laterew/expr conseq)
       ,(laterew/expr alt)))

(define-late-rewriter CALL (rator #!rest rands)
  (cond ((and (QUOTE/? rator)
	      (rewrite-operator/late? (quote/text rator)))
	 => (lambda (handler)
	      (handler (laterew/expr* rands))))
	(else
	 `(CALL ,(laterew/expr rator)
		,@(laterew/expr* rands)))))


(define (laterew/expr expr)
  (if (not (pair? expr))
      (illegal expr))
  (case (car expr)
    ((QUOTE)
     (laterew/quote expr))
    ((LOOKUP)
     (laterew/lookup expr))
    ((LAMBDA)
     (laterew/lambda expr))
    ((LET)
     (laterew/let expr))
    ((DECLARE)
     (laterew/declare expr))
    ((CALL)
     (laterew/call expr))
    ((BEGIN)
     (laterew/begin expr))
    ((IF)
     (laterew/if expr))
    ((LETREC)
     (laterew/letrec expr))
    ((SET! UNASSIGNED? OR DELAY
      ACCESS DEFINE IN-PACKAGE THE-ENVIRONMENT)
     (no-longer-legal expr))
    (else
     (illegal expr))))

(define (laterew/expr* exprs)
  (lmap (lambda (expr)
	  (laterew/expr expr))
	exprs))

(define (laterew/remember new old)
  (code-rewrite/remember new old))

(define (laterew/new-name prefix)
  (new-variable prefix))

;;;; Late open-coding of generic arithmetic

(define (laterew/binaryop op %fixop %genop n-bits #!optional right-sided?)
  (let ((right-sided?
	 (if (default-object? right-sided?)
	     false
	     right-sided?))
	(%test
	 (cond ((not (number? n-bits))
		(lambda (name constant-rand)
		  (if constant-rand
		      `(CALL (QUOTE ,%small-fixnum?)
			     (QUOTE #F)
			     (LOOKUP ,name)
			     (QUOTE ,(n-bits constant-rand)))
		      `(QUOTE #F))))
	       #|
	       ;; Always open code as %small-fixnum?
	       ;; So that generic arithmetic can be
	       ;; recognized=>optimized at the RTL level
	       ((zero? n-bits)
		(lambda (name constant-rand)
		  constant-rand		; ignored
		  `(CALL (QUOTE ,%machine-fixnum?)
			 (QUOTE #F)
			 (LOOKUP ,name))))
	       |#
	       (else
		(lambda (name constant-rand)
		  constant-rand		; ignored		  
		  `(CALL (QUOTE ,%small-fixnum?)
			 (QUOTE #F)
			 (LOOKUP ,name)
			 (QUOTE ,n-bits)))))))
    (lambda (rands)
      (let ((cont (first rands))
	    (x    (second rands))
	    (y    (third rands)))
	(laterew/verify-hook-continuation cont)
	(let ((%continue
	       (if (eq? (car cont) 'QUOTE)
		   (lambda (expr)
		     expr)
		   (lambda (expr)
		     `(CALL (QUOTE ,%invoke-continuation)
			    ,cont
			    ,expr)))))
		   
	  (cond ((form/number? x)
		 => (lambda (x-value)
		      (cond ((form/number? y)
			     => (lambda (y-value)
				  `(QUOTE ,(op x-value y-value))))
			    (right-sided?
			     `(CALL (QUOTE ,%genop) ,cont ,x ,y))
			    (else
			     (let ((y-name (laterew/new-name 'Y)))
			       `(LET ((,y-name ,y))
				  (IF ,(%test y-name x-value)
				      ,(%continue
					`(CALL (QUOTE ,%fixop)
					       (QUOTE #f)
					       (QUOTE ,x-value)
					       (LOOKUP ,y-name)))
				      (CALL (QUOTE ,%genop)
					    ,cont
					    (QUOTE ,x-value)
					    (LOOKUP ,y-name)))))))))

		((form/number? y)
		 => (lambda (y-value)
		      (let ((x-name (laterew/new-name 'X)))
			`(LET ((,x-name ,x))
			   (IF ,(%test x-name y-value)
			       ,(%continue
				 `(CALL (QUOTE ,%fixop)
					(QUOTE #f)
					(LOOKUP ,x-name)
					(QUOTE ,y-value)))
			       (CALL (QUOTE ,%genop)
				     ,cont
				     (LOOKUP ,x-name)
				     (QUOTE ,y-value)))))))
		(right-sided?
		 `(CALL (QUOTE ,%genop) ,cont ,x ,y))
		(else
		 (let ((x-name (laterew/new-name 'X))
		       (y-name (laterew/new-name 'Y)))
		   `(LET ((,x-name ,x)
			  (,y-name ,y))
		      ;; There is no AND, since this occurs
		      ;; after macro-expansion
		      (IF ,(andify (%test x-name false)
				   (%test y-name false))
			  ,(%continue
			    `(CALL (QUOTE ,%fixop)
				   (QUOTE #F)
				   (LOOKUP ,x-name)
				   (LOOKUP ,y-name)))
			  (CALL (QUOTE ,%genop)
				,cont
				(LOOKUP ,x-name)
				(LOOKUP ,y-name))))))))))))


(define (laterew/verify-hook-continuation cont)
  (if (not (or (QUOTE/? cont)
	       (LOOKUP/? cont)
	       (CALL/%stack-closure-ref? cont)))
      (internal-error "Unexpected continuation to out-of-line hook"
		      cont))
  unspecific)

(define *late-rewritten-operators* (make-eq-hash-table))

(define-integrable (rewrite-operator/late? rator)
  (hash-table/get *late-rewritten-operators* rator false))

(define (define-rewrite/late operator-name-or-object handler)
  (hash-table/put! *late-rewritten-operators*
		   (if (hash-table/get *operator-properties*
				       operator-name-or-object
				       false)
		       operator-name-or-object
		       (make-primitive-procedure operator-name-or-object))
		   handler))

(define-rewrite/late '&+
  (laterew/binaryop + fix:+ %+ 1))

(define-rewrite/late '&-
  (laterew/binaryop - fix:- %- 1))

(define-rewrite/late '&*
  (laterew/binaryop * fix:* %* good-factor->nbits))

;; NOTE: these could use 0 as the number of bits, but this would prevent
;; a common RTL-level optimization triggered by CSE.

(define-rewrite/late '&=
  (laterew/binaryop = fix:= %= 1))

(define-rewrite/late '&<
  (laterew/binaryop < fix:< %< 1))

(define-rewrite/late '&>
  (laterew/binaryop > fix:> %> 1))

(define-rewrite/late 'QUOTIENT
  (laterew/binaryop careful/quotient fix:quotient %quotient
		    (lambda (value)
		      (cond ((zero? value)
			     (user-error "QUOTIENT by 0"))
			    ((= value -1)
			     ;; Most negative fixnum overflows!
			     1)
			    (else
			     0)))
		    true))

(define-rewrite/late 'REMAINDER
  (laterew/binaryop careful/remainder fix:remainder %remainder
		    (lambda (value)
		      (if (zero? value)
			  (user-error "REMAINDER by 0")
			  0))
		    true))