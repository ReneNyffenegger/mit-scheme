#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/rtlopt/rcseep.scm,v 4.4 1988/08/11 20:10:58 cph Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

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

;;;; RTL Common Subexpression Elimination: Expression Predicates
;;;  Based on the GNU C Compiler

(declare (usual-integrations))

(define (expression-equivalent? x y validate?)
  ;; If VALIDATE? is true, assume that Y comes from the hash table and
  ;; should have its register references validated.
  (define (loop x y)
    (let ((type (rtl:expression-type x)))
      (and (eq? type (rtl:expression-type y))
	   (case type
	     ((REGISTER)
	      (register-equivalent? x y))
	     ((OFFSET BYTE-OFFSET)
	      (let ((rx (rtl:offset-register x)))
		(and (register-equivalent? rx (rtl:offset-register y))
		     (if (interpreter-stack-pointer? rx)
			 (eq? (stack-reference-quantity x)
			      (stack-reference-quantity y))
			 (= (rtl:offset-number x)
			    (rtl:offset-number y))))))
	     (else
	      (rtl:match-subexpressions x y loop))))))

  (define (register-equivalent? x y)
    (let ((x (rtl:register-number x))
	  (y (rtl:register-number y)))
      (and (eq? (get-register-quantity x) (get-register-quantity y))
	   (or (not validate?)
	       (= (register-in-table y) (register-tick y))))))

  (loop x y))

(define (expression-refers-to? x y)
  ;; True iff any subexpression of X matches Y.
  (define (loop x)
    (or (eq? x y)
	(if (eq? (rtl:expression-type x) (rtl:expression-type y))
	    (expression-equivalent? x y false)
	    (rtl:any-subexpression? x loop))))
  (loop x))

(define-integrable (interpreter-register-reference? expression)
  (and (rtl:offset? expression)
       (interpreter-regs-pointer? (rtl:offset-register expression))))

(define (expression-non-object? expression)
  (if (rtl:register? expression)
      (or (register-contains-address? (rtl:register-number expression))
	  (register-contains-fixnum? (rtl:register-number expression)))
      (memq (rtl:expression-type expression)
	    '(OBJECT->ADDRESS
	      OBJECT->DATUM
	      OBJECT->TYPE
	      OBJECT->FIXNUM
	      CHAR->ASCII
	      OFFSET-ADDRESS
	      VARIABLE-CACHE
	      ASSIGNMENT-CACHE))))

(define (expression-address-varies? expression)
  (and (not (interpreter-register-reference? expression))
       (or (memq (rtl:expression-type expression)
		 '(OFFSET BYTE-OFFSET PRE-INCREMENT POST-INCREMENT)))
       (rtl:any-subexpression? expression expression-address-varies?)))