#| -*-Scheme-*-

$Id: numpar.scm,v 14.9 1995/06/27 22:15:06 adams Exp $

Copyright (c) 1989-95 Massachusetts Institute of Technology

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

;;;; Number Parser
;;; package: (runtime number-parser)

(declare (usual-integrations))

(define (string->number string #!optional radix-default)
  (parse-chars (string->list string)
	       (if (default-object? radix-default) 10 radix-default)
	       'STRING->NUMBER))

(define (substring->number string start end #!optional radix-default)
  (parse-chars (substring->list string start end)
	       (if (default-object? radix-default) 10 radix-default)
	       'SUBSTRING->NUMBER))

(define (parse-chars chars radix-default name)
  (if (not (memv radix-default '(2 8 10 16)))
      (error:bad-range-argument radix-default name))
  (with-values (lambda () (parse-prefix chars))
    (lambda (chars radix-prefix exactness)
      ((if (eq? exactness 'INEXACT)
	   (lambda (number)
	     (and number
		  (exact->inexact number)))
	   identity-procedure)
       (let ((radix (or radix-prefix radix-default)))
	 (with-values (lambda () (parse-sign chars))
	   (lambda (chars real-sign)
	     (if (and real-sign (imaginary-suffix? chars))
		 (make-rectangular 0 real-sign)
		 (with-values (lambda () (parse-unsigned-real chars radix))
		   (lambda (chars real inexact?)
		     (let ((real
			    (combine-sign real-sign
					  real
					  exactness
					  inexact?)))
		       (cond ((or (null? chars) (not real))
			      real)
			     ((and real-sign (imaginary-suffix? chars))
			      (make-rectangular 0 real))
			     ((char=? #\@ (car chars))
			      (with-values
				  (lambda ()
				    (parse-signed-real (cdr chars)
						       radix
						       exactness))
				(lambda (chars angle)
				  (and angle
				       (null? chars)
				       (make-polar real angle)))))
			     (else
			      (parse-imaginary-tail chars
						    radix
						    exactness
						    real))))))))))))))

(define (parse-imaginary-tail chars radix exactness real)
  (with-values (lambda () (parse-sign chars))
    (lambda (chars sign)
      (and sign
	   (if (imaginary-suffix? chars)
	       (make-rectangular real sign)
	       (with-values (lambda () (parse-unsigned-real chars radix))
		 (lambda (chars imag inexact?)
		   (and imag
			(imaginary-suffix? chars)
			(make-rectangular
			 real
			 (combine-sign sign imag exactness inexact?))))))))))

(define (parse-prefix chars)
  (parse-1-prefix chars
    (lambda (chars radix)
      (parse-1-prefix chars
	(lambda (chars radix)
	  chars radix
	  (values '() false false))
	(lambda (chars exactness)
	  (values chars radix exactness))
	(lambda (chars)
	  (values chars radix false))))
    (lambda (chars exactness)
      (parse-1-prefix chars
	(lambda (chars radix)
	  (values chars radix exactness))
	(lambda (chars exactness)
	  chars exactness
	  (values '() false false))
	(lambda (chars)
	  (values chars false exactness))))
    (lambda (chars)
      (values chars false false))))

(define (parse-1-prefix chars if-radix if-exactness if-neither)
  (if (and (not (null? chars))
	   (char=? (car chars) #\#)
	   (not (null? (cdr chars))))
      (let ((char (cadr chars))
	    (chars* (cddr chars)))
	(cond ((char-ci=? #\i char) (if-exactness chars* 'INEXACT))
	      ((char-ci=? #\e char) (if-exactness chars* 'EXACT))
	      ((char-ci=? #\b char) (if-radix chars* 2))
	      ((char-ci=? #\o char) (if-radix chars* 8))
	      ((char-ci=? #\d char) (if-radix chars* 10))
	      ((char-ci=? #\x char) (if-radix chars* 16))
	      (else (if-neither chars))))
      (if-neither chars)))

(define (imaginary-suffix? chars)
  (and (not (null? chars))
       (null? (cdr chars))
       (or (char-ci=? (car chars) #\i)
	   (char-ci=? (car chars) #\j))))

(define (parse-signed-real chars radix exactness)
  (with-values (lambda () (parse-sign chars))
    (lambda (chars sign)
      (with-values (lambda () (parse-unsigned-real chars radix))
	(lambda (chars real inexact?)
	  (values chars (combine-sign sign real exactness inexact?)))))))

(define (parse-unsigned-real chars radix)
  (with-values (lambda () (parse-integer chars radix))
    (lambda (chars* numerator inexact?)
      (cond ((not numerator)
	     (if (= radix 10)
		 (parse-decimal chars)
		 (values chars false false)))
	    ((and (not (null? chars*))
		  (char=? #\/ (car chars*)))
	     (with-values (lambda () (parse-integer (cdr chars*) radix))
	       (lambda (chars* denominator inexact?*)
		 (if denominator
		     (values chars*
			     (/ numerator denominator)
			     (or inexact? inexact?*))
		     (values chars false false)))))
	    (else
	     (values chars* numerator inexact?))))))

(define (parse-integer chars radix)
  (if (or (null? chars)
	  (not (char->digit (car chars) radix)))
      (values chars false false)
      (let loop ((chars* (cdr chars)) (n (char->digit (car chars) radix)))
	(if (null? chars*)
	    (values chars* n false)
	    (let ((digit (char->digit (car chars*) radix)))
	      (cond (digit
		     (loop (cdr chars*) (+ (* n radix) digit)))
		    ((dot-or-exponent? (car chars*))
		     (values chars false false))
		    ((char=? (car chars*) #\#)
		     (let loop ((chars* (cdr chars*)) (n (* n radix)))
		       (cond ((null? chars*)
			      (values chars* n true))
			     ((char=? (car chars*) #\#)
			      (loop (cdr chars*) (* n radix)))
			     ((dot-or-exponent? (car chars*))
			      (values chars false false))
			     (else
			      (values chars* n true)))))
		    (else
		     (values chars* n false))))))))

(define (dot-or-exponent? char)
  (or (char=? #\. char)
      (char-ci=? #\e char)
      (char-ci=? #\s char)
      (char-ci=? #\f char)
      (char-ci=? #\d char)
      (char-ci=? #\l char)))

(define (parse-decimal chars)
  (cond ((null? chars)
	 (values chars false false))
	((char=? #\. (car chars))
	 (let ((chars* (cdr chars)))
	   (if (and (not (null? chars*))
		    (char->digit (car chars*) 10))
	       (with-values (lambda () (parse-decimal-fraction chars*))
		 (lambda (chars x)
		   (parse-decimal-suffix chars x true)))
	       (values chars false false))))
	(else
	 (let ((digit (char->digit (car chars) 10)))
	   (if digit
	       (parse-decimal-integer (cdr chars) digit)
	       (values chars false false))))))

(define (parse-decimal-integer chars n)
  (if (null? chars)
      (parse-decimal-suffix '() n false)
      (let ((digit (char->digit (car chars) 10)))
	(if digit
	    (parse-decimal-integer (cdr chars) (+ (* n 10) digit))
	    (cond ((char=? #\. (car chars))
		   (with-values
		       (lambda () (parse-decimal-fraction (cdr chars)))
		     (lambda (chars fraction)
		       (parse-decimal-suffix chars (+ n fraction) true))))
		  ((char=? #\# (car chars))
		   (let loop ((chars (cdr chars)) (n (* n 10)))
		     (cond ((null? chars)
			    (parse-decimal-suffix '() n true))
			   ((char=? #\# (car chars))
			    (loop (cdr chars) (* n 10)))
			   ((char=? #\. (car chars))
			    (let loop ((chars (cdr chars)))
			      (if (and (not (null? chars))
				       (char=? #\# (car chars)))
				  (loop (cdr chars))
				  (parse-decimal-suffix chars n true))))
			   (else
			    (parse-decimal-suffix chars n true)))))
		  (else
		   (parse-decimal-suffix chars n false)))))))

(define (parse-decimal-fraction chars)
  (let loop ((chars chars) (f 0) (exponent 0))
    (let ((done
	   (lambda (chars)
	     (values chars (* f (expt 10 exponent))))))
      (if (null? chars)
	  (done '())
	  (let ((digit (char->digit (car chars) 10)))
	    (if digit
		(loop (cdr chars) (+ (* f 10) digit) (-1+ exponent))
		(let loop ((chars chars))
		  (cond ((not (char=? #\# (car chars))) (done chars))
			((null? (cdr chars)) (done '()))
			(else (loop (cdr chars)))))))))))

(define (parse-decimal-suffix chars x inexact?)
  (let ((finish
	 (lambda (chars exponent)
	   (if exponent
	       (values chars (* x (expt 10 exponent)) true)
	       (values chars x inexact?)))))
    (if (and (not (null? chars))
	     (or (char-ci=? #\e (car chars))
		 (char-ci=? #\s (car chars))
		 (char-ci=? #\f (car chars))
		 (char-ci=? #\d (car chars))
		 (char-ci=? #\l (car chars))))
	(with-values (lambda () (parse-sign (cdr chars)))
	  (lambda (chars* sign)
	    (let ((digit
		   (and (not (null? chars*))
			(char->digit (car chars*) 10))))
	      (if digit
		  (let loop ((chars* (cdr chars*)) (n digit))
		    (let ((digit
			   (and (not (null? chars*))
				(char->digit (car chars*) 10))))
		      (if digit
			  (loop (cdr chars*) (+ (* n 10) digit))
			  (finish chars* (if (eqv? -1 sign) (- n) n)))))
		  (finish chars false)))))
	(finish chars false))))

(define (parse-sign chars)
  (cond ((null? chars) (values chars false))
	((char=? (car chars) #\+) (values (cdr chars) 1))
	((char=? (car chars) #\-) (values (cdr chars) -1))
	(else (values chars false))))

(define (combine-sign sign real exactness inexact?)
  (let ((real (if (and real (eqv? -1 sign)) (- real) real)))
    (if (and inexact?
	     (not (eq? exactness 'EXACT)))
	(exact->inexact real)
	real)))