#| -*-Scheme-*-

$Id: make.scm,v 3.82 1993/11/18 01:20:59 cph Exp $

Copyright (c) 1989-93 Massachusetts Institute of Technology

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

;;;; Edwin: System Construction

(declare (usual-integrations))

((access with-directory-rewriting-rule
	 (->environment '(RUNTIME COMPILER-INFO)))
 (working-directory-pathname)
 (pathname-as-directory "edwin")
 (lambda ()
   (declare-shared-library "edwin" (lambda () true))
   (package/system-loader
    "edwin"
    `((os-type . ,(intern (microcode-identification-item 'OS-NAME-STRING))))
    'QUERY)))
(add-system! (make-system "Edwin" 3 82 '()))