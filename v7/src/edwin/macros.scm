;;; -*-Scheme-*-
;;;
;;;	$Id: macros.scm,v 1.57 1992/11/16 22:41:07 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-1992 Massachusetts Institute of Technology
;;;
;;;	This material was developed by the Scheme project at the
;;;	Massachusetts Institute of Technology, Department of
;;;	Electrical Engineering and Computer Science.  Permission to
;;;	copy this software, to redistribute it, and to use it for any
;;;	purpose is granted, subject to the following restrictions and
;;;	understandings.
;;;
;;;	1. Any copy made of this software must include this copyright
;;;	notice in full.
;;;
;;;	2. Users of this software agree to make their best efforts (a)
;;;	to return to the MIT Scheme project any improvements or
;;;	extensions that they make, so that these may be included in
;;;	future releases; and (b) to inform MIT of noteworthy uses of
;;;	this software.
;;;
;;;	3. All materials developed as a consequence of the use of this
;;;	software shall duly acknowledge such use, in accordance with
;;;	the usual standards of acknowledging credit in academic
;;;	research.
;;;
;;;	4. MIT has made no warrantee or representation that the
;;;	operation of this software will be error-free, and MIT is
;;;	under no obligation to provide any services, by way of
;;;	maintenance, update, or otherwise.
;;;
;;;	5. In conjunction with products arising from the use of this
;;;	material, there shall be no use of the name of the
;;;	Massachusetts Institute of Technology nor of any adaptation
;;;	thereof in any advertising, promotional, or sales literature
;;;	without prior written consent from MIT in each case.
;;;
;;; NOTE: Parts of this program (Edwin) were created by translation
;;; from corresponding parts of GNU Emacs.  Users should be aware that
;;; the GNU GENERAL PUBLIC LICENSE may apply to these parts.  A copy
;;; of that license should have been included along with this file.
;;;

;;;; Editor Macros

(declare (usual-integrations))

(define edwin-syntax-table
  (make-syntax-table syntax-table/system-internal))

;;; DEFINE-NAMED-STRUCTURE is a simple alternative to DEFSTRUCT,
;;; which defines a vector-based tagged data structure.  The first
;;; argument is a string, which will be stored in the structure's 0th
;;; slot.  The remaining arguments are symbols, which should be the
;;; names of the slots.  Do not use the slot names %TAG or %SIZE.

(syntax-table-define edwin-syntax-table 'DEFINE-NAMED-STRUCTURE
  (lambda (name . slots)
    (define ((make-symbols x) y)
      (make-symbol x y))

    (define (make-symbol . args)
      (intern (apply string-append args)))

    (let ((structure-name (intern name))
	  (slot-strings (map symbol->string slots))
	  (prefix (string-append name "-")))
      (let ((tag-name (make-symbol "%" prefix "tag"))
	    (constructor-name (make-symbol "%make-" name))
	    (predicate-name (make-symbol name "?"))
	    (slot-names
	     (map (make-symbols (string-append prefix "index:")) slot-strings))
	    (selector-names (map (make-symbols prefix) slot-strings)))
	(define (slot-loop slot-names n)
	  (if (null? slot-names)
	      '()
	      (cons `(DEFINE-INTEGRABLE ,(car slot-names) ,n)
		    (slot-loop (cdr slot-names) (1+ n)))))

	(define (selector-loop selector-names n)
	  (if (null? selector-names)
	      '()
	      (cons `(DEFINE-INTEGRABLE
		       (,(car selector-names) ,structure-name)
		       (VECTOR-REF ,structure-name ,n))
		    (selector-loop (cdr selector-names) (1+ n)))))

	`(BEGIN (DEFINE ,tag-name ,name)
		(DEFINE (,constructor-name)
		  (LET ((,structure-name
			 (MAKE-VECTOR ,(1+ (length slots)) '())))
		    (VECTOR-SET! ,structure-name 0 ,tag-name)
		    ,structure-name))
		(DEFINE (,predicate-name OBJECT)
		  (AND (VECTOR? OBJECT)
		       (NOT (ZERO? (VECTOR-LENGTH OBJECT)))
		       (EQ? ,tag-name (VECTOR-REF OBJECT 0))))
		(UNPARSER/SET-TAGGED-VECTOR-METHOD!
		 ,tag-name
		 (UNPARSER/STANDARD-METHOD ',structure-name))
		,@(slot-loop slot-names 1)
		,@(selector-loop selector-names 1))))))

(syntax-table-define edwin-syntax-table 'DEFINE-COMMAND
  (lambda (name description interactive procedure)
    (let ((name (canonicalize-name name)))
      (let ((scheme-name (command-name->scheme-name name)))
	`(DEFINE ,scheme-name
	   (MAKE-COMMAND ',name
			 ,description
			 ,(if (null? interactive)
			      `'()
			      interactive)
			 ,(if (and (pair? procedure)
				   (eq? 'LAMBDA (car procedure))
				   (pair? (cdr procedure)))
			      `(NAMED-LAMBDA (,scheme-name
					      ,@(cadr procedure))
				 ,@(cddr procedure))
			      procedure)))))))

(syntax-table-define edwin-syntax-table 'REF-COMMAND-OBJECT
  (lambda (name)
    (command-name->scheme-name (canonicalize-name name))))

