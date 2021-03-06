#| -*-Scheme-*-

Copyright (c) 1988-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; Assembler and Linker top level
;;; package: (compiler top-level)

(declare (usual-integrations))

;;;; Exports to the compiler

(define compiled-output-extension "com")

(define (compiler-file-output object pathname)
  (fasdump object pathname))

(define (compiler-output->procedure scode environment)
  (scode-eval (if (compiled-module? scode)
		  (compiled-module/expression scode)
		  scode)
	      environment))

(define (compiler-output->compiled-expression cexp)
  cexp)

(define (compile-scode/internal/hook action)
  (action))

;;; Global variables for the assembler and linker

(define *recursive-compilation-results*)

;; First set: phase/rtl-generation
;; Last used: phase/link
(define *block-label*)

;; First set: phase/lap-generation
;; Last used: phase/info-generation-2
(define *external-labels*)

;; First set: phase/assemble
;; Last used: phase/link
(define *label-bindings*)
(define *code-vector*)
(define *entry-points*)

;; First set: phase/link
;; Last used: result of compilation
(define *result*)

(define (assemble&link info-output-pathname)
  (phase/assemble)
  (if compiler:cross-compiling?
      (begin
	(if info-output-pathname
	    (cross-compiler-phase/info-generation-2 info-output-pathname))
	(cross-compiler-phase/link))
      (begin
	(if info-output-pathname
	    (phase/info-generation-2 info-output-pathname))
	(phase/link)))
  *result*)

(define (wrap-lap entry-label some-lap)
  (LAP ,@(if *procedure-result?*
	     (LAP (ENTRY-POINT ,entry-label))
	     (lap:make-entry-point entry-label *block-label*))
       ,@some-lap))

