#| -*-Scheme-*-

$Id: output.scm,v 14.15 1993/10/21 11:49:47 cph Exp $

Copyright (c) 1988-93 Massachusetts Institute of Technology

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

;;;; Output
;;; package: (runtime output-port)

(declare (usual-integrations))

;;;; Output Ports

(define (output-port/write-char port char)
  ((output-port/operation/write-char port) port char))

(define (output-port/write-string port string)
  ((output-port/operation/write-string port) port string))

(define (output-port/write-substring port string start end)
  ((output-port/operation/write-substring port) port string start end))

(define (output-port/write-object port object)
  (unparse-object/internal object port 0 true (current-unparser-table)))

(define (output-port/flush-output port)
  ((output-port/operation/flush-output port) port))

(define (output-port/discretionary-flush port)
  ((output-port/operation/discretionary-flush port) port))

(define (output-port/x-size port)
  (or (let ((operation (port/operation port 'X-SIZE)))
	(and operation
	     (operation port)))
      79))

(define (output-port/y-size port)
  (let ((operation (port/operation port 'Y-SIZE)))
    (and operation
	 (operation port))))

;;;; Output Procedures

(define (newline #!optional port)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port))))
    (output-port/write-char port #\newline)
    (output-port/discretionary-flush port)))

(define (fresh-line #!optional port)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port))))
    (let ((operation (port/operation port 'FRESH-LINE)))
      (if operation
	  (operation port)
	  (output-port/write-char port #\newline)))
    (output-port/discretionary-flush port)))

(define (write-char char #!optional port)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port))))
    (output-port/write-char port char)
    (output-port/discretionary-flush port)))

(define (write-string string #!optional port)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port))))
    (output-port/write-string port string)
    (output-port/discretionary-flush port)))

(define (wrap-custom-operation-0 operation-name)
  (lambda (#!optional port)
    (let ((port
	   (if (default-object? port)
	       (current-output-port)
	       (guarantee-output-port port))))
      (let ((operation (port/operation port operation-name)))
	(if operation
	    (begin
	      (operation port)
	      (output-port/discretionary-flush port)))))))

(define beep
  (wrap-custom-operation-0 'BEEP))

(define clear
  (wrap-custom-operation-0 'CLEAR))

(define (display object #!optional port unparser-table)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port)))
	(unparser-table
	 (if (default-object? unparser-table)
	     (current-unparser-table)
	     (guarantee-unparser-table unparser-table))))
    (if (string? object)
	(output-port/write-string port object)
	(unparse-object/internal object port 0 false unparser-table))
    (output-port/discretionary-flush port)))

(define (write object #!optional port unparser-table)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port)))
	(unparser-table
	 (if (default-object? unparser-table)
	     (current-unparser-table)
	     (guarantee-unparser-table unparser-table))))
    (unparse-object/internal object port 0 true unparser-table)
    (output-port/discretionary-flush port)))

(define (write-line object #!optional port unparser-table)
  (let ((port
	 (if (default-object? port)
	     (current-output-port)
	     (guarantee-output-port port)))
	(unparser-table
	 (if (default-object? unparser-table)
	     (current-unparser-table)
	     (guarantee-unparser-table unparser-table))))
    (output-port/write-char port #\Newline)
    (unparse-object/internal object port 0 true unparser-table)
    (output-port/discretionary-flush port)))

(define (flush-output #!optional port)
  (output-port/flush-output
   (if (default-object? port)
       (current-output-port)
       (guarantee-output-port port))))