#| -*-Scheme-*-

$Id: test-parser.scm,v 1.5 2003/02/14 18:25:21 cph Exp $

Copyright 2001 Massachusetts Institute of Technology

This file is part of MIT Scheme.

MIT Scheme is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

MIT Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT Scheme; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

|#

(define (test-matcher matcher string)
  (let ((buffer (string->parser-buffer string)))
    (and (matcher buffer)
	 (if (peek-parser-buffer-char buffer)
	     (get-parser-buffer-pointer buffer)
	     #t))))

(define (test-parser parser string)
  (let ((buffer (string->parser-buffer string)))
    (let ((v (parser buffer)))
      (and v
	   (if (peek-parser-buffer-char buffer)
	       (begin
		 (write-string "Lose: ")
		 (write (get-parser-buffer-pointer buffer))
		 (newline)
		 #f)
	       v)))))

(define parse-list
  (*parser
   (encapsulate vector->list
     (seq (noise (string "("))
	  (noise (* (alphabet char-set:whitespace)))
	  (? (seq parse-element
		  (* (seq (noise (+ (alphabet char-set:whitespace)))
			  parse-element))))
	  (noise (* (alphabet char-set:whitespace)))
	  (noise (string ")"))))))

(define parse-element
  (*parser (alt parse-num-10 parse-identifier parse-list)))

(define parse-identifier
  (*parser (map intern (match match-identifier))))

(define parse-num-10
  (*parser (map string->number (match match-num-10))))

(define parse-whitespace
  (*parser (noise (+ (alphabet char-set:whitespace)))))

(define parse-optional-whitespace
  (*parser (noise (* (alphabet char-set:whitespace)))))

(define match-identifier
  (let* ((initial-alphabet
	  (char-set-union char-set:alphabetic
			  (string->char-set "!$%&*/:<=>?^_~")))
	 (subsequent-alphabet
	  (char-set-union initial-alphabet
			  char-set:numeric
			  (string->char-set "+-.@"))))
    (*matcher
     (alt (seq (alphabet initial-alphabet)
	       (* (alphabet subsequent-alphabet)))
	  (string "+")
	  (string "-")
	  (string "...")))))

(define match-num-10
  (*matcher
   (seq (? (alt (seq (string-ci "#d")
		     (? (alt (string-ci "#i")
			     (string-ci "#e"))))
		(seq (alt (string-ci "#i")
			  (string-ci "#e"))
		     (? (string-ci "#d")))))
	match-complex-10)))

(define match-complex-10
  (*matcher
   (alt (seq match-ureal-10
	     (? (alt match-angle-10
		     match-imaginary-10)))
	(seq (alphabet (string->char-set "+-"))
	     (alt (seq match-ureal-10
		       (? (alt match-angle-10
			       match-imaginary-10
			       (string-ci "i"))))
		  (string-ci "i"))))))

(define match-angle-10
  (*matcher
   (seq (string "@")
	(? (alphabet (string->char-set "+-")))
	match-ureal-10)))

(define match-imaginary-10
  (*matcher
   (seq (alphabet (string->char-set "+-"))
	(? match-ureal-10)
	(string-ci "i"))))

(define match-ureal-10
  (*matcher
   (alt (seq (+ (alphabet char-set:numeric))
	     (? (alt (seq (string ".")
			  (* (alphabet char-set:numeric))
			  (* (string "#"))
			  (? match-exponent-10))
		     (seq (string "/")
			  (+ (alphabet char-set:numeric))
			  (* (string "#")))
		     (seq (+ (string "#"))
			  (? (alt (seq (string ".")
				       (* (string "#"))
				       (? match-exponent-10))
				  (seq (string "/")
				       (+ (alphabet char-set:numeric))
				       (* (string "#")))
				  match-exponent-10)))
		     match-exponent-10)))
	(seq (string ".")
	     (+ (alphabet char-set:numeric))
	     (* (string "#"))
	     (? match-exponent-10)))))

(define match-exponent-10
  (*matcher
   (seq (alphabet (string->char-set "esfdlESFDL"))
	(? (alphabet (string->char-set "+-")))
	(+ (alphabet char-set:numeric)))))