#| -*-Scheme-*-

$Id: wrkdir.scm,v 14.7 1993/07/31 03:11:56 cph Exp $

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

;;;; Working Directory
;;; package: (runtime working-directory)

(declare (usual-integrations))

(define (initialize-package!)
  (reset!)
  (add-event-receiver! event:after-restore reset!))

(define (reset!)
  (let ((pathname
	 (pathname-simplify
	  (pathname-as-directory
	   ((ucode-primitive working-directory-pathname))))))
    (set! *working-directory-pathname* pathname)
    (set! *default-pathname-defaults* pathname))
  unspecific)

(define *working-directory-pathname*)

(define (working-directory-pathname)
  *working-directory-pathname*)

(define (set-working-directory-pathname! name)
  (let ((pathname
	 (pathname-as-directory
	  (merge-pathnames name *working-directory-pathname*))))
    (if (not (file-directory? pathname))
	(error "Not a valid directory:" pathname))
    (let ((pathname (pathname-simplify pathname)))
      (set! *working-directory-pathname* pathname)
      (set! *default-pathname-defaults*
	    (merge-pathnames pathname *default-pathname-defaults*))
      (cmdl/set-default-directory (nearest-cmdl) pathname)
      pathname)))

(define (with-working-directory-pathname name thunk)
  (let ((pathname
	 (pathname-as-directory
	  (merge-pathnames name *working-directory-pathname*))))
    (if (not (file-directory? pathname))
	(error "Not a valid directory:" pathname))
    (let ((pathname (pathname-simplify pathname)))
      (fluid-let ((*working-directory-pathname* pathname)
		  (*default-pathname-defaults*
		   (merge-pathnames pathname *default-pathname-defaults*)))
	(thunk)))))