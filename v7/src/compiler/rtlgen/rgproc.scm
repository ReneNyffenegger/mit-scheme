#| -*-Scheme-*-

$Id: rgproc.scm,v 4.13 1992/11/09 18:43:08 jinx Exp $

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

;;;; RTL Generation: Procedure Headers
;;; package: (compiler rtl-generator generate/procedure-header)

(declare (usual-integrations))

(define (generate/procedure-header procedure body inline?)
  (scfg*scfg->scfg!
   (let ((context (make-reference-context (procedure-block procedure))))
     (set-reference-context/offset! context 0)
     (if (procedure/ic? procedure)
	 (scfg*scfg->scfg!
	  (if inline?
	      (make-null-cfg)
	      (rtl:make-ic-procedure-header (procedure-label procedure)))
	  (setup-ic-frame procedure context))
	 (scfg*scfg->scfg!
	  (cond (inline?
		 ;; Paranoia
		 (if (not (procedure/virtually-open? procedure))
		     (error "Inlining a real closure!" procedure))
		 (make-null-cfg))
		((procedure/closure? procedure)
		 (let ((needs-entry?
			(or (procedure-rest procedure)
			    (closure-procedure-needs-external-descriptor?
			     procedure))))
		   (cond ((not (procedure/trivial-closure? procedure))
			  (let* ((block (procedure-closing-block procedure))
				 (nentries (block-entry-number
					    (block-shared-block block))))
			    (if (or (not needs-entry?) (zero? nentries))
				;; It's not an open procedure but it looks like
				;; one at the rtl level.
				(rtl:make-open-procedure-header
				 (procedure-label procedure))
				(rtl:make-closure-header
				 (procedure-label procedure)
				 nentries
				 (closure-block-entry-number block)))))
			 (needs-entry?
			  (with-values
			      (lambda () (procedure-arity-encoding procedure))
			    (lambda (min max)
			      (rtl:make-procedure-header
			       (procedure-label procedure)
			       min max))))
			 (else
			  ;; It's not an open procedure but it looks like one
			  ;; at the rtl level.
			  (rtl:make-open-procedure-header
			   (procedure-label procedure))))))
		((procedure-rest procedure)
		 (with-values (lambda () (procedure-arity-encoding procedure))
		   (lambda (min max)
		     (if (open-procedure-needs-dynamic-link? procedure)
			 (scfg*scfg->scfg!
			  (rtl:make-procedure-header
			   (procedure-label procedure)
			   (1+ min)
			   (-1+ max))
			  (rtl:make-pop-link))
			 (rtl:make-procedure-header (procedure-label procedure)
						    min max)))))
		(else
		 (rtl:make-open-procedure-header (procedure-label procedure))))
	  (setup-stack-frame procedure context))))
   body))

(define (setup-ic-frame procedure context)
  (scfg*->scfg!
   (map (let ((block (procedure-block procedure)))
	  (lambda (name value)
	    (generate/rvalue value scfg*scfg->scfg!
	     (lambda (expression)
	       (load-temporary-register scfg*scfg->scfg! expression
		(lambda (expression)
		  (wrap-with-continuation-entry
		   context
		   (lambda (cont-label)
		     (rtl:make-interpreter-call:set!
		      cont-label
		      (rtl:make-fetch register:environment)
		      (intern-scode-variable! block (variable-name name))
		      expression)))))))))
	(procedure-names procedure)
	(procedure-values procedure))))

