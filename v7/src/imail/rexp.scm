;;; -*-Scheme-*-
;;;
;;; $Id: rexp.scm,v 1.9 2000/04/13 17:57:57 cph Exp $
;;;
;;; Copyright (c) 2000 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;;; List-based Regular Expressions

(declare (usual-integrations))

(define (rexp? rexp)
  (or (string? rexp)
      (char-set? rexp)
      (and (pair? rexp)
	   (list? (cdr rexp))
	   (let ((one-arg
		  (lambda ()
		    (and (fix:= 1 (length (cdr rexp)))
			 (rexp? (cadr rexp))))))
	     (case (car rexp)
	       ((ALTERNATIVES SEQUENCE)
		(for-all? (cdr rexp) rexp?))
	       ((GROUP OPTIONAL * +)
		(and (one-arg)
		     (not (or (and (string? rexp)
				   (string-null? rexp))
			      (and (pair? rexp)
				   (memq (car rexp) boundary-rexp-types))))))
	       ((ANY-CHAR LINE-START LINE-END STRING-START STRING-END
			  WORD-EDGE NOT-WORD-EDGE WORD-START WORD-END
			  WORD-CHAR NOT-WORD-CHAR)
		(null? (cdr rexp)))
	       ((SYNTAX-CHAR NOT-SYNTAX-CHAR)
		(and (one-arg)
		     (assq (cadr rexp) syntax-type-alist)))
	       (else #f))))))

(define boundary-rexp-types
  '(LINE-START LINE-END STRING-START STRING-END WORD-EDGE NOT-WORD-EDGE
	       WORD-START WORD-END))

(define syntax-type-alist
  '((WHITESPACE . " ")
    (PUNCTUATION . ".")
    (WORD . "w")
    (SYMBOL . "_")
    (OPEN . "(")
    (CLOSE . ")")
    (QUOTE . "\'")
    (STRING-DELIMITER . "\"")
    (MATH-DELIMITER . "$")
    (ESCAPE . "\\")
    (CHAR-QUOTE . "/")
    (COMMENT-START . "<")
    (COMMENT-END . ">")))

(define (rexp-alternatives . rexps)
  `(ALTERNATIVES ,@rexps))

(define (rexp-sequence . rexps)
  (let ((rexps (simplify-sequence-args rexps)))
    (if (pair? rexps)
	(if (pair? (cdr rexps))
	    `(SEQUENCE ,@rexps)
	    (car rexps))
	"")))

(define (simplify-sequence-args rexps)
  (append-map (lambda (rexp)
		(cond ((and (string? rexp) (string-null? rexp))
		       '())
		      ((and (pair? rexp) (eq? 'SEQUENCE (car rexp)))
		       (cdr rexp))
		      ((and (pair? rexp) (eq? 'ALTERNATIVES (car rexp)))
		       (list (rexp-group rexp)))
		      (else
		       (list rexp))))
	      rexps))

(define (rexp-group . rexps)
  `(GROUP ,(apply rexp-sequence rexps)))

(define (rexp-optional . rexps)
  `(OPTIONAL ,(rexp-groupify (apply rexp-sequence rexps))))

(define (rexp* . rexps)
  `(* ,(rexp-groupify (apply rexp-sequence rexps))))

(define (rexp+ . rexps)
  `(+ ,(rexp-groupify (apply rexp-sequence rexps))))

(define (rexp-groupify rexp)
  (let ((no-group (lambda () (error "Expression can't be grouped:" rexp))))
    (cond ((string? rexp)
	   (case (string-length rexp)
	     ((0) (no-group))
	     ((1) rexp)
	     (else (rexp-group rexp))))
	  ((pair? rexp)
	   (cond ((memq (car rexp) boundary-rexp-types)
		  (no-group))
		 ((memq (car rexp) '(ALTERNATIVES SEQUENCE OPTIONAL * +))
		  (rexp-group rexp))
		 (else rexp)))
	  (else rexp))))

(define (rexp-any-char) `(ANY-CHAR))
(define (rexp-line-start) `(LINE-START))
(define (rexp-line-end) `(LINE-END))
(define (rexp-string-start) `(STRING-START))
(define (rexp-string-end) `(STRING-END))
(define (rexp-word-edge) `(WORD-EDGE))
(define (rexp-not-word-edge) `(NOT-WORD-EDGE))
(define (rexp-word-start) `(WORD-START))
(define (rexp-word-end) `(WORD-END))
(define (rexp-word-char) `(WORD-CHAR))
(define (rexp-not-word-char) `(NOT-WORD-CHAR))
(define (rexp-syntax-char type) `(SYNTAX-CHAR ,type))
(define (rexp-not-syntax-char type) `(NOT-SYNTAX-CHAR ,type))

(define (rexp-case-fold rexp)
  (cond ((string? rexp)
	 `(CASE-FOLD rexp))
	((and (pair? rexp)
	      (memq (car rexp) '(ALTERNATIVES SEQUENCE GROUP OPTIONAL * +))
	      (list? (cdr rexp)))
	 (cons (car rexp)
	       (map rexp-case-fold (cdr rexp))))
	(else rexp)))

(define (rexp-compile rexp)
  (re-compile-pattern (rexp->regexp rexp) #f))

(define (rexp->regexp rexp)
  (let ((lose (lambda () (error "Malformed rexp:" rexp))))
    (cond ((string? rexp)
	   (re-quote-string rexp))
	  ((char-set? rexp)
	   (char-set->regexp rexp))
	  ((and (pair? rexp) (list? (cdr rexp)))
	   (let ((one-arg
		  (lambda ()
		    (if (fix:= 1 (length (cdr rexp)))
			(cadr rexp)
			(lose))))
		 (rexp-args (lambda () (map rexp->regexp (cdr rexp)))))
	     (let ((rexp-arg (lambda () (rexp->regexp (one-arg))))
		   (syntax-type
		    (lambda ()
		      (let ((entry (assq (one-arg) syntax-type-alist)))
			(if entry
			    (cdr entry)
			    (lose))))))
	       (case (car rexp)
		 ((ALTERNATIVES) (separated-append (rexp-args) "\\|"))
		 ((SEQUENCE) (apply string-append (rexp-args)))
		 ((GROUP) (string-append "\\(" (rexp-arg) "\\)"))
		 ((OPTIONAL) (string-append (rexp-arg) "?"))
		 ((*) (string-append (rexp-arg) "*"))
		 ((+) (string-append (rexp-arg) "+"))
		 ((CASE-FOLD)
		  (let ((arg (one-arg)))
		    (if (string? arg)
			(case-fold-string arg)
			(lose))))
		 ((ANY-CHAR) ".")
		 ((LINE-START) "^")
		 ((LINE-END) "$")
		 ((STRING-START) "\\`")
		 ((STRING-END) "\\'")
		 ((WORD-EDGE) "\\b")
		 ((NOT-WORD-EDGE) "\\B")
		 ((WORD-START) "\\<")
		 ((WORD-END) "\\>")
		 ((WORD-CHAR) "\\w")
		 ((NOT-WORD-CHAR) "\\W")
		 ((SYNTAX-CHAR) (string-append "\\s" (syntax-type)))
		 ((NOT-SYNTAX-CHAR) (string-append "\\S" (syntax-type)))
		 (else (lose))))))
	  (else (lose)))))

(define (case-fold-string s)
  (let ((end (string-length s)))
    (let loop ((start 0) (parts '()))
      (let ((index
	     (substring-find-next-char-in-set s start end
					      char-set:alphabetic)))
	(if index
	    (loop (fix:+ index 1)
		  (cons* (let ((char (string-ref s index)))
			   (string-append "["
					  (string (char-upcase char))
					  (string (char-downcase char))
					  "]"))
			 (re-quote-string
			  (substring s start index))
			 parts))
	    (apply string-append (reverse! parts)))))))