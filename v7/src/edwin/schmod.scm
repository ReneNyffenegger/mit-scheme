;;; -*-Scheme-*-
;;;
;;;	$Id: schmod.scm,v 1.32 1993/04/01 23:37:28 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-93 Massachusetts Institute of Technology
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

;;;; Scheme Mode

(declare (usual-integrations))

(define-command scheme-mode
  "Enter Scheme mode."
  ()
  (lambda ()
    (set-current-major-mode! (ref-mode-object scheme))))

(define-major-mode scheme fundamental "Scheme"
  "Major mode specialized for editing Scheme code.
\\[lisp-indent-line] indents the current line for Scheme.
\\[indent-sexp] indents the next s-expression.

The following commands evaluate Scheme expressions:

\\[eval-expression] reads and evaluates an expression in minibuffer.
\\[eval-last-sexp] evaluates the expression preceding point.
\\[eval-defun] evaluates the current definition.
\\[eval-current-buffer] evaluates the buffer.
\\[eval-region] evaluates the current region."
  (lambda (buffer)
    (define-variable-local-value! buffer (ref-variable-object syntax-table)
      scheme-mode:syntax-table)
    (define-variable-local-value! buffer
	(ref-variable-object syntax-ignore-comments-backwards)
      false)
    (define-variable-local-value! buffer (ref-variable-object lisp-indent-hook)
      standard-lisp-indent-hook)
    (define-variable-local-value! buffer
	(ref-variable-object lisp-indent-methods)
      scheme-mode:indent-methods)
    (define-variable-local-value! buffer (ref-variable-object comment-column)
      40)
    (define-variable-local-value! buffer
	(ref-variable-object comment-locator-hook)
      lisp-comment-locate)
    (define-variable-local-value! buffer
	(ref-variable-object comment-indent-hook)
      lisp-comment-indentation)
    (define-variable-local-value! buffer (ref-variable-object comment-start)
      ";")
    (define-variable-local-value! buffer (ref-variable-object comment-end)
      "")
    (let ((separate
	   (string-append "^$\\|" (ref-variable page-delimiter buffer))))
      (define-variable-local-value! buffer
	  (ref-variable-object paragraph-start)
	separate)
      (define-variable-local-value! buffer
	  (ref-variable-object paragraph-separate)
	separate))
    (define-variable-local-value! buffer
	(ref-variable-object paragraph-ignore-fill-prefix)
      true)
    (define-variable-local-value! buffer
	(ref-variable-object indent-line-procedure)
      (ref-command lisp-indent-line))
    (define-variable-local-value! buffer
	(ref-variable-object mode-line-process)
      '(RUN-LIGHT (": " RUN-LIGHT) ""))
    (event-distributor/invoke! (ref-variable scheme-mode-hook buffer) buffer)))

(define-variable scheme-mode-hook
  "An event distributor that is invoked when entering Scheme mode."
  (make-event-distributor))

(define-key 'scheme #\rubout 'backward-delete-char-untabify)
(define-key 'scheme #\tab 'lisp-indent-line)
(define-key 'scheme #\) 'lisp-insert-paren)
(define-key 'scheme #\m-A 'show-parameter-list)
(define-key 'scheme #\m-g 'undefined)
(define-key 'scheme #\m-o 'eval-current-buffer)
(define-key 'scheme #\m-q 'undefined)
(define-key 'scheme #\m-z 'eval-defun)
(define-key 'scheme #\c-m-q 'indent-sexp)
(define-key 'scheme #\c-m-z 'eval-region)
(define-key 'scheme #\m-tab 'scheme-complete-variable)
(define-key 'scheme '(#\c-c #\c-c) 'eval-abort-top-level)

;;;; Read Syntax

(define scheme-mode:syntax-table (make-syntax-table))

(modify-syntax-entries! scheme-mode:syntax-table #\nul #\/ "_")
(modify-syntax-entries! scheme-mode:syntax-table #\: #\@ "_")
(modify-syntax-entries! scheme-mode:syntax-table #\[ #\` "_")
(modify-syntax-entries! scheme-mode:syntax-table #\{ #\rubout "_")

(modify-syntax-entry! scheme-mode:syntax-table #\space " ")
(modify-syntax-entry! scheme-mode:syntax-table #\tab " ")
(modify-syntax-entry! scheme-mode:syntax-table #\page " ")
(modify-syntax-entry! scheme-mode:syntax-table #\[ "(]")
(modify-syntax-entry! scheme-mode:syntax-table #\] ")[")
(modify-syntax-entry! scheme-mode:syntax-table #\{ "(}")
(modify-syntax-entry! scheme-mode:syntax-table #\} "){")
(modify-syntax-entry! scheme-mode:syntax-table #\| "  23")

(modify-syntax-entry! scheme-mode:syntax-table #\; "< ")
(modify-syntax-entry! scheme-mode:syntax-table #\newline "> ")

(modify-syntax-entry! scheme-mode:syntax-table #\' "  p")
(modify-syntax-entry! scheme-mode:syntax-table #\` "  p")
(modify-syntax-entry! scheme-mode:syntax-table #\, "_ p")
(modify-syntax-entry! scheme-mode:syntax-table #\@ "_ p")
(modify-syntax-entry! scheme-mode:syntax-table #\# "_ p14")

(modify-syntax-entry! scheme-mode:syntax-table #\" "\" ")
(modify-syntax-entry! scheme-mode:syntax-table #\\ "\\ ")
(modify-syntax-entry! scheme-mode:syntax-table #\( "()")
(modify-syntax-entry! scheme-mode:syntax-table #\) ")(")

;;;; Indentation

(define (scheme-mode:indent-let-method state indent-point normal-indent)
  (lisp-indent-special-form
   (if (let ((start
	      (forward-to-sexp-start
	       (forward-one-sexp (mark1+ (parse-state-containing-sexp state))
				 indent-point)
	       indent-point)))
	 (and start
	      (not (re-match-forward "\\s(" start))))
       2
       1)
   state indent-point normal-indent))

(define scheme-mode:indent-methods (make-string-table))

(for-each (lambda (entry)
	    (string-table-put! scheme-mode:indent-methods
			       (symbol->string (car entry))
			       (cdr entry)))
	  `(
	    (BEGIN . 0)
	    (CASE . 1)
	    (DELAY . 0)
	    (DO . 2)
	    (LAMBDA . 1)
	    (LET . ,scheme-mode:indent-let-method)
	    (LET* . 1)
	    (LETREC . 1)

	    (CALL-WITH-INPUT-FILE . 1)
	    (WITH-INPUT-FROM-FILE . 1)
	    (CALL-WITH-OUTPUT-FILE . 1)
	    (WITH-OUTPUT-TO-FILE . 1)

	    ;; Remainder are MIT Scheme specific.

	    (FLUID-LET . 1)
	    (IN-PACKAGE . 1)
	    (LET-SYNTAX . 1)
	    (LOCAL-DECLARE . 1)
	    (MACRO . 1)
	    (MAKE-ENVIRONMENT . 0)
	    (NAMED-LAMBDA . 1)
	    (USING-SYNTAX . 1)

	    (WITH-INPUT-FROM-PORT . 1)
	    (WITH-INPUT-FROM-STRING . 1)
	    (WITH-OUTPUT-TO-PORT . 1)
	    (WITH-OUTPUT-TO-STRING . 0)
	    (WITH-VALUES . 1)
	    (WITHIN-CONTINUATION . 1)

	    (MAKE-CONDITION-TYPE . 3)
	    (BIND-RESTART . 3)
	    (WITH-SIMPLE-RESTART . 2)
	    (BIND-CONDITION-HANDLER . 2)
	    (LIST-TRANSFORM-POSITIVE . 1)
	    (LIST-TRANSFORM-NEGATIVE . 1)
	    (LIST-SEARCH-POSITIVE . 1)
	    (LIST-SEARCH-NEGATIVE . 1)
	    (SYNTAX-TABLE-DEFINE . 2)
	    (FOR-ALL? . 1)
	    (THERE-EXISTS? . 1)
	    ))

;;;; Completion

(define (scheme-complete-symbol bound-only?)
  (let ((end
	 (let ((point (current-point)))
	   (or (re-match-forward "\\(\\sw\\|\\s_\\)+"
				 point
				 (group-end point)
				 false)
	       (let ((start (group-start point)))
		 (if (not (and (mark< start point)
			       (re-match-forward "\\sw\\|\\s_"
						 (mark-1+ point)
						 point
						 false)))
		     (editor-error "No symbol preceding point"))
		 point)))))
    (let ((start (forward-prefix-chars (backward-sexp end 1 'LIMIT) end)))
      (standard-completion (extract-string start end)
	(lambda (prefix if-unique if-not-unique if-not-found)
	  (let ((completions
		 (let ((completions (obarray-completions prefix)))
		   (if (not bound-only?)
		       completions
		       (let ((environment (evaluation-environment false)))
			 (list-transform-positive completions
			   (lambda (name)
			     (environment-bound? environment name))))))))
	    (cond ((null? completions)
		   (if-not-found))
		  ((null? (cdr completions))
		   (if-unique (system-pair-car (car completions))))
		  (else
		   (let ((completions (map system-pair-car completions)))
		     (if-not-unique
		      (string-greatest-common-prefix completions)
		      (lambda () (sort completions string<=?))))))))
	(lambda (completion)
	  (delete-string start end)
	  (insert-string completion start))))))

(define (obarray-completions prefix)
  (let ((obarray (fixed-objects-item 'OBARRAY)))
    (let ((prefix-length (string-length prefix))
	  (obarray-length (vector-length obarray)))
      (let index-loop ((i 0))
	(if (fix:< i obarray-length)
	    (let bucket-loop ((symbols (vector-ref obarray i)))
	      (if (null? symbols)
		  (index-loop (fix:+ i 1))
		  (let ((string (system-pair-car (car symbols))))
		    (if (and (fix:<= prefix-length (string-length string))
			     (let loop ((index 0))
			       (or (fix:= index prefix-length)
				   (and (char=? (string-ref prefix index)
						(string-ref string index))
					(loop (fix:+ index 1))))))
			(cons (car symbols) (bucket-loop (cdr symbols)))
			(bucket-loop (cdr symbols))))))
	    '())))))

(define-command scheme-complete-symbol
  "Perform completion on Scheme symbol preceding point.
That symbol is compared against the symbols that exist
and any additional characters determined by what is there
are inserted.
With prefix arg, only symbols that are bound in the buffer's
environment are considered."
  "P"
  scheme-complete-symbol)

(define-command scheme-complete-variable
  "Perform completion on Scheme variable name preceding point.
That name is compared against the bound variables in the evaluation environment
and any additional characters determined by what is there are inserted.
With prefix arg, the evaluation environment is ignored and all symbols
are considered for completion."
  "P"
  (lambda (all-symbols?) (scheme-complete-symbol (not all-symbols?))))

(define-command show-parameter-list
  "Show the parameter list of the \"current\" procedure.
The \"current\" procedure is the expression at the head of the enclosing list."
  "d"
  (lambda (point)
    (let ((start
	   (forward-down-list (backward-up-list point 1 'ERROR) 1 'ERROR))
	  (buffer (mark-buffer point)))
      (let ((end (forward-sexp start 1 'ERROR)))
	(let ((procedure
	       (let ((environment (evaluation-environment buffer)))
		 (extended-scode-eval
		  (syntax (with-input-from-region (make-region start end) read)
			  (evaluation-syntax-table buffer environment))
		  environment))))
	  (if (procedure? procedure)
	      (message (procedure-argl procedure))
	      (editor-error "Expression does not evaluate to a procedure: "
			    (extract-string start end))))))))

(define (procedure-argl proc)
  "Returns the arg list of PROC.
Grumbles if PROC is an undocumented primitive."
  (if (primitive-procedure? proc)
      (let ((doc-string (primitive-procedure-documentation proc)))
	(if doc-string
	    (let ((newline (string-find-next-char doc-string #\newline)))
	      (if newline
		  (string-head doc-string newline)
		  doc-string))
	    (string-append (write-to-string proc)
			   " has no documentation string.")))
      (let ((code (procedure-lambda proc)))
	(lambda-components* code
	  (lambda (name required optional rest body)
	    (append required
		    (if (null? optional) '() `(#!OPTIONAL ,@optional))
		    (if rest `(#!REST ,rest) '())))))))