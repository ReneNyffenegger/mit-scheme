#| -*-Scheme-*-

$Id: dospth.scm,v 1.18 1993/01/12 23:09:04 gjr Exp $

Copyright (c) 1992-1993 Massachusetts Institute of Technology

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

;;;; Dos Pathnames (originally based on unxpth version 14.9)
;;; package: (runtime pathname dos)

(declare (usual-integrations))

(define hook/dos/end-of-line-string)
(define hook/dos/end-of-file-marker/input)
(define hook/dos/end-of-file-marker/output)

(define sub-directory-delimiters
  ;; Allow forward slashes as well as backward slashes so that
  ;; - improperly-written scripts (e.g. compiler/comp.sf) will work
  ;; - laziness when typing file names since the backward slash
  ;;   must be quoted by another.
  (char-set #\\ #\/))

(define sub-directory-delimiter-string 
  "\\")

(define init-file-name "scheme.ini")

(define (make-dos-host-type index)
  (make-host-type index
		  'DOS
		  dos/parse-namestring
		  dos/pathname->namestring
		  dos/make-pathname
		  dos/pathname-wild?
		  dos/pathname-as-directory
		  dos/directory-pathname-as-file
		  dos/pathname->truename
		  dos/user-homedir-pathname
		  dos/init-file-pathname
		  dos/pathname-simplify
		  dos/end-of-line-string
		  dos/canonicalize
		  dos/end-of-file-marker/input
		  dos/end-of-file-marker/output))

(define (initialize-package!)
  (set! hook/dos/end-of-line-string default/dos/end-of-line-string)
  (set! hook/dos/end-of-file-marker/input default/dos/end-of-file-marker/input)
  (set! hook/dos/end-of-file-marker/output default/dos/end-of-file-marker/output)
  (add-pathname-host-type! 'DOS make-dos-host-type))

;;;; Pathname Parser

(define (dos/parse-namestring string host)
  ;; The DOS file system is case-insensitive, and the canonical case
  ;; is upper, but it is too inconvenient to type.
  (let ((components (string-components (string-downcase string)
				       sub-directory-delimiters)))
    (with-namestring-device-and-path
      (expand-directory-prefixes (car components))
      (lambda (device directory-components)
	(let ((components (append directory-components (cdr components))))
	  (parse-name (car (last-pair components))
            (lambda (name type)
	      (%make-pathname host
			      device
			      (let ((components (except-last-pair components)))
				(and (not (null? components))
				     (simplify-directory
				      (if (string=? "" (car components))
					  (cons 'ABSOLUTE
						(map parse-directory-component
						     (cdr components)))
					  (cons 'RELATIVE
						(map parse-directory-component
						     components))))))
			      name
			      type
			      'UNSPECIFIC))))))))

(define (with-namestring-device-and-path components receiver)
  (let ((string (car components)))
    (let ((colon (string-find-next-char string #\:)))
      (if (not colon)
	  (receiver false components)
	  (receiver (substring string 0 (1+ colon))
		    (cons 
		     (substring string (1+ colon)
				(string-length string))
		     (cdr components)))))))

(define (simplify-directory directory)
  (if (and (eq? (car directory) 'RELATIVE) (null? (cdr directory)))
      false
      directory))

(define (parse-directory-component component)
  (if (string=? ".." component)
      'UP
      (let ((len (string-length component)))
	(cond ((substring-find-previous-char component 0 len #\.)
	       ;; Handle screwy directories with dots in their names.
	       (parse-name component unparse-name))
	      ((> len 8)
	       (substring component 0 8))
	      (else
	       component)))))

(define (expand-directory-prefixes string)
  (if (or (string-null? string)
	  (not *expand-directory-prefixes?*))
      (list string)
      (case (string-ref string 0)
	((#\$)
	 (let* ((name (string-tail string 1))
		(value (get-environment-variable name)))
	   (if (not value)
	       (list string)
	       (string-components value sub-directory-delimiters))))
	((#\~)
	 (let ((user-name (substring string 1 (string-length string))))
	   (string-components
	    (if (string-null? user-name)
		(dos/current-home-directory)
		(dos/user-home-directory user-name))
	    sub-directory-delimiters)))
	(else (list string)))))

(define (string-components string delimiters)
  (substring-components string 0 (string-length string) delimiters))

(define (substring-components string start end delimiters)
  (let loop ((start start))
    (let ((index (substring-find-next-char-in-set string start 
                                                  end delimiters)))
      (if index
	  (cons (substring string start index) (loop (+ index 1)))
	  (list (substring string start end))))))

(define (parse-name string receiver)
  (let ((receiver
	 (lambda (first second)
	   (receiver (if (and (string? first)
			      (> (string-length first) 8))
			 (substring first 0 8)
			 first)
		     (if (and (string? second)
			      (> (string-length second) 3))
			 (substring second 0 3)
			 second)))))
    (let ((end (string-length string)))
      (let ((dot (substring-find-previous-char string 0 end #\.)))
	(if (or (not dot)
		(= dot 0)
		(= dot (- end 1))
		(char=? #\. (string-ref string (- dot 1))))
	    (receiver (cond ((= end 0) false)
			    ((string=? "*" string) 'WILD)
			    (else string))
		      false)
	    (receiver (extract string 0 dot)
		      (extract string (+ dot 1) end)))))))

(define (extract string start end)
  (if (substring=? string start end "*" 0 1)
      'WILD
      (substring string start end)))

(define (dos/canonicalize pathname)
  (define (valid? field length)
    (or (not (string? field))
	(<= (string-length field) length)))

  (define (canonicalize-field field length)
    (if (valid? field length)
	field
	(substring field 0 length)))

  ;; This should really canonicalize the directory as well.
  (let ((name (%pathname-name pathname))
	(type (%pathname-type pathname)))
    (if (and (valid? name 8) (valid? type 3))
	pathname
	(%make-pathname (%pathname-host pathname)
			(%pathname-device pathname)
			(%pathname-directory pathname)
			(canonicalize-field name 8)
			(canonicalize-field type 3)
			(%pathname-version pathname)))))

;;;; Pathname Unparser

(define (dos/pathname->namestring pathname)
  (string-append (unparse-device (%pathname-device pathname))
		 (unparse-directory (%pathname-directory pathname))
		 (unparse-name (%pathname-name pathname)
			       (%pathname-type pathname))))

(define (unparse-device device)
  (if (or (not device) (eq? device 'UNSPECIFIC))
      ""
      device))

(define (unparse-directory directory)
  (cond ((or (not directory) (eq? directory 'UNSPECIFIC))
	 "")
	((pair? directory)
	 (string-append
	  (if (eq? (car directory) 'ABSOLUTE) 
              sub-directory-delimiter-string
              "")
	  (let loop ((directory (cdr directory)))
	    (if (null? directory)
		""
		(string-append (unparse-directory-component (car directory))
			       sub-directory-delimiter-string
			       (loop (cdr directory)))))))
	(else
	 (error "Illegal pathname directory:" directory))))

(define (unparse-directory-component component)
  (cond ((eq? component 'UP) "..")
	((string? component) component)
	(else (error "Illegal pathname directory component:" component))))

(define (unparse-name name type)
  (let ((name (or (unparse-component name) ""))
	(type (unparse-component type)))
    (if type
	(string-append name "." type)
	name)))

(define (unparse-component component)
  (cond ((or (not component) (string? component)) component)
	((eq? component 'WILD) "*")
	(else (error "Illegal pathname component:" component))))

;;;; Pathname Constructors

(define (dos/make-pathname host device directory name type version)
  (define (check-directory-components components)
    (for-all? components
      (lambda (element)
	(if (string? element)
	    (not (string-null? element))
	    (eq? element 'UP)))))
    
  (%make-pathname
   host
   (cond ((string? device) device)
	 ((memq device '(#F UNSPECIFIC)) device)
	 (else
	  (error:wrong-type-argument device "pathname device" 'MAKE-PATHNAME)))
   (cond ((or (not directory) (eq? directory 'UNSPECIFIC))
	  directory)
	 ((and (list? directory)
	       (not (null? directory))
	       (case (car directory)
		 ((RELATIVE)
		  (check-directory-components (cdr directory)))
		 ((ABSOLUTE)
		  ;; This should handle share network drives (\\machine\...)
		  (let ((rest (cdr directory)))
		    (or (null? rest)
			(and (string? (car rest))
			     (check-directory-components (cdr rest))))))
		 (else
		  false)))
	  (simplify-directory directory))
	 (else
	  (error:wrong-type-argument directory "pathname directory"
				     'MAKE-PATHNAME)))
   (if (or (memq name '(#F WILD))
	   (and (string? name) (not (string-null? name))))
       name
       (error:wrong-type-argument name "pathname name" 'MAKE-PATHNAME))
   (if (or (memq type '(#F WILD))
	   (and (string? type) (not (string-null? type))))
       type
       (error:wrong-type-argument type "pathname type" 'MAKE-PATHNAME))
   (if (memq version '(#F UNSPECIFIC WILD NEWEST))
       'UNSPECIFIC
       (error:wrong-type-argument version "pathname version"
				  'MAKE-PATHNAME))))

(define (dos/pathname-as-directory pathname)
  (let ((name (%pathname-name pathname))
	(type (%pathname-type pathname)))
    (if (or name type)
	(%make-pathname
	 (%pathname-host pathname)
	 (%pathname-device pathname)
	 (let ((directory (%pathname-directory pathname))
	       (component
		(parse-directory-component (unparse-name name type))))
	   (cond ((not (pair? directory))
		  (list 'RELATIVE component))
		 ((equal? component ".")
		  directory)
		 (else
		  (append directory (list component)))))
	 false
	 false
	 'UNSPECIFIC)
	pathname)))

(define (dos/directory-pathname-as-file pathname)
  (let ((directory (%pathname-directory pathname)))
    (if (not (and (pair? directory)
		  (or (eq? 'ABSOLUTE (car directory))
		      (pair? (cdr directory)))))
	(error:bad-range-argument pathname 'DIRECTORY-PATHNAME-AS-FILE))
    (if (null? (cdr directory))
	(%make-pathname (%pathname-host pathname)
			(%pathname-device pathname)
			directory
			""
			false
			'UNSPECIFIC)
	(parse-name (unparse-directory-component (car (last-pair directory)))
	  (lambda (name type)
	    (%make-pathname (%pathname-host pathname)
			    (%pathname-device pathname)
			    (simplify-directory (except-last-pair directory))
			    name
			    type
			    'UNSPECIFIC))))))

;;;; Miscellaneous

(define (dos/pathname-wild? pathname)
  (or (eq? 'WILD (%pathname-name pathname))
      (eq? 'WILD (%pathname-type pathname))))

(define (dos/pathname->truename pathname)
  (if (eq? true (file-exists? pathname))
      pathname
      (dos/pathname->truename
       (error:file-operation pathname "find" "file" "file does not exist"
			     dos/pathname->truename (list pathname)))))

(define (dos/user-homedir-pathname host)
  (and (eq? host local-host)
       (pathname-as-directory (dos/current-home-directory))))

(define (dos/init-file-pathname host)
  (let ((pathname
	 (merge-pathnames init-file-name (dos/user-homedir-pathname host))))
    (and (file-exists? pathname)
	 pathname)))

(define (dos/pathname-simplify pathname)
  (or (and (implemented-primitive-procedure? (ucode-primitive file-eq? 2))
	   (let ((directory (pathname-directory pathname)))
	     (and (pair? directory)
		  (let ((directory*
			 (cons (car directory)
			       (reverse!
				(let loop
				    ((elements (reverse (cdr directory))))
				  (if (null? elements)
				      '()
				       (let ((head (car elements))
					     (tail (loop (cdr elements))))
					 (if (and (eq? head 'UP)
						  (not (null? tail))
						  (not (eq? (car tail) 'UP)))
					     (cdr tail)
					     (cons head tail)))))))))
		    (and (not (equal? directory directory*))
			 (let ((pathname*
				(pathname-new-directory pathname directory*)))
			   (and ((ucode-primitive file-eq? 2)
				 (->namestring pathname)
				 (->namestring pathname*))
				pathname*)))))))
      pathname))

(define (dos/end-of-line-string pathname)
  (hook/dos/end-of-line-string pathname))

(define (default/dos/end-of-line-string pathname)
  pathname				; ignored
  "\r\n")

;; Scheme understands files that end in ^Z, but does not create them

(define (dos/end-of-file-marker/input pathname)
  (hook/dos/end-of-file-marker/input pathname))

(define (default/dos/end-of-file-marker/input pathname)
  pathname				; ignored
  #\Call				; ^Z
  )

(define (dos/end-of-file-marker/output pathname)
  (hook/dos/end-of-file-marker/output pathname))

(define (default/dos/end-of-file-marker/output pathname)
  pathname				; ignored
  false)