(syntax-table-define edwin-syntax-table 'REF-COMMAND
  (lambda (name)
    `(COMMAND-PROCEDURE
      ,(command-name->scheme-name (canonicalize-name name)))))

(syntax-table-define edwin-syntax-table 'COMMAND-DEFINED?
  (lambda (name)
    (let ((variable-name (command-name->scheme-name (canonicalize-name name))))
      `(let ((env (->environment '(EDWIN))))
	 (and (environment-bound? env ',variable-name)
	      (not (lexical-unassigned? env
					',variable-name)))))))

(define (command-name->scheme-name name)
  (symbol-append 'EDWIN-COMMAND$ name))

(let ((variable-definition
       (lambda (buffer-local?)
	 (lambda (name description #!optional value test)
	   (let ((name (canonicalize-name name)))
	     (let ((scheme-name (variable-name->scheme-name name)))
	       `(BEGIN
		  (DEFINE ,scheme-name
		    (MAKE-VARIABLE ',name
				   ',description
				   ,(if (default-object? value) '#F value)
				   ',buffer-local?))
		  ,@(if (default-object? test)
			'()
			`((DEFINE-VARIABLE-VALUE-VALIDITY-TEST ,scheme-name
			    ,test))))))))))
  (syntax-table-define edwin-syntax-table 'DEFINE-VARIABLE
    (variable-definition false))
  (syntax-table-define edwin-syntax-table 'DEFINE-VARIABLE-PER-BUFFER
    (variable-definition true)))

(syntax-table-define edwin-syntax-table 'REF-VARIABLE-OBJECT
  (lambda (name)
    (variable-name->scheme-name (canonicalize-name name))))

(syntax-table-define edwin-syntax-table 'REF-VARIABLE
  (lambda (name #!optional buffer)
    (let ((name (variable-name->scheme-name (canonicalize-name name))))
      (if (default-object? buffer)
	  `(VARIABLE-VALUE ,name)
	  `(VARIABLE-LOCAL-VALUE ,buffer ,name)))))

(syntax-table-define edwin-syntax-table 'SET-VARIABLE!
  (lambda (name #!optional value)
    `(SET-VARIABLE-VALUE!
      ,(variable-name->scheme-name (canonicalize-name name))
      ,(if (default-object? value) '#F value))))

(syntax-table-define edwin-syntax-table 'LOCAL-SET-VARIABLE!
  (lambda (name #!optional value)
    `(DEFINE-VARIABLE-LOCAL-VALUE!
      (CURRENT-BUFFER)
      ,(variable-name->scheme-name (canonicalize-name name))
      ,(if (default-object? value) '#F value))))

(define (variable-name->scheme-name name)
  (symbol-append 'EDWIN-VARIABLE$ name))

(syntax-table-define edwin-syntax-table 'DEFINE-MAJOR-MODE
  (lambda (name super-mode-name display-name description
		#!optional initialization)
    (let ((name (canonicalize-name name))
	  (super-mode-name
	   (and super-mode-name (canonicalize-name super-mode-name))))
      `(DEFINE ,(mode-name->scheme-name name)
	 (MAKE-MODE ',name
		    #T
		    ',(or display-name (symbol->string name))
		    ,(if super-mode-name
			 `(->MODE ',super-mode-name)
			 `#F)
		    ',description
		    ,(let ((super-initialization
			    (and super-mode-name
				 `(MODE-INITIALIZATION
				   ,(mode-name->scheme-name super-mode-name))))
			   (initialization
			    (and (not (default-object? initialization))
				 initialization)))
		       (cond (super-initialization
			      `(LAMBDA (BUFFER)
				 (,super-initialization BUFFER)
				 ,@(if initialization
				       `((,initialization BUFFER))
				       `())))
			     (initialization)
			     (else `(LAMBDA (BUFFER) BUFFER UNSPECIFIC)))))))))

(syntax-table-define edwin-syntax-table 'DEFINE-MINOR-MODE
  (lambda (name display-name description #!optional initialization)
    (let ((name (canonicalize-name name)))
      `(DEFINE ,(mode-name->scheme-name name)
	 (MAKE-MODE ',name
		    #F
		    ',(or display-name (symbol->string name))
		    #F
		    ',description
		    ,(if (and (not (default-object? initialization))
			      initialization)
			 initialization
			 `(LAMBDA (BUFFER) BUFFER UNSPECIFIC)))))))

(syntax-table-define edwin-syntax-table 'REF-MODE-OBJECT
  (lambda (name)
    (mode-name->scheme-name (canonicalize-name name))))

(define (mode-name->scheme-name name)
  (symbol-append 'EDWIN-MODE$ name))

(define (canonicalize-name name)
  (cond ((symbol? name) name)
	((string? name) (intern (string-replace name #\Space #\-)))
	(else (error "illegal name" name))))

(syntax-table-define edwin-syntax-table 'VALUES-LET
  (lambda (bindings . forms)

    (define (transform/binding binding forms)
      (if (or (not (pair? binding))
	      (not (pair? (cdr binding))))
	  (error "values-let: bad binding clause" binding))
      `(WITH-VALUES (LAMBDA () ,(cadr binding))
	 (LAMBDA (,@(car binding)) ,@forms)))

    (define (transform/values-let bindings forms)
      (transform/binding
       (car bindings)
       (if (null? (cdr bindings))
	   forms
	   (list (transform/values-let (cdr bindings) forms)))))

    (if (not (pair? bindings))
	(error "values-let: missing bindings" (cons bindings forms))
	(transform/values-let bindings forms))))