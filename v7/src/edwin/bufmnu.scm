;;; -*-Scheme-*-
;;;
;;;	$Id: bufmnu.scm,v 1.121 1992/11/12 18:00:15 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-92 Massachusetts Institute of Technology
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

;;;; Buffer Menu

(declare (usual-integrations))

(define-variable buffer-menu-kill-on-quit
  "If not false, kill the *Buffer-List* buffer when leaving it."
  false)

(define-command list-buffers
  "Display a list of names of existing buffers.
Inserts it in buffer *Buffer-List* and displays that.
Note that buffers with names starting with spaces are omitted.
Non-null optional arg FILES-ONLY? means mention only file buffers.

The M column contains a * for buffers that are modified.
The R column contains a % for buffers that are read-only."
  "P"
  (lambda (files-only?)
    (pop-up-buffer (update-buffer-list files-only?) false)))

(define-command buffer-menu
  "Make a menu of buffers so you can save, delete or select them.
With argument, show only buffers that are visiting files.
Type ? after invocation to get help on commands available.
Type q immediately to make the buffer menu go away."
  "P"
  (lambda (files-only?)
    (pop-up-buffer (update-buffer-list files-only?) true)
    (message "Commands: d, s, x; 1, 2, m, u, q; rubout; ? for help.")))

