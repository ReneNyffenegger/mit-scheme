#| -*-Scheme-*-

$Id: rules3.scm,v 1.6 1995/01/11 22:09:38 ssmith Exp $

Copyright (c) 1992-1993 Massachusetts Institute of Technology

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

;;;; LAP Generation Rules: Invocations and Entries
;;; package: (compiler lap-syntaxer)

(declare (usual-integrations))

;;;; Invocations

(define-integrable (clear-continuation-type-code)
  (LAP (AND W (@R ,regnum:stack-pointer) (R ,regnum:datum-mask))))

(define-rule statement
  (POP-RETURN)
  (cond ((block-association 'POP-RETURN)
	 => current-bblock-continue!)
	(else
	 (let ((bblock
		(make-new-sblock
		 (let ((interrupt-label (generate-label 'INTERRUPT)))
		   (LAP (CMP W (R ,regnum:free-pointer) ,reg:compiled-memtop)
			(JGE (@PCR ,interrupt-label))
			,@(clear-continuation-type-code)
			(RET)
			(LABEL ,interrupt-label)
			,@(invoke-hook
			   entry:compiler-interrupt-continuation-2))))))
	   (block-associate! 'POP-RETURN bblock)
	   (current-bblock-continue! bblock))))
  (clear-map!))

(define-rule statement
  (INVOCATION:APPLY (? frame-size) (? continuation))
  continuation
  (LAP ,@(clear-map!)
       (POP (R ,ecx))
       #|
       (MOV W (R ,edx) (& ,frame-size))
       ,@(invoke-interface code:compiler-apply)
       |#
       ,@(case frame-size
	   ((1) (invoke-hook entry:compiler-shortcircuit-apply-size-1))
	   ((2) (invoke-hook entry:compiler-shortcircuit-apply-size-2))
	   ((3) (invoke-hook entry:compiler-shortcircuit-apply-size-3))
	   ((4) (invoke-hook entry:compiler-shortcircuit-apply-size-4))
	   ((5) (invoke-hook entry:compiler-shortcircuit-apply-size-5))
	   ((6) (invoke-hook entry:compiler-shortcircuit-apply-size-6))
	   ((7) (invoke-hook entry:compiler-shortcircuit-apply-size-7))
	   ((8) (invoke-hook entry:compiler-shortcircuit-apply-size-8))
	   (else
	    (LAP (MOV W (R ,edx) (& ,frame-size))
		 ,@(invoke-hook entry:compiler-shortcircuit-apply))))))

(define-rule statement
  (INVOCATION:JUMP (? frame-size) (? continuation) (? label))
  frame-size continuation
  (LAP ,@(clear-map!)
       (JMP (@PCR ,label))))

(define-rule statement
  (INVOCATION:COMPUTED-JUMP (? frame-size) (? continuation))
  frame-size continuation
  ;; It expects the procedure at the top of the stack
  (LAP ,@(clear-map!)
       ,@(clear-continuation-type-code)
       (RET)))

(define-rule statement
  (INVOCATION:LEXPR (? number-pushed) (? continuation) (? label))
  continuation
  (with-pc
    (lambda (pc-label pc-register)
      (LAP ,@(clear-map!)
	   (LEA (R ,ecx) (@RO W ,pc-register (- ,label ,pc-label)))
	   (MOV W (R ,edx) (& ,number-pushed))
	   ,@(invoke-interface code:compiler-lexpr-apply)))))

(define-rule statement
  (INVOCATION:COMPUTED-LEXPR (? number-pushed) (? continuation))
  continuation
  ;; It expects the procedure at the top of the stack
  (LAP ,@(clear-map!)
       ,@(clear-continuation-type-code)
       (POP (R ,ecx))
       (MOV W (R ,edx) (& ,number-pushed))
       ,@(invoke-interface code:compiler-lexpr-apply)))

(define-rule statement
  (INVOCATION:UUO-LINK (? frame-size) (? continuation) (? name))
  continuation
  (LAP ,@(clear-map!)
       (JMP (@PCRO ,(free-uuo-link-label name frame-size) 3))))

(define-rule statement
  (INVOCATION:GLOBAL-LINK (? frame-size) (? continuation) (? name))
  continuation
  (LAP ,@(clear-map!)
       (JMP (@PCRO ,(global-uuo-link-label name frame-size) 3))))

(define-rule statement
  (INVOCATION:CACHE-REFERENCE (? frame-size) (? continuation) (? extension))
  (QUALIFIER (interpreter-call-argument? extension))
  continuation
  (let* ((set-extension
	  (interpreter-call-argument->machine-register! extension ecx))
	 (set-address
	  (begin (require-register! edx)
		 (load-pc-relative-address (INST-EA (R ,edx))
					   *block-label*))))
	  
    (delete-dead-registers!)
    (LAP ,@set-extension
	 ,@set-address
	 ,@(clear-map!)
	 (MOV W (R ,ebx) (& ,frame-size))
	 ,@(invoke-interface code:compiler-cache-reference-apply))))  

(define-rule statement
  (INVOCATION:LOOKUP (? frame-size) (? continuation) (? environment) (? name))
  (QUALIFIER (interpreter-call-argument? environment))
  continuation
  (let* ((set-environment
	  (interpreter-call-argument->machine-register! environment ecx))
	 (set-name (object->machine-register! name edx)))
    (delete-dead-registers!)
    (LAP ,@set-environment
	 ,@set-name
	 ,@(clear-map!)
	 (MOV W (R ,ebx) (& ,frame-size))
	 ,@(invoke-interface code:compiler-lookup-apply))))

(define-rule statement
  (INVOCATION:PRIMITIVE (? frame-size) (? continuation) (? primitive))
  continuation				; ignored
  (let-syntax ((invoke
		#|
		(macro (code entry)
		  entry			; ignored (for now)
		  `(invoke-interface ,code))
		|#
		(macro (code entry)
		  code			; ignored
		  `(invoke-hook ,entry))))

    (if (eq? primitive compiled-error-procedure)
	(LAP ,@(clear-map!)
	     (MOV W (R ,ecx) (& ,frame-size))
	     ,@(invoke code:compiler-error entry:compiler-error))
	(let ((arity (primitive-procedure-arity primitive)))
	  (cond ((not (negative? arity))
		 (with-values (lambda () (get-cached-label))
		   (lambda (pc-label pc-reg)
		     pc-reg		; ignored
		     (if pc-label
			 (let ((get-code
				(object->machine-register! primitive ecx)))
			   (LAP ,@get-code
				,@(clear-map!)
				,@(invoke code:compiler-primitive-apply
					  entry:compiler-primitive-apply)))
			 (let ((prim-label (constant->label primitive))
			       (offset-label (generate-label 'PRIMOFF)))
			   (LAP ,@(clear-map!)
				,@(invoke-hook/call
				   entry:compiler-short-primitive-apply)
				(LABEL ,offset-label)
				(LONG S (- ,prim-label ,offset-label))))))))
		((= arity -1)
		 (let ((get-code (object->machine-register! primitive ecx)))
		   (LAP ,@get-code
			,@(clear-map!)
			(MOV W ,reg:lexpr-primitive-arity
			     (& ,(-1+ frame-size)))
			,@(invoke code:compiler-primitive-lexpr-apply
				  entry:compiler-primitive-lexpr-apply))))
		(else
		 ;; Unknown primitive arity.  Go through apply.
		 (let ((get-code (object->machine-register! primitive ecx)))
		   (LAP ,@get-code
			,@(clear-map!)
			(MOV W (R ,edx) (& ,frame-size))
			,@(invoke-interface code:compiler-apply)))))))))

(let-syntax
    ((define-special-primitive-invocation
       (macro (name)
	 `(define-rule statement
	    (INVOCATION:SPECIAL-PRIMITIVE
	     (? frame-size)
	     (? continuation)
	     ,(make-primitive-procedure name true))
	    frame-size continuation
	    (special-primitive-invocation
	     ,(symbol-append 'CODE:COMPILER- name)))))

     (define-optimized-primitive-invocation
       (macro (name)
	 `(define-rule statement
	    (INVOCATION:SPECIAL-PRIMITIVE
	     (? frame-size)
	     (? continuation)
	     ,(make-primitive-procedure name true))
	    frame-size continuation
	    (optimized-primitive-invocation
	     ,(symbol-append 'ENTRY:COMPILER- name))))))

  (let-syntax ((define-primitive-invocation
		 (macro (name)
		   #|
		   `(define-special-primitive-invocation ,name)
		   |#
		   `(define-optimized-primitive-invocation ,name))))

    (define-primitive-invocation &+)
    (define-primitive-invocation &-)
    (define-primitive-invocation &*)
    (define-primitive-invocation &/)
    (define-primitive-invocation &=)
    (define-primitive-invocation &<)
    (define-primitive-invocation &>)
    (define-primitive-invocation 1+)
    (define-primitive-invocation -1+)
    (define-primitive-invocation zero?)
    (define-primitive-invocation positive?)
    (define-primitive-invocation negative?)
    (define-primitive-invocation quotient)
    (define-primitive-invocation remainder)))

(define (special-primitive-invocation code)
  (LAP ,@(clear-map!)
       ,@(invoke-interface code)))

(define (optimized-primitive-invocation entry)
  (LAP ,@(clear-map!)
       ,@(invoke-hook entry)))

;;; Invocation Prefixes

(define-rule statement
  (INVOCATION-PREFIX:MOVE-FRAME-UP 0 (REGISTER 4))
  (LAP))

(define-rule statement
  (INVOCATION-PREFIX:DYNAMIC-LINK 0 (REGISTER 4) (? any))
  any					; ignored
  (LAP))

(define-rule statement
  (INVOCATION-PREFIX:MOVE-FRAME-UP
   (? frame-size)
   (OFFSET-ADDRESS (REGISTER 4)
		   (MACHINE-CONSTANT (? offset))))
  (QUALIFIER (or (zero? (- offset frame-size)) (< frame-size 3)))
  (let ((how-far (- offset frame-size)))
    (cond ((zero? how-far)
	   (LAP))
	  ((zero? frame-size)
	   (LAP (ADD W (R 4) (& ,(* 4 how-far)))))
	  ((= frame-size 1)
	   (let ((temp (temporary-register-reference)))
	     (LAP (MOV W ,temp (@R 4))
		  (ADD W (R 4) (& ,(* 4 offset)))
		  (PUSH W ,temp))))
	  ((= frame-size 2)
	   (let ((temp1 (temporary-register-reference))
		 (temp2 (temporary-register-reference)))
	     (LAP (MOV W ,temp2 (@RO B 4 4))
		  (MOV W ,temp1 (@R 4))
		  (ADD W (R 4) (& ,(* 4 offset)))
		  (PUSH W ,temp2)
		  (PUSH W ,temp1))))
	  (else
	   (error "INVOCATION-PREFIX:MOVE-FRAME-UP: Incorrectly invoked!")))))

(define-rule statement
  (INVOCATION-PREFIX:MOVE-FRAME-UP (? frame-size) (REGISTER (? reg)))
  (generate/move-frame-up* frame-size
			   (move-to-temporary-register! reg 'GENERAL)
			   temporary-register-reference))

(define-rule statement
  (INVOCATION-PREFIX:DYNAMIC-LINK (? frame-size)
				  (REGISTER (? reg-1))
				  (REGISTER (? reg-2)))
  (QUALIFIER (not (= reg-1 4)))
  (let* ((label (generate-label 'DYN-CHOICE))
	 (temp1 (move-to-temporary-register! reg-1 'GENERAL))
	 (temp2 (standard-move-to-temporary! reg-2)))
    (LAP (CMP W (R ,temp1) ,temp2)
	 (JLE (@PCR ,label))
	 (MOV W (R ,temp1) ,temp2)
	 (LABEL ,label)
	 ,@(generate/move-frame-up* frame-size temp1 (lambda () temp2)))))

(define (generate/move-frame-up* frame-size reg get-temp)
  (if (zero? frame-size)
      (LAP (MOV W (R 4) (R ,reg)))
      (let ((temp (get-temp))
	    (ctr (allocate-temporary-register! 'GENERAL))
	    (label (generate-label 'MOVE-LOOP)))
	(LAP (LEA (R ,reg)
		  ,(byte-offset-reference reg (* -4 frame-size)))
	     (MOV W (R ,ctr) (& ,(-1+ frame-size)))
	     (LABEL ,label)
	     (MOV W ,temp (@RI 4 ,ctr 4))
	     (MOV W (@RI ,reg ,ctr 4) ,temp)
	     (DEC W (R ,ctr))
	     (JGE (@PCR ,label))
	     (MOV W (R 4) (R ,reg))))))

;;;; External Labels

;;; Entry point types

(define (make-procedure-code-word min max)
  ;; The "min" byte must be less than #x80; the "max" byte may not
  ;; equal #x80 but can take on any other value.
  (if (or (negative? min) (>= min #x80))
      (error "MAKE-PROCEDURE-CODE-WORD: minimum out of range" min))
  (if (>= (abs max) #x80)
      (error "MAKE-PROCEDURE-CODE-WORD: maximum out of range" max))
  (make-code-word min (if (negative? max) (+ #x100 max) max)))

(define internal-entry-code-word
  (make-code-word #xff #xfe))

(define internal-continuation-code-word
  (make-code-word #xff #xfc))

(define (frame-size->code-word offset default)
  (cond ((not offset)
	 default)
	((< offset #x2000)
	 ;; This uses up through (#xff #xdf).
	 (let ((qr (integer-divide offset #x80)))
	   (make-code-word (+ #x80 (integer-divide-remainder qr))
			   (+ #x80 (integer-divide-quotient qr)))))
	(else
	 (error "Unable to encode continuation offset"
		offset))))

(define (continuation-code-word label)
  (frame-size->code-word
   (if label
       (rtl-continuation/next-continuation-offset (label->object label))
       0)
   internal-continuation-code-word))

(define (internal-procedure-code-word rtl-proc)
  (frame-size->code-word
   (rtl-procedure/next-continuation-offset rtl-proc)
   internal-entry-code-word))

;;;; Procedure headers

;;; The following calls MUST appear as the first thing at the entry
;;; point of a procedure.  They assume that the register map is clear
;;; and that no register contains anything of value.
;;;
;;; The only reason that this is true is that no register is live
;;; across calls.  If that were not true, then we would have to save
;;; any such registers on the stack so that they would be GC'ed
;;; appropriately.
;;;
;;; The only exception is the dynamic link register, handled
;;; specially.  Procedures that require a dynamic link use a different
;;; interrupt handler that saves and restores the dynamic link
;;; register.

(define (interrupt-check procedure-label interrupt-label)
  ;; This always does interrupt checks in line.
  (LAP (CMP W (R ,regnum:free-pointer) ,reg:compiled-memtop)
       (JGE (@PCR ,interrupt-label))
       ,@(if (let ((object (label->object procedure-label)))
	       (and (rtl-procedure? object)
		    (not (rtl-procedure/stack-leaf? object))
		    compiler:generate-stack-checks?))
	     (LAP (CMP W (R ,regnum:stack-pointer) ,reg:stack-guard)
		  (JL (@PCR ,interrupt-label)))
	     (LAP))))

(define (simple-procedure-header code-word label entry)
  (let ((gc-label (generate-label)))    
    (LAP (LABEL ,gc-label)
	 ,@(invoke-hook/call entry)
	 ,@(make-external-label code-word label)
	 ,@(interrupt-check label gc-label))))

(define-rule statement
  (CONTINUATION-ENTRY (? internal-label))
  (make-external-label (continuation-code-word internal-label)
		       internal-label))

(define-rule statement
  (CONTINUATION-HEADER (? internal-label))
  #|
  (simple-procedure-header (continuation-code-word internal-label)
			   internal-label
			   entry:compiler-interrupt-continuation)
  |#
  (make-external-label (continuation-code-word internal-label)
		       internal-label))

(define-rule statement
  (IC-PROCEDURE-HEADER (? internal-label))
  (let ((procedure (label->object internal-label)))
    (let ((external-label (rtl-procedure/external-label procedure))
	  (gc-label (generate-label)))
      (LAP (ENTRY-POINT ,external-label)
	   (EQUATE ,external-label ,internal-label)
	   (LABEL ,gc-label)
	   ,@(invoke-interface/call code:compiler-interrupt-ic-procedure)
	   ,@(make-external-label expression-code-word internal-label)
	   ,@(interrupt-check internal-label gc-label)))))

(define-rule statement
  (OPEN-PROCEDURE-HEADER (? internal-label))
  (let ((rtl-proc (label->object internal-label)))
    (LAP (EQUATE ,(rtl-procedure/external-label rtl-proc) ,internal-label)
	 ,@(simple-procedure-header (internal-procedure-code-word rtl-proc)
				    internal-label
				    (if (rtl-procedure/dynamic-link? rtl-proc)
					entry:compiler-interrupt-dlink
					entry:compiler-interrupt-procedure)))))

(define-rule statement
  (PROCEDURE-HEADER (? internal-label) (? min) (? max))
  (LAP (EQUATE ,(rtl-procedure/external-label
		 (label->object internal-label))
	       ,internal-label)
       ,@(simple-procedure-header (make-procedure-code-word min max)
				  internal-label
				  entry:compiler-interrupt-procedure)))

;;;; Closures:			 

;; Since i386 instructions are pc-relative, the GC can't relocate them unless
;; there is a way to find where the closure was in old space before being
;; transported.  The first entry point (tagged as an object) is always
;; the last component of closures with any entry points.

(define (generate/cons-closure target procedure-label min max size)
  (let* ((mtarget (target-register target))
	 (target (register-reference mtarget))
	 (temp (temporary-register-reference)))
    (LAP ,@(load-pc-relative-address
	    temp
	    `(- ,(rtl-procedure/external-label (label->object procedure-label))
		5))
	 (MOV W (@R ,regnum:free-pointer)
	      (&U ,(make-non-pointer-literal (ucode-type manifest-closure)
					     (+ 4 size))))
	 (MOV W (@RO B ,regnum:free-pointer 4)
	      (&U ,(make-closure-code-longword min max 8)))
	 (LEA ,target (@RO B ,regnum:free-pointer 8))
	 ;; (CALL (@PCR <entry>))
	 (MOV B (@RO B ,regnum:free-pointer 8) (&U #xe8))
	 (SUB W ,temp ,target)
	 (MOV W (@RO B ,regnum:free-pointer 9) ,temp) ; displacement
	 (ADD W (R ,regnum:free-pointer) (& ,(* 4 (+ 5 size))))
	 (LEA ,temp (@RO UW
			 ,mtarget
			 ,(make-non-pointer-literal (ucode-type compiled-entry)
						    0)))
	 (MOV W (@RO B ,regnum:free-pointer -4) ,temp))))

(define (generate/cons-multiclosure target nentries size entries)
  (let* ((mtarget (target-register target))
	 (target (register-reference mtarget))
	 (temp (temporary-register-reference)))
    (with-pc
      (lambda (pc-label pc-reg)
	(define (generate-entries entries offset)
	  (let ((entry (car entries))
		(rest (cdr entries)))
	    (LAP (MOV W (@RO B ,regnum:free-pointer -9)
		      (&U ,(make-closure-code-longword (cadr entry)
						       (caddr entry)
						       offset)))
		 (MOV B (@RO B ,regnum:free-pointer -5) (&U #xe8))
		 (LEA ,temp (@RO W
				 ,pc-reg
				 (- ,(rtl-procedure/external-label
				      (label->object (car entry)))
				    ,pc-label)))
		 (SUB W ,temp (R ,regnum:free-pointer))
		 (MOV W (@RO B ,regnum:free-pointer -4) ,temp)
		 ,@(if (null? rest)
		       (LAP)
		       (LAP (ADD W (R ,regnum:free-pointer) (& 10))
			    ,@(generate-entries rest (+ 10 offset)))))))

	(LAP (MOV W (@R ,regnum:free-pointer)
		  (&U ,(make-non-pointer-literal
			(ucode-type manifest-closure)
			(+ size (quotient (* 5 (1+ nentries)) 2)))))
	     (MOV W (@RO B ,regnum:free-pointer 4)
		  (&U ,(make-closure-longword nentries 0)))
	     (LEA ,target (@RO B ,regnum:free-pointer 12))
	     (ADD W (R ,regnum:free-pointer) (& 17))
	     ,@(generate-entries entries 12)
	     (ADD W (R ,regnum:free-pointer)
		  (& ,(+ (* 4 size) (if (odd? nentries) 7 5))))
	     (LEA ,temp
		  (@RO UW
		       ,mtarget
		       ,(make-non-pointer-literal (ucode-type compiled-entry)
						  0)))
	     (MOV W (@RO B ,regnum:free-pointer -4) ,temp))))))

(define closure-share-names
  '#(
     closure-0-interrupt closure-1-interrupt closure-2-interrupt closure-3-interrupt
     closure-4-interrupt closure-5-interrupt closure-6-interrupt closure-7-interrupt
     ))

(define (generate/closure-header internal-label nentries entry)
  nentries				; ignored
  (let* ((rtl-proc (label->object internal-label))
	 (external-label (rtl-procedure/external-label rtl-proc)))
    (if (zero? nentries)
	(LAP (EQUATE ,external-label ,internal-label)
	     ,@(simple-procedure-header
		(internal-procedure-code-word rtl-proc)
		internal-label
		entry:compiler-interrupt-procedure))
	(let ((prefix
	       (lambda (gc-label)
		 (LAP (LABEL ,gc-label)
		      ,@(if (zero? entry)
			    (LAP)
			    (LAP (ADD W (@R ,esp) (& ,(* 10 entry)))))
		      ,@(invoke-hook entry:compiler-interrupt-closure))))
	      (suffix
	       (lambda (gc-label)
		 (LAP ,@(make-external-label internal-entry-code-word
					     external-label)
		      (ADD W (@R ,esp)
			   (&U ,(generate/make-magic-closure-constant entry)))
		      (LABEL ,internal-label)
		      ,@(interrupt-check internal-label gc-label)))))
	  (if (>= entry (vector-length closure-share-names))
	      (let ((gc-label (generate-label)))
		(LAP ,@(prefix gc-label)
		     ,@(suffix gc-label)))
	      (share-instruction-sequence!
	       (vector-ref closure-share-names entry)
	       suffix
	       (lambda (gc-label)
		 (LAP ,@(prefix gc-label)
		      ,@(suffix gc-label)))))))))

(define (generate/make-magic-closure-constant entry)
  (- (make-non-pointer-literal (ucode-type compiled-entry) 0)
     (+ (* entry 10) 5)))

(define (make-closure-longword code-word pc-offset)
  (+ code-word (* #x20000 pc-offset)))

(define (make-closure-code-longword frame/min frame/max pc-offset)
  (make-closure-longword (make-procedure-code-word frame/min frame/max)
			 pc-offset))

(define-rule statement
  (CLOSURE-HEADER (? internal-label) (? nentries) (? entry))
  (generate/closure-header internal-label nentries entry))

(define-rule statement
  (ASSIGN (REGISTER (? target))
	  (CONS-CLOSURE (ENTRY:PROCEDURE (? procedure-label))
			(? min) (? max) (? size)))
  (generate/cons-closure target procedure-label min max size))

(define-rule statement
  (ASSIGN (REGISTER (? target))
	  (CONS-MULTICLOSURE (? nentries) (? size) (? entries)))
  (case nentries
    ((0)
     (let ((target (target-register-reference target)))
       (LAP (MOV W ,target (R ,regnum:free-pointer))
	    (MOV W (@R ,regnum:free-pointer)
		 (&U ,(make-non-pointer-literal (ucode-type manifest-vector)
						size)))
	    (ADD W (R ,regnum:free-pointer) (& ,(* 4 (1+ size)))))))
    ((1)
     (let ((entry (vector-ref entries 0)))
       (generate/cons-closure target
			      (car entry) (cadr entry) (caddr entry)
			      size)))
    (else
     (generate/cons-multiclosure target nentries size
				 (vector->list entries)))))

;;;; Entry Header
;;; This is invoked by the top level of the LAP generator.

(define (generate/quotation-header environment-label free-ref-label n-sections)
  (pc->reg eax
	   (lambda (pc-label prefix)
	     (LAP ,@prefix
		  (MOV W (R ,ecx) ,reg:environment)
		  (MOV W (@RO W ,eax (- ,environment-label ,pc-label))
		       (R ,ecx))
		  (LEA (R ,edx) (@RO W ,eax (- ,*block-label* ,pc-label)))
		  (LEA (R ,ebx) (@RO W ,eax (- ,free-ref-label ,pc-label)))
		  (MOV W ,reg:utility-arg-4 (& ,n-sections))
		  #|
		  ,@(invoke-interface/call code:compiler-link)
		  |#
		  ,@(invoke-hook/call entry:compiler-link)
		  ,@(make-external-label (continuation-code-word false)
					 (generate-label))))))

(define (generate/remote-link code-block-label
			      environment-offset
			      free-ref-offset
			      n-sections)
  (pc->reg eax
	   (lambda (pc-label prefix)
	     (LAP ,@prefix
		  (MOV W (R ,edx) (@RO W ,eax (- ,code-block-label ,pc-label)))
		  (AND W (R ,edx) (R ,regnum:datum-mask))
		  (LEA (R ,ebx) (@RO W ,edx ,free-ref-offset))
		  (MOV W (R ,ecx) ,reg:environment)
		  (MOV W (@RO W ,edx ,environment-offset) (R ,ecx))
		  (MOV W ,reg:utility-arg-4 (& ,n-sections))
		  #|
		  ,@(invoke-interface/call code:compiler-link)
		  |#
		  ,@(invoke-hook/call entry:compiler-link)
		  ,@(make-external-label (continuation-code-word false)
					 (generate-label))))))

(define (generate/remote-links n-blocks vector-label nsects)
  (if (zero? n-blocks)
      (LAP)
      (let ((loop (generate-label))
	    (bytes  (generate-label))
	    (end (generate-label)))
	(LAP
	 ;; Push counter
	 (PUSH W (& 0))
	 (LABEL ,loop)
	 ,@(pc->reg
	    eax
	    (lambda (pc-label prefix)
	      (LAP ,@prefix
		   ;; Get index
		   (MOV W (R ,ecx) (@R ,esp))
		   ;; Get vector
		   (MOV W (R ,edx) (@RO W ,eax (- ,vector-label ,pc-label)))
		   ;; Get n-sections for this cc-block
		   (XOR W (R ,ebx) (R ,ebx))
		   (MOV B (R ,ebx) (@ROI B ,eax (- ,bytes ,pc-label) ,ecx 1))
		   ;; address of vector
		   (AND W (R ,edx) (R ,regnum:datum-mask))
		   ;; Store n-sections in arg
		   (MOV W ,reg:utility-arg-4 (R ,ebx))
		   ;; vector-ref -> cc block
		   (MOV W (R ,edx) (@ROI B ,edx 4 ,ecx 4))
		   ;; address of cc-block
		   (AND W (R ,edx) (R ,regnum:datum-mask))
		   ;; cc-block length
		   (MOV W (R ,ebx) (@R ,edx))
		   ;; Get environment
		   (MOV W (R ,ecx) ,reg:environment)
		   ;; Eliminate length tags
		   (AND W (R ,ebx) (R ,regnum:datum-mask))
		   ;; Store environment
		   (MOV W (@RI ,edx ,ebx 4) (R ,ecx))
		   ;; Get NMV header
		   (MOV W (R ,ecx) (@RO B ,edx 4))
		   ;; Eliminate NMV tag
		   (AND W (R ,ecx) (R ,regnum:datum-mask))
		   ;; Address of first free reference
		   (LEA (R ,ebx) (@ROI B ,edx 8 ,ecx 4))
		   ;; Invoke linker
		   ,@(invoke-hook/call entry:compiler-link)
		   ,@(make-external-label (continuation-code-word false)
					 (generate-label))		   
		   ;; Increment counter and loop
		   (INC W (@R ,esp))
		   (CMP W (@R ,esp) (& ,n-blocks))
		   (JL (@PCR ,loop))
		   )))
	 (JMP (@PCR ,end))
	 (LABEL ,bytes)
	 ,@(let walk ((bytes (vector->list nsects)))
	     (if (null? bytes)
		 (LAP)
		 (LAP (BYTE U ,(car bytes))
		      ,@(walk (cdr bytes)))))
	 (LABEL ,end)
	 ;; Pop counter
	 (POP (R ,eax))))))

(define (generate/constants-block constants references assignments
				  uuo-links global-links static-vars)
  (let ((constant-info
	 (declare-constants 0 (transmogrifly uuo-links)
	   (declare-constants 1 references
	     (declare-constants 2 assignments
	       (declare-constants 3 (transmogrifly global-links)
		 (declare-constants false
		     (map (lambda (pair)
			    (cons false (cdr pair)))
			  static-vars)
		   (declare-constants false constants
		     (cons false (LAP))))))))))
    (let ((free-ref-label (car constant-info))
	  (constants-code (cdr constant-info))
	  (debugging-information-label (allocate-constant-label))
	  (environment-label (allocate-constant-label))
	  (n-sections
	   (+ (if (null? uuo-links) 0 1)
	      (if (null? references) 0 1)
	      (if (null? assignments) 0 1)
	      (if (null? global-links) 0 1))))
      (values
       (LAP ,@constants-code
	    ;; Place holder for the debugging info filename
	    (SCHEME-OBJECT ,debugging-information-label DEBUGGING-INFO)
	    ;; Place holder for the load time environment if needed
	    (SCHEME-OBJECT ,environment-label
			   ,(if (null? free-ref-label) 0 'ENVIRONMENT)))
       environment-label
       free-ref-label
       n-sections))))

(define (declare-constants tag constants info)
  (define (inner constants)
    (if (null? constants)
	(cdr info)
	(let ((entry (car constants)))
	  (LAP (SCHEME-OBJECT ,(cdr entry) ,(car entry))
	       ,@(inner (cdr constants))))))
  (if (and tag (not (null? constants)))
      (let ((label (allocate-constant-label)))
	(cons label
	      (inner
	       `((,(let ((datum (length constants)))
		     (if (> datum #xffff)
			 (error "datum too large" datum))
		     (+ (* tag #x10000) datum))
		  . ,label)
		 ,@constants))))
      (cons (car info) (inner constants))))

;; IMPORTANT:
;; frame-size and uuo-label are switched (with respect to the 68k
;; version) in order to preserve the arity in a constant position (the
;; i386 is little-endian).  The invocation rule for uuo-links has been
;; changed to take the extra 2 bytes into account.
;;
;; Like closures, execute caches use pc-relative JMP instructions,
;; which can only be relocated if the old address is available.
;; Thus execute-cache blocks are extended by a single word that
;; contains its own address.

(define (transmogrifly uuos)
  (define (do-rest uuos)
    (define (inner name assoc)
      (if (null? assoc)
	  (do-rest (cdr uuos))
	  (cons (cons (caar assoc)			; frame-size
		      (cdar assoc))			; uuo-label
		(cons (cons name			; variable name
			    (allocate-constant-label))	; dummy label
		      (inner name (cdr assoc))))))

    (if (null? uuos)
	'()
	(inner (caar uuos) (cdar uuos))))

  (if (null? uuos)
      '()
      (cons (cons false (allocate-constant-label)) 	; relocation address
	    (do-rest uuos))))


;; The following rules were created specifically for the new version
;; and therefore are required (unlike the rules above, which may or may not
;; be obsolete in the new version 8.0)

;; Copied from the Spectrum's rules3.scm
;; NOTE that make-external-label is in i386/lapgen, but in spectrum/rules3
;;   also, there are some differences ** potential bug
;; 
(define-rule statement
  (TRIVIAL-CLOSURE (? label)
		   (? dbg-info)
		   (MACHINE-CONSTANT (? min))
		   (MACHINE-CONSTANT (? max)))
  dbg-info				; ignored
  (make-external-label (make-procedure-code-word min max)
		       label))

(define-rule statement
  (CLOSURE (? label) (? dbg-info) (MACHINE-CONSTANT (? frame-size)))
  dbg-info frame-size			; ignored
  (LAP ,@(make-external-label internal-closure-code-word label)))

(define-rule statement
  (EXPRESSION (? label) (? dbg-info))
  #|
  ;; Prefix takes care of this
  (LAP ,@(make-external-label expression-code-word label))
  |#
  label dbg-info			; ignored
  (LAP))

(define-rule statement
  (INTERRUPT-CHECK:PROCEDURE (? intrpt) (? heap) (? stack) (? label)
			     (MACHINE-CONSTANT (? frame-size)))
  (generate-interrupt-check/new
   intrpt heap stack
   (lambda (interrupt-label)
     (let ((ret-add-label (generate-label)))
       (LAP (LABEL ,interrupt-label)
	    (MOV B (R ,regnum:hook) (& ,(- frame-size 1)))
	    ,@(invoke-hook hook:compiler-interrupt-procedure/new)
	    (LABEL ,ret-add-label)
	    (WORD () (- (- ,label ,ret-add-label) ,*privilege-level*)))))))

(define-rule statement
  (INTERRUPT-CHECK:CONTINUATION (? intrpt) (? heap) (? stack) (? label)
				(MACHINE-CONSTANT (? frame-size)))
  ;; Generated both for continuations and in some weird case of
  ;; top-level expressions.
  (generate-interrupt-check/new
   intrpt heap
   (and (= frame-size 1) stack)		; expressions only
   (lambda (interrupt-label)
     (let ((ret-add-label (generate-label)))
       (LAP (LABEL ,interrupt-label)
	    (MOV B (R ,regnum:hook) (& ,(- frame-size 1)))
	    #| (LDI ()
		    ,(if (= nregs 0)	; **** probably wrong
			 code:compiler-interrupt-procedure
			 code:compiler-interrupt-continuation)
		    28) |#
	    ,@(invoke-hook hook:compiler-interrupt-continuation/new)
	    (LABEL ,ret-add-label)
	    (WORD () (- (- ,label ,ret-add-label) ,*privilege-level*)))))))

(define-rule statement
  (INTERRUPT-CHECK:CLOSURE (? intrpt) (? heap) (? stack)
			   (MACHINE-CONSTANT (? frame-size)))
  (generate-interrupt-check/new
   intrpt heap stack
   (lambda (interrupt-label)
     (LAP (LABEL ,interrupt-label)
	  (MOV B (R ,regnum:hook) (& ,(- frame-size 2))) ; Continuation and self
	  ; register are saved by other
	  ; means.
	  ,@(invoke-hook hook:compiler-interrupt-closure/new)))))

(define-rule statement
  (INTERRUPT-CHECK:SIMPLE-LOOP (? intrpt) (? heap) (? stack)
			       (? loop-label) (? header-label)
			       (MACHINE-CONSTANT (? frame-size)))
  ;; Nothing generates this now -- JSM
  loop-label				; ignored
  (generate-interrupt-check/new
   intrpt heap stack
   (lambda (interrupt-label)
     (let ((ret-add-label (generate-label)))
       (LAP (LABEL ,interrupt-label)
	    (MOV B (R regnum:hook) (& ,(- frame-size 1)))
	    ,@(invoke-hook hook:compiler-interrupt-procedure/new)
	    (LABEL ,ret-add-label)
	    (WORD () (- (- ,header-label ,ret-add-label)
			,*privilege-level*)))))))


;; Copied and modified from Spectrum's
(define (generate-interrupt-check/new intrpt heap stack generate-stub)
  ;; This does not check the heap because it is assumed that there is
  ;; a large buffer at the end of the heap.  As long as the code can't
  ;; loop without checking, which is what intrpt guarantees, there
  ;; is no need to check.

  (if (and (number? heap)
	   (> heap 1000))
      (internal-warning "Large allocation " heap 'words))
  (let* ((interrupt-label (generate-label))
	 (heap-check? intrpt)
	 (stack-check? (and stack compiler:generate-stack-checks?))
	 (need-interrupt-code (lambda ()
				(add-end-of-block-code!
				 (lambda ()
				   (generate-stub interrupt-label))))))
    (cond ((and heap-check? stack-check?)
	   (need-interrupt-code)
	   (profile-info/add 'HEAP-CHECK)
	   (profile-info/add 'STACK-CHECK)
	   (LAP (CMP W (R ,regnum:free-pointer) (@RO B ,regnum:regs-pointer ,register-block/memtop-offset))
		;; The following should be JAE, but on certain occasions
		;; memtop is set to -1 to force an abort, which wouldn't
		;; fare too well here.  This restricts memory to the lower
		;; 2 Gigabytes.  Oh darn.  Of course, it could cause problems
		;; in operating systems that don't let us map memory where we
		;; want it.
		(JGE (@PCR ,interrupt-label))
		(CMP W (R ,regnum:stack-pointer) (@RO B ,regnum:regs-pointer ,register-block/stack-guard-offset))
		;; Same may apply here
		(JL (@PCR ,interrupt-label))))
	  ;; NOTE: Spectrum loads memtop into a register at this point...
	  (heap-check?
	   (need-interrupt-code)
	   (profile-info/add 'HEAP-CHECK)
	   (LAP (CMP W (R ,regnum:free-pointer) (@RO B ,regnum:regs-pointer ,register-block/memtop-offset))
		;; NOTE: See above
		(JGE (@PCR ,interrupt-label))))
	  (stack-check?
	   (need-interrupt-code)
	   (profile-info/add 'STACK-CHECK)
	   (LAP (CMP W (R ,regnum:stack-pointer) (@RO B ,regnum:regs-pointer ,register-block/stack-guard-offset))
		(JL (@PCR ,interrupt-label))))
	  (else
	   (LAP)))))


;; Invocation rules

;; Jumps to the location stored in the register
(define-rule statement
  (INVOCATION:REGISTER 0 #F (REGISTER (? reg))
		       #F (MACHINE-CONSTANT (? nregs)))
  nregs					; ignored
  (profile-info/add 'INVOCATION:REGISTER)
  (let ((addr (standard-source! reg)))
    (LAP ,@(clear-map!)
	 (JMP (@R ,addr)))))

;; NOTE for this procedure, we may need to alter the return address
;; that's pushed onto the stack...  I'm not sure what the best way to
;; do that is.  Potential bug.
(define-rule statement
  (INVOCATION:PROCEDURE 0 (? continuation) (? destination)
			(MACHINE-CONSTANT (? nregs)))
  nregs					; ignored
  (profile-info/add 'INVOCATION:PROCEDURE)
  (LAP ,@(clear-map!)
       ,@(if (not continuation)
	     (LAP (JMP (@PCR ,destination)))
	     (LAP (CALL (@PCR ,destination))))))

(define-rule statement
  (INVOCATION:NEW-APPLY (? frame-size) (? continuation)
			(REGISTER (? dest)) (MACHINE-CONSTANT (? nregs)))
  ;; *** For now, ignore nregs and use frame-size ***
  nregs
  (profile-info/add 'INVOCATION:NEW-APPLY)
  (let* ((obj (register-alias dest (register-type dest)))
	 (prefix (if obj
		     (LAP)
		     (%load-machine-register! dest regnum:first-arg
					      delete-dead-registers!)))
	 (obj* (or obj regnum:first-arg)))
    (need-register! obj*)
    (if continuation
	(need-register! 19))
    (let ((addr (if untagged-entries? obj* (standard-temporary!)))
	  (temp (standard-temporary!))
	  (label (generate-label))
	  (load-continuation
	   (if continuation
	       (load-pc-relative-address continuation 19 'CODE)
	       '())))
      (LAP ,@prefix
	   ,@(clear-map!)
	   ,@load-continuation
	   ,@(object->type obj* temp)
	   ,@(let ((tag (ucode-type compiled-entry)))
	       (LAP (CMP W ,temp (& ,tag))
		    (JNE (@PCR ,label))))
	   ,@(if untagged-entries?
		 (LAP)
		 (LAP (MOV W (R ,addr) (R ,obj*))
		      ,@(adjust-type (ucode-type compiled-entry)
				     quad-mask-value
				     addr)))
	   (CMP B (@RO B ,addr -3) 0)
	   ;; This is ugly - oh well
	   (JNE (@PCR ,label))
	   (JMP (@R ,addr))
	   (LABEL ,label)
	   ,@(copy obj* regnum:first-arg)
	   ,@(%invocation:apply frame-size)))))


;;; Local Variables: ***
;;; eval: (put 'declare-constants 'scheme-indent-hook 2) ***
;;; End: ***


