;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/tximod.scm,v 1.10 1989/03/14 08:03:31 cph Exp $
;;;
;;;	Copyright (c) 1987, 1989 Massachusetts Institute of Technology
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

;;;; Texinfo Mode

(declare (usual-integrations))

(define-command ("Texinfo Mode")
  "Make the current mode be Texinfo mode."
  (set-current-major-mode! texinfo-mode))

(define-major-mode "Texinfo" "Text"
  "Major mode for editing texinfo files.
These are files that are input for TeX and also to be turned
into Info files by \\[Texinfo Format Buffer].
These files must be written in a very restricted and
modified version of TeX input format."
  (local-set-variable! "Syntax Table" texinfo-mode:syntax-table)
  (local-set-variable! "Fill Column" 75)
  (local-set-variable! "Require Final Newline" true)
  (local-set-variable! "Page Delimiter"
		       (string-append "^@node\\|"
				      (ref-variable "Page Delimiter")))
  (local-set-variable! "Paragraph Start"
		       (string-append "^\\|^@[a-z]*[ \n]\\|"
				      (ref-variable "Paragraph Start")))
  (local-set-variable! "Paragraph Separate"
		       (string-append "^\\|^@[a-z]*[ \n]\\|"
				      (ref-variable "Paragraph Separate")))
  (if (ref-variable "Texinfo Mode Hook") ((ref-variable "Texinfo Mode Hook"))))

(define texinfo-mode:syntax-table
  (make-syntax-table))

(modify-syntax-entry! texinfo-mode:syntax-table #\" " ")
(modify-syntax-entry! texinfo-mode:syntax-table #\\ " ")
(modify-syntax-entry! texinfo-mode:syntax-table #\@ "\\")
(modify-syntax-entry! texinfo-mode:syntax-table #\C-Q "\\")
(modify-syntax-entry! texinfo-mode:syntax-table #\' "w")