;;; -*-Scheme-*-
;;;
;;;	$Id: unix.scm,v 1.32 1993/02/21 05:55:02 cph Exp $
;;;
;;;	Copyright (c) 1989-93 Massachusetts Institute of Technology
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

;;;; Unix Customizations for Edwin

(declare (usual-integrations))

(define-variable backup-by-copying-when-symlink
  "True means use copying to create backups for a symbolic name.
This causes the actual names to refer to the latest version as edited.
'QUERY means ask whether to backup by copying and write through, or rename.
This variable is relevant only if  backup-by-copying  is false."
  false)

(define-variable backup-by-copying-when-linked
  "True means use copying to create backups for files with multiple names.
This causes the alternate names to refer to the latest version as edited.
This variable is relevant only if  backup-by-copying  is false."
  false
  boolean?)

(define-variable backup-by-copying-when-mismatch
  "True means create backups by copying if this preserves owner or group.
Renaming may still be used (subject to control of other variables)
when it would not result in changing the owner or group of the file;
that is, for files which are owned by you and whose group matches
the default for a new file created there by you.
This variable is relevant only if  Backup By Copying  is false."
  false
  boolean?)

(define-variable version-control
  "Control use of version numbers for backup files.
#T means make numeric backup versions unconditionally.
#F means make them for files that have some already.
'NEVER means do not make them."
  false)

(define-variable kept-old-versions
  "Number of oldest versions to keep when a new numbered backup is made."
  2
  exact-nonnegative-integer?)

(define-variable kept-new-versions
  "Number of newest versions to keep when a new numbered backup is made.
Includes the new backup.  Must be > 0."
  2
  (lambda (n) (and (exact-integer? n) (> n 0))))

