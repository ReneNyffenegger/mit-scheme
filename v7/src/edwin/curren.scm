;;; -*-Scheme-*-
;;;
;;;	$Id: curren.scm,v 1.121 1996/04/24 01:49:03 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-96 Massachusetts Institute of Technology
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

;;;; Current State

(declare (usual-integrations))

;;;; Screens

(define (screen-list)
  (editor-screens current-editor))

(define (selected-screen)
  (editor-selected-screen current-editor))

(define (selected-screen? screen)
  (eq? screen (selected-screen)))

(define (multiple-screens?)
  (display-type/multiple-screens? (current-display-type)))

(define (make-screen buffer . make-screen-args)
  (let ((display-type (current-display-type)))
    (if (not (display-type/multiple-screens? display-type))
	(error "display doesn't support multiple screens" display-type))
    (without-interrupts
     (lambda ()
       (let ((screen (display-type/make-screen display-type make-screen-args)))
	 (initialize-screen-root-window! screen
					 (editor-bufferset current-editor)
					 buffer)
	 (set-editor-screens! current-editor
			      (append! (editor-screens current-editor)
				       (list screen)))
	 (event-distributor/invoke!
	  (variable-default-value (ref-variable-object frame-creation-hook))
	  screen)
	 (update-screen! screen false)
	 screen)))))

(define-variable frame-creation-hook
  "An event distributor that is invoked when a frame is created.
The new frame passed as its argument.
The frame is guaranteed to be deselected at that time."
  (make-event-distributor))
(define edwin-variable$screen-creation-hook edwin-variable$frame-creation-hook)

