;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/comman.scm,v 1.57 1989/04/15 00:47:49 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989 Massachusetts Institute of Technology
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

;;;; Commands and Variables

(declare (usual-integrations))

(define-named-structure "Command"
  name
  description
  interactive-specification
  procedure)

(define (command-name-string command)
  (editor-name/internal->external (symbol->string (command-name command))))

(define (editor-name/internal->external string)
  string)

(define (editor-name/external->internal string)
  string)

(define (make-command name description specification procedure)
  (let ((command
	 (let ((name (symbol->string name)))
	   (or (string-table-get editor-commands name)
	       (let ((command (%make-command)))
		 (string-table-put! editor-commands name command)
		 command)))))
    (vector-set! command command-index:name name)
    (vector-set! command command-index:description description)
    (vector-set! command command-index:interactive-specification specification)
    (vector-set! command command-index:procedure procedure)
    command))

(define editor-commands
  (make-string-table 500))

(define (name->command name)
  (let ((name (canonicalize-name name)))
    (or (string-table-get editor-commands (symbol->string name))
	(letrec ((command
		  (make-command
		   name
		   "undefined command"
		   '()
		   (lambda ()
		     (editor-error "Undefined command: "
				   (command-name-string command))))))
	  command))))

(define-named-structure "Variable"
  name
  description
  value)

(define (variable-name-string variable)
  (editor-name/internal->external (symbol->string (variable-name variable))))

(define (make-variable name description value)
  (let ((variable
	 (let ((name (symbol->string name)))
	   (or (string-table-get editor-variables name)
	       (let ((variable (%make-variable)))
		 (string-table-put! editor-variables name variable)
		 variable)))))
    (vector-set! variable variable-index:name name)
    (vector-set! variable variable-index:description description)
    (vector-set! variable variable-index:value value)
    variable))

(define editor-variables
  (make-string-table 50))

(define (name->variable name)
  (let ((name (canonicalize-name name)))
    (or (string-table-get editor-variables (symbol->string name))
	(make-variable name "" false))))
(define-integrable (set-variable-value! variable value)  (vector-set! variable variable-index:value value)
  unspecific)
(define (with-variable-value! variable new-value thunk)
  (let ((old-value))
    (dynamic-wind (lambda ()
		    (set! old-value (variable-value variable))
		    (set-variable-value! variable new-value)
		    (set! new-value)
		    unspecific)
		  thunk
		  (lambda ()
		    (set! new-value (variable-value variable))
		    (set-variable-value! variable old-value)
		    (set! old-value)
		    unspecific))))