#| -*-Scheme-*-

$Id: logmer.scm,v 1.24 2000/03/31 14:37:47 cph Exp $

Copyright (c) 1988-2000 Massachusetts Institute of Technology

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

;;;; RCS Log Merge

(declare (usual-integrations))

(define (rcs-directory-log directory #!optional output-file
			   changelog? changelog-map)
  (let ((changelog? (if (default-object? changelog?) #f changelog?))
	(changelog-map
	 (if (default-object? changelog-map)
	     (list (os/hostname))
	     changelog-map))
	(port (notification-output-port)))
    (let ((output-file
	   (merge-pathnames (if (or (default-object? output-file)
				    (not output-file))
				(if changelog? "ChangeLog" "RCS.log")
				output-file)
			    (pathname-as-directory directory))))
      (write-string "regenerating log for directory: " port)
      (write (->namestring directory))
      (write-string "..." port)
      (let ((pathnames (rcs-directory-read directory)))
	(if (let ((time (file-modification-time-indirect output-file)))
	      (or (not time)
		  (there-exists? pathnames
		    (lambda (w.r)
		      (> (file-modification-time-indirect (cdr w.r))
			 time)))))
	    (begin
	      (newline port)
	      (write-string "total files: " port)
	      (write (length pathnames) port)
	      (newline port)
	      (let ((entries (read-entries pathnames port)))
		(write-string "total entries: " port)
		(write (length entries) port)
		(newline port)
		(let ((entries
		       (if changelog?
			   (sort-entries-for-changelog entries)
			   (sort-entries-for-rcs.log entries))))
		  (write-string "sorting finished" port)
		  (newline port)
		  (call-with-output-file output-file
		    (lambda (port)
		      (if changelog?
			  (format-changelog entries
					    (if (pair? changelog?)
						changelog?
						'())
					    changelog-map
					    port)
			  (format-rcs.log entries port)))))))
	    (begin
	      (write-string " log is up to date" port)
	      (newline port)))))))

;;;; RCS.log format

(define (format-rcs.log entries port)
  (let ((groups (group-entries-by-log entries))
	(format-group
	 (lambda (group)
	   (for-each (lambda (entry)
		       (let ((delta (car entry))
			     (filename (cdr entry)))
			 (write-string "file: " port)
			 (write-string filename port)
			 (write-string ";  revision: " port)
			 (write-string (delta/number delta) port)
			 (write-string "\ndate: " port)
			 (write-string (date->string (delta/date delta)) port)
			 (write-string ";  author: " port)
			 (write-string (delta/author delta) port)
			 (newline port)))
		     group)
	   (newline port)
	   (write-string (delta/log (car (car group))) port)
	   (newline port))))
    (if (pair? groups)
	(begin
	  (format-group (car groups))
	  (for-each (lambda (group)
		      (write-string "----------------------------" port)
		      (newline port)
		      (format-group group))
		    (cdr groups))))))

(define (sort-entries-for-rcs.log entries)
  (sort entries
    (lambda (x y)
      (date<? (delta/date (car y)) (delta/date (car x))))))

;;;; ChangeLog format

(define (format-changelog entries options changelog-map port)
  (let ((groups
	 (group-entries-by-author&day
	  (list-transform-negative entries
	    (lambda (entry)
	      (string-prefix? "#" (delta/log (car entry)))))))
	(format-group
	 (lambda (entries)
	   (write-string
	    (format-date-for-changelog (delta/date (caar entries)))
	    port)
	   (write-string "  " port)
	   (let ((author (delta/author (caar entries))))
	     (let ((mentry (assoc author (cdr changelog-map))))
	       (write-string (if mentry (cadr mentry) author) port)
	       (write-string " <" port)
	       (if (and mentry (pair? (cddr mentry)))
		   (write-string (caddr mentry) port)
		   (begin
		     (write-string author port)
		     (write-string "@" port)
		     (write-string (car changelog-map) port)))
	       (write-string ">" port)))
	   (newline port)
	   (for-each
	    (lambda (entries)
	      (newline port)
	      (write-char #\tab port)
	      (write-string "* " port)
	      (let ((filenames
		     (if (memq 'SHOW-VERSIONS options)
			 (map (lambda (entry)
				(string-append (cdr entry)
					       "["
					       (delta/number (car entry))
					       "]"))
			      (sort-group-by-name&date entries))
			 (remove-duplicate-strings
			  (sort (map cdr entries) string<?)))))
		(write-string (car filenames) port)
		(let loop
		    ((filenames (cdr filenames))
		     (column (fix:+ 11 (string-length (car filenames)))))
		  (if (pair? filenames)
		      (let ((filename (car filenames)))
			(let ((column*
			       (+ column 2 (string-length filename))))
			  (if (fix:>= column* 80)
			      (begin
				(write-string "," port)
				(newline port)
				(write-char #\tab port)
				(write-string "  " port)
				(write-string filename port)
				(loop (cdr filenames)
				      (fix:+ 11
					     (string-length filename))))
			      (begin
				(write-string ", " port)
				(write-string filename port)
				(loop (cdr filenames) column*))))))))
	      (write-string ":" port)
	      (newline port)
	      (format-log-for-changelog (delta/log (caar entries)) port))
	    (sort-groups-by-date (group-entries-by-log entries))))))
    (if (pair? groups)
	(begin
	  (format-group (car groups))
	  (for-each (lambda (group)
		      (newline port)
		      (format-group group))
		    (cdr groups))))))

(define (sort-entries-for-changelog entries)
  (sort entries
    (lambda (x y)
      (or (day>? (delta/date (car x)) (delta/date (car y)))
	  (and (day=? (delta/date (car x)) (delta/date (car y)))
	       (or (string<? (delta/author (car x))
			     (delta/author (car y)))
		   (and (string=? (delta/author (car x))
				  (delta/author (car y)))
			(string<? (delta/log (car x))
				  (delta/log (car y))))))))))

(define (sort-group-by-name&date entries)
  (sort entries
    (lambda (x y)
      (or (string<? (cdr x) (cdr y))
	  (and (string=? (cdr x) (cdr y))
	       (date>? (delta/date (car x)) (delta/date (car y))))))))

(define (format-date-for-changelog date)
  (let ((dt (date/decoded date)))
    (string-append
     (number->string (decoded-time/year dt))
     "-"
     (string-pad-left (number->string (decoded-time/month dt)) 2 #\0)
     "-"
     (string-pad-left (number->string (decoded-time/day dt)) 2 #\0))))

(define (format-log-for-changelog log port)
  (write-char #\tab port)
  (let ((end (string-length log)))
    (let loop ((start 0))
      (let ((index (substring-find-next-char log start end #\newline)))
	(if index
	    (let ((index (fix:+ index 1)))
	      (write-substring log start index port)
	      (if (fix:< index end)
		  (begin
		    (write-char #\tab port)
		    (loop index))))
	    (begin
	      (write-substring log start end port)
	      (newline port)))))))

(define (remove-duplicate-strings strings)
  ;; Assumes that STRINGS is sorted.
  (let loop ((strings strings) (result '()))
    (if (pair? strings)
	(loop (cdr strings)
	      (if (and (pair? (cdr strings))
		       (string=? (car strings) (cadr strings)))
		  result
		  (cons (car strings) result)))
	(reverse! result))))

(define (sort-groups-by-date groups)
  (sort-groups groups
	       (lambda (entries)
		 (let loop
		     ((entries (cdr entries))
		      (winner (caar entries)))
		   (if (pair? entries)
		       (loop (cdr entries)
			     (if (date<? (delta/date (caar entries))
					 (delta/date winner))
				 (caar entries)
				 winner))
		       winner)))
	       (lambda (x y)
		 (date>? (delta/date x) (delta/date y)))))

(define (sort-groups groups choose-representative predicate)
  (map cdr
       (sort (map (lambda (group)
		    (cons (choose-representative group) group))
		  groups)
	 (lambda (x y)
	   (predicate (car x) (car y))))))

(define (group-entries-by-author&day entries)
  (group-entries entries
    (lambda (x y)
      (and (string=? (delta/author (car x)) (delta/author (car y)))
	   (day=? (delta/date (car x)) (delta/date (car y)))))))

(define (group-entries-by-log entries)
  (group-entries entries
    (lambda (x y)
      (string=? (delta/log (car x)) (delta/log (car y))))))

(define (group-entries entries predicate)
  (let outer ((entries entries) (groups '()))
    (if (pair? entries)
	(let ((entry (car entries)))
	  (let inner ((entries (cdr entries)) (group (list entry)))
	    (if (and (pair? entries)
		     (predicate entry (car entries)))
		(inner (cdr entries) (cons (car entries) group))
		(outer entries (cons (reverse! group) groups)))))
	(reverse! groups))))

(define (read-entries pairs notification-port)
  (let ((prefix (greatest-common-prefix (map car pairs))))
    (append-map!
     (lambda (w.r)
       (map (let ((filename (->namestring (enough-pathname (car w.r) prefix))))
	      (lambda (delta)
		(cons delta filename)))
	    (read-file (cdr w.r) notification-port)))
     pairs)))

(define (read-file pathname notification-port)
  (if notification-port
      (begin
	(write-string "read-file " notification-port)
	(write-string (->namestring pathname) notification-port)
	(newline notification-port)))
  (let ((deltas (rcstext->deltas (rcs/read-file pathname 'LOG-ONLY))))
    (for-each (lambda (delta)
		(set-delta/log! delta
				(let ((log (string-trim (delta/log delta))))
				  (if (string-null? log)
				      empty-log-message
				      log))))
	      deltas)
    (list-transform-negative deltas delta/trivial-log?)))

(define (delta/trivial-log? delta)
  (string=? (delta/log delta) "Initial revision"))

(define empty-log-message "*** empty log message ***")

(define (rcstext->deltas rcstext)
  (let ((head (rcstext/head rcstext)))
    (if (not head)
	'()
	(let loop ((input (list head)) (output '()))
	  (if (null? input)
	      output
	      (let ((input* (append (delta/branches (car input)) (cdr input))))
		(loop (if (delta/next (car input))
			  (cons (delta/next (car input)) input*)
			  input*)
		      (cons (car input) output))))))))

(define (rcs-directory-read pathname)
  (let ((files '()))
    (define (scan-directory cvs-mode? directory original-directory)
      (let ((directory (pathname-as-directory directory))
	    (original-directory (pathname-as-directory original-directory)))
	(for-each (lambda (pathname)
		    (scan-file cvs-mode?
			       pathname
			       (merge-pathnames (file-pathname pathname)
						original-directory)))
		  (directory-read directory #f))))

    (define (scan-file cvs-mode? pathname original-pathname)
      (let ((attributes (file-attributes-direct pathname)))
	(if (not attributes)
	    (warn "Cannot get attributes.  Path might contain stale symlink."
		  (error-irritant/noise "\n;   ")
		  original-pathname
		  (error-irritant/noise "\n; points to\n;   ")
		  pathname)
	    (let ((type (file-attributes/type attributes)))
	      (cond ((not type)
		     (if (not (or (ignored-file-name? cvs-mode? pathname)
				  (ignored-file-name? cvs-mode?
						      original-pathname)))
			 (let ((file (rcs-files cvs-mode? pathname)))
			   (if file
			       (set! files (cons file files))))))
		    ((eq? type #t)
		     (if (not (member (file-namestring pathname)
				      '("." ".." "CVS" "RCS")))
			 (scan-directory cvs-mode?
					 pathname original-pathname)))
		    ((string? type)
		     (scan-file cvs-mode?
				(merge-pathnames type
						 (directory-pathname pathname))
				original-pathname)))))))

    (define (rcs-files cvs-mode? pathname)
      (let ((directory (directory-pathname pathname))
	    (name (file-namestring pathname)))
	(if cvs-mode?
	    (and (string-suffix? ",v" name)
		 (cons (merge-pathnames
			(string-head name (- (string-length name) 2))
			directory)
		       pathname))
	    (let* ((name (string-append name ",v"))
		   (p
		    (merge-pathnames name (merge-pathnames "RCS/" directory))))
	      (if (regular-file? p)
		  (cons pathname p)
		  (let ((p (merge-pathnames name directory)))
		    (and (regular-file? p)
			 (cons pathname p))))))))

    (define (regular-file? pathname)
      (let ((attributes (file-attributes pathname)))
	(and attributes
	     (not (file-attributes/type attributes)))))

    (define (ignored-file-name? cvs-mode? pathname)
      (let ((name (file-namestring pathname)))
	(or (string-suffix? "~" name)
	    (string-prefix? "#" name)
	    (and (not cvs-mode?) (string-suffix? ",v" name)))))

    (let ((directory (pathname-as-directory pathname)))
      (let ((cvs (merge-pathnames "CVS/" directory)))
	(if (file-directory? cvs)
	    (let ((pathname
		   (merge-pathnames
		    (read-one-line-file (merge-pathnames "Repository" cvs))
		    (pathname-as-directory
		     (read-one-line-file (merge-pathnames "Root" cvs))))))
	      (scan-directory #t pathname pathname))
	    (scan-directory #f pathname pathname))))
    files))

(define (read-one-line-file pathname)
  (call-with-input-file pathname read-line))

(define (greatest-common-prefix pathnames)
  (if (null? pathnames)
      (->pathname "")
      (let ((prefix 'NONE))
	(for-each (lambda (pathname)
		    (let ((directory (pathname-directory pathname)))
		      (set! prefix
			    (if (eq? prefix 'NONE)
				directory
				(let common-prefix ((x prefix) (y directory))
				  (if (and (pair? x)
					   (pair? y)
					   (equal? (car x) (car y)))
				      (cons (car x)
					    (common-prefix (cdr x) (cdr y)))
				      '()))))))
		  pathnames)
	(pathname-new-directory "" prefix))))