(define (delete-screen! screen #!optional allow-kill-scheme?)
  (without-interrupts
   (lambda ()
     (if (not (screen-deleted? screen))
	 (let ((other (other-screen screen 1 #t)))
	   (if other
	       (begin
		 (if (selected-screen? screen)
		     (select-screen (or (other-screen screen 1 #f) other)))
		 (screen-discard! screen)
		 (set-editor-screens! current-editor
				      (delq! screen
					     (editor-screens current-editor)))
		 #t)
	       (if (or (default-object? allow-kill-scheme?) allow-kill-scheme?)
		   ((ref-command save-buffers-kill-scheme) #t)
		   #f)))))))

(define (select-screen screen)
  (without-interrupts
   (lambda ()
     (if (not (screen-deleted? screen))
	 (let ((screen* (selected-screen)))
	   (if (not (eq? screen screen*))
	       (let ((message (current-message)))
		 (clear-current-message!)
		 (screen-exit! screen*)
		 (let ((window (screen-selected-window screen)))
		   (undo-leave-window! window)
		   (change-selected-buffer window (window-buffer window) true
		     (lambda ()
		       (set-editor-selected-screen! current-editor screen))))
		 (set-current-message! message)
		 (screen-enter! screen)
		 (update-screen! screen false))))))))

(define (update-screens! display-style)
  (let loop ((screens (screen-list)))
    (if (null? screens)
	(begin
	  ;; All the buffer changes have been successfully written to
	  ;; the screens, so erase the change records.
	  (do ((buffers (buffer-list) (cdr buffers)))
	      ((null? buffers))
	    (set-group-start-changes-index! (buffer-group (car buffers))
					    false))
	  true)
	(and (update-screen! (car screens) display-style)
	     (loop (cdr screens))))))

(define (update-selected-screen! display-style)
  (update-screen! (selected-screen) display-style))

(define (screen0)
  (car (screen-list)))

(define (screen1+ screen)
  (let ((screens (screen-list)))
    (let ((s (memq screen screens)))
      (if (not s)
	  (error "not a member of screen-list" screen))
      (if (null? (cdr s))
	  (car screens)
	  (cadr s)))))

(define (screen-1+ screen)
  (let ((screens (screen-list)))
    (if (eq? screen (car screens))
	(car (last-pair screens))
	(let loop ((previous screens) (screens (cdr screens)))
	  (if (null? screens)
	      (error "not a member of screen-list" screen))
	  (if (eq? screen (car screens))
	      (car previous)
	      (loop screens (cdr screens)))))))

(define (screen+ screen n)
  (cond ((positive? n)
	 (let loop ((n n) (screen screen))
	   (if (= n 1)
	       (screen1+ screen)
	       (loop (-1+ n) (screen1+ screen)))))
	((negative? n)
	 (let loop ((n n) (screen screen))
	   (if (= n -1)
	       (screen-1+ screen)
	       (loop (1+ n) (screen-1+ screen)))))
	(else
	 screen)))

(define (other-screen screen n invisible-ok?)
  (let ((next-screen (if (> n 0) screen1+ screen-1+)))
    (let loop ((screen* screen) (n (abs n)))
      (if (= n 0)
	  screen*
	  (let ((screen* (next-screen screen*)))
	    (and (not (eq? screen* screen))
		 (loop screen*
		       (if (or invisible-ok? (screen-visible? screen*))
			   (- n 1)
			   n))))))))

(define (other-screen? screen)
  (other-screen screen 1 #t))

;;;; Windows

(define (window-list)
  (append-map screen-window-list (screen-list)))

(define (selected-window)
  (screen-selected-window (selected-screen)))

(define (selected-window? window)
  (eq? window (selected-window)))

(define current-window selected-window)
(define current-window? selected-window?)

(define (window0)
  (screen-window0 (selected-screen)))

(define (select-window window)
  (without-interrupts
   (lambda ()
     (undo-leave-window! window)
     (let ((screen (window-screen window)))
       (if (selected-screen? screen)
	   (change-selected-buffer window (window-buffer window) true
	     (lambda ()
	       (screen-select-window! screen window)))
	   (begin
	     (screen-select-window! screen window)
	     (select-screen screen)))))))

(define (select-cursor window)
  (screen-select-cursor! (window-screen window) window))

(define (window-visible? window)
  (and (window-live? window)
       (screen-visible? (window-screen window))))

(define (window-live? window)
  (let ((screen (window-screen window)))
    (or (eq? window (screen-typein-window screen))
	(let ((window0 (screen-window0 screen)))
	  (let loop ((window* (window1+ window0)))
	    (or (eq? window window*)
		(and (not (eq? window* window0))
		     (loop (window1+ window*)))))))))

(define (global-window-modeline-event! #!optional predicate)
  (let ((predicate
	 (if (or (default-object? predicate) (not predicate))
	     (lambda (window) window 'GLOBAL-MODELINE)
	     predicate)))
    (for-each
     (lambda (screen)
       (let ((window0 (screen-window0 screen)))
	 (let loop ((window (window1+ window0)))
	   (let ((type (predicate window)))
	     (if type
		 (window-modeline-event! window type)))
	   (if (not (eq? window window0))
	       (loop (window1+ window))))))
     (screen-list))))

(define (other-window #!optional n other-screens?)
  (let ((n (if (or (default-object? n) (not n)) 1 n))
	(other-screens?
	 (if (default-object? other-screens?) #f other-screens?))
	(selected-window (selected-window))
	(typein-ok? (within-typein-edit?)))
    (cond ((positive? n)
	   (let loop ((n n) (window selected-window))
	     (if (zero? n)
		 window
		 (let ((window
			(next-visible-window window
					     typein-ok?
					     other-screens?)))
		   (if window
		       (loop (-1+ n) window)
		       selected-window)))))
	  ((negative? n)
	   (let loop ((n n) (window selected-window))
	     (if (zero? n)
		 window
		 (let ((window
			(previous-visible-window window
						 typein-ok?
						 other-screens?)))
		   (if window
		       (loop (1+ n) window)
		       selected-window)))))
	  (else
	   selected-window))))

(define (next-visible-window first-window typein-ok? #!optional other-screens?)
  (let ((other-screens?
	 (if (default-object? other-screens?) #f other-screens?))
	(first-screen (window-screen first-window)))
    (letrec
	((next-screen
	  (lambda (screen)
	    (let ((screen (if other-screens? (screen1+ screen) screen)))
	      (let ((window (screen-window0 screen)))
		(if (screen-visible? screen)
		    (and (not (and (eq? screen first-screen)
				   (eq? window first-window)))
			 window)
		    (and (not (eq? screen first-screen))
			 (next-screen screen))))))))
      (if (or (not (screen-visible? first-screen))
	      (eq? first-window (screen-typein-window first-screen)))
	  (next-screen first-screen)
	  (let ((window (window1+ first-window)))
	    (if (eq? window (screen-window0 first-screen))
		(or (and typein-ok? (screen-typein-window first-screen))
		    (next-screen first-screen))
		window))))))

(define (previous-visible-window first-window typein-ok?
				 #!optional other-screens?)
  (let ((other-screens?
	 (if (default-object? other-screens?) #f other-screens?))
	(first-screen (window-screen first-window)))
    (letrec
	((previous-screen
	  (lambda (screen)
	    (let ((screen (if other-screens? (screen-1+ screen) screen)))
	      (let ((window
		     (or (and typein-ok? (screen-typein-window screen))
			 (window-1+ (screen-window0 screen)))))
		(if (screen-visible? screen)
		    (and (not (and (eq? screen first-screen)
				   (eq? window first-window)))
			 window)
		    (and (not (eq? screen first-screen))
			 (previous-screen screen))))))))
      (if (or (not (screen-visible? first-screen))
	      (eq? first-window (screen-window0 first-screen)))
	  (previous-screen first-screen)
	  (window-1+ first-window)))))

(define (typein-window)
  (screen-typein-window (selected-screen)))

(define (typein-window? window)
  (eq? window (screen-typein-window (window-screen window))))

(define (current-message)
  (window-override-message (typein-window)))

(define (set-current-message! message)
  (let ((window (typein-window)))
    (if message
	(window-set-override-message! window message)
	(window-clear-override-message! window))
    (if (not *executing-keyboard-macro?*)
	(window-direct-update! window true))))

(define (clear-current-message!)
  (let ((window (typein-window)))
    (window-clear-override-message! window)
    (if (not *executing-keyboard-macro?*)
	(window-direct-update! window true))))

;;;; Buffers

(define (buffer-list)
  (bufferset-buffer-list (current-bufferset)))

(define (buffer-alive? buffer)
  (memq buffer (buffer-list)))

(define (buffer-names)
  (bufferset-names (current-bufferset)))

(define (selected-buffer)
  (window-buffer (selected-window)))

(define (selected-buffer? buffer)
  (eq? buffer (selected-buffer)))

(define current-buffer selected-buffer)
(define current-buffer? selected-buffer?)

(define (previous-buffer)
  (other-buffer (selected-buffer)))

(define (other-buffer buffer)
  (let loop ((less-preferred false) (buffers (buffer-list)))
    (cond ((null? buffers)
	   less-preferred)
	  ((or (eq? buffer (car buffers))
	       (minibuffer? (car buffers)))
	   (loop less-preferred (cdr buffers)))
	  ((buffer-visible? (car buffers))
	   (loop (or less-preferred (car buffers)) (cdr buffers)))
	  (else
	   (car buffers)))))

(define (bury-buffer buffer)
  (bufferset-bury-buffer! (current-bufferset) buffer))

(define (find-buffer name #!optional error?)
  (let ((buffer (bufferset-find-buffer (current-bufferset) name)))
    (if (and (not buffer)
	     (not (default-object? error?))
	     error?)
	(editor-error "No buffer named " name))
    buffer))

(define (create-buffer name)
  (bufferset-create-buffer (current-bufferset) name))

(define (find-or-create-buffer name)
  (bufferset-find-or-create-buffer (current-bufferset) name))

(define (rename-buffer buffer new-name)
  (without-interrupts
   (lambda ()
     (for-each (lambda (hook) (hook buffer new-name))
	       (get-buffer-hooks buffer 'RENAME-BUFFER-HOOKS))
     (bufferset-rename-buffer (current-bufferset) buffer new-name))))

(define-integrable (add-rename-buffer-hook buffer hook)
  (add-buffer-hook buffer 'RENAME-BUFFER-HOOKS hook))

(define-integrable (remove-rename-buffer-hook buffer hook)
  (remove-buffer-hook buffer 'RENAME-BUFFER-HOOKS hook))

(define (kill-buffer buffer)
  (without-interrupts
   (lambda ()
     (for-each (lambda (process)
		 (hangup-process process true)
		 (set-process-buffer! process false))
	       (buffer-processes buffer))
     (for-each (lambda (hook) (hook buffer))
	       (get-buffer-hooks buffer 'KILL-BUFFER-HOOKS))
     (let loop
	 ((windows (buffer-windows buffer))
	  (last-buffer false))
       (if (not (null? windows))
	   (let ((new-buffer
		  (or (other-buffer buffer)
		      last-buffer
		      (error "Buffer to be killed has no replacement"
			     buffer))))
	     (select-buffer-in-window new-buffer (car windows) false)
	     (loop (cdr windows) new-buffer))))
     (bufferset-kill-buffer! (current-bufferset) buffer))))

(define-integrable (add-kill-buffer-hook buffer hook)
  (add-buffer-hook buffer 'KILL-BUFFER-HOOKS hook))

(define-integrable (remove-kill-buffer-hook buffer hook)
  (remove-buffer-hook buffer 'KILL-BUFFER-HOOKS hook))

(define (add-buffer-hook buffer key hook)
  (let ((hooks (get-buffer-hooks buffer key)))
    (cond ((null? hooks)
	   (buffer-put! buffer key (list hook)))
	  ((not (memq hook hooks))
	   (set-cdr! (last-pair hooks) (list hook))))))

(define (remove-buffer-hook buffer key hook)
  (buffer-put! buffer key (delq! hook (get-buffer-hooks buffer key))))

(define-integrable (get-buffer-hooks buffer key)
  (or (buffer-get buffer key) '()))

(define (select-buffer buffer)
  (select-buffer-in-window buffer (selected-window) true))

(define (select-buffer-no-record buffer)
  (select-buffer-in-window buffer (selected-window) false))

(define (select-buffer-in-window buffer window record?)
  (without-interrupts
   (lambda ()
     (undo-leave-window! window)
     (if (selected-window? window)
	 (change-selected-buffer window buffer record?
	   (lambda ()
	     (set-window-buffer! window buffer)))
	 (set-window-buffer! window buffer)))))

(define (change-selected-buffer window buffer record? selection-thunk)
  (change-local-bindings! (selected-buffer) buffer selection-thunk)
  (set-buffer-point! buffer (window-point window))
  (if record?
      (bufferset-select-buffer! (current-bufferset) buffer))
  (for-each (lambda (hook) (hook buffer window))
	    (get-buffer-hooks buffer 'SELECT-BUFFER-HOOKS))
  (if (not (minibuffer? buffer))
      (event-distributor/invoke! (ref-variable select-buffer-hook #f)
				 buffer
				 window)))

(define-integrable (add-select-buffer-hook buffer hook)
  (add-buffer-hook buffer 'SELECT-BUFFER-HOOKS hook))

(define-integrable (remove-select-buffer-hook buffer hook)
  (remove-buffer-hook buffer 'SELECT-BUFFER-HOOKS hook))

(define-variable select-buffer-hook
  "An event distributor that is invoked when a buffer is selected.
The new buffer and the window in which it is selected are passed as arguments.
The buffer is guaranteed to be selected at that time."
  (make-event-distributor))

(define (with-selected-buffer buffer thunk)
  (let ((old-buffer))
    (dynamic-wind (lambda ()
		    (let ((window (selected-window)))
		      (set! old-buffer (window-buffer window))
		      (if (buffer-alive? buffer)
			  (select-buffer-in-window buffer window true)))
		    (set! buffer)
		    unspecific)
		  thunk
		  (lambda ()
		    (let ((window (selected-window)))
		      (set! buffer (window-buffer window))
		      (if (buffer-alive? old-buffer)
			  (select-buffer-in-window old-buffer window true)))
		    (set! old-buffer)
		    unspecific))))

(define (current-process)
  (let ((process (get-buffer-process (selected-buffer))))
    (if (not process)
	(editor-error "Selected buffer has no process"))
    process))

;;;; Point

(define (current-point)
  (window-point (selected-window)))

(define (set-current-point! mark)
  (set-window-point! (selected-window) mark))

(define (set-buffer-point! buffer mark)
  (let ((window (selected-window)))
    (if (eq? buffer (window-buffer window))
	(set-window-point! window mark)
	(%set-buffer-point! buffer mark))))

(define (with-current-point point thunk)
  (let ((old-point))
    (dynamic-wind (lambda ()
		    (let ((window (selected-window)))
		      (set! old-point (window-point window))
		      (set-window-point! window point))
		    (set! point)
		    unspecific)
		  thunk
		  (lambda ()
		    (let ((window (selected-window)))
		      (set! point (window-point window))
		      (set-window-point! window old-point))
		    (set! old-point)
		    unspecific))))

(define (current-column)
  (mark-column (current-point)))

(define (save-excursion thunk)
  (let ((point (mark-left-inserting-copy (current-point)))
	(mark (mark-right-inserting-copy (current-mark))))
    (thunk)
    (let ((buffer (mark-buffer point)))
      (if (buffer-alive? buffer)
	  (begin
	    (set-buffer-point! buffer point)
	    (set-buffer-mark! buffer mark))))))

;;;; Mark and Region

(define (current-mark)
  (buffer-mark (selected-buffer)))

(define (buffer-mark buffer)
  (let ((ring (buffer-mark-ring buffer)))
    (if (ring-empty? ring)
	(editor-error)
	(ring-ref ring 0))))

(define (set-current-mark! mark)
  (set-buffer-mark! (selected-buffer) (guarantee-mark mark)))

(define (set-buffer-mark! buffer mark)
  (ring-set! (buffer-mark-ring buffer) 0 (mark-right-inserting-copy mark)))

(define-variable auto-push-point-notification
  "Message to display when point is pushed on the mark ring.
If false, don't display any message."
  "Mark set"
  string-or-false?)

(define (push-current-mark! mark)
  (push-buffer-mark! (selected-buffer) (guarantee-mark mark))
  (let ((notification (ref-variable auto-push-point-notification)))
    (if (and notification
	     (not *executing-keyboard-macro?*)
	     (not (typein-window? (selected-window))))
	(temporary-message notification))))

(define (push-buffer-mark! buffer mark)
  (ring-push! (buffer-mark-ring buffer) (mark-right-inserting-copy mark)))

(define (pop-current-mark!)
  (pop-buffer-mark! (selected-buffer)))

(define (pop-buffer-mark! buffer)
  (ring-pop! (buffer-mark-ring buffer)))

(define (current-region)
  (make-region (current-point) (current-mark)))

(define (set-current-region! region)
  (set-current-point! (region-start region))
  (push-current-mark! (region-end region)))

(define (set-current-region-reversed! region)
  (push-current-mark! (region-start region))
  (set-current-point! (region-end region)))

;;;; Modes and Comtabs

(define (current-major-mode)
  (buffer-major-mode (selected-buffer)))

(define (current-minor-modes)
  (buffer-minor-modes (selected-buffer)))

(define (current-comtabs)
  (buffer-comtabs (selected-buffer)))

(define (set-current-major-mode! mode)
  (set-buffer-major-mode! (selected-buffer) mode))

(define (current-minor-mode? mode)
  (buffer-minor-mode? (selected-buffer) mode))

(define (enable-current-minor-mode! mode)
  (enable-buffer-minor-mode! (selected-buffer) mode))

(define (disable-current-minor-mode! mode)
  (disable-buffer-minor-mode! (selected-buffer) mode))