(define (setup-stack-frame procedure context)
  (let ((block (procedure-block procedure)))
    (define (cellify-variables variables)
      (scfg*->scfg! (map cellify-variable variables)))

    (define (cellify-variable variable)
      (if (and (variable-in-cell? variable)
	       (not (and (variable-source-node variable)
			 (procedure-inline-code? procedure))))
	  (let ((locative
		 (let ((register (variable/register variable)))
		   (or register
		       (stack-locative-offset
			(rtl:make-fetch register:stack-pointer)
			(variable-offset block variable))))))
	    (rtl:make-assignment
	     locative
	     (rtl:make-cell-cons (rtl:make-fetch locative))))
	  (make-null-cfg)))

    (let ((names (procedure-names procedure))
	  (values (procedure-values procedure)))
      (scfg-append!
       (setup-bindings names values '())
       (cellify-variables (procedure-required-arguments procedure))
       (cellify-variables (procedure-optional procedure))
       (let ((rest (procedure-rest procedure)))
	 (if rest
	     (cellify-variable rest)
	     (make-null-cfg)))
       (scfg*->scfg! (map (lambda (name value)
			    (close-binding context name value))
			  names values))))))

(define (setup-bindings names values pushes)
  (if (null? names)
      (scfg*->scfg! pushes)
      (setup-bindings (cdr names)
		      (cdr values)
		      (letrec-value (car names) (car values)
		       (lambda (scfg expression)
			 (cons (scfg*scfg->scfg!
				scfg
				(make-auxiliary-push (car names) expression))
			       pushes))))))

(define (make-auxiliary-push variable value)
  (rtl:make-push (if (variable-in-cell? variable)
		     (rtl:make-cell-cons value)
		     value)))

(define (letrec-value name value recvr)
  (cond ((constant? value)
	 (recvr (make-null-cfg)
		(rtl:make-constant (constant-value value))))
	((procedure? value)
	 (enqueue-procedure! value)
	 (case (procedure/type value)
	   ((CLOSURE)
	    (let ((closing-block (procedure-closing-block value)))
	      (recvr
	       (make-null-cfg)
	       (if (eq? closing-block (block-shared-block closing-block))
		   (make-non-trivial-closure-cons value false)
		   (let ((how (procedure-closure-cons value)))
		     (cond ((or (not (eq? (car how) 'INDIRECTED))
				(not (eq? (variable-block (cdr how))
					  (variable-block name))))
			    (make-cons-closure-redirection value))
			   ((not (variable-in-cell? name))
			    (error "letrec-value: Non-indirected shared sibling!"
				   value))
			   (else
			    (rtl:make-constant
			     (make-unassigned-reference-trap)))))))))
	   ((IC)
	    (with-values (lambda () (make-ic-cons value 'USE-ENV)) recvr))
	   ((TRIVIAL-CLOSURE)
	    ;; This is not an error.
	    ;; It can be the consequence of bad style.
	    (warn "Letrec value is trivial closure" value)
	    (recvr (make-null-cfg)
		   (make-trivial-closure-cons value)))
	   ((OPEN-EXTERNAL OPEN-INTERNAL)
	    (error "Letrec value is open procedure" value))
	   (else
	    (error "Unknown procedure type" value))))
	((block? value)
	 (for-each
	  (lambda (block*)
	    (enqueue-procedure!
	     (block-procedure (car (block-children block*)))))
	  (block-grafted-blocks value))
	 (recvr (make-null-cfg)
		(make-non-trivial-closure-cons
		 (indirection-block-procedure value)
		 value)))
	(else
	 (error "Unknown letrec binding value" value))))

(define (close-binding context name value)
  (cond ((block? value)
	 (letrec-close context name
		       (indirection-block-procedure value)))
	((and (procedure? value)
	      (not (procedure/trivial-or-virtual? value)))
	 (let ((closing-block (procedure-closing-block value)))
	   (if (eq? closing-block (block-shared-block closing-block))
	       (letrec-close context name value)
	       (let ((how (procedure-closure-cons value)))
		 (cond ((or (not (eq? (car how) 'INDIRECTED))
			    (not (eq? (variable-block (cdr how))
				      (variable-block name))))
			(make-null-cfg))
		       ((not (variable-in-cell? name))
			(error "close-binding: Non-indirected shared sibling!"
			       value))
		       (else
			(find-variable/locative
			 context name
			 (lambda (locative)
			   (rtl:make-assignment
			    locative
			    (make-cons-closure-indirection value)))
			 (lambda (environment name)
			   environment
			   (error "close-binding: IC letrec name" name))
			 (lambda (name)
			   (error "close-binding: cached letrec name"
				  name)))))))))
	(else
	 (make-null-cfg))))

(define (letrec-close context variable value)
  (load-closure-environment
   value
   (find-variable/value/simple
    context variable
    "letrec-close: Missing closure variable")
   context))