(define (os/trim-pathname-string string)
  (let ((end (string-length string)))
    (let loop ((index end))
      (let ((slash (substring-find-previous-char string 0 index #\/)))
	(cond ((not slash)
	       string)
	      ((and (< (1+ slash) end)
		    (memv (string-ref string (1+ slash)) '(#\~ #\$)))
	       (string-tail string (1+ slash)))
	      ((zero? slash)
	       string)
	      ((char=? #\/ (string-ref string (-1+ slash)))
	       (string-tail string slash))
	      (else
	       (loop (-1+ slash))))))))

(define (os/pathname->display-string pathname)
  (let ((pathname (enough-pathname pathname (user-homedir-pathname))))
    (if (pathname-absolute? pathname)
	(->namestring pathname)
	(string-append "~/" (->namestring pathname)))))

(define (os/filename->display-string filename)
  (let ((home (unix/current-home-directory)))
    (cond ((not (string-prefix? home filename))
	   filename)
	  ((string=? home filename)
	   "~")
	  ((char=? #\/ (string-ref filename (string-length home)))
	   (string-append "~" (string-tail filename (string-length home))))
	  (else
	   filename))))

(define (os/auto-save-pathname pathname buffer)
  (let ((wrap
	 (lambda (name directory)
	   (merge-pathnames (string-append "#" name "#") directory))))
    (if (not pathname)
	(wrap (string-append "%" (buffer-name buffer))
	      (buffer-default-directory buffer))
	(wrap (file-namestring pathname)
	      (directory-pathname pathname)))))

(define (os/precious-backup-pathname pathname)
  (->pathname (string-append (->namestring pathname) "#")))

(define (os/backup-buffer? truename)
  (and (memv (string-ref (vector-ref (file-attributes truename) 8) 0)
	     '(#\- #\l))
       (not
	(let ((directory (pathname-directory truename)))
	  (and (pair? directory)
	       (eq? 'ABSOLUTE (car directory))
	       (pair? (cdr directory))
	       (eqv? "tmp" (cadr directory)))))))

(define (os/default-backup-filename)
  "~/%backup%~")

(define (os/truncate-filename-for-modeline filename width)
  (let ((length (string-length filename)))
    (if (< 0 width length)
	(let ((result
	       (substring
		filename
		(let ((index (- length width)))
		  (or (and (not (char=? #\/ (string-ref filename index)))
			   (substring-find-next-char filename index length
						     #\/))
		      (1+ index)))
		length)))
	  (string-set! result 0 #\$)
	  result)
	filename)))

(define (os/backup-by-copying? truename buffer)
  (let ((attributes (file-attributes truename)))
    (or (and (ref-variable backup-by-copying-when-linked buffer)
	     (> (file-attributes/n-links attributes) 1))
	(let ((flag (ref-variable backup-by-copying-when-symlink buffer)))
	  (and flag
	       (string? (file-attributes/type attributes))
	       (or (not (eq? flag 'QUERY))
		   (prompt-for-confirmation?
		    (string-append "Write through symlink to "
				   (->namestring
				    (enough-pathname
				     (pathname-simplify
				      (merge-pathnames
				       (file-attributes/type attributes)
				       (buffer-pathname buffer)))
				     (buffer-default-directory buffer))))))))
	(and (ref-variable backup-by-copying-when-mismatch buffer)
	     (not (and (= (file-attributes/uid attributes)
			  (unix/current-uid))
		       (= (file-attributes/gid attributes)
			  (unix/current-gid))))))))

(define (os/buffer-backup-pathname truename)
  (with-values
      (lambda ()
	;; Handle compressed files specially.
	(let ((type (pathname-type truename)))
	  (if (member type unix/encoding-pathname-types)
	      (values (->namestring (pathname-new-type truename false))
		      (string-append "~." type))
	      (values (->namestring truename) "~"))))
    (lambda (filename suffix)
      (let ((no-versions
	     (lambda ()
	       (values (->pathname (string-append filename suffix)) '()))))
	(if (eq? 'NEVER (ref-variable version-control))
	    (no-versions)
	    (let ((prefix (string-append (file-namestring filename) ".~")))
	      (let ((filenames
		     (os/directory-list-completions
		      (directory-namestring filename)
		      prefix))
		    (prefix-length (string-length prefix)))
		(let ((versions
		       (sort
			(let ((pattern
			       (re-compile-pattern
				(string-append "\\([0-9]+\\)"
					       (re-quote-string suffix)
					       "$")
				false)))
			  (let loop ((filenames filenames))
			    (cond ((null? filenames)
				   '())
				  ((re-match-substring-forward
				    pattern false false
				    (car filenames)
				    prefix-length
				    (string-length (car filenames)))
				   (let ((version
					  (string->number
					   (substring
					    (car filenames)
					    (re-match-start-index 1)
					    (re-match-end-index 1)))))
				     (cons version
					   (loop (cdr filenames)))))
				  (else
				   (loop (cdr filenames))))))
			<)))
		  (let ((high-water-mark (apply max (cons 0 versions))))
		    (if (or (ref-variable version-control)
			    (positive? high-water-mark))
			(let ((version->pathname
			       (let ((directory
				      (directory-pathname filename)))
				 (lambda (version)
				   (merge-pathnames
				    (string-append prefix
						   (number->string version)
						   suffix)
				    directory)))))
			  (values
			   (version->pathname (+ high-water-mark 1))
			   (let ((start (ref-variable kept-old-versions))
				 (end
				  (- (length versions)
				     (- (ref-variable kept-new-versions)
					1))))
			     (if (< start end)
				 (map version->pathname
				      (sublist versions start end))
				 '()))))
			(no-versions)))))))))))

(define (os/directory-list directory)
  (let ((channel (directory-channel-open directory)))
    (let loop ((result '()))
      (let ((name (directory-channel-read channel)))
	(if name
	    (loop (cons name result))
	    (begin
	      (directory-channel-close channel)
	      result))))))

(define (os/directory-list-completions directory prefix)
  (let ((channel (directory-channel-open directory)))
    (let loop ((result '()))
      (let ((name (directory-channel-read-matching channel prefix)))
	(if name
	    (loop (cons name result))
	    (begin
	      (directory-channel-close channel)
	      result))))))

(define-integrable os/file-directory?
  (ucode-primitive file-directory?))

(define-integrable (os/make-filename directory filename)
  (string-append directory filename))

(define-integrable (os/filename-as-directory filename)
  (string-append filename "/"))

(define (os/filename-directory filename)
  (let ((end (string-length filename)))
    (let ((index (substring-find-previous-char filename 0 end #\/)))
      (and index
	   (substring filename 0 (+ index 1))))))

(define (os/filename-non-directory filename)
  (let ((end (string-length filename)))
    (let ((index (substring-find-previous-char filename 0 end #\/)))
      (if index
	  (substring filename (+ index 1) end)
	  filename))))

(define unix/encoding-pathname-types
  '("Z"))

(define unix/backup-suffixes
  (cons "~"
	(map (lambda (type) (string-append "~." type))
	     unix/encoding-pathname-types)))

(define (os/backup-filename? filename)
  (let loop ((suffixes unix/backup-suffixes))
    (and (not (null? suffixes))
	 (or (string-suffix? (car suffixes) filename)
	     (loop (cdr suffixes))))))

(define (os/pathname-type-for-mode pathname)
  (let ((type (pathname-type pathname)))
    (if (member type unix/encoding-pathname-types)
	(pathname-type (->namestring (pathname-new-type pathname false)))
	type)))

(define (os/completion-ignore-filename? filename)
  (and (not (os/file-directory? filename))
       (there-exists? (ref-variable completion-ignored-extensions)
         (lambda (extension)
	   (string-suffix? extension filename)))))

(define (os/completion-ignored-extensions)
  (append '(".o" ".elc" ".bin" ".lbin" ".fasl"
		 ".dvi" ".toc" ".log" ".aux"
		 ".lof" ".blg" ".bbl" ".glo" ".idx" ".lot")
	  (list-copy unix/backup-suffixes)))

(define-variable completion-ignored-extensions
  "Completion ignores filenames ending in any string in this list."
  (os/completion-ignored-extensions)
  (lambda (extensions)
    (and (list? extensions)
	 (for-all? extensions
	   (lambda (extension)
	     (and (string? extension)
		  (not (string-null? extension))))))))

(define (os/file-type-to-major-mode)
  (alist-copy
   `(("article" . text)
     ("asm" . midas)
     ("bib" . text)
     ("c" . c)
     ("cc" . c)
     ("h" . c)
     ("pas" . pascal)
     ("s" . scheme)
     ("scm" . scheme)
     ("text" . text)
     ("txi" . texinfo)
     ("txt" . text)
     ("y" . c))))

(define (os/init-file-name)
  "~/.edwin")

(define (os/find-file-initialization-filename pathname)
  (or (and (equal? "scm" (pathname-type pathname))
	   (let ((pathname (pathname-new-type pathname "ffi")))
	     (and (file-exists? pathname)
		  pathname)))
      (let ((pathname
	     (merge-pathnames ".edwin-ffi" (directory-pathname pathname))))
	(and (file-exists? pathname)
	     pathname))))

(define (os/auto-save-filename? filename)
  ;; This could be more sophisticated, but is what the edwin
  ;; code was originally doing.
  (and (string? filename)
       (string-find-next-char filename #\#)))

(define (os/read-file-methods)
  (list maybe-read-compressed-file
	maybe-read-encrypted-file))

(define (os/write-file-methods)
  (list maybe-write-compressed-file
	maybe-write-encrypted-file))

;;;; Compressed Files

(define-variable enable-compressed-files
  "If true, compressed files are automatically uncompressed when read,
and recompressed when written.  A compressed file is identified by the
filename suffix \".Z\"."
  true
  boolean?)

(define (maybe-read-compressed-file pathname mark visit?)
  visit?
  (and (ref-variable enable-compressed-files mark)
       (equal? "Z" (pathname-type pathname))
       (begin
	 (read-compressed-file pathname mark)
	 true)))

(define (read-compressed-file pathname mark)
  (if (not (equal? '(EXITED . 0)
		   (shell-command false
				  mark
				  (directory-pathname pathname)
				  false
				  (string-append "uncompress < "
						 (file-namestring pathname)))))
      (error:file-operation pathname
			    "uncompress"
			    "file"
			    "[unknown]"
			    read-compressed-file
			    (list pathname mark))))

(define (maybe-write-compressed-file region pathname visit?)
  visit?
  (and (ref-variable enable-compressed-files (region-start region))
       (equal? "Z" (pathname-type pathname))
       (begin
	 (write-compressed-file region pathname)
	 true)))

(define (write-compressed-file region pathname)
  (if (not (equal? '(EXITED . 0)
		   (shell-command region
				  false
				  (directory-pathname pathname)
				  false
				  (string-append "compress > "
						 (file-namestring pathname)))))
      (error:file-operation pathname
			    "compress"
			    "file"
			    "[unknown]"
			    write-compressed-file
			    (list region pathname))))

;;;; Encrypted files

(define-variable enable-encrypted-files
  "If true, encrypted files are automatically decrypted when read,
and recrypted when written.  An encrypted file is identified by the
filename suffix \".KY\"."
  true
  boolean?)

(define (maybe-read-encrypted-file pathname mark visit?)
  visit?
  (and (ref-variable enable-encrypted-files mark)
       (equal? "KY" (pathname-type pathname))
       (begin
	 (read-encrypted-file pathname mark)
	 true)))

(define (read-encrypted-file pathname mark)
  (let ((the-encrypted-file
	 (with-input-from-file pathname
	   (lambda ()
	     (read-string (char-set)))))
	(password 
	 (prompt-for-password "Password: ")))
    (insert-string
     (decrypt the-encrypted-file password
	      (lambda () 
		(kill-buffer (mark-buffer mark))
		(editor-beep)
		(message "krypt: Password error!")
		(abort-current-command))
	      (lambda (x) 
		(editor-beep)
		(message "krypt: Checksum error!")
		x))
     mark)
    ;; CPH says that this doesn't work because mode initialization
    ;; zaps the buffer's variables afterwards:
#|
    ;; Disable auto-save here since we don't want to
    ;; auto-save the unencrypted contents of the 
    ;; encrypted file.
    (define-variable-local-value! (mark-buffer mark)
      (name->variable 'auto-save-default) #f)
|#
    ))

(define (maybe-write-encrypted-file region pathname visit?)
  visit?
  (and (ref-variable enable-encrypted-files (region-start region))
       (equal? "KY" (pathname-type pathname))
       (begin
	 (write-encrypted-file region pathname)
	 true)))

(define (write-encrypted-file region pathname)
  (let* ((password 
	  (prompt-for-confirmed-password))
	 (the-encrypted-file
	  (encrypt (extract-string (region-start region) (region-end region))
		   password)))
    (with-output-to-file pathname
      (lambda ()
	(write-string the-encrypted-file)))))

;;; End of encrypted files

;;;; Dired customization

(define-variable dired-listing-switches
  "Switches passed to ls for dired.  MUST contain the 'l' option.
CANNOT contain the 'F' option."
  "-al"
  string?)

(define-variable list-directory-brief-switches
  "Switches for list-directory to pass to `ls' for brief listing,"
  "-CF"
  string?)

(define-variable list-directory-verbose-switches
  "Switches for list-directory to pass to `ls' for verbose listing,"
  "-l"
  string?)

(define (read-directory pathname switches mark)
  (let ((directory (directory-pathname pathname)))
    (if (file-directory? pathname)
	(run-synchronous-process false mark directory false
				 (find-program "ls" false)
				 switches
				 (->namestring pathname))
	(shell-command false mark directory false
		       (string-append "ls "
				      switches
				      " "
				      (file-namestring pathname))))))

(define (insert-dired-entry! pathname directory lstart)
  (let ((start (mark-right-inserting lstart)))
    (run-synchronous-process false lstart directory false
			     (find-program "ls" directory)
			     "-d"
			     (ref-variable dired-listing-switches lstart)
			     (->namestring pathname))
    (insert-string "  " start)
    (let ((start (mark-right-inserting (dired-filename-start start))))
      (insert-string
       (file-namestring
	(extract-and-delete-string start (line-end start 0)))
       start))))