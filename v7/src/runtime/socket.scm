#| -*-Scheme-*-

$Id: socket.scm,v 1.7 1996/05/17 17:49:45 cph Exp $

Copyright (c) 1990-96 Massachusetts Institute of Technology

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

;;;; Socket Support
;;; package: (runtime socket)

(declare (usual-integrations))

(define (open-tcp-stream-socket host-name service)
  (socket-ports (open-tcp-stream-socket-channel host-name service)))

(define (open-unix-stream-socket filename)
  (socket-ports (open-unix-stream-socket-channel filename)))

(define (socket-ports channel)
  (let ((port (make-generic-i/o-port channel channel 64 64)))
    (values port port)))

(define (open-tcp-stream-socket-channel host-name service)
  (let ((host (vector-ref (get-host-by-name host-name) 0))
	(port (tcp-service->port service)))
    (without-background-interrupts
     (lambda ()
       (make-channel
	((ucode-primitive open-tcp-stream-socket 2) host port))))))

(define (get-host-by-name host-name)
  (with-thread-timer-stopped
    (lambda ()
      ((ucode-primitive get-host-by-name 1) host-name))))

(define (open-unix-stream-socket-channel filename)
  (without-background-interrupts
   (lambda ()
     (make-channel ((ucode-primitive open-unix-stream-socket 1) filename)))))

(define (open-tcp-server-socket service)
  (without-background-interrupts
   (lambda ()
     (make-channel
      ((ucode-primitive open-tcp-server-socket 1)
       (tcp-service->port service))))))

(define (tcp-service->port service)
  (if (exact-nonnegative-integer? service)
      service
      ((ucode-primitive get-service-by-name 2) service "tcp")))

(define (close-tcp-server-socket server-socket)
  (channel-close server-socket))

(define (allocate-host-address)
  (string-allocate ((ucode-primitive host-address-length 0))))

(define (tcp-server-connection-accept server-socket block?)
  (let ((peer-address (allocate-host-address)))
    (let ((channel
	   (with-channel-blocking server-socket false
	     (lambda ()
	       (let loop ()
		 (or (without-background-interrupts
		      (lambda ()
			(let ((descriptor
			       ((ucode-primitive tcp-server-connection-accept
						 2)
				(channel-descriptor server-socket)
				peer-address)))
			  (and descriptor
			       (make-channel descriptor)))))
		     (and block?
			  (begin
			    (if (other-running-threads?)
				(yield-current-thread))
			    (loop)))))))))
      (if channel
	  (let ((port (make-generic-i/o-port channel channel 64 64)))
	    (values port port peer-address))
	  (values false false false)))))