#| -*-Scheme-*-

$Id: syntax.scm,v 14.24 1994/02/22 21:14:00 cph Exp $

Copyright (c) 1988-1994 Massachusetts Institute of Technology

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

;;;; SYNTAX: S-Expressions -> SCODE
;;; package: (runtime syntaxer)

(declare (usual-integrations))

(define (initialize-package!)
  (set-fluid-let-type! 'SHALLOW)
  (enable-scan-defines!)
  (set! system-global-syntax-table (make-system-global-syntax-table))
  (set! user-initial-syntax-table
	(make-syntax-table system-global-syntax-table))
  (set! hook/syntax-expression default/syntax-expression)
  unspecific)

(define system-global-syntax-table)
(define user-initial-syntax-table)
(define *syntax-table*)
(define *current-keyword* #f)
(define *syntax-top-level?*)

(define (make-system-global-syntax-table)
  (let ((table (make-syntax-table)))
    (for-each (lambda (entry)
		(syntax-table-define table (car entry)
		  (make-primitive-syntaxer (cadr entry))))
	      `(
		;; R*RS special forms
		(BEGIN ,syntax/begin)
		(COND ,syntax/cond)
		(DEFINE ,syntax/define)
		(DELAY ,syntax/delay)
		(IF ,syntax/if)
		(LAMBDA ,syntax/lambda)
		(LET ,syntax/let)
		(OR ,syntax/or)
		(QUOTE ,syntax/quote)
		(SET! ,syntax/set!)

		;; Syntax extensions
		(DEFINE-SYNTAX ,syntax/define-syntax)
		(DEFINE-MACRO ,syntax/define-macro)
		(LET-SYNTAX ,syntax/let-syntax)
		(MACRO ,syntax/lambda)
		(USING-SYNTAX ,syntax/using-syntax)

		;; Environment extensions
		(ACCESS ,syntax/access)
		(IN-PACKAGE ,syntax/in-package)
		(THE-ENVIRONMENT ,syntax/the-environment)
		(UNASSIGNED? ,syntax/unassigned?)
		;; To facilitate upgrade to new option argument mechanism.
		(DEFAULT-OBJECT? ,syntax/unassigned?)

		;; Miscellaneous extensions
		(DECLARE ,syntax/declare)
		(FLUID-LET ,syntax/fluid-let)
		(LOCAL-DECLARE ,syntax/local-declare)
		(NAMED-LAMBDA ,syntax/named-lambda)
		(SCODE-QUOTE ,syntax/scode-quote)))
    table))

;;;; Top Level Syntaxers

(define (syntax expression #!optional table)
  (syntax* (list expression) (if (default-object? table) #f table)))

(define (syntax* expressions #!optional table)
  (fluid-let ((*syntax-table*
	       (cond ((or (default-object? table) (not table))
		      (if (unassigned? *syntax-table*)
			  (nearest-repl/syntax-table)
			  *syntax-table*))
		     ((syntax-table? table)
		      table)
		     (else
		      (error:wrong-type-argument table
						 "syntax table"
						 'SYNTAX*))))
	      (*current-keyword* #f))
    (syntax-sequence #t expressions)))

(define (syntax/top-level?)
  *syntax-top-level?*)

(define-integrable (syntax-subsequence expressions)
  (syntax-sequence #f expressions))

(define (syntax-sequence top-level? original-expressions)
  (make-scode-sequence
   (syntax-sequence-internal top-level? original-expressions)))

(define (syntax-sequence-internal top-level? original-expressions)
  (if (null? original-expressions)
      (syntax-error "no subforms in sequence")
      (let process ((expressions original-expressions))
	(cond ((pair? expressions)
	       ;; Force eval order.  This is required so that special
	       ;; forms such as `define-syntax' work correctly.
	       (let ((first (syntax-expression top-level? (car expressions))))
		 (cons first (process (cdr expressions)))))
	      ((null? expressions)
	       '())
	      (else
	       (syntax-error "bad sequence" original-expressions))))))

(define-integrable (syntax-subexpression expression)
  (syntax-expression #f expression))

(define (syntax-expression top-level? expression)
  (hook/syntax-expression top-level? expression *syntax-table*))

(define hook/syntax-expression)
(define (default/syntax-expression top-level? expression syntax-table)
  (cond
   ((pair? expression)
    (if (not (list? expression))
	(error "syntax-expression: not a valid expression" expression))
    (let ((transform
	   (syntax-table-ref syntax-table (car expression))))
      (if transform
	  (if (primitive-syntaxer? transform)
	      (transform-apply (primitive-syntaxer/transform transform)
			       (car expression)
			       (cons top-level? (cdr expression)))
	      (let ((result
		     (fluid-let ((*syntax-top-level?* top-level?))
		       (transform-apply transform
					(car expression)
					(cdr expression)))))
		(if (syntax-closure? result)
		    (syntax-closure/expression result)
		    (syntax-expression top-level? result))))
	  (make-combination (syntax-subexpression (car expression))
			    (map syntax-subexpression (cdr expression))))))
   ((symbol? expression)
    (make-variable expression))
   (else
    expression)))

;;; Two overlapping kludges here.  This should go away and be replaced
;;; by a true syntactic closure mechanism like that described by
;;; Bawden and Rees.

(define-integrable (make-syntax-closure expression)
  (cons syntax-closure-tag expression))

(define (syntax-closure? expression)
  (and (pair? expression)
       (eq? (car expression) syntax-closure-tag)))

(define-integrable (syntax-closure/expression syntax-closure)
  (cdr syntax-closure))

(define syntax-closure-tag
  "syntax-closure")

(define-integrable (make-primitive-syntaxer expression)
  (cons primitive-syntaxer-tag expression))

(define (primitive-syntaxer? expression)
  (and (pair? expression)
       (eq? (car expression) primitive-syntaxer-tag)))

(define-integrable (primitive-syntaxer/transform primitive-syntaxer)
  (cdr primitive-syntaxer))

(define primitive-syntaxer-tag
  "primitive-syntaxer")

(define (transform-apply transform keyword arguments)
  (fluid-let ((*current-keyword* keyword))
    (let ((n-arguments (length arguments)))
      (if (not (procedure-arity-valid? transform n-arguments))
	  (syntax-error "incorrect number of subforms" n-arguments)))
    (apply transform arguments)))

(define (syntax-error message . irritants)
  (apply error
	 (cons
	  (string-append "SYNTAX: "
			 (if *current-keyword*
			     (string-append (symbol->string *current-keyword*)
					    ": "
					    message)
			     message))
	  irritants)))

(define (syntax-bindings bindings receiver)
  (if (not (list? bindings))
      (syntax-error "bindings must be a list" bindings)
      (let loop ((bindings bindings) (receiver receiver))
	(cond ((null? bindings)
	       (receiver '() '()))
	      ((and (pair? (car bindings))
		    (symbol? (caar bindings)))
	       (loop (cdr bindings)
		 (lambda (names values)
		   (receiver (cons (caar bindings) names)
			     (cons (expand-binding-value (cdar bindings))
				   values)))))
	      (else
	       (syntax-error "badly formed binding" (car bindings)))))))

;;;; Expanders

(define (expand-access chain cont)
  (if (symbol? (car chain))
      (cont (if (null? (cddr chain))
		(syntax-subexpression (cadr chain))
		(expand-access (cdr chain) make-access))
	    (car chain))
      (syntax-error "non-symbolic variable" (car chain))))

(define (expand-binding-value rest)
  (cond ((null? rest) (make-unassigned-reference-trap))
	((null? (cdr rest)) (syntax-subexpression (car rest)))
	(else (syntax-error "too many forms in value" rest))))

(define (expand-disjunction forms)
  (if (null? forms)
      false
      (let process ((forms forms))
	(if (null? (cdr forms))
	    (syntax-subexpression (car forms))
	    (make-disjunction (syntax-subexpression (car forms))
			      (process (cdr forms)))))))

(define (expand-lambda pattern actions receiver)
  ((if (pair? pattern)
       (letrec ((loop
		 (lambda (pattern body)
		   (if (pair? (car pattern))
		       (loop (car pattern)
			     (make-simple-lambda (cdr pattern) body))
		       (receiver pattern body)))))
	 loop)
       receiver)
   pattern
   (syntax-lambda-body actions)))

(define (syntax-lambda-body body)
  (syntax-subsequence
   (if (and (not (null? body))
	    (not (null? (cdr body)))
	    (string? (car body)))
       (cdr body)			;discard documentation string.
       body)))

;;;; Basic Syntax

(define (syntax/scode-quote top-level? expression)
  top-level?
  (make-quotation (syntax-subexpression expression)))

(define (syntax/quote top-level? expression)
  top-level?
  expression)

(define (syntax/the-environment top-level?)
  top-level?
  (make-the-environment))

(define (syntax/unassigned? top-level? name)
  top-level?
  (make-unassigned? name))

(define (syntax/access top-level? . chain)
  top-level?
  (if (not (and (pair? chain) (pair? (cdr chain))))
      (syntax-error "too few forms" chain))
  (expand-access chain make-access))

(define (syntax/set! top-level? name . rest)
  top-level?
  ((invert-expression (syntax-subexpression name))
   (expand-binding-value rest)))

(define (syntax/define top-level? pattern . rest)
  top-level?
  (let ((make-definition
	 (lambda (name value)
	   (if (syntax-table-ref *syntax-table* name)
	       (syntax-error "redefinition of syntactic keyword" name))
	   (make-definition name value))))
    (cond ((symbol? pattern)
	   (make-definition
	    pattern
	    (let ((value
		   (expand-binding-value
		    (if (and (= (length rest) 2)
			     (string? (cadr rest)))
			(list (car rest))
			rest))))
	      (if (lambda? value)
		  (lambda-components* value
		    (lambda (name required optional rest body)
		      (if (eq? name lambda-tag:unnamed)
			  (make-lambda* pattern required optional rest body)
			  value)))
		  value))))
	  ((pair? pattern)
	   (expand-lambda pattern rest
	     (lambda (pattern body)
	       (make-definition (car pattern)
				(make-named-lambda (car pattern) (cdr pattern)
						   body)))))
	  (else
	   (syntax-error "bad pattern" pattern)))))

(define (syntax/begin top-level? . actions)
  (syntax-sequence top-level? actions))

(define (syntax/in-package top-level? environment . body)
  top-level?
  (make-in-package (syntax-subexpression environment)
		   (make-sequence (syntax-sequence-internal #t body))))

(define (syntax/delay top-level? expression)
  top-level?
  (make-delay (syntax-subexpression expression)))

;;;; Conditionals

(define (syntax/if top-level? predicate consequent . rest)
  top-level?
  (make-conditional (syntax-subexpression predicate)
		    (syntax-subexpression consequent)
		    (cond ((null? rest)
			   undefined-conditional-branch)
			  ((null? (cdr rest))
			   (syntax-subexpression (car rest)))
			  (else
			   (syntax-error "too many forms" (cdr rest))))))

(define (syntax/or top-level? . expressions)
  top-level?
  (expand-disjunction expressions))

(define (syntax/cond top-level? . clauses)
  top-level?
  (define (loop clause rest)
    (cond ((not (pair? clause))
	   (syntax-error "bad COND clause" clause))
	  ((eq? (car clause) 'ELSE)
	   (if (not (null? rest))
	       (syntax-error "ELSE not last clause" rest))
	   (syntax-subsequence (cdr clause)))
	  ((null? (cdr clause))
	   (make-disjunction (syntax-subexpression (car clause)) (next rest)))
	  ((and (pair? (cdr clause))
		(eq? (cadr clause) '=>))
	   (if (not (and (pair? (cddr clause))
			 (null? (cdddr clause))))
	       (syntax-error "misformed => clause" clause))
	   (let ((predicate (string->uninterned-symbol "PREDICATE")))
	     (make-closed-block lambda-tag:let
				(list predicate)
				(list (syntax-subexpression (car clause)))
	       (let ((predicate (syntax-subexpression predicate)))
		 (make-conditional
		  predicate
		  (make-combination* (syntax-subexpression (caddr clause))
				     predicate)
		  (next rest))))))
	  (else
	   (make-conditional (syntax-subexpression (car clause))
			     (syntax-subsequence (cdr clause))
			     (next rest)))))

  (define (next rest)
    (if (null? rest)
	undefined-conditional-branch
	(loop (car rest) (cdr rest))))

  (next clauses))

;;;; Procedures

(define (syntax/lambda top-level? pattern . body)
  top-level?
  (make-simple-lambda pattern (syntax-lambda-body body)))

(define (syntax/named-lambda top-level? pattern . body)
  top-level?
  (expand-lambda pattern body
    (lambda (pattern body)
      (if (pair? pattern)
	  (make-named-lambda (car pattern) (cdr pattern) body)
	  (syntax-error "illegal named-lambda list" pattern)))))

(define (syntax/let top-level? name-or-pattern pattern-or-first . rest)
  top-level?
  (if (symbol? name-or-pattern)
      (syntax-bindings pattern-or-first
	(lambda (names values)
	  (if (memq name-or-pattern names)
	      (syntax-error "name conflicts with binding"
			    name-or-pattern))
	  (make-combination
	   (make-letrec (list name-or-pattern)
			(list (make-named-lambda name-or-pattern names
						 (syntax-subsequence rest)))
			(make-variable name-or-pattern))
	   values)))
      (syntax-bindings name-or-pattern
	(lambda (names values)
	  (make-closed-block
	   lambda-tag:let names values
	   (syntax-subsequence (cons pattern-or-first rest)))))))

;;;; Syntax Extensions

(define (syntax/let-syntax top-level? bindings . body)
  (syntax-bindings bindings
    (lambda (names values)
      (fluid-let ((*syntax-table*
		   (syntax-table/extend
		    *syntax-table*
		    (map (lambda (name value)
			   (cons name (syntax-eval value)))
			 names
			 values))))
	(syntax-sequence top-level? body)))))

(define (syntax/using-syntax top-level? table . body)
  (let ((table* (syntax-eval (syntax-subexpression table))))
    (if (not (syntax-table? table*))
	(syntax-error "not a syntax table" table))
    (fluid-let ((*syntax-table* table*))
      (syntax-sequence top-level? body))))

(define (syntax/define-syntax top-level? name value)
  top-level?
  (if (not (symbol? name))
      (syntax-error "illegal name" name))
  (syntax-table-define *syntax-table* name
    (syntax-eval (syntax-subexpression value)))
  name)

(define (syntax/define-macro top-level? pattern . body)
  top-level?
  (let ((keyword (car pattern)))
    (syntax-table-define *syntax-table* keyword
      (syntax-eval (apply syntax/named-lambda #f pattern body)))
    keyword))

(define-integrable (syntax-eval scode)
  (extended-scode-eval scode syntaxer/default-environment))

;;;; FLUID-LET

(define (syntax/fluid-let top-level? bindings . body)
  (syntax/fluid-let/current top-level? bindings body))

(define syntax/fluid-let/current)

(define (set-fluid-let-type! type)
  (set! syntax/fluid-let/current
	(case type
	  ((SHALLOW) syntax/fluid-let/shallow)
	  ((DEEP) syntax/fluid-let/deep)
	  ((COMMON-LISP) syntax/fluid-let/common-lisp)
	  (else (error "SET-FLUID-LET-TYPE!: unknown type" type)))))

(define (syntax/fluid-let/shallow top-level? bindings body)
  (if (null? bindings)
      (syntax-sequence top-level? body)
      (syntax-fluid-bindings/shallow bindings
	(lambda (names values transfers-in transfers-out)
	  (make-closed-block lambda-tag:fluid-let names values
	    (make-combination*
	     (make-absolute-reference 'SHALLOW-FLUID-BIND)
	     (make-thunk (make-scode-sequence transfers-in))
	     (make-thunk (syntax-subsequence body))
	     (make-thunk (make-scode-sequence transfers-out))))))))

(define (syntax/fluid-let/deep top-level? bindings body)
  top-level?
  (syntax/fluid-let/deep* (ucode-primitive add-fluid-binding! 3)
			  bindings
			  body))

(define (syntax/fluid-let/common-lisp top-level? bindings body)
  top-level?
  (syntax/fluid-let/deep* (ucode-primitive make-fluid-binding! 3)
			  bindings
			  body))

(define (syntax/fluid-let/deep* add-fluid-binding! bindings body)
  (make-closed-block lambda-tag:fluid-let '() '()
    (make-combination*
     (ucode-primitive with-saved-fluid-bindings 1)
     (make-thunk
      (make-scode-sequence*
       (make-scode-sequence
	(syntax-fluid-bindings/deep add-fluid-binding! bindings))
       (syntax-subsequence body))))))

(define (syntax-fluid-bindings/shallow bindings receiver)
  (if (null? bindings)
      (receiver '() '() '() '())
      (syntax-fluid-bindings/shallow (cdr bindings)
	(lambda (names values transfers-in transfers-out)
	  (let ((binding (car bindings)))
	    (if (pair? binding)
		(let ((transfer
		       (let ((reference (syntax-subexpression (car binding))))
			 (let ((assignment (invert-expression reference)))
			   (lambda (target source)
			     (make-assignment
			      target
			      (assignment (make-assignment source)))))))
		      (value (expand-binding-value (cdr binding)))
		      (inside-name
		       (string->uninterned-symbol "INSIDE-PLACEHOLDER"))
		      (outside-name
		       (string->uninterned-symbol "OUTSIDE-PLACEHOLDER")))
		  (receiver (cons* inside-name outside-name names)
			    (cons* value (make-unassigned-reference-trap)
				   values)
			    (cons (transfer outside-name inside-name)
				  transfers-in)
			    (cons (transfer inside-name outside-name)
				  transfers-out)))
		(syntax-error "binding not a pair" binding)))))))

(define (syntax-fluid-bindings/deep add-fluid-binding! bindings)
  (map (lambda (binding)
	 (syntax-fluid-binding/deep add-fluid-binding! binding))
       bindings))

(define (syntax-fluid-binding/deep add-fluid-binding! binding)
  (if (pair? binding)
      (let ((name (syntax-subexpression (car binding)))
	    (finish
	     (lambda (environment name)
	       (make-combination* add-fluid-binding!
				  environment
				  name
				  (expand-binding-value (cdr binding))))))
	(cond ((variable? name)
	       (finish (make-the-environment) (make-quotation name)))
	      ((access? name)
	       (access-components name finish))
	      (else
	       (syntax-error "binding name illegal" (car binding)))))
      (syntax-error "binding not a pair" binding)))

;;;; Extended Assignment Syntax

(define (invert-expression target)
  (cond ((variable? target)
	 (invert-variable (variable-name target)))
	((access? target)
	 (access-components target invert-access))
	(else
	 (syntax-error "bad target" target))))

(define ((invert-variable name) value)
  (make-assignment name value))

(define ((invert-access environment name) value)
  (make-combination* lexical-assignment environment name value))

;;;; Declarations

;;; All declarations are syntactically checked; the resulting
;;; DECLARATION objects all contain lists of standard declarations.
;;; Each standard declaration is a proper list with symbolic keyword.

(define (syntax/declare top-level? . declarations)
  top-level?
  (make-block-declaration (map process-declaration declarations)))

(define (syntax/local-declare top-level? declarations . body)
  (make-declaration (process-declarations declarations)
		    (syntax-sequence top-level? body)))

;;; These two procedures use `error' instead of `syntax-error' because
;;; they are also called when the syntaxer is not running.

(define (process-declarations declarations)
  (if (list? declarations)
      (map process-declaration declarations)
      (error "SYNTAX: Illegal declaration list" declarations)))

(define (process-declaration declaration)
  (cond ((symbol? declaration)
	 (list declaration))
	((and (list? declaration)
	      (not (null? declaration))
	      (symbol? (car declaration)))
	 declaration)
	(else
	 (error "SYNTAX: Illegal declaration" declaration))))

;;;; SCODE Constructors

(define (make-conjunction first second)
  (make-conditional first second false))

(define (make-combination* operator . operands)
  (make-combination operator operands))

(define (make-scode-sequence* . operands)
  (make-scode-sequence operands))

(define (make-absolute-reference name . rest)
  (let loop ((reference (make-access false name)) (rest rest))
    (if (null? rest)
	reference
	(loop (make-access reference (car rest)) (cdr rest)))))

(define (make-thunk body)
  (make-simple-lambda '() body))

(define (make-simple-lambda pattern body)
  (make-named-lambda lambda-tag:unnamed pattern body))

(define (make-named-lambda name pattern body)
  (if (not (symbol? name))
      (syntax-error "name of lambda expression must be a symbol" name))
  (parse-lambda-list pattern
    (lambda (required optional rest)
      (internal-make-lambda name required optional rest body))))

(define (make-closed-block tag names values body)
  (make-combination (internal-make-lambda tag names '() false body) values))

(define (make-letrec names values body)
  (make-closed-block lambda-tag:let '() '()
		     (make-scode-sequence
		      (append! (map make-definition names values)
			       (list body)))))

(define-integrable lambda-tag:unnamed
  ((ucode-primitive string->symbol) "#[unnamed-procedure]"))

(define-integrable lambda-tag:let
  ((ucode-primitive string->symbol) "#[let-procedure]"))

(define-integrable lambda-tag:fluid-let
  ((ucode-primitive string->symbol) "#[fluid-let-procedure]"))

(define-integrable lambda-tag:make-environment
  ((ucode-primitive string->symbol) "#[make-environment]"))

;;;; Lambda List Parser

(define (parse-lambda-list lambda-list receiver)
  (let ((required (list '()))
	(optional (list '())))
    (define (parse-parameters cell pattern)
      (let loop ((pattern pattern))
	(cond ((null? pattern) (finish false))
	      ((symbol? pattern) (finish pattern))
	      ((not (pair? pattern)) (bad-lambda-list pattern))
	      ((eq? (car pattern) lambda-rest-tag)
	       (if (and (pair? (cdr pattern)) (null? (cddr pattern)))
		   (cond ((symbol? (cadr pattern)) (finish (cadr pattern)))
			 ((and (pair? (cadr pattern))
			       (symbol? (caadr pattern)))
			  (finish (caadr pattern)))
			 (else (bad-lambda-list (cdr pattern))))
		   (bad-lambda-list (cdr pattern))))
	      ((eq? (car pattern) lambda-optional-tag)
	       (if (eq? cell required)
		   (parse-parameters optional (cdr pattern))
		   (bad-lambda-list pattern)))
	      ((symbol? (car pattern))
	       (set-car! cell (cons (car pattern) (car cell)))
	       (loop (cdr pattern)))
	      ((and (pair? (car pattern)) (symbol? (caar pattern)))
	       (set-car! cell (cons (caar pattern) (car cell)))
	       (loop (cdr pattern)))
	      (else (bad-lambda-list pattern)))))

    (define (finish rest)
      (let ((required (reverse! (car required)))
	    (optional (reverse! (car optional))))
	(do ((parameters
	      (append required optional (if rest (list rest) '()))
	      (cdr parameters)))
	    ((null? parameters))
	  (if (memq (car parameters) (cdr parameters))
	      (syntax-error "lambda list has duplicate parameters"
			    lambda-list)))
	(receiver required optional rest)))

    (define (bad-lambda-list pattern)
      (syntax-error "illegally-formed lambda list" pattern))

    (parse-parameters required lambda-list)))

;;;; Scan Defines

(define (make-sequence/scan actions)
  (scan-defines (make-sequence actions)
    make-open-block))

(define (make-lambda/no-scan name required optional rest body)
  (make-lambda name required optional rest '() '() body))

(define (make-lambda/scan name required optional rest body)
  (make-lambda* name required optional rest body))

(define make-scode-sequence)
(define internal-make-lambda)

(define (enable-scan-defines!)
  (set! make-scode-sequence make-sequence/scan)
  (set! internal-make-lambda make-lambda/scan))

(define (disable-scan-defines!)
  (set! make-scode-sequence make-sequence)
  (set! internal-make-lambda make-lambda/no-scan))