;;; -*-Scheme-*-
;;;
;;;	$Id: dos.scm,v 1.26 1995/07/11 23:10:41 cph Exp $
;;;
;;;	Copyright (c) 1992-95 Massachusetts Institute of Technology
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

;;;; DOS Customizations for Edwin

(declare (usual-integrations))

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
  true
  (lambda (thing)
    (or (eq? thing 'NEVER) (boolean? thing))))

(define-variable kept-old-versions
  "Number of oldest versions to keep when a new numbered backup is made."
  2
  exact-nonnegative-integer?)

(define-variable kept-new-versions
  "Number of newest versions to keep when a new numbered backup is made.
Includes the new backup.  Must be > 0."
  2
  (lambda (n) (and (exact-integer? n) (> n 0))))

(define os/directory-char-set (char-set #\\ #\/))
(define os/expand-char-set (char-set #\$ #\~))

(define (os/trim-pathname-string string prefix)
  (let ((index (string-match-forward prefix string)))
    (if (and index
	     (re-match-substring-forward
	      (re-compile-pattern "[\\/$~]\\|[a-zA-Z]:" #t)
	      #t #f string index (string-length string)))
	(string-tail string index)
	string)))

(define os/pathname->display-string
  ->namestring)

(define (file-type->version type version)
  (let ((version-string
	 (and (fix:fixnum? version)
	      (number->string (fix:remainder version 1000)))))
    (if (not version-string)
	(error "Illegal version" version)
	(let ((version-string
	       (string-pad-left version-string 3 #\0)))
	  (if (string? type)
	      (if (fix:> (string-length type) 0)
		  (string-append (substring type 0 1)
				 (substring version-string 1 3))
		  version-string)
	      version-string)))))

(define (filename->version-number filename)
  (let ((type (pathname-type filename)))
    (and (string? type)
	 (fix:= (string-length type) 3)
	 (or (string->number type)
	     (string->number (substring type 1 3))))))

(define (os/auto-save-pathname pathname buffer)
  buffer
  (pathname-new-type pathname
		     (file-type->version (pathname-type pathname) 0)))

(define (os/precious-backup-pathname pathname)
  ;; Use the autosave name for the precious backup
  (pathname-new-type pathname
		     (file-type->version (pathname-type pathname) 0)))

(define (os/backup-buffer? truename)
  (let ((attrs (file-attributes truename)))
    (and attrs
	 (memv (string-ref (file-attributes/mode-string attrs) 0)
	       '(#\- #\l))
	 (not (let ((directory (pathname-directory truename)))
		(and (pair? directory)
		     (eq? 'ABSOLUTE (car directory))
		     (pair? (cdr directory))
		     (eqv? "tmp" (cadr directory))))))))

(define (os/default-backup-filename)
  "c:/tmp/edwin.bak")

(define (os/truncate-filename-for-modeline filename width)
  (let ((length (string-length filename)))
    (if (< 0 width length)
	(let ((result
	       (substring
		filename
		(let ((index (- length width)))
		  (or (and (not
			    (char-set-member? os/directory-char-set
					      (string-ref filename index)))
			   (substring-find-next-char-in-set
			    filename index length os/directory-char-set))
		      (1+ index)))
		length)))
	  (string-set! result 0 #\$)
	  result)
	filename)))

(define (os/backup-by-copying? truename buffer) 
  truename buffer
  false)
	
(define (os/buffer-backup-pathname truename)
  (let ((directory (directory-namestring truename))
	(type (pathname-type truename))
	(filename (pathname-name truename)))

    (define (no-versions)
      (values (pathname-new-type truename (file-type->version type 0)) '()))
    (define (version->pathname version)
      (pathname-new-type truename (file-type->version type version)))
    (define (files->versions files)
      (if (or (not files) (null? files))
	  '()
	  (let ((type-number (filename->version-number (car files))))
	    (if type-number
		(cons type-number (files->versions (cdr files)))
		(files->versions (cdr files))))))
	  
    (if (eq? 'NEVER (ref-variable version-control))
	(no-versions)
	(let ((search-name (string-append filename ".")))
	  (let ((filenames
		 (os/directory-list-completions directory search-name)))
	    (let ((versions (sort (files->versions filenames) <)))
	      (let ((high-water-mark (apply max (cons 0 versions))))
		(if (or (ref-variable version-control)
			(positive? high-water-mark))
		    (values
		     (version->pathname (+ high-water-mark 1))
		     (let ((start (ref-variable kept-old-versions))
			   (end (fix:- (length versions)
				       (fix:-1+
					(ref-variable kept-new-versions)))))
		       (if (fix:< start end)
			   (map version->pathname
				(sublist versions start end))
			   '())))
		    (no-versions)))))))))

(define (os/directory-list-completions directory prefix)
  (define (->directory-namestring s)
    (->namestring (pathname-as-directory (->pathname s))))

  (define (->directory-wildcard s)
    (string-append (->directory-namestring s)
		   "*.*"))

  (let ((plen (string-length prefix)))
    (let loop ((pathnames (directory-read (->directory-wildcard directory))))
      (if (null? pathnames)
	  '()
	  (let ((filename (file-namestring (car pathnames))))
	    (if (and (fix:>= (string-length filename) plen)
		     (string-ci=? prefix (substring filename 0 plen)))
		(cons filename (loop (cdr pathnames)))
		(loop (cdr pathnames))))))))

(define (os/directory-list directory)
  (os/directory-list-completions directory ""))

(define dos/encoding-pathname-types '())

(define dos/backup-suffixes '())

(define (os/backup-filename? filename)
  (let ((version (filename->version-number filename)))
    (and (fix:fixnum? version)
	 (fix:> version 0))))

(define (os/numeric-backup-filename? filename)
  (let ((type (pathname-type filename)))
    (and (string? type)
	 (fix:= (string-length type) 3)
	 (let ((version (string->number type)))
	   (and version
		(cons (->namestring (pathname-new-type filename #f))
		      version)))
	 (let ((version (substring->number type 1 3)))
	   (and version
		(cons (->namestring (pathname-new-type filename
						       (string-head type 1)))
		      version))))))

(define (os/auto-save-filename? filename)
  (let ((version (filename->version-number filename)))
    (and (fix:fixnum? version)
	 (fix:= version 0))))  

(define (os/pathname-type-for-mode pathname)
  (let ((type (pathname-type pathname)))
    (if (member type dos/encoding-pathname-types)
	(pathname-type (->namestring (pathname-new-type pathname false)))
	type)))

(define (os/completion-ignore-filename? filename)
  (or (os/backup-filename? filename)
      (os/auto-save-filename? filename)
      (and (not (file-directory? filename))
	   (there-exists? (ref-variable completion-ignored-extensions)
   	     (lambda (extension)
	       (string-suffix? extension filename))))))

(define (os/completion-ignored-extensions)
  (append '(".bin" ".com" ".ext"
	    ".inf" ".bif" ".bsm" ".bci" ".bcs"
  	    ".psb" ".moc" ".fni"
  	    ".bco" ".bld" ".bad" ".glo" ".fre"
	    ".obj" ".exe" ".pif" ".grp"
	    ".dvi" ".toc" ".log" ".aux")
	  (list-copy dos/backup-suffixes)))

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
   `(("asm" . midas)
     ("bat" . text)
     ("bib" . text)
     ("c" . c)
     ("h" . c)
     ("m4" . midas)
     ("pas" . pascal)
     ("s" . scheme)
     ("scm" . scheme)
     ("txi" . texinfo)
     ("txt" . text))))

(define (os/init-file-name)
  (let ((user-init-file
	 (merge-pathnames "edwin.ini"
			  (pathname-as-directory (current-home-directory)))))
    (if (file-exists? user-init-file)
	(->namestring user-init-file)
	"/scheme/lib/edwin.ini")))

(define (os/find-file-initialization-filename pathname)
  (or (and (equal? "scm" (pathname-type pathname))
	   (let ((pathname (pathname-new-type pathname "ffi")))
	     (and (file-exists? pathname)
		  pathname)))
      (let ((pathname
	     (merge-pathnames "edwin.ffi" (directory-pathname pathname))))
	(and (file-exists? pathname)
	     pathname))))

(define (os/read-file-methods) '())

(define (os/write-file-methods) '())

;;;; Dired customization

(define-variable dired-listing-switches
  "Dired listing format -- Ignored under DOS."
  #f
  false?)

(define-variable list-directory-brief-switches
  "list-directory brief listing format -- Ignored under DOS."
  #f
  false?)

(define-variable list-directory-verbose-switches
  "list-directory verbose listing format -- Ignored under DOS."
  #f
  false?)

(define (insert-directory! file switches mark type)
  switches				; ignored
  ;; Insert directory listing for FILE at MARK.
  ;; TYPE can have one of three values:
  ;;   'WILDCARD means treat FILE as shell wildcard.
  ;;   'DIRECTORY means FILE is a directory and a full listing is expected.
  ;;   'FILE means FILE itself should be listed, and not its contents.
  ;; SWITCHES are ignored.
  (case type
    ((WILDCARD)
     (generate-dired-listing! file mark))
    ((DIRECTORY)
     (generate-dired-listing!
      (string-append (->namestring (pathname-as-directory file))
		     "*.*")
      mark))
    (else
     (generate-dired-entry! file mark))))

;;; Scheme version of ls

(define (generate-dired-listing! pathname point)
  (let ((files (directory-read (->namestring (merge-pathnames pathname)))))
    (for-each (lambda (file) (generate-dired-entry! file point))
	      files)))

(define (generate-dired-entry! file point)
  (define (file-attributes/ls-time-string attr)
    ;; Swap year around to the start
    (let ((time-string
	   (file-time->string (file-attributes/modification-time attr))))
      (if (string? time-string)
	  (or (let ((len (string-length time-string)))
		(and (fix:> len 5) ;; Grap the space char as well
		     (string-append (substring time-string (fix:- len 5) len)
				    " "
				    (substring time-string 0 (fix:- len 5)))))
	      ""))))

  (let ((name (file-namestring file))
	(attr (or (file-attributes file)
		  (dummy-file-attributes))))
    (let ((entry (string-append
		  (string-pad-right	; Mode string
		   (file-attributes/mode-string attr) 12 #\Space)
		  (string-pad-left    ; Length
		   (number->string (file-attributes/length attr)) 10 #\Space)
		  (string-pad-right   ; Mod time
		   (file-attributes/ls-time-string attr) 26 #\Space)
		  name)))
      (let ((point (mark-left-inserting-copy point)))
	(insert-string entry point)
	(insert-newline point)
	(mark-temporary! point)))))

(define-integrable (dummy-file-attributes)
  '#(#f 0 0 0 0 0 0 0 "----------" 0))

(define (os/scheme-can-quit?)
  true)

(define (os/quit dir)
  (with-real-working-directory-pathname dir %quit))

(define (with-real-working-directory-pathname dir thunk)
  (let ((inside (->namestring (directory-pathname-as-file dir)))
	(outside false))
    (dynamic-wind
     (lambda ()
       (stop-thread-timer)
       (set! outside (->namestring
			  (directory-pathname-as-file
			   (working-directory-pathname))))
       (set-working-directory-pathname! inside)
       ((ucode-primitive set-working-directory-pathname! 1) inside))
     thunk
     (lambda ()
       (set! inside (->namestring
		     (directory-pathname-as-file
		      (working-directory-pathname))))
       ((ucode-primitive set-working-directory-pathname! 1) outside)
       (set-working-directory-pathname! outside)
       (start-thread-timer)))))

(define (os/set-file-modes-writable! pathname)
  (set-file-modes! pathname #o777))

(define (os/sendmail-program)
  "sendmail.exe")

(define (os/rmail-pop-procedure)
  #f)

(define (os/hostname)
  (error "OS/HOSTNAME procedure unimplemented."))

(define (os/interprogram-cut string)
  string push?
  unspecific)

(define (os/interprogram-paste)
  #f)