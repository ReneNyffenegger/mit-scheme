;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/motcom.scm,v 1.38 1989/04/15 00:51:47 cph Exp $
;;;
;;;	Copyright (c) 1985, 1989 Massachusetts Institute of Technology
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

;;;; Motion Commands

(declare (usual-integrations))

(define-command beginning-of-line
  "Move point to beginning of line."
  "p"
  (lambda (argument)
    (set-current-point! (line-start (current-point) (-1+ argument) 'LIMIT))))

(define-command backward-char
  "Move back one character.
With argument, move that many characters backward.
Negative arguments move forward."
  "p"
  (lambda (argument)
    (move-thing mark- argument)))

(define-command end-of-line
  "Move point to end of line."
  "p"
  (lambda (argument)
    (set-current-point! (line-end (current-point) (-1+ argument) 'LIMIT))))

(define-command forward-char
  "Move forward one character.
With argument, move that many characters forward.
Negative args move backward."
  "p"
  (lambda (argument)
    (move-thing mark+ argument)))

(define-command beginning-of-buffer
  "Go to beginning of buffer (leaving mark behind).
With arg from 0 to 10, goes that many tenths of the file
down from the beginning.  Just \\[universal-argument] as arg means go to end."
  "P"
  (lambda (argument)
    (push-current-mark! (current-point))
    (cond ((not argument)
	   (set-current-point! (buffer-start (current-buffer))))
	  ((command-argument-multiplier-only?)
	   (set-current-point! (buffer-end (current-buffer))))
	  ((<= 0 argument 10)
	   (set-current-point! (region-10ths (buffer-region (current-buffer))
					     argument))))))

(define-command end-of-buffer
  "Go to end of buffer (leaving mark behind).
With arg from 0 to 10, goes up that many tenths of the file from the end."
  "P"
  (lambda (argument)
    (push-current-mark! (current-point))
    (cond ((not argument)
	   (set-current-point! (buffer-end (current-buffer))))
	  ((<= 0 argument 10)
	   (set-current-point! (region-10ths (buffer-region (current-buffer))
					     (- 10 argument)))))))

(define (region-10ths region n)
  (mark+ (region-start region)
	 (quotient (* n (region-count-chars region)) 10)))

(define-command goto-char
  "Goto the Nth character from the start of the buffer."
  "p"
  (lambda (argument)
    (let ((mark (mark+ (buffer-start (current-buffer)) (-1+ argument))))
      (if mark
	  (set-current-point! mark)
	  (editor-error)))))

(define-command goto-line
  "Goto the Nth line from the start of the buffer."
  "p"
  (lambda (argument)
    (let ((mark (line-start (buffer-start (current-buffer)) (-1+ argument))))
      (if mark
	  (set-current-point! mark)
	  (editor-error)))))

(define-command goto-page
  "Goto the Nth page from the start of the buffer."
  "p"
  (lambda (argument)
    (let ((mark (forward-page (buffer-start (current-buffer)) (-1+ argument))))
      (if mark
	  (set-current-point! mark)
	  (editor-error)))))

(define-variable goal-column
  "Semipermanent goal column for vertical motion,
as set by \\[set-goal-column], or false, indicating no goal column."
  false)

(define temporary-goal-column-tag
  "Temporary Goal Column")

(define-command set-goal-column
  "Set (or flush) a permanent goal for vertical motion.
With no argument, makes the current column the goal for vertical
motion commands.  They will always try to go to that column.
With argument, clears out any previously set goal.
Only \\[previous-line] and \\[next-line] are affected."
  "P"
  (lambda (argument)
    (set-variable! goal-column (and (not argument) (current-column)))))

(define (current-goal-column)
  (or (ref-variable goal-column)
      (command-message-receive temporary-goal-column-tag
	identity-procedure
	current-column)))

(define-command next-line
  "Move down vertically to next real line.
Continuation lines are skipped.  If given after the
last newline in the buffer, makes a new one at the end."
  "P"
  (lambda (argument)
    (let ((column (current-goal-column)))
      (cond ((not argument)
	     (let ((mark (line-start (current-point) 1 false)))
	       (if mark
		   (set-current-point! (move-to-column mark column))
		   (begin (set-current-point! (group-end (current-point)))
			  (insert-newlines 1)))))
	    ((not (zero? argument))
	     (set-current-point!
	      (move-to-column (line-start (current-point) argument 'FAILURE)
			      column))))
      (set-command-message! temporary-goal-column-tag column))))

(define-command previous-line
  "Move up vertically to next real line.
Continuation lines are skipped."
  "p"
  (lambda (argument)
    (let ((column (current-goal-column)))
      (if (not (zero? argument))
	  (set-current-point!
	   (move-to-column (line-start (current-point) (- argument) 'FAILURE)
			   column)))
      (set-command-message! temporary-goal-column-tag column))))