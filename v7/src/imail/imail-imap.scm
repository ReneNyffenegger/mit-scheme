;;; -*-Scheme-*-
;;;
;;; $Id: imail-imap.scm,v 1.34 2000/05/15 19:01:50 cph Exp $
;;;
;;; Copyright (c) 1999-2000 Massachusetts Institute of Technology
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

;;;; IMAIL mail reader: IMAP back end

(declare (usual-integrations))

;;;; URL

(define-class (<imap-url>
	       (constructor %make-imap-url (user-id host port mailbox)))
    (<url>)
  ;; User name to connect as.
  (user-id define accessor)
  ;; Name or IP address of host to connect to.
  (host define accessor)
  ;; Port number to connect to.
  (port define accessor)
  ;; Name of mailbox to access.
  (mailbox define accessor))

(define (make-imap-url user-id host port mailbox)
  (save-url (%make-imap-url user-id host port mailbox)))

(define-url-protocol "imap" <imap-url>
  (let ((//server/
	 (optional-parser
	  (sequence-parser (noise-parser (string-matcher "//"))
			   imap:parse:server
			   (noise-parser (string-matcher "/")))))
	(mbox (optional-parser imap:parse:simple-message)))
    (lambda (string)
      (let ((end (string-length string)))
	(let ((pv1 (//server/ string 0 end)))
	  (let ((pv2
		 (or (parse-substring mbox string (car pv1) end)
		     (error:bad-range-argument string 'STRING->URL))))
	    (%make-imap-url (parser-token pv1 'USER-ID)
			    (parser-token pv1 'HOST)
			    (let ((port (parser-token pv1 'PORT)))
			      (and port
				   (string->number port)))
			    (parser-token pv2 'MAILBOX))))))))

(define-method url-body ((url <imap-url>))
  (string-append
   (let ((user-id (imap-url-user-id url))
	 (host (imap-url-host url))
	 (port (imap-url-port url)))
     (if (or user-id host port)
	 (string-append
	  "//"
	  (if user-id
	      (string-append (url:encode-string user-id) "@")
	      "")
	  host
	  (if port
	      (string-append ":" (number->string port))
	      "")
	  "/")
	 ""))
   (url:encode-string (imap-url-mailbox url))))

(define-method url-presentation-name ((url <imap-url>))
  (imap-url-mailbox url))

;;;; Server connection

(define-class (<imap-connection> (constructor (host ip-port user-id))) ()
  (host define accessor)
  (ip-port define accessor)
  (user-id define accessor)
  (passphrase define standard
	      initial-value #f)
  (port define standard
	initial-value #f)
  (sequence-number define standard
		   initial-value 0)
  (response-queue define accessor
		  initializer (lambda () (cons '() '())))
  (folder define standard
	  initial-value #f))

(define (reset-imap-connection connection)
  (without-interrupts
   (lambda ()
     (set-imap-connection-sequence-number! connection 0)
     (let ((queue (imap-connection-response-queue connection)))
       (set-car! queue '())
       (set-cdr! queue '()))
     (set-imap-connection-folder! connection #f))))

(define (next-imap-command-tag connection)
  (let ((n (imap-connection-sequence-number connection)))
    (set-imap-connection-sequence-number! connection (+ n 1))
    (nonnegative-integer->base26-string n 3)))

(define (nonnegative-integer->base26-string n min-length)
  (let ((s
	 (make-string (max (ceiling->exact (/ (log (+ n 1)) (log 26)))
			   min-length)
		      #\A)))
    (let loop ((n n) (i (fix:- (string-length s) 1)))
      (let ((q.r (integer-divide n 26)))
	(string-set! s i (string-ref "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (cdr q.r)))
	(if (not (= (car q.r) 0))
	    (loop (car q.r) (fix:- i 1)))))
    s))

(define (base26-string->nonnegative-integer s)
  (let ((end (string-length s)))
    (let loop ((start 0) (n 0))
      (if (fix:< start end)
	  (let ((digit (- (vector-8b-ref s start) (char->integer #\A))))
	    (if (not (<= 0 digit 25))
		(error:bad-range-argument s
					  'BASE26-STRING->NONNEGATIVE-INTEGER))
	    (loop (fix:+ start 1) (+ (* n 26) digit)))
	  n))))

(define (enqueue-imap-response connection response)
  (let ((queue (imap-connection-response-queue connection)))
    (let ((next (cons response '())))
      (without-interrupts
       (lambda ()
	 (if (pair? (cdr queue))
	     (set-cdr! (cdr queue) next)
	     (set-car! queue next))
	 (set-cdr! queue next))))))

(define (dequeue-imap-responses connection)
  (let ((queue (imap-connection-response-queue connection)))
    (without-interrupts
     (lambda ()
       (let ((responses (car queue)))
	 (set-car! queue '())
	 (set-cdr! queue '())
	 responses)))))

(define (get-imap-connection url)
  (let ((host (imap-url-host url))
	(ip-port (imap-url-port url))
	(user-id (imap-url-user-id url)))
    (let loop ((connections memoized-imap-connections) (prev #f))
      (if (weak-pair? connections)
	  (let ((connection (weak-car connections)))
	    (if connection
		(if (and (string-ci=? (imap-connection-host connection) host)
			 (eqv? (imap-connection-ip-port connection) ip-port)
			 (string=? (imap-connection-user-id connection)
				   user-id))
		    connection
		    (loop (weak-cdr connections) connections))
		(let ((next (weak-cdr connections)))
		  (if prev
		      (weak-set-cdr! prev next)
		      (set! memoized-imap-connections next))
		  (loop next prev))))
	  (let ((connection (make-imap-connection host ip-port user-id)))
	    (set! memoized-imap-connections
		  (weak-cons connection memoized-imap-connections))
	    connection)))))

(define memoized-imap-connections '())

(define (guarantee-imap-connection-open connection)
  (if (imap-connection-port connection)
      #f
      (let ((host (imap-connection-host connection))
	    (ip-port (imap-connection-ip-port connection))
	    (user-id (imap-connection-user-id connection)))
	(let ((port
	       (open-tcp-stream-socket host (or ip-port "imap2") #f "\n")))
	  (read-line port)	;discard server announcement
	  (set-imap-connection-port! connection port)
	  (reset-imap-connection connection)
	  (if (not (memq 'IMAP4REV1 (imap:command:capability connection)))
	      (begin
		(close-imap-connection connection)
		(error "Server doesn't support IMAP4rev1:" host)))
	  (let ((response
		 (call-with-memoized-passphrase connection
		   (lambda (passphrase)
		     (imap:command:login connection user-id passphrase)))))
	    (if (imap:response:no? response)
		(begin
		  (close-imap-connection connection)
		  (error "Unable to log in:" response)))))
	#t)))

(define (close-imap-connection connection)
  (let ((port (imap-connection-port connection)))
    (if port
	(begin
	  (close-port port)
	  (set-imap-connection-port! connection #f))))
  (reset-imap-connection connection))

(define (imap-connection-open? connection)
  (imap-connection-port connection))

(define (call-with-memoized-passphrase connection receiver)
  (let ((passphrase (imap-connection-passphrase connection)))
    (if passphrase
	(call-with-unobscured-passphrase passphrase receiver)
	(authenticate (imap-connection-host connection)
		      (imap-connection-user-id connection)
	  (lambda (passphrase)
	    (set-imap-connection-passphrase! connection
					     (obscure-passphrase passphrase))
	    (receiver passphrase))))))

(define (obscure-passphrase clear-text)
  (let ((n (string-length clear-text)))
    (let ((noise (random-byte-vector n)))
      (let ((obscured-text (make-string (* 2 n))))
	(string-move! noise obscured-text 0)
	(do ((i 0 (fix:+ i 1)))
	    ((fix:= i n))
	  (vector-8b-set! obscured-text (fix:+ i n)
			  (fix:xor (vector-8b-ref clear-text i)
				   (vector-8b-ref noise i))))
	obscured-text))))

(define (call-with-unobscured-passphrase obscured-text receiver)
  (let ((n (quotient (string-length obscured-text) 2))
	(clear-text))
    (dynamic-wind
     (lambda ()
       (set! clear-text (make-string n))
       unspecific)
     (lambda ()
       (do ((i 0 (fix:+ i 1)))
	   ((fix:= i n))
	 (vector-8b-set! clear-text i
			 (fix:xor (vector-8b-ref obscured-text i)
				  (vector-8b-ref obscured-text (fix:+ i n)))))
       (receiver clear-text))
     (lambda ()
       (string-fill! clear-text #\NUL)
       (set! clear-text)
       unspecific))))

;;;; Folder datatype

(define-class (<imap-folder> (constructor (url connection))) (<folder>)
  (connection define accessor)
  (read-only? define standard)
  (allowed-flags define standard)
  (permanent-flags define standard)
  (permanent-keywords? define standard)
  (uidnext define standard)
  (uidvalidity define standard)
  (unseen define standard)
  (messages-synchronized? define standard)
  (n-messages define standard initial-value 0)
  (messages define standard initial-value '#()))

(define (reset-imap-folder! folder)
  (without-interrupts
   (lambda ()
     (detach-all-messages! folder)
     (set-imap-folder-read-only?! folder #f)
     (set-imap-folder-allowed-flags! folder '())
     (set-imap-folder-permanent-flags! folder '())
     (set-imap-folder-permanent-keywords?! folder #f)
     (set-imap-folder-uidnext! folder #f)
     (set-imap-folder-uidvalidity! folder #f)
     (set-imap-folder-unseen! folder #f)
     (set-imap-folder-messages-synchronized?! folder #f)
     (set-imap-folder-n-messages! folder 0)
     (set-imap-folder-messages! folder '#()))))

(define (new-imap-folder-uidvalidity! folder uidvalidity)
  (without-interrupts
   (lambda ()
     (detach-all-messages! folder)
     (fill-messages-vector! folder 0)
     (set-imap-folder-uidvalidity! folder uidvalidity)
     (folder-modified! folder)))
  (read-message-headers! folder 0))

(define (detach-all-messages! folder)
  (let ((v (imap-folder-messages folder))
	(n (imap-folder-n-messages folder)))
    (do ((i 0 (fix:+ i 1)))
	((fix:= i n))
      (detach-message! (vector-ref v i)))))

(define (fill-messages-vector! folder start)
  (let ((v (imap-folder-messages folder))
	(n (imap-folder-n-messages folder)))
    (do ((index start (fix:+ index 1)))
	((fix:= index n))
      (vector-set! v index (make-imap-message folder index)))))

(define (read-message-headers! folder start)
  ((imail-message-wrapper "Reading message headers")
   (lambda ()
     (imap:command:fetch-range (imap-folder-connection folder)
			       start
			       (folder-length folder)
			       imap-header-keywords))))

(define (remove-imap-folder-message folder index)
  (without-interrupts
   (lambda ()
     (let ((v (imap-folder-messages folder))
	   (n (imap-folder-n-messages folder)))
       (detach-message! (vector-ref v index))
       (subvector-move-left! v (fix:+ index 1) n v index)
       (let ((n (fix:- n 1)))
	 (vector-set! v n #f)
	 (set-imap-folder-n-messages! folder n)
	 (if (fix:> (vector-length v) 16)
	     (let ((l (fix:quotient (vector-length v) 2)))
	       (if (fix:<= n l)
		   (set-imap-folder-messages!
		    folder
		    (vector-head v (fix:max l 16))))))))))
  (folder-modified! folder))

;;; This needs explanation.  There are two basic cases.

;;; In the first case, our folder is synchronized with the server,
;;; meaning that our folder has the same length and UIDs as the
;;; server's mailbox.  In that case, length changes can only be
;;; increases, and we know that no deletions occur except those
;;; reflected by EXPUNGE responses (both constraints required by the
;;; IMAP specification).

;;; In the second case, we have lost synchrony with the server,
;;; usually because the connection was closed and then reopened.  Here
;;; we must resynchronize, matching up messages by UID.  Our strategy
;;; is to detach all of the existing messages, create a new message
;;; set with empty messages, read in the UIDs for the new messages,
;;; then match up the old messages with the new.  Any old message that
;;; matches a new one replaces it in the folder, thus preserving
;;; message pointers where possible.

;;; The reason for this complexity in the second case is that we can't
;;; be guaranteed that we will complete reading the UIDs for the new
;;; messages, either due to error or the user aborting the read.  So
;;; we must have everything in a consistent (if nonoptimal) state
;;; while reading.  If the read finishes, we can do the match/replace
;;; operation atomically.

(define (set-imap-folder-length! folder count)
  (if (or (imap-folder-messages-synchronized? folder)
	  (= 0 (imap-folder-n-messages folder)))
      (read-message-headers!
       folder
       (without-interrupts
	(lambda ()
	  (let ((v (imap-folder-messages folder))
		(n (imap-folder-n-messages folder)))
	    (if (not (> count n))
		(error "EXISTS response decreased folder length:" folder))
	    (if (> count (vector-length v))
		(set-imap-folder-messages! folder (vector-grow v count #f)))
	    (set-imap-folder-n-messages! folder count)
	    (fill-messages-vector! folder n)
	    (folder-modified! folder)
	    n))))
      (let ((v.n
	     (without-interrupts
	      (lambda ()
		(detach-all-messages! folder)
		(let ((v (imap-folder-messages folder))
		      (n (imap-folder-n-messages folder)))
		  (set-imap-folder-n-messages! folder count)
		  (set-imap-folder-messages! folder (make-vector count #f))
		  (fill-messages-vector! folder 0)
		  (set-imap-folder-messages-synchronized?! folder #t)
		  (folder-modified! folder)
		  (cons v n))))))
	((imail-message-wrapper "Reading message UIDs")
	 (lambda ()
	   (imap:command:fetch-all (imap-folder-connection folder) '(UID))))
	(without-interrupts
	 (lambda ()
	   (let ((v* (imap-folder-messages folder))
		 (n* (imap-folder-n-messages folder)))
	     (let loop ((i 0) (i* 0))
	       (if (and (fix:< i (cdr v.n)) (fix:< i* n*))
		   (let ((m (vector-ref (car v.n) i))
			 (m* (vector-ref v* i*)))
		     (cond ((= (imap-message-uid m) (imap-message-uid m*))
			    ;; Flags might have been updated while
			    ;; reading the UIDs.
			    (if (%message-flags-initialized? m*)
				(%set-message-flags! m (message-flags m*)))
			    (detach-message! m*)
			    (attach-message! m folder i*)
			    (vector-set! v* i* m)
			    (loop (fix:+ i 1) (fix:+ i* 1)))
			   ((< (imap-message-uid m) (imap-message-uid m*))
			    (loop (fix:+ i 1) i*))
			   (else
			    (loop i (fix:+ i* 1))))))))
	   (folder-modified! folder))))))

;;;; Message datatype

(define-class (<imap-message> (constructor (folder index))) (<message>)
  (uid)
  (length))

(define (imap-message-connection message)
  (imap-folder-connection (message-folder message)))

(define-method set-message-flags! ((message <imap-message>) flags)
  (imap:command:store-flags (imap-message-connection message)
			    (message-index message)
			    (map imail-flag->imap-flag
				 (flags-delete "\\recent" flags))))

(define (imap-flag->imail-flag flag)
  (case flag
    ((\ANSWERED) "answered")
    ((\DELETED) "deleted")
    ((\SEEN) "seen")
    (else (symbol->string flag))))

(define (imail-flag->imap-flag flag)
  (cond ((string-ci=? flag "answered") '\ANSWERED)
	((string-ci=? flag "deleted") '\DELETED)
	((string-ci=? flag "seen") '\SEEN)
	(else (intern flag))))

;;; These reflectors are needed to guarantee that we read the
;;; appropriate information from the server.  Normally most message
;;; slots are filled in by READ-MESSAGE-HEADERS!, but it's possible
;;; for READ-MESSAGE-HEADERS! to be interrupted, leaving unfilled
;;; slots.  Also, we don't want to fill the BODY slot until it is
;;; requested, as the body might be very large.

(define (guarantee-headers-initialized message initpred)
  (guarantee-slot-initialized message initpred "headers" imap-header-keywords))

(define imap-header-keywords
  '(UID FLAGS RFC822.SIZE RFC822.HEADER))

(define (guarantee-body-initialized message initpred)
  (guarantee-slot-initialized message initpred "body" '(RFC822.TEXT)))

(let ((reflector
       (lambda (generic-procedure slot-name guarantee)
	 (let ((initpred (slot-initpred <imap-message> slot-name)))
	   (define-method generic-procedure ((message <imap-message>))
	     (guarantee message initpred)
	     (call-next-method message))))))
  (reflector message-header-fields 'HEADER-FIELDS
	     guarantee-headers-initialized)
  (reflector message-body 'BODY guarantee-body-initialized)
  (reflector message-flags 'FLAGS guarantee-headers-initialized))

(define-generic imap-message-uid (message))
(define-generic imap-message-length (message))

(let ((reflector
       (lambda (generic-procedure slot-name)
	 (let ((accessor (slot-accessor <imap-message> slot-name))
	       (initpred (slot-initpred <imap-message> slot-name)))
	   (define-method generic-procedure ((message <imap-message>))
	     (guarantee-headers-initialized message initpred)
	     (accessor message))))))
  (reflector imap-message-uid 'UID)
  (reflector imap-message-length 'LENGTH))

(define (guarantee-slot-initialized message initpred noun keywords)
  (if (not (initpred message))
      (let ((connection (imap-message-connection message))
	    (index (message-index message)))
	(let ((suffix
	       (string-append " " noun " for message "
			      (number->string (+ index 1)))))
	  ((imail-message-wrapper "Reading" suffix)
	   (lambda ()
	     (imap:command:fetch connection index keywords)
	     (if (not (initpred message))
		 (begin
		   ;; Still don't have the goods.  Send a NOOP, in
		   ;; case the server is holding it back because it
		   ;; also needs to send an EXPUNGE.
		   (imap:command:noop connection)
		   (if (not (initpred message))
		       (error
			(string-append "Unable to obtain" suffix)))))))))))

;;;; Server operations

(define-method %new-folder ((url <imap-url>))
  ???)

(define-method %delete-folder ((url <imap-url>))
  ???)

(define-method %move-folder ((url <imap-url>) (new-url <imap-url>))
  ???)

(define-method %copy-folder ((url <imap-url>) (new-url <imap-url>))
  ???)

(define-method %append-message ((message <message>) (url <imap-url>))
  ???)

(define-method available-folder-names ((url <imap-url>))
  ???)

;;;; Folder operations

(define-method %open-folder ((url <imap-url>))
  (let ((folder (make-imap-folder url (get-imap-connection url))))
    (reset-imap-folder! folder)
    (guarantee-imap-folder-open folder)
    folder))

(define (guarantee-imap-folder-open folder)
  (let ((connection (imap-folder-connection folder)))
    (if (guarantee-imap-connection-open connection)
	(begin
	  (set-imap-folder-messages-synchronized?! folder #f)
	  (set-imap-connection-folder! connection folder)
	  (if (not
	       (imap:command:select connection
				    (imap-url-mailbox (folder-url folder))))
	      (set-imap-connection-folder! connection #f))
	  #t))))

(define-method close-folder ((folder <imap-folder>))
  (close-imap-connection (imap-folder-connection folder)))

(define-method %folder-valid? ((folder <imap-folder>))
  folder
  #t)

(define-method folder-length ((folder <imap-folder>))
  (guarantee-imap-folder-open folder)
  (imap-folder-n-messages folder))

(define-method %get-message ((folder <imap-folder>) index)
  (guarantee-imap-folder-open folder)
  (vector-ref (imap-folder-messages folder) index))

#|
;; There's no guarantee that UNSEEN is kept up to date by the server.
;; So unless we want to manually update it, it's useless.
(define-method first-unseen-message-index ((folder <imap-folder>))
  (guarantee-imap-folder-open folder)
  (or (imap-folder-unseen folder) 0))
|#

(define-method expunge-deleted-messages ((folder <imap-folder>))
  (guarantee-imap-folder-open folder)
  (imap:command:expunge (imap-folder-connection folder)))

(define-method search-folder ((folder <imap-folder>) criteria)
  (guarantee-imap-folder-open folder)
  ???)

(define-method folder-sync-status ((folder <imap-folder>))
  ;; Changes are always written through.
  folder
  'SYNCHRONIZED)

(define-method save-folder ((folder <imap-folder>))
  ;; Changes are always written through.
  folder
  unspecific)

(define-method discard-folder-cache ((folder <imap-folder>))
  (close-imap-connection (imap-folder-connection folder))
  (reset-imap-folder! folder))

;;;; IMAP command invocation

(define (imap:command:capability connection)
  (imap:response:capabilities
   (imap:command:single-response imap:response:capability?
				 connection 'CAPABILITY)))

(define (imap:command:login connection user-id passphrase)
  ((imail-message-wrapper "Logging in as " user-id)
   (lambda ()
     (imap:command:no-response connection 'LOGIN user-id passphrase))))

(define (imap:command:select connection mailbox)
  ((imail-message-wrapper "Select mailbox " mailbox)
   (lambda ()
     (imap:response:ok?
      (imap:command:no-response connection 'SELECT mailbox)))))

(define (imap:command:fetch connection index items)
  (imap:command:single-response imap:response:fetch?
				connection 'FETCH (+ index 1) items))

(define (imap:command:fetch-all connection items)
  (imap:command:multiple-response imap:response:fetch?
				  connection 'FETCH
				  (cons 'ATOM "1:*")
				  items))

(define (imap:command:fetch-range connection start end items)
  (if (< start end)
      (imap:command:multiple-response imap:response:fetch?
				      connection 'FETCH
				      (cons 'ATOM
					    (string-append
					     (number->string (+ start 1))
					     ":"
					     (number->string end)))
				      items)
      '()))

(define (imap:command:store-flags connection index flags)
  (imap:command:no-response connection 'STORE (+ index 1) 'FLAGS flags))

(define (imap:command:expunge connection)
  ((imail-message-wrapper "Expunging messages")
   (lambda ()
     (imap:command:no-response connection 'EXPUNGE))))

(define (imap:command:noop connection)
  (imap:command:no-response connection 'NOOP))

(define (imap:command:no-response connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (not (null? (cdr responses)))
	(error "Malformed response from IMAP server:" responses))
    (car responses)))

(define (imap:command:single-response predicate connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (imap:response:ok? (car responses))
	(if (and (pair? (cdr responses))
		 (predicate (cadr responses))
		 (null? (cddr responses)))
	    (cadr responses)
	    (error "Malformed response from IMAP server:" responses))
	(error "Server signalled a command error:" (car responses)))))

(define (imap:command:multiple-response predicate
					connection command . arguments)
  (let ((responses (apply imap:command connection command arguments)))
    (if (imap:response:ok? (car responses))
	(if (for-all? (cdr responses) predicate)
	    (cdr responses)
	    (error "Malformed response from IMAP server:" responses))
	(error "Server signalled a command error:" (car responses)))))

(define (imap:command connection command . arguments)
  (bind-condition-handler (list condition-type:system-call-error)
      (lambda (condition)
	(if (and (memq (system-call-name condition) '(READ WRITE))
		 (eq? 'BROKEN-PIPE (system-call-error condition)))
	    (begin
	      (close-imap-connection connection)
	      (error "Connection to IMAP server broken; please try again."))))
    (lambda ()
      (imap:wait-for-tagged-response connection
				     (imap:send-command connection
							command arguments)
				     command))))

(define system-call-name
  (condition-accessor condition-type:system-call-error 'SYSTEM-CALL))

(define system-call-error
  (condition-accessor condition-type:system-call-error 'ERROR-TYPE))

(define imail-trace? #f)
(define imail-trace-output)

(define (start-imail-trace)
  (without-interrupts
   (lambda ()
     (set! imail-trace? #t)
     (set! imail-trace-output '())
     unspecific)))

(define (stop-imail-trace)
  (reverse!
   (without-interrupts
    (lambda ()
      (set! imail-trace? #f)
      (let ((output imail-trace-output))
	(set! imail-trace-output)
	output)))))

(define (imail-trace-record-output object)
  (without-interrupts
   (lambda ()
     (set! imail-trace-output (cons object imail-trace-output))
     unspecific)))

(define (imap:send-command connection command arguments)
  (let ((tag (next-imap-command-tag connection))
	(port (imap-connection-port connection)))
    (if imail-trace?
	(imail-trace-record-output (cons* 'SEND tag command arguments)))
    (write-string tag port)
    (write-char #\space port)
    (write command port)
    (for-each (lambda (argument)
		(write-char #\space port)
		(imap:send-command-argument connection tag argument))
	      arguments)
    (write-char #\return port)
    (write-char #\linefeed port)
    (flush-output port)
    tag))

(define (imap:send-command-argument connection tag argument)
  (let ((port (imap-connection-port connection)))
    (let loop ((argument argument))
      (cond ((or (symbol? argument)
		 (exact-nonnegative-integer? argument))
	     (write argument port))
	    ((and (pair? argument)
		  (eq? (car argument) 'ATOM)
		  (string? (cdr argument)))
	     (write-string (cdr argument) port))
	    ((string? argument)
	     (if (imap:string-may-be-quoted? argument)
		 (imap:write-quoted-string argument port)
		 (imap:write-literal-string connection tag argument)))
	    ((list? argument)
	     (write-char #\( port)
	     (if (pair? argument)
		 (begin
		   (loop (car argument))
		   (for-each (lambda (object)
			       (write-char #\space port)
			       (loop object))
			     (cdr argument))))
	     (write-char #\) port))
	    (else (error "Illegal IMAP syntax:" argument))))))

(define (imap:write-literal-string connection tag string)
  (let ((port (imap-connection-port connection)))
    (imap:write-literal-string-header string port)
    (flush-output port)
    (let loop ()
      (let ((response (imap:read-server-response port)))
	(cond ((imap:response:continue? response)
	       (imap:write-literal-string-body string port))
	      ((and (imap:response:tag response)
		    (string-ci=? tag (imap:response:tag response)))
	       (error "Unable to finish continued command:" response))
	      (else
	       (enqueue-imap-response connection response)
	       (loop)))))))

(define (imap:wait-for-tagged-response connection tag command)
  (let ((port (imap-connection-port connection)))
    (let loop ()
      (let ((response (imap:read-server-response port)))
	(if imail-trace?
	    (imail-trace-record-output (list 'RECEIVE response)))
	(let ((tag* (imap:response:tag response)))
	  (if tag*
	      (let ((responses
		     (process-responses
		      connection command
		      (dequeue-imap-responses connection))))
		(if (string-ci=? tag tag*)
		    (if (or (imap:response:ok? response)
			    (imap:response:no? response))
			(cons response responses)
			(error "IMAP protocol error:" response))
		    (if (< (base26-string->nonnegative-integer tag*)
			   (base26-string->nonnegative-integer tag))
			;; If this is an old tag, ignore it and move on.
			(loop)
			(error "Out-of-sequence tag:" tag* tag))))
	      (begin
		(enqueue-imap-response connection response)
		(loop))))))))

(define (process-responses connection command responses)
  (if (pair? responses)
      (if (process-response connection command (car responses))
	  (cons (car responses)
		(process-responses connection command (cdr responses)))
	  (process-responses connection command (cdr responses)))
      '()))

(define (process-response connection command response)
  (cond ((imap:response:status-response? response)
	 (let ((code (imap:response:response-text-code response))
	       (text (imap:response:response-text-string response)))
	   (if code
	       (process-response-text connection command code text))
	   (if (and (imap:response:bye? response)
		    (not (eq? command 'LOGOUT)))
	       (begin
		 (close-imap-connection connection)
		 (error "Server shut down connection:" text)))
	   (if (or (imap:response:no? response)
		   (imap:response:bad? response))
	       (imail-present-user-alert
		(lambda (port)
		  (write-string "Notice from IMAP server:" port)
		  (newline port)
		  (display text port)
		  (newline port)))))
	 (imap:response:preauth? response))
	((imap:response:exists? response)
	 (let ((count (imap:response:exists-count response))
	       (folder (imap-connection-folder connection)))
	   (if (not (and (imap-folder-messages-synchronized? folder)
			 (= count (folder-length folder))))
	       (set-imap-folder-length! folder count)))
	 #f)
	((imap:response:expunge? response)
	 (let ((folder (imap-connection-folder connection)))
	   (remove-imap-folder-message folder
				       (imap:response:expunge-index response))
	   (folder-modified! folder))
	 #f)
	((imap:response:flags? response)
	 (let ((folder (imap-connection-folder connection)))
	   (set-imap-folder-allowed-flags!
	    folder
	    (map imap-flag->imail-flag (imap:response:flags response)))
	   (folder-modified! folder))
	 #f)
	((imap:response:recent? response)
	 #f)
	((imap:response:capability? response)
	 (eq? command 'CAPABILITY))
	((imap:response:list? response)
	 (eq? command 'LIST))
	((imap:response:lsub? response)
	 (eq? command 'LSUB))
	((imap:response:search? response)
	 (eq? command 'SEARCH))
	((imap:response:status? response)
	 (eq? command 'STATUS))
	((imap:response:fetch? response)
	 (process-fetch-attributes
	  (get-message (imap-connection-folder connection)
		       (- (imap:response:fetch-index response) 1))
	  response)
	 (eq? command 'FETCH))
	(else
	 (error "Illegal server response:" response))))

(define (process-response-text connection command code text)
  command
  (cond ((imap:response-code:alert? code)
	 (imail-present-user-alert
	  (lambda (port)
	    (write-string "Alert from IMAP server:" port)
	    (newline port)
	    (display text port)
	    (newline port))))
	((imap:response-code:permanentflags? code)
	 (let ((pflags (imap:response-code:permanentflags code))
	       (folder (imap-connection-folder connection)))
	   (set-imap-folder-permanent-keywords?!
	    folder
	    (if (memq '\* pflags) #t #f))
	   (set-imap-folder-permanent-flags!
	    folder
	    (map imap-flag->imail-flag (delq '\* pflags)))
	   (folder-modified! folder)))
	((imap:response-code:read-only? code)
	 (let ((folder (imap-connection-folder connection)))
	   (set-imap-folder-read-only?! folder #t)
	   (folder-modified! folder)))
	((imap:response-code:read-write? code)
	 (let ((folder (imap-connection-folder connection)))
	   (set-imap-folder-read-only?! folder #f)
	   (folder-modified! folder)))
	((imap:response-code:uidnext? code)
	 (let ((folder (imap-connection-folder connection)))
	   (set-imap-folder-uidnext! folder (imap:response-code:uidnext code))
	   (folder-modified! folder)))
	((imap:response-code:uidvalidity? code)
	 (let ((folder (imap-connection-folder connection))
	       (uidvalidity (imap:response-code:uidvalidity code)))
	   (if (not (eqv? uidvalidity (imap-folder-uidvalidity folder)))
	       (new-imap-folder-uidvalidity! folder uidvalidity))))
	((imap:response-code:unseen? code)
	 (let ((folder (imap-connection-folder connection)))
	   (set-imap-folder-unseen!
	    folder
	    (- (imap:response-code:unseen code) 1))
	   (folder-modified! folder)))
	#|
	((or (imap:response-code:badcharset? code)
	     (imap:response-code:newname? code)
	     (imap:response-code:parse? code)
	     (imap:response-code:trycreate? code))
	 unspecific)
	|#
	))

(define (process-fetch-attributes message response)
  (let loop
      ((keywords (imap:response:fetch-attribute-keywords response))
       (any-modifications? #f))
    (if (pair? keywords)
	(loop (cdr keywords)
	      (or (process-fetch-attribute
		   message
		   (car keywords)
		   (imap:response:fetch-attribute response (car keywords)))
		  any-modifications?))
	(if any-modifications?
	    (message-modified! message)))))

(define (process-fetch-attribute message keyword datum)
  (case keyword
    ((FLAGS)
     (%set-message-flags! message (map imap-flag->imail-flag datum))
     #t)
    ((RFC822.HEADER)
     (%set-message-header-fields!
      message
      (lines->header-fields (network-string->lines datum)))
     #t)
    ((RFC822.SIZE)
     (%set-imap-message-length! message datum)
     #t)
    ((RFC822.TEXT)
     (%set-message-body! message (translate-string-line-endings datum))
     #t)
    ((UID)
     (%set-imap-message-uid! message datum)
     #t)
    (else #f)))

(define %set-message-header-fields!
  (slot-modifier <imap-message> 'HEADER-FIELDS))

(define %set-message-body!
  (slot-modifier <imap-message> 'BODY))

(define %set-message-flags!
  (slot-modifier <imap-message> 'FLAGS))

(define %message-flags-initialized?
  (slot-initpred <imap-message> 'FLAGS))

(define %set-imap-message-uid!
  (slot-modifier <imap-message> 'UID))

(define %set-imap-message-length!
  (slot-modifier <imap-message> 'LENGTH))