(define (update-buffer-list files-only?)
  (let ((buffer (temporary-buffer "*Buffer-List*")))
    (set-buffer-major-mode! buffer (ref-mode-object buffer-menu))
    (buffer-put! buffer 'REVERT-BUFFER-FILES-ONLY? files-only?)
    (buffer-put! buffer 'REVERT-BUFFER-METHOD revert-buffer-menu)
    (fill-buffer-menu! buffer files-only?)
    buffer))

(define (revert-buffer-menu buffer dont-use-auto-save? dont-confirm?)
  dont-use-auto-save? dont-confirm?	;ignore
  (set-buffer-writable! buffer)
  (region-delete! (buffer-region buffer))
  (fill-buffer-menu! buffer (buffer-get buffer 'REVERT-BUFFER-FILES-ONLY?)))

(define (fill-buffer-menu! buffer files-only?)
  (call-with-output-mark (buffer-point buffer)
    (lambda (port)
      (write-string list-buffers-header port)
      (let ((current (current-buffer)))
	(for-each (lambda (buffer)
		    (if (not (or (minibuffer? buffer)
				 (and files-only?
				      (not (buffer-pathname buffer)))))
			(begin
			 (write-string
			  (list-buffers-format
			   (if (eq? buffer current) "." " ")
			   (if (buffer-modified? buffer) "*" " ")
			   (if (buffer-writable? buffer) " " "%")
			   (buffer-name buffer)
			   (write-to-string
			    (group-length (buffer-group buffer)))
			   (mode-display-name (buffer-major-mode buffer))
			   (let ((truename (buffer-truename buffer)))
			     (if truename (->namestring truename) "")))
			  port)
			 (newline port))))
		  (buffer-list)))))
  (set-buffer-point! buffer (line-start (buffer-start buffer) 2))
  (set-buffer-read-only! buffer))

(define-major-mode buffer-menu read-only-noarg "Buffer Menu"
  "Major mode for editing a list of buffers.
Each line describes one of the buffers in Emacs.
Letters do not insert themselves; instead, they are commands.
m -- mark buffer to be displayed.
q -- select buffer of line point is on.
  Also show buffers marked with m in other windows.
1 -- select that buffer in full-screen window.
2 -- select that buffer in one window,
  together with buffer selected before this one in another window.
f -- select that buffer in place of the buffer menu buffer.
o -- select that buffer in another window,
  so the buffer menu buffer remains visible in its window.
~ -- clear modified-flag on that buffer.
s -- mark that buffer to be saved, and move down.
d or k -- mark that buffer to be deleted, and move down.
C-d -- mark that buffer to be deleted, and move up.
x -- delete or save marked buffers.
u -- remove all kinds of marks from current line.
Delete -- back up a line and remove marks.")

(define-key 'buffer-menu #\m 'buffer-menu-mark)
(define-key 'buffer-menu #\q 'buffer-menu-quit)
(define-key 'buffer-menu #\1 'buffer-menu-1-window)
(define-key 'buffer-menu #\2 'buffer-menu-2-window)
(define-key 'buffer-menu #\f 'buffer-menu-this-window)
(define-key 'buffer-menu #\o 'buffer-menu-other-window)
(define-key 'buffer-menu #\~ 'buffer-menu-not-modified)
(define-key 'buffer-menu #\s 'buffer-menu-save)
(define-key 'buffer-menu #\d 'buffer-menu-delete)
(define-key 'buffer-menu #\k 'buffer-menu-delete)
(define-key 'buffer-menu #\c-d 'buffer-menu-delete-backwards)
(define-key 'buffer-menu #\c-k 'buffer-menu-delete)
(define-key 'buffer-menu #\x 'buffer-menu-execute)
(define-key 'buffer-menu #\u 'buffer-menu-unmark)
(define-key 'buffer-menu #\rubout 'buffer-menu-backup-unmark)
(define-key 'buffer-menu #\space 'buffer-menu-next-line)
(define-key 'buffer-menu #\c-\] 'buffer-menu-abort)
(define-key 'buffer-menu #\? 'describe-mode)

(define-command buffer-menu-mark
  "Mark buffer on this line for being displayed by \\[buffer-menu-quit] command."
  "p"
  (lambda (argument)
    (set-multiple-marks! 0 #\> argument)))

(define-command buffer-menu-quit
  "Select this line's buffer; also display buffers marked with >.
You can mark buffers with the \\[buffer-menu-mark] command."
  ()
  (lambda ()
    (let ((lstart (current-lstart))
	  (window (current-window)))
      (let ((menu (window-buffer window))
	    (buffer (buffer-menu-buffer lstart))
	    (others (map buffer-menu-buffer (find-buffers-marked 0 #\>))))
	(if (and (ref-variable preserve-window-arrangement)
		 (null? others))
	    (buffer-menu-select menu buffer false)
	    (begin
	      (delete-other-windows window)
	      (buffer-menu-select menu buffer (memq menu others))
	      (let ((height (max (quotient (1+ (window-y-size window))
					   (1+ (length others)))
				 (1+ (ref-variable window-min-height)))))
		(define (loop window buffers)
		  (let ((new (window-split-vertically! window height)))
		    (if new
			(begin
			  (select-buffer-in-window (car buffers) new true)
			  (loop new (cdr buffers))))))
		(loop window others))))))
    (clear-message)))

(define-command buffer-menu-1-window
  "Select this line's buffer, alone, in full screen."
  ()
  (lambda ()
    (let ((window (current-window)))
      (delete-other-windows window)
      (buffer-menu-select (window-buffer window)
			  (buffer-menu-buffer (current-lstart))
			  false))
    (clear-message)))

(define-command buffer-menu-2-window
  "Select this line's buffer, with previous buffer in second window."
  ()
  (lambda ()
    (buffer-menu-select (window-buffer (current-window))
			(buffer-menu-buffer (current-lstart))
			false)
    (with-variable-value! (ref-variable-object pop-up-windows) true
      (lambda ()
	(pop-up-buffer (previous-buffer))))
    (clear-message)))

(define-command buffer-menu-this-window
  "Select this line's buffer."
  ()
  (lambda ()
    (buffer-menu-find select-buffer)))

(define-command buffer-menu-other-window
  "Select this line's buffer in another window."
  ()
  (lambda ()
    (buffer-menu-find select-buffer-other-window)))

(define (buffer-menu-find select-buffer)
  (let ((buffer (buffer-menu-buffer (current-lstart))))
    (if (not (eq? (current-buffer) buffer))
	(select-buffer buffer)))
  (clear-message))

(define-command buffer-menu-not-modified
  "Mark buffer on this line as unmodified (no changes to save)."
  ()
  (lambda ()
    (buffer-not-modified! (buffer-menu-buffer (current-lstart)))
    (let ((lstart (current-lstart)))
      (if (char=? #\* (buffer-menu-mark lstart 1))
	  (set-buffer-menu-mark! lstart 1 #\Space)))))

(define-command buffer-menu-save
  "Mark buffer on this line to be saved by \\[buffer-menu-execute] command."
  "p"
  (lambda (argument)
    (set-multiple-marks! 1 #\S argument)))

(define-command buffer-menu-delete
  "Mark buffer on this line to be killed by \\[buffer-menu-execute] command."
  "p"
  (lambda (argument)
    (set-multiple-marks! 0 #\D argument)))

(define-command buffer-menu-delete-backwards
  "Mark buffer on this line to be killed by \\[buffer-menu-execute] command
and then move up one line."
  "p"
  (lambda (argument)
    (do ((i 0 (+ i 1)))
	((>= i argument))
      (set-buffer-menu-mark! (current-lstart) 0 #\D)
      (set-current-point! (previous-lstart)))))

(define-command buffer-menu-execute
  "Save and/or Kill buffers marked with \\[buffer-menu-save] or \\[buffer-menu-delete]."
  ()
  (lambda ()
    (buffer-menu-save-and-kill!)))

(define-command buffer-menu-unmark
  "Remove all marks from this line."
  ()
  (lambda ()
    (let ((lstart (mark-right-inserting (current-lstart))))
      (let ((buffer (buffer-menu-buffer lstart)))
	(set-buffer-menu-mark! lstart 0 #\Space)
	(set-buffer-menu-mark! lstart 1
			       (if (buffer-modified? buffer) #\* #\Space))))
    (set-current-point! (next-lstart))))

(define-command buffer-menu-backup-unmark
  "Remove all marks from the previous line."
  ()
  (lambda ()
    (set-current-point! (previous-lstart))
    ((ref-command buffer-menu-unmark))
    (set-current-point! (previous-lstart))))

(define-command buffer-menu-next-line
  "Move down to the next line."
  "p"
  (lambda (argument)
    (set-current-point! (line-start (current-point) argument 'BEEP))))

(define-command buffer-menu-abort
  "Abort buffer menu edit."
  ()
  (lambda ()
    (kill-buffer-interactive (current-buffer))
    (clear-message)))

(define (buffer-menu-select menu buffer needed?)
  (select-buffer buffer)
  (if (not (or (eq? menu buffer) needed?))
      (if (ref-variable buffer-menu-kill-on-quit)
	  (kill-buffer-interactive menu)
	  (bury-buffer menu))))

(define (buffer-menu-save-and-kill!)
  (for-each buffer-menu-save! (find-buffers-marked 1 #\S))
  (for-each buffer-menu-kill! (find-buffers-marked 0 #\D)))

(define (buffer-menu-save! lstart)
  (save-buffer (buffer-menu-buffer lstart) false)
  (set-buffer-menu-mark! lstart 1 #\space))

(define (buffer-menu-kill! lstart)
  (define (erase-line)
    (with-read-only-defeated lstart
      (lambda ()
	(delete-string lstart (line-start lstart 1)))))
  (let ((buffer (find-buffer (buffer-menu-buffer-name lstart))))
    (cond ((not buffer) (erase-line))
	  ((not (eq? buffer (current-buffer)))
	   (kill-buffer-interactive buffer)
	   (erase-line)))))

(define (buffer-menu-buffer lstart)
  (let ((name (buffer-menu-buffer-name lstart)))
    (or (find-buffer name)
	(editor-error "No buffer named '" name "'"))))

(define (buffer-menu-buffer-name lstart)
  (guarantee-buffer-line lstart)
  (buffer-line-name lstart))

(define (current-lstart)
  (line-start (current-point) 0))

(define (next-lstart)
  (line-start (current-point) 1 'ERROR))

(define (previous-lstart)
  (line-start (current-point) -1 'ERROR))

(define (set-multiple-marks! column char n)
  (dotimes n
    (lambda (i)
      i					;ignore
      (set-buffer-menu-mark! (current-lstart) column char)
      (set-current-point! (next-lstart)))))

(define (guarantee-buffer-line lstart)
  (if (not (buffer-line? lstart))
      (editor-error "No buffer on this line")))

(define (buffer-line? lstart)
  (and (mark>= lstart (line-start (group-start lstart) 2))
       (not (mark= lstart (line-end lstart 0)))))

(define (buffer-line-name lstart)
  (let ((start (mark+ lstart 4)))
    (extract-string
     start
     (skip-chars-backward
      " \t"
      (let ((end (line-end start 0)))
	(or (re-search-forward "\t\\|  " start end)
	    end))))))

(define (buffer-menu-mark lstart column)
  (guarantee-buffer-line lstart)
  (mark-right-char (mark+ lstart column)))

(define (set-buffer-menu-mark! lstart column char)
  (guarantee-buffer-line lstart)
  (let ((m (mark+ lstart column)))
    (with-read-only-defeated m
      (lambda ()
	(delete-right-char m)
	(region-insert-char! m char)))))

(define (list-buffers-format k m r buffer size mode file)
  (let* ((result
	  (string-append k m r " " (pad-on-right-to buffer 13) "  " size))
	 (result (string-append (pad-on-right-to result 24) " " mode)))
    (string-append (pad-on-right-to result 39) " " file)))

(define list-buffers-header
  (string-append
   (list-buffers-format " " "M" "R" "Buffer" "Size" "Mode" "File")
   "\n"
   (list-buffers-format " " "-" "-" "------" "----" "----" "----")
   "\n"))

(define (find-buffers-marked column char)
  (define (loop lstart)
    (let ((next (line-start lstart 1)))
      (cond ((not next) '())
	    ((char=? (mark-right-char (mark+ lstart column)) char)
	     (cons (mark-permanent! lstart) (loop next)))
	    (else (loop next)))))
  (loop (line-start (buffer-start (current-buffer)) 2)))