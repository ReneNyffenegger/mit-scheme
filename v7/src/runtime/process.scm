#| -*-Scheme-*-

$Id: process.scm,v 1.22 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1989-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; Subprocess Support
;;; package: (runtime subprocess)

(declare (usual-integrations))

(define subprocesses)
(define scheme-subprocess-environment)
(define global-status-tick)

(define (initialize-package!)
  (reset-package!)
  (add-event-receiver! event:after-restore reset-package!)
  (add-event-receiver! event:before-exit delete-all-processes))

(define (reset-package!)
  (set! subprocesses '())
  (set! scheme-subprocess-environment ((ucode-primitive scheme-environment 0)))
  (set! global-status-tick (cons false false))
  unspecific)

(define (delete-all-processes)
  (for-each subprocess-delete subprocesses))

(define (subprocess-list)
  (list-copy subprocesses))

(define-structure (subprocess
		   (constructor %make-subprocess
				(filename arguments index pty-master
					  input-channel output-channel))
		   (conc-name subprocess-))
  (filename false read-only true)
  (arguments false read-only true)
  index
  pty-master
  input-channel
  output-channel
  (id ((ucode-primitive process-id 1) index) read-only true)
  (%i/o-port false)
  (%status false)
  (exit-reason false)
  (%status-tick false)
  (properties (make-1d-table) read-only true))

(define (subprocess-get process key)
  (1d-table/get (subprocess-properties process) key false))

(define (subprocess-put! process key datum)
  (1d-table/put! (subprocess-properties process) key datum))

(define (subprocess-remove! process key)
  (1d-table/remove! (subprocess-properties process) key))

(define (subprocess-i/o-port process #!optional
			     input-line-translation output-line-translation)
  (let* ((input-line-translation
	  (if (default-object? input-line-translation)
	      'DEFAULT
	      input-line-translation))
	 (output-line-translation
	  (if (default-object? output-line-translation)
	      input-line-translation
	      output-line-translation)))
    (without-interrupts
     (lambda ()
       (or (subprocess-%i/o-port process)
	   (let ((port
		  (let ((input-channel (subprocess-input-channel process))
			(output-channel (subprocess-output-channel process)))
		    (if input-channel
			(if output-channel
			    (make-generic-i/o-port input-channel output-channel
						   512 512
						   input-line-translation
						   output-line-translation)
			    (make-generic-input-port input-channel
						     512
						     input-line-translation))
			(if output-channel
			    (make-generic-output-port output-channel
						      512
						      output-line-translation)
			    false)))))
	     (set-subprocess-%i/o-port! process port)
	     port))))))

(define (subprocess-input-port process)
  (let ((port (subprocess-i/o-port process)))
    (and (input-port? port)
	 port)))

(define (subprocess-output-port process)
  (let ((port (subprocess-i/o-port process)))
    (and (output-port? port)
	 port)))

(define (close-subprocess-i/o process)
  (without-interrupts (lambda () (%close-subprocess-i/o process))))

(define (%close-subprocess-i/o process)
  ;; Assumes that interrupts are locked.
  (cond ((subprocess-%i/o-port process)
	 => (lambda (port)
	      (set-subprocess-%i/o-port! process false)
	      (set-subprocess-input-channel! process false)
	      (set-subprocess-output-channel! process false)
	      (close-port port))))
  (cond ((subprocess-input-channel process)
	 => (lambda (input-channel)
	      (set-subprocess-input-channel! process false)
	      (channel-close input-channel))))
  (cond ((subprocess-output-channel process)
	 => (lambda (output-channel)
	      (set-subprocess-output-channel! process false)
	      (channel-close output-channel))))
  (cond ((subprocess-pty-master process)
	 => (lambda (pty-master)
	      (set-subprocess-pty-master! process false)
	      (channel-close pty-master)))))

(define (make-subprocess filename arguments environment
			 ctty stdin stdout stderr
			 pty-master input-channel output-channel)
  (let ((process
	 (let ((ctty-allowed? (string? ctty)))
	   (define-integrable (convert-stdio-arg stdio)
	     (cond ((not stdio) false)
		   ((eq? stdio 'INHERIT) -1)
		   ((and ctty-allowed? (eq? stdio 'CTTY)) -2)
		   ((channel? stdio) (channel-descriptor stdio))
		   (else
		    (error:wrong-type-argument stdio "process I/O channel"
					       'MAKE-SUBPROCESS))))
	   (let ((working-directory #f)
		 (ctty
		  (cond ((eq? ctty 'BACKGROUND) -1)
			((eq? ctty 'FOREGROUND) -2)
			((or (not ctty) (string? ctty)) ctty)
			(else
			 (error:wrong-type-argument
			  ctty
			  "process controlling terminal"
			  'MAKE-SUBPROCESS))))
		 (stdin (convert-stdio-arg stdin))
		 (stdout (convert-stdio-arg stdout))
		 (stderr (convert-stdio-arg stderr)))
	     (if (pair? environment)
		 (begin
		   (set! working-directory (cdr environment))
		   (set! environment (car environment))))
	     (without-interrupts
	      (lambda ()
		(let ((index
		       (os/make-subprocess filename arguments environment
					   working-directory ctty
					   stdin stdout stderr)))
		  (let ((process
			 (%make-subprocess filename arguments index pty-master
					   input-channel output-channel)))
		    (set-subprocess-%status!
		     process
		     ((ucode-primitive process-status 1) index))
		    (set-subprocess-exit-reason!
		     process
		     ((ucode-primitive process-reason 1) index))
		    (set! subprocesses (cons process subprocesses))
		    process))))))))
    (if (and (eq? ctty 'FOREGROUND)
	     (eqv? (%subprocess-status process) 0))
	(subprocess-continue-foreground process))
    process))

(define (subprocess-delete process)
  (without-interrupts
   (lambda ()
     (if (subprocess-index process)
	 (begin
	   ((ucode-primitive process-delete 1) (subprocess-index process))
	   (set! subprocesses (delq! process subprocesses))
	   (set-subprocess-index! process false)
	   (%close-subprocess-i/o process))))))

(define (subprocess-status process)
  (convert-subprocess-status (%subprocess-status process)))

(define (subprocess-wait process)
  (let loop ()
    ((ucode-primitive process-wait 1) (subprocess-index process))
    (let ((status (%subprocess-status process)))
      (if (eqv? status 0)
	  (loop)
	  (convert-subprocess-status status)))))

(define (subprocess-continue-foreground process)
  (let loop ()
    ((ucode-primitive process-continue-foreground 1)
     (subprocess-index process))
    (let ((status (%subprocess-status process)))
      (if (eqv? status 0)
	  (loop)
	  (convert-subprocess-status status)))))

(define (%subprocess-status process)
  (without-interrupts
   (lambda ()
     (let ((index (subprocess-index process)))
       (if (and index ((ucode-primitive process-status-sync 1) index))
	   (begin
	     (set-subprocess-%status!
	      process
	      ((ucode-primitive process-status 1) index))
	     (set-subprocess-exit-reason!
	      process
	      ((ucode-primitive process-reason 1) index))
	     (set-subprocess-%status-tick! process false))))))
  (subprocess-%status process))

(define (subprocess-status-tick process)
  (or (subprocess-%status-tick process)
      (let ((tick (cons false false)))
	(set-subprocess-%status-tick! process tick)
	tick)))

(define (subprocess-global-status-tick)
  (without-interrupts
   (lambda ()
     (if ((ucode-primitive process-status-sync-all 0))
	 (let ((tick (cons false false)))
	   (set! global-status-tick tick)
	   tick)
	 global-status-tick))))

(define (convert-subprocess-status status)
  (case status
    ((0) 'RUNNING)
    ((1) 'STOPPED)
    ((2) 'EXITED)
    ((3) 'SIGNALLED)
    (else (error "Illegal process status:" status))))

(define (subprocess-job-control-status process)
  (let ((n
	 ((ucode-primitive process-job-control-status 1)
	  (subprocess-index process))))
    (case n
      ((0) 'NO-CTTY)
      ((1) 'UNRELATED-CTTY)
      ((2) 'NO-JOB-CONTROL)
      ((3) 'JOB-CONTROL)
      (else (error "Illegal process job-control status:" n)))))

(define (handle-subprocess-status-change)
  (if (eq? 'NT microcode-id/operating-system)
      (for-each (lambda (process)
		  (if (memq (subprocess-status process) '(EXITED SIGNALLED))
		      (close-subprocess-i/o process)))
		subprocesses)))

(define-integrable subprocess-job-control-available?
  (ucode-primitive os-job-control? 0))

(define (subprocess-continue-background process)
  ((ucode-primitive process-continue-background 1) (subprocess-index process)))

(define (subprocess-signal process signal)
  ((ucode-primitive process-signal 2) (subprocess-index process) signal))

(define (subprocess-kill process)
  ((ucode-primitive process-kill 1) (subprocess-index process))
  (maybe-close-subprocess-i/o process))

(define (subprocess-interrupt process)
  ((ucode-primitive process-interrupt 1) (subprocess-index process)))

(define (subprocess-quit process)
  ((ucode-primitive process-quit 1) (subprocess-index process)))

(define (subprocess-hangup process)
  ((ucode-primitive process-hangup 1) (subprocess-index process))
  (maybe-close-subprocess-i/o process))

(define (maybe-close-subprocess-i/o process)
  (if (eq? 'NT microcode-id/operating-system)
      (close-subprocess-i/o process)))

(define (subprocess-stop process)
  ((ucode-primitive process-stop 1) (subprocess-index process)))

(define (start-batch-subprocess filename arguments environment)
  (make-subprocess filename arguments environment
		   false false false false
		   false false false))

(define (start-subprocess-in-background filename arguments environment)
  (make-subprocess filename arguments environment
		   'BACKGROUND 'INHERIT 'INHERIT 'INHERIT
		   false false false))

(define (run-subprocess-in-foreground filename arguments environment)
  (make-subprocess filename arguments environment
		   'FOREGROUND 'INHERIT 'INHERIT 'INHERIT
		   false false false))

(define (start-pipe-subprocess filename arguments environment)
  (with-values make-pipe
    (lambda (child-read parent-write)
      (with-values make-pipe
	(lambda (parent-read child-write)
	  (let ((process
		 (make-subprocess filename arguments environment
				  false child-read child-write child-write
				  false parent-read parent-write)))
	    (channel-close child-read)
	    (channel-close child-write)
	    process))))))

(define (start-pty-subprocess filename arguments environment)
  (with-values open-pty-master
    (lambda (master-channel master-name slave-name)
      master-name
      (make-subprocess filename arguments environment
		       slave-name 'CTTY 'CTTY 'CTTY
		       master-channel master-channel master-channel))))