;;; -*-Scheme-*-
;;;
;;;	$Id: wincom.scm,v 1.113 1992/11/13 22:59:28 cph Exp $
;;;
;;;	Copyright (c) 1987, 1989-92 Massachusetts Institute of Technology
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

;;;; Window Commands

(declare (usual-integrations))

(define-variable window-min-width
  "Delete any window less than this wide.
Do not set this variable below 2."
  2
  (lambda (object) (and (exact-integer? object) (>= object 2))))

(define-variable window-min-height
  "Delete any window less than this high.
The modeline is not included in this figure.
Do not set this variable below 1."
  1
  (lambda (object) (and (exact-integer? object) (>= object 1))))

(define-variable next-screen-context-lines
  "Number of lines of continuity when scrolling by screenfuls."
  2
  exact-nonnegative-integer?)

(define-variable use-multiple-screens
  "If true, commands try to use multiple screens rather than multiple windows.
Has no effect unless multiple-screen support is available."
  false
  boolean?)

(define-variable pop-up-windows
  "True enables the use of pop-up windows."
  true
  boolean?)

(define-variable preserve-window-arrangement
  "True means commands that normally change the window arrangement do not."
  false
  boolean?)

(define-variable split-height-threshold
  "Pop-up windows would prefer to split the largest window if this large.
If there is only one window, it is split regardless of this value."
  500
  exact-nonnegative-integer?)

(define-command redraw-display
  "Redraws the entire display from scratch."
  ()
  (lambda () (update-screens! true)))

(define-command recenter
  "Choose new window putting point at center, top or bottom.
With no argument, chooses a window to put point at the center
\(cursor-centering-point says where).
An argument gives the line to put point on;
negative args count from the bottom."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (if (not argument)
	  (begin
	    (window-scroll-y-absolute! window (window-y-center window))
	    (window-redraw! window)
	    (update-selected-screen! true))
	  (window-scroll-y-absolute!
	   window
	   (modulo (if (command-argument-multiplier-only? argument)
		       (window-y-center window)
		       (command-argument-value argument))
		   (window-y-size window)))))))

(define-command move-to-window-line
  "Position point relative to window.
With no argument, position at text at center of window.
An argument specifies screen line; zero means top of window,
negative means relative to bottom of window."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (let ((mark
	     (or (window-coordinates->mark
		  window 0
		  (if (not argument)
		      (window-y-center window)
		      (modulo (command-argument-value argument)
			      (window-y-size window))))
		 (window-coordinates->mark
		  window 0
		  (window-mark->y window
				  (buffer-end (window-buffer window)))))))
	(set-current-point! (if (group-start? mark)
				(group-start mark)
				mark))))))

(define-command home-cursor
  "Position point at upper-left corner of window."
  ()
  (lambda ()
    (let ((mark (window-coordinates->mark (current-window) 0 0)))
      (set-current-point! (if (group-start? mark)
			      (group-start mark)
			      mark)))))

(define-command scroll-up
  "Move down to display next screenful of text.
With argument, moves window down that many lines (negative moves up).
Just minus as an argument moves up a full screen."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (scroll-window window
		     (standard-scroll-window-argument window argument 1)))))

(define-command scroll-down
  "Move up to display previous screenful of text.
With argument, moves window up that many lines (negative moves down).
Just minus as an argument moves down a full screen."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (scroll-window window
		     (standard-scroll-window-argument window argument -1)))))

(define-command scroll-up-several-screens
  "Move down to display next screenful of text.
With argument, move window down that many screenfuls (negative moves up).
Just minus as an argument moves up a full screen."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (scroll-window window
		     (multi-scroll-window-argument window argument 1)))))

(define-command scroll-down-several-screens
  "Move up to display previous screenful of text.
With argument, move window down that many screenfuls (negative moves down).
Just minus as an argument moves down full screen."
  "P"
  (lambda (argument)
    (let ((window (current-window)))
      (scroll-window window
		     (multi-scroll-window-argument window argument -1)))))

(define-command scroll-other-window
  "Scroll text of next window up ARG lines, or near full screen if no arg."
  "P"
  (lambda (argument)
    (let ((window
	   (or (and (typein-window? (current-window))
		    (object-unhash *minibuffer-scroll-window*))
	       (other-window-interactive 1))))
      (scroll-window window
		     (standard-scroll-window-argument window argument 1)))))

(define-command scroll-other-window-down
  "Scroll text of next window down ARG lines, or near full screen if no arg."
  "P"
  (lambda (argument)
    (let ((window
	   (or (and (typein-window? (current-window))
		    (object-unhash *minibuffer-scroll-window*))
	       (other-window-interactive 1))))
      (scroll-window window
		     (standard-scroll-window-argument window argument -1)))))

