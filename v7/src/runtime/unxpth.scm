#| -*-Scheme-*-

$Id: unxpth.scm,v 14.21 1996/02/27 21:53:14 cph Exp $

Copyright (c) 1988-96 Massachusetts Institute of Technology

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

;;;; Unix Pathnames
;;; package: (runtime pathname unix)

(declare (usual-integrations))

(define (make-unix-host-type index)
  (make-host-type index
		  'UNIX
		  unix/parse-namestring
		  unix/pathname->namestring
		  unix/make-pathname
		  unix/pathname-wild?
		  unix/pathname-as-directory
		  unix/directory-pathname-as-file
		  unix/pathname->truename
		  unix/user-homedir-pathname
		  unix/init-file-pathname
		  unix/pathname-simplify
		  unix/end-of-line-string))

(define (initialize-package!)
  (add-pathname-host-type! 'UNIX make-unix-host-type))

;;;; Pathname Parser

(define (unix/parse-namestring string host)
  (let ((end (string-length string)))
    (let ((components
	   (expand-directory-prefixes
	    (substring-components string 0 end #\/))))
      (parse-name (car (last-pair components))
	(lambda (name type)
	  (%make-pathname host
			  'UNSPECIFIC
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
			  'UNSPECIFIC))))))

(define (expand-directory-prefixes components)
  (let ((string (car components))
	(replace-head
	 (lambda (string)
	   ;; If STRING has a trailing slash, and it's followed by a
	   ;; slash, drop the trailing slash to avoid doubling.
	   (let ((head (string-components string #\/)))
	     (append (if (and (pair? (cdr components))
			      (pair? (cdr head))
			      (string-null? (car (last-pair head))))
			 (except-last-pair head)
			 head)
		     (cdr components))))))
    (if (or (string-null? string)
	    (not *expand-directory-prefixes?*))
	components
	(case (string-ref string 0)
	  ((#\$)
	   (let ((name (string-tail string 1)))
	     (let ((value (get-environment-variable name)))
	       (if value
		   (replace-head value)
		   components))))
	  ((#\~)
	   (replace-head
	    (->namestring
	     (let ((user-name (substring string 1 (string-length string))))
	       (if (string-null? user-name)
		   (current-home-directory)
		   (user-home-directory user-name))))))
	  (else components)))))

(define (simplify-directory directory)
  (if (and (eq? (car directory) 'RELATIVE) (null? (cdr directory)))
      false
      directory))

(define (parse-directory-component component)
  (if (string=? ".." component)
      'UP
      component))

(define (string-components string delimiter)
  (substring-components string 0 (string-length string) delimiter))

(define (substring-components string start end delimiter)
  (let loop ((start start))
    (let ((index (substring-find-next-char string start end delimiter)))
      (if index
	  (cons (substring string start index) (loop (+ index 1)))
	  (list (substring string start end))))))

(define (parse-name string receiver)
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
		    (extract string (+ dot 1) end))))))

(define (extract string start end)
  (if (substring=? string start end "*" 0 1)
      'WILD
      (substring string start end)))

;;;; Pathname Unparser

(define (unix/pathname->namestring pathname)
  (string-append (unparse-directory (%pathname-directory pathname))
		 (unparse-name (%pathname-name pathname)
			       (%pathname-type pathname))))

(define (unparse-directory directory)
  (cond ((not directory)
	 "")
	((pair? directory)
	 (string-append
	  (if (eq? (car directory) 'ABSOLUTE) "/" "")
	  (let loop ((directory (cdr directory)))
	    (if (null? directory)
		""
		(string-append (unparse-directory-component (car directory))
			       "/"
			       (loop (cdr directory)))))))
	(else
	 (error:illegal-pathname-component directory "directory"))))

(define (unparse-directory-component component)
  (cond ((eq? component 'UP) "..")
	((string? component) component)
	(else
	 (error:illegal-pathname-component component "directory component"))))

(define (unparse-name name type)
  (let ((name (or (unparse-component name) ""))
	(type (unparse-component type)))
    (if type
	(string-append name "." type)
	name)))

(define (unparse-component component)
  (cond ((or (not component) (string? component)) component)
	((eq? component 'WILD) "*")
	(else (error:illegal-pathname-component component "component"))))

;;;; Pathname Constructors

(define (unix/make-pathname host device directory name type version)
  (%make-pathname
   host
   (if (memq device '(#F UNSPECIFIC))
       'UNSPECIFIC
       (error:illegal-pathname-component device "device"))
   (cond ((not directory)
	  directory)
	 ((and (list? directory)
	       (not (null? directory))
	       (memq (car directory) '(RELATIVE ABSOLUTE))
	       (for-all? (cdr directory)
		 (lambda (element)
		   (if (string? element)
		       (not (string-null? element))
		       (eq? element 'UP)))))
	  (simplify-directory directory))
	 (else
	  (error:illegal-pathname-component directory "directory")))
   (if (or (memq name '(#F WILD))
	   (and (string? name) (not (string-null? name))))
       name
       (error:illegal-pathname-component name "name"))
   (if (or (memq type '(#F WILD))
	   (and (string? type) (not (string-null? type))))
       type
       (error:illegal-pathname-component type "type"))
   (if (memq version '(#F UNSPECIFIC WILD NEWEST))
       'UNSPECIFIC
       (error:illegal-pathname-component version "version"))))

(define (unix/pathname-as-directory pathname)
  (let ((name (%pathname-name pathname))
	(type (%pathname-type pathname)))
    (if (or name type)
	(%make-pathname
	 (%pathname-host pathname)
	 'UNSPECIFIC
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

(define (unix/directory-pathname-as-file pathname)
  (let ((directory (%pathname-directory pathname)))
    (if (not (and (pair? directory)
		  (or (eq? 'ABSOLUTE (car directory))
		      (pair? (cdr directory)))))
	(error:bad-range-argument pathname 'DIRECTORY-PATHNAME-AS-FILE))
    (if (or (%pathname-name pathname)
	    (%pathname-type pathname)
	    (null? (cdr directory)))
	;; Root directory can't be represented as a file, because the
	;; name field of a pathname must be a non-null string.  We
	;; could signal an error here, but instead we'll just return
	;; the original pathname and leave it to the caller to deal
	;; with any problems this might cause.
	pathname
	(parse-name (unparse-directory-component (car (last-pair directory)))
	  (lambda (name type)
	    (%make-pathname (%pathname-host pathname)
			    'UNSPECIFIC
			    (simplify-directory (except-last-pair directory))
			    name
			    type
			    'UNSPECIFIC))))))

;;;; Miscellaneous

(define (unix/pathname-wild? pathname)
  (or (eq? 'WILD (%pathname-name pathname))
      (eq? 'WILD (%pathname-type pathname))))

(define (unix/pathname->truename pathname)
  (if (eq? true (file-exists? pathname))
      pathname
      (unix/pathname->truename
       (error:file-operation pathname "find" "file" "file does not exist"
			     unix/pathname->truename (list pathname)))))

(define (unix/user-homedir-pathname host)
  (and (eq? host local-host)
       (pathname-as-directory (current-home-directory))))

(define (unix/init-file-pathname host)
  (let ((pathname
	 (merge-pathnames ".scheme.init" (unix/user-homedir-pathname host))))
    (and (file-exists? pathname)
	 pathname)))

(define (unix/pathname-simplify pathname)
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

(define (unix/end-of-line-string pathname)
  (or (os/file-end-of-line-translation pathname) "\n"))