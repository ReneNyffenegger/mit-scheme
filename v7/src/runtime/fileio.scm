#| -*-Scheme-*-

$Id: fileio.scm,v 1.7 1993/10/21 14:52:36 cph Exp $

Copyright (c) 1991-1993 Massachusetts Institute of Technology

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

;;;; File I/O Ports
;;; package: (runtime file-i/o-port)

(declare (usual-integrations))

(define (initialize-package!)
  (let ((input-operations
	 `((BUFFERED-INPUT-CHARS ,operation/buffered-input-chars)
	   (CHAR-READY? ,operation/char-ready?)
	   (CHARS-REMAINING ,operation/chars-remaining)
	   (DISCARD-CHAR ,operation/discard-char)
	   (DISCARD-CHARS ,operation/discard-chars)
	   (EOF? ,operation/eof?)
	   (INPUT-BLOCKING-MODE ,operation/input-blocking-mode)
	   (INPUT-BUFFER-SIZE ,operation/input-buffer-size)
	   (INPUT-CHANNEL ,operation/input-channel)
	   (INPUT-TERMINAL-MODE ,operation/input-terminal-mode)
	   (LENGTH ,operation/length)
	   (PEEK-CHAR ,operation/peek-char)
	   (READ-CHAR ,operation/read-char)
	   (READ-CHARS ,operation/read-chars)
	   (READ-STRING ,operation/read-string)
	   (READ-SUBSTRING ,operation/read-substring)
	   (REST->STRING ,operation/rest->string)
	   (SET-INPUT-BLOCKING-MODE ,operation/set-input-blocking-mode)
	   (SET-INPUT-BUFFER-SIZE ,operation/set-input-buffer-size)
	   (SET-INPUT-TERMINAL-MODE ,operation/set-input-terminal-mode)))
	(output-operations
	 `((BUFFERED-OUTPUT-CHARS ,operation/buffered-output-chars)
	   (FLUSH-OUTPUT ,operation/flush-output)
	   (OUTPUT-BLOCKING-MODE ,operation/output-blocking-mode)
	   (OUTPUT-BUFFER-SIZE ,operation/output-buffer-size)
	   (OUTPUT-CHANNEL ,operation/output-channel)
	   (OUTPUT-TERMINAL-MODE ,operation/output-terminal-mode)
	   (SET-OUTPUT-BLOCKING-MODE ,operation/set-output-blocking-mode)
	   (SET-OUTPUT-BUFFER-SIZE ,operation/set-output-buffer-size)
	   (SET-OUTPUT-TERMINAL-MODE ,operation/set-output-terminal-mode)
	   (WRITE-CHAR ,operation/write-char)
	   (WRITE-STRING ,operation/write-string)
	   (WRITE-SUBSTRING ,operation/write-substring)))
	(other-operations
	 `((CLOSE ,operation/close)
	   (PATHNAME ,operation/pathname)
	   (WRITE-SELF ,operation/write-self)
	   (TRUENAME ,operation/truename))))
    (set! input-file-template
	  (make-input-port (append input-operations
				   other-operations)
			   false))
    (set! output-file-template
	  (make-output-port (append output-operations
				    other-operations)
			    false))
    (set! i/o-file-template
	  (make-i/o-port (append input-operations
				 output-operations
				 other-operations)
			 false)))
  unspecific)

(define input-file-template)
(define output-file-template)
(define i/o-file-template)

(define input-buffer-size 512)
(define output-buffer-size 512)

(define (open-input-file filename)
  (let* ((pathname (merge-pathnames filename))
	 (channel (file-open-input-channel (->namestring pathname)))
	 (port
	  (port/copy
	   input-file-template
	   (make-file-state
	    (make-input-buffer channel
			       input-buffer-size
			       (pathname-newline-translation pathname)
			       (pathname-end-of-file-marker/input pathname))
	    false
	    pathname))))
    (set-channel-port! channel port)
    port))

(define (open-output-file filename #!optional append?)
  (let* ((pathname (merge-pathnames filename))
	 (channel
	  (let ((filename (->namestring pathname)))
	    (if (and (not (default-object? append?)) append?)
		(file-open-append-channel filename)
		(file-open-output-channel filename))))
	 (port
	  (port/copy
	   output-file-template
	   (make-file-state
	    false
	    (make-output-buffer channel
				output-buffer-size
				(pathname-newline-translation pathname)
				(pathname-end-of-file-marker/output pathname))
	    pathname))))
    (set-channel-port! channel port)
    port))

(define (open-i/o-file filename)
  (let* ((pathname (merge-pathnames filename))
	 (channel (file-open-io-channel (->namestring pathname)))
	 (translation (pathname-newline-translation pathname))
	 (port
	  (port/copy
	   i/o-file-template
	   (make-file-state
	    (make-input-buffer channel
			       input-buffer-size
			       translation
			       (pathname-end-of-file-marker/input pathname))
	    (make-output-buffer channel
				output-buffer-size
				translation
				(pathname-end-of-file-marker/output pathname))
	    pathname))))
    (set-channel-port! channel port)
    port))

(define (pathname-newline-translation pathname)
  (let ((end-of-line (pathname-end-of-line-string pathname)))
    (and (not (string=? "\n" end-of-line))
	 end-of-line)))

(define (open-binary-input-file filename)
  (let* ((pathname (merge-pathnames filename))
	 (channel (file-open-input-channel (->namestring pathname)))
	 (port
	  (port/copy input-file-template
		     (make-file-state (make-input-buffer channel
							 input-buffer-size
							 false
							 false)
				      false
				      pathname))))
    (set-channel-port! channel port)
    port))

(define (open-binary-output-file filename #!optional append?)
  (let* ((pathname (merge-pathnames filename))
	 (channel
	  (let ((filename (->namestring pathname)))
	    (if (and (not (default-object? append?)) append?)
		(file-open-append-channel filename)
		(file-open-output-channel filename))))
	 (port
	  (port/copy output-file-template
		     (make-file-state false
				      (make-output-buffer channel
							  output-buffer-size
							  false
							  false)
				      pathname))))
    (set-channel-port! channel port)
    port))

(define (open-binary-i/o-file filename)
  (let* ((pathname (merge-pathnames filename))
	 (channel (file-open-io-channel (->namestring pathname)))
	 (port
	  (port/copy i/o-file-template
		     (make-file-state (make-input-buffer channel
							 input-buffer-size
							 false
							 false)
				      (make-output-buffer channel
							  output-buffer-size
							  false
							  false)
				      pathname))))
    (set-channel-port! channel port)
    port))

(define ((make-call-with-file open) input-specifier receiver)
  (let ((port (open input-specifier)))
    (let ((value (receiver port)))
      (close-port port)
      value)))

(define call-with-input-file 
  (make-call-with-file open-input-file))

(define call-with-binary-input-file
  (make-call-with-file open-binary-input-file))

(define call-with-output-file
  (make-call-with-file open-output-file))

(define call-with-binary-output-file
  (make-call-with-file open-binary-output-file))

(define ((make-with-input-from-file call) input-specifier thunk)
  (call input-specifier
    (lambda (port)
      (with-input-from-port port thunk))))

(define with-input-from-file
  (make-with-input-from-file call-with-input-file))

(define with-input-from-binary-file
  (make-with-input-from-file call-with-binary-input-file))

(define ((make-with-output-to-file call) output-specifier thunk)
  (call output-specifier
    (lambda (port)
      (with-output-to-port port thunk))))

(define with-output-to-file
  (make-with-output-to-file call-with-output-file))

(define with-output-to-binary-file
  (make-with-output-to-file call-with-binary-output-file))

(define-structure (file-state (type vector)
			      (conc-name file-state/))
  ;; First two elements of this vector are required by the generic
  ;; I/O port operations.
  (input-buffer false read-only true)
  (output-buffer false read-only true)
  (pathname false read-only true))

(define (operation/length port)
  (file-length (operation/input-channel port)))

(define (operation/pathname port)
  (file-state/pathname (port/state port)))

(define operation/truename
  ;; This works for unix because truename and pathname are the same.
  ;; On operating system where they differ, there must be support to
  ;; determine the truename.
  operation/pathname)

(define (operation/write-self port output-port)
  (write-string " for file: " output-port)
  (write (operation/truename port) output-port))

(define (operation/rest->string port)
  ;; This operation's intended purpose is to snarf an entire file in
  ;; a single gulp, exactly what a text editor would need.
  (let ((buffer (file-state/input-buffer (port/state port))))
    (let ((remaining (input-buffer/chars-remaining buffer))
	  (fill-buffer
	   (lambda (string)
	     (let ((length (string-length string)))
	       (let loop ()
		 (or (input-buffer/read-substring buffer string 0 length)
		     (loop)))))))
      (if remaining
	  (let ((result (make-string remaining)))
	    (let ((n (fill-buffer result)))
	      (if (< n remaining)
		  (substring result 0 n)
		  result)))
	  (apply string-append
		 (let loop ()
		   (let ((string (make-string input-buffer-size)))
		     (let ((n (fill-buffer string)))
		       (cond ((zero? n) '())
			     ((< n remaining) (list (substring string 0 n)))
			     (else (cons string (loop))))))))))))