(define-command scroll-other-window-several-screens
  "Scroll other window up several screenfuls.
Specify the number as a numeric argument, negative for down.
The default is one screenful up.  Just minus as an argument
means scroll one screenful down."
  "P"
  (lambda (argument)
    (let ((window
	   (or (and (typein-window? (current-window))
		    (object-unhash *minibuffer-scroll-window*))
	       (other-window-interactive 1))))
      (scroll-window window
		     (multi-scroll-window-argument window argument 1)))))

(define (scroll-window window n #!optional limit)
  (if (window-mark-visible?
       window
       ((if (negative? n) buffer-start buffer-end) (window-buffer window)))
      ((if (default-object? limit) editor-error limit))
      (window-scroll-y-relative! window n)))

(define (standard-scroll-window-argument window argument factor)
  (* factor
     (let ((quantum
	    (- (window-y-size window)
	       (ref-variable next-screen-context-lines))))
       (cond ((not argument) quantum)
	     ((command-argument-negative-only? argument) (- quantum))
	     (else (command-argument-value argument))))))

(define (multi-scroll-window-argument window argument factor)
  (* factor
     (let ((quantum
	    (- (window-y-size window)
	       (ref-variable next-screen-context-lines))))
       (cond ((not argument) quantum)
	     ((command-argument-negative-only? argument) (- quantum))
	     (else (* (command-argument-value argument) quantum))))))

(define-command what-cursor-position
  "Print info on cursor position (on screen and within buffer)."
  ()
  (lambda ()
    (let ((buffer (current-buffer))
	  (point (current-point)))
      (let ((position (mark-index point))
	    (total (group-length (buffer-group buffer))))
	(message (if (group-end? point)
		     ""
		     (let ((char (mark-right-char point)))
		       (let ((n (char->ascii char)))
			 (string-append "Char: " (key-name char)
					" ("
					(if (zero? n) "" "0")
					(number->string n 8)
					") "))))
		 "point=" (+ position 1)
		 " of " total
		 "("
		 (if (zero? total)
		     0
		     (integer-round (* 100 position) total))
		 "%) "
		 (let ((group (mark-group point)))
		   (let ((start (group-start-index group))
			 (end (group-end-index group)))
		     (if (and (zero? start) (= end total))
			 ""
			 (string-append "<" (number->string start)
					" - " (number->string end)
					"> "))))
		 "x=" (mark-column point))))))

;;;; Multiple Windows

(define-command split-window-vertically
  "Split current window into two windows, one above the other.
This window becomes the uppermost of the two, and gets
ARG lines.  No arg means split equally."
  "P"
  (lambda (argument)
    (disallow-typein)
    (window-split-vertically! (current-window)
			      (command-argument-value argument))))

(define-command split-window-horizontally
  "Split current window into two windows side by side.
This window becomes the leftmost of the two, and gets
ARG lines.  No arg means split equally."
  "P"
  (lambda (argument)
    (disallow-typein)
    (window-split-horizontally! (current-window)
				(command-argument-value argument))))

(define-command enlarge-window
  "Makes current window ARG lines bigger."
  "p"
  (lambda (argument)
    (disallow-typein)
    (window-grow-vertically! (current-window) argument)))

(define-command shrink-window
  "Makes current window ARG lines smaller."
  "p"
  (lambda (argument)
    (disallow-typein)
    (window-grow-vertically! (current-window) (- argument))))

(define-command enlarge-window-horizontally
  "Makes current window ARG columns wider."
  "p"
  (lambda (argument)
    (disallow-typein)
    (window-grow-horizontally! (current-window) argument)))

(define-command shrink-window-horizontally
  "Makes current window ARG columns narrower."
  "p"
  (lambda (argument)
    (disallow-typein)
    (window-grow-horizontally! (current-window) (- argument))))

(define-command delete-window
  "Delete the current window from the screen."
  ()
  (lambda ()
    (let ((window (current-window)))
      (if (and (window-has-no-neighbors? window)
	       (use-multiple-screens?)
	       (other-screen (selected-screen) false))
	  (delete-screen! (selected-screen))
	  (window-delete! window)))))

(define-command delete-other-windows
  "Make the current window fill the screen."
  ()
  (lambda ()
    (delete-other-windows (current-window))))

(define-command other-window
  "Select the ARG'th different window."
  "p"
  (lambda (argument)
    (select-window (other-window-interactive argument))))

(define (other-window-interactive n)
  (let ((window
	 (let ((window (other-window n)))
	   (if (current-window? window)
	       (let ((screen (other-screen (selected-screen) false)))
		 (and screen
		      (screen-selected-window screen)))
	       window))))
    (if (not window)
	(editor-error "No other window"))
    window))

(define (disallow-typein)
  (if (typein-window? (current-window))
      (editor-error "Not implemented for typein window")))

(define (use-multiple-screens?)
  (and (ref-variable use-multiple-screens)
       (multiple-screens?)))

(define (select-buffer-other-window buffer)
  (let ((window (current-window))
	(use-window
	 (lambda (window)
	   (select-buffer-in-window buffer window true)
	   (select-window window))))
    (let loop ((windows (buffer-windows buffer)))
      (cond ((null? windows)
	     (let ((window* (next-visible-window window false)))
	       (cond (window*
		      (use-window window*))
		     ((use-multiple-screens?)
		      (select-buffer-other-screen buffer))
		     (else
		      (use-window (window-split-vertically! window false))))))
	    ((and (not (eq? (car windows) window))
		  (window-visible? (car windows)))
	     (select-window (car windows)))
	    (else
	     (loop (cdr windows)))))))

(define (select-buffer-other-screen buffer)
  (if (multiple-screens?)
      (select-screen
       (let ((screen (other-screen (selected-screen) false)))
	 (if screen
	     (begin
	       (select-buffer-in-window buffer
					(screen-selected-window screen)
					true)
	       screen)
	     (make-screen buffer))))
      (editor-error "Display doesn't support multiple screens")))

;;;; Pop-up Buffers

(define-command kill-pop-up-buffer
  "Kills the most recently popped up buffer, if one exists.
Also kills any pop up window it may have created."
  ()
  (lambda ()
    (kill-pop-up-buffer true)))

(define (cleanup-pop-up-buffers thunk)
  (fluid-let ((*previous-popped-up-window* (object-hash false))
	      (*previous-popped-up-buffer* (object-hash false))
	      (*minibuffer-scroll-window* (object-hash false)))
    (unwind-protect false
		    thunk
		    (lambda () (kill-pop-up-buffer false)))))

(define (kill-pop-up-buffer error-if-none?)
  (let ((window (object-unhash *previous-popped-up-window*)))
    (if window
	(begin
	  (set! *previous-popped-up-window* (object-hash false))
	  (if (and (window-live? window)
		   (not (window-has-no-neighbors? window)))
	      (window-delete! window)))))
  (let ((buffer (object-unhash *previous-popped-up-buffer*)))
    (cond ((and buffer (buffer-alive? buffer))
	   (set! *previous-popped-up-buffer* (object-hash false))
	   (kill-buffer-interactive buffer))
	  (error-if-none?
	   (editor-error "No previous pop up buffer")))))

(define *previous-popped-up-buffer* (object-hash false))
(define *previous-popped-up-window* (object-hash false))
(define *minibuffer-scroll-window* (object-hash false))

(define (pop-up-buffer buffer #!optional select? not-current-window)
  ;; If some new window is created by this procedure, it is returned
  ;; as the value.  Otherwise the value is false.
  (let ((select? (and (not (default-object? select?)) select?))
	(current-window-ok?
	 (not (and (not (default-object? not-current-window?))
		   not-current-window?))))

    (define (pop-up-window window)
      (let ((window (window-split-vertically! window false)))
	(pop-into-window window)
	window))

    (define (pop-into-window window)
      (select-buffer-in-window buffer window true)
      (maybe-record-window window))

    (define (maybe-record-window window)
      (set! *minibuffer-scroll-window* (object-hash window))
      (if select? (select-window window))
      (and (eq? window (object-unhash *previous-popped-up-window*))
	   window))

    (define (find-visible-window buffer)
      (let loop ((windows (buffer-windows buffer)))
	(and (not (null? windows))
	     (let ((window (car windows)))
	       (if (and (window-visible? window)
			(or current-window-ok? (not (current-window? window))))
		   window
		   (loop (cdr windows)))))))

    (if (< (ref-variable window-min-height) 2)
	(set-variable! window-min-height 2))
    (let ((window
	   (let ((window (find-visible-window buffer)))
	     (if window
		 (begin
		   (set-window-point! window (buffer-point buffer))
		   (maybe-record-window window))
		 (let ((limit (* 2 (ref-variable window-min-height))))
		   (if (< (ref-variable split-height-threshold) limit)
		       (set-variable! split-height-threshold limit))
		   (cond ((and (use-multiple-screens?)
			       (other-screen (selected-screen) false))
			  =>
			  (lambda (screen)
			    (pop-into-window (screen-selected-window screen))))
			 ((ref-variable preserve-window-arrangement)
			  (pop-into-window (largest-window)))
			 ((not (ref-variable pop-up-windows))
			  (pop-into-window (lru-window)))
			 ((use-multiple-screens?)
			  (maybe-record-window
			   (screen-selected-window (make-screen buffer))))
			 (else
			  (let ((window (largest-window)))
			    (if (and (>= (window-y-size window)
					 (ref-variable split-height-threshold))
				     (not
				      (window-has-horizontal-neighbor?
				       window)))
				(pop-up-window window)
				(let ((window (lru-window))
				      (current (current-window)))
				  (if (and (or (eq? window current)
					       (and (typein-window? current)
						    (eq? window
							 (window1+ window))))
					   (>= (window-y-size window) limit))
				      (pop-up-window window)
				      (pop-into-window window))))))))))))
      (set! *previous-popped-up-window* (object-hash window))
      (set! *previous-popped-up-buffer* (object-hash buffer))
      window)))

(define (get-buffer-window buffer)
  (let loop ((windows (buffer-windows buffer)))
    (and (not (null? windows))
	 (if (window-visible? (car windows))
	     (car windows)
	     (loop (cdr windows))))))

(define (largest-window)
  (let ((start (window0)))
    (let loop
	((window (window1+ start))
	 (largest start)
	 (largest-area (* (window-x-size start) (window-y-size start))))
      (if (eq? window start)
	  largest
	  (let ((area (* (window-x-size window) (window-y-size window))))
	    (if (> area largest-area)
		(loop (window1+ window) window area)
		(loop (window1+ window) largest largest-area)))))))

(define (lru-window)
  (let ((start (window0)))
    (define (search-full-width window smallest smallest-time)
      (let ((next (window1+ window))
	    (time (window-select-time window)))
	(let ((consider-window?
	       (and (not (window-has-horizontal-neighbor? window))
		    (or (not smallest)
			(< time smallest-time)))))
	  (if (eq? window start)
	      (if consider-window?
		  window
		  (or smallest
		      (search-all next
				  start
				  (window-select-time start))))
	      (if consider-window?
		  (search-full-width next window time)
		  (search-full-width next smallest smallest-time))))))

    (define (search-all window smallest smallest-time)
      (if (eq? window start)
	  smallest
	  (let ((time (window-select-time window)))
	    (if (< time smallest-time)
		(search-all (window1+ window) window time)
		(search-all (window1+ window) smallest smallest-time)))))

    (search-full-width (window1+ start) false false)))

(define (delete-other-windows start)
  (let loop ((window (window1+ start)))
    (if (not (eq? window start))
	(begin
	  (window-delete! window)
	  (loop (window1+ window))))))

(define-command toggle-screen-width
  "Restrict the editor's width on the screen.
With no argument, restricts the width to 80 columns,
 unless it is already restricted, in which case it undoes the restriction.
With \\[universal-argument] only, undoes all restrictions.
Otherwise, the argument is the number of columns desired."
  "P"
  (lambda (argument)
    (let ((screen (selected-screen)))
      (let ((window (screen-root-window screen)))
	(send window ':set-size!
	      (let ((x-size (screen-x-size screen)))
		(cond ((command-argument-multiplier-only? argument)
		       x-size)
		      ((not argument)
		       (let ((x-size* (window-x-size window)))
			 (if (< x-size* x-size)
			     x-size
			     (min 80 x-size))))
		      (else
		       (let ((argument (command-argument-value argument)))
			 (if (< argument 10)
			     (editor-error "restriction too small: " argument))
			 (min x-size argument)))))
	      (screen-y-size screen)))
      (update-screen! screen true))))

(define-command compare-windows
  "Compare text in current window with text in next window.
Compares the text starting at point in each window,
moving over text in each one as far as they match."
  ()
  (lambda ()
    (let ((w1 (current-window))
	  (w2 (other-window-interactive 1)))
      (let ((p1 (window-point w1)))
	(let loop ((s1 p1) (s2 (window-point w2)) (length 1024))
	  (if (> length 0)
	      (let ((e1 (mark+ s1 length false))
		    (e2 (mark+ s2 length false)))
		(if (and e1
			 e2
			 (if (= length 1)
			     (char=? (extract-right-char s1)
				     (extract-right-char s2))
			     (string=? (extract-string s1 e1)
				       (extract-string s2 e2))))
		    (loop e1 e2 length)
		    (loop s1 s2 (quotient length 2))))
	      (begin
		(set-window-point! w1 s1)
		(set-window-point! w2 s2)
		(if (mark= s1 p1)
		    (editor-beep)))))))))