(define (bind-assembler&linker-top-level-variables thunk)
  (fluid-let ((*recursive-compilation-results* '()))
    (thunk)))

(define (bind-assembler&linker-variables thunk)
  (fluid-let ((*block-associations*)
	      (*block-label*)
	      (*external-labels*)
	      (*end-of-block-code*)
	      (*next-constant*)
	      (*interned-assignments*)
	      (*interned-constants*)
	      (*interned-global-links*)
	      (*interned-static-variables*)
	      (*interned-uuo-links*)
	      (*interned-variables*)
	      (*block-profiles*)
	      (*label-bindings*)
	      (*code-vector*)
	      (*entry-points*)
	      (*result*))
    (thunk)))

(define (assembler&linker-reset!)
  (set! *recursive-compilation-results* '())
  (set! *block-associations*)
  (set! *block-label*)
  (set! *external-labels*)
  (set! *end-of-block-code*)
  (set! *next-constant*)
  (set! *interned-assignments*)
  (set! *interned-constants*)
  (set! *interned-global-links*)
  (set! *interned-static-variables*)
  (set! *interned-uuo-links*)
  (set! *interned-variables*)
  (set! *block-profiles*)
  (set! *label-bindings*)
  (set! *code-vector*)
  (set! *entry-points*)
  (set! *result*)
  unspecific)

(define (initialize-back-end!)
  (set! *block-associations* '())
  (set! *block-label* (generate-label))
  (set! *external-labels* '())
  (set! *end-of-block-code* '())
  (set! *next-constant* 0)
  (set! *interned-assignments* '())
  (set! *interned-constants* '())
  (set! *interned-global-links* '())
  (set! *interned-static-variables* '())
  (set! *interned-uuo-links* '())
  (set! *interned-variables* '())
  (set! *block-profiles* '())
  unspecific)

;;;; Assembler and linker

(define (phase/assemble)
  (compiler-phase
   "Assembly"
   (lambda ()
     (with-values (lambda () (assemble *block-label* (last-reference *lap*)))
       (lambda (count code-vector labels bindings)
	 (set! *code-vector* code-vector)
	 (set! *entry-points* labels)
	 (set! *label-bindings* bindings)
	 (if compiler:show-phases?
	     (begin
	       (newline)
	       (write-string *output-prefix*)
	       (write-string "  Branch tensioning done in ")
	       (write (1+ count))
	       (write-string
		(if (zero? count) " iteration." " iterations.")))))))))

(define (phase/link)
  (compiler-phase
   "Linkification"
   (lambda ()
     ;; This has sections locked against GC to prevent relocation
     ;; while computing addresses.
     (let* ((label->offset
	     (lambda (label)
	       (cdr (or (assq label *label-bindings*)
			(error "Missing entry point" label)))))
	    (bindings
	     (map (lambda (label)
		    (cons
		     label
		     (with-absolutely-no-interrupts
		       (lambda ()
			 ((ucode-primitive primitive-object-set-type)
			  type-code:compiled-entry
			  (make-non-pointer-object
			   (+ (label->offset label)
			      (object-datum *code-vector*))))))))
		  *entry-points*))
	    (label->address
	     (lambda (label)
	       (cdr (or (assq label bindings)
			(error "Label not defined as entry point"
			       label))))))
       (set! *result*
	     (if *procedure-result?*
		 (let ((linking-info *subprocedure-linking-info*))
		   (let ((compiled-procedure (label->address *entry-label*))
			 (translate-label
			  (let ((block-offset (label->offset *block-label*)))
			    (lambda (index)
			      (let ((label (vector-ref linking-info index)))
				(and label
				     (- (label->offset label)
					block-offset)))))))
		     (cons compiled-procedure
			   (vector
			    (compiled-code-address->block compiled-procedure)
			    (translate-label 0)
			    (translate-label 1)
			    (vector-ref linking-info 2)))))
		 (label->address *entry-label*)))
       (for-each (lambda (entry)
		   (set-lambda-body! (car entry)
				     (label->address (cdr entry))))
		 *ic-procedure-headers*))
     ((ucode-primitive declare-compiled-code-block 1) *code-vector*)
     (if (not compiler:preserve-data-structures?)
	 (begin
	   (set! *code-vector*)
	   (set! *entry-points*)
	   (set! *subprocedure-linking-info*)
	   (set! *label-bindings*)
	   (set! *block-label*)
	   (set! *entry-label*)
	   (set! *ic-procedure-headers*)
	   unspecific)))))

;;;; Dumping the assembler's symbol table to the debugging file...

(define (phase/info-generation-2 pathname)
  (info-generation-2 pathname
		     set-compiled-code-block/debugging-info!
		     (compiled-code-block/constant-offset-map *code-vector*)))

(define (info-generation-2 pathname set-debugging-info! constant-offset-map)
  (compiler-phase "Debugging Information Generation"
    (lambda ()
      (set-debugging-info!
       *code-vector*
       (if  *use-debugging-info?*
	    (let ((info
		   (info-generation-phase-3
		    (last-reference *dbg-expression*)
		    (last-reference *dbg-procedures*)
		    (last-reference *dbg-continuations*)
		    *label-bindings*
		    (last-reference *external-labels*)
		    constant-offset-map)))
	      (cond ((eq? pathname 'KEEP) ; for dynamic execution
		     info)
		    ((eq? pathname 'RECURSIVE) ; recursive compilation
		     (set! *recursive-compilation-results*
			   (cons (vector *recursive-compilation-number*
					 info
					 *code-vector*)
				 *recursive-compilation-results*))
		     (cons *info-output-filename*
			   *recursive-compilation-number*))
		    (else
		     (compiler:dump-info-file
		      (let ((all-blocks
			     (list->vector
			      (cons info
				    (map (lambda (other) (vector-ref other 1))
					 (recursive-compilation-results))))))
			all-blocks)
		      pathname)
		     *info-output-filename*)))
	    *input-filename-for-temporary-info-info*)))))

(define (recursive-compilation-results)
  (sort *recursive-compilation-results*
	(lambda (x y)
	  (< (vector-ref x 0)
	     (vector-ref y 0)))))

(define (compiled-code-block/constant-offset-map block)
  (let ((start  (compiled-code-block/constants-start block))
	(end    (compiled-code-block/constants-end block))
	(table  (make-eq-hash-table)))
    (let loop ((i start))
      (if (< i end)
	  (begin
	    (hash-table/put! table (system-vector-ref block i) i)
	    (loop (+ i 1)))))
    (lambda (constant)
      (hash-table/get table constant #F))))

;;; Various ways of dumping an info file

(define (fasdump-dbg-object object locator file-type compress?)
  (let ((wrapped-object
	 (make-dbg-wrapper object (dbg-locator/timestamp locator)))
	(pathname
	 (pathname-new-type (dbg-locator/file locator) file-type)))
    (if compress?
	(call-with-temporary-filename
	 (lambda (temporary-file)
	   (fasdump wrapped-object temporary-file true)
	   (compress temporary-file pathname)))
	(fasdump wrapped-object pathname true))
    (if compiler:noisy?
	(let ((port (nearest-cmdl/port)))
	  (fresh-line port)
	  (write-string ";")
	  (write (->namestring pathname))
	  (write-string " dumped ")))
    unspecific))
  
(define (compiler:dump-inf-file binf locator)
  (fasdump-dbg-object binf locator "inf" #F))

(define (compiler:dump-bif/bsm-files binf locator)
  (let ((bsm (split-inf-structure! binf 'DUMPED-SEPARATELY)))
    (fasdump-dbg-object binf locator "bif" #F)
    (fasdump-dbg-object bsm  locator "bsm" #F)))
  
(define (compiler:dump-bci/bcs-files binf locator)
  (let ((bsm (split-inf-structure! binf 'DUMPED-SEPARATELY)))
    (fasdump-dbg-object binf locator "bci" 'COMPRESS)
    (fasdump-dbg-object bsm  locator "bcs" 'COMPRESS)))
  
(define (compiler:dump-bci-file binf locator)
  (split-inf-structure! binf false)
  (fasdump-dbg-object binf locator "bci" 'COMPRESS))

(define compiler:dump-info-file
  compiler:dump-bci-file)

;;;; LAP->CODE
;;; Example of `lap->code' usage (MC68020):

#|
(define bar
  ;; defines bar to be a procedure that adds 1 to its argument
  ;; with no type or range checks.
  (scode-eval
   (lap->code
    'start
    `((entry-point start)
      (dc uw #xffff)
      (block-offset start)
      (label start)
      (pea (@pcr proc))
      (or b (& ,(* (microcode-type 'compiled-entry) 4)) (@a 7))
      (mov l (@a+ 7) (@ao 6 8))
      (and b (& #x3) (@a 7))
      (rts)
      (dc uw #x0202)
      (block-offset proc)
      (label proc)
      (mov l (@a+ 7) (d 0))
      (addq l (& 1) (d 0))
      (mov l (d 0) (@ao 6 8))
      (and b (& #x3) (@a 7))
      (rts)))
   '()))
|#

(define (lap->code label instructions)
  (in-compiler
   (lambda ()
     (set! *lap* instructions)
     (set! *entry-label* label)
     (set! *current-label-number* 0)
     (set! *next-constant* 0)
     (set! *interned-assignments* '())
     (set! *interned-constants* '())
     (set! *interned-global-links* '())
     (set! *interned-static-variables* '())
     (set! *interned-uuo-links* '())
     (set! *interned-variables* '())
     (set! *block-label* (generate-label))
     (set! *external-labels* '())
     (set! *ic-procedure-headers* '())
     (phase/assemble)
     (phase/link)
     *result*)))

(define (canonicalize-label-name name)
  ;; The Scheme assembler allows any Scheme symbol as a label
  name)