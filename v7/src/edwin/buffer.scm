;;; -*-Scheme-*-
;;;
;;;	$Id: buffer.scm,v 1.158 1992/11/16 22:40:50 cph Exp $
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

;;;; Buffer Abstraction

(declare (usual-integrations))

(define-named-structure "Buffer"
  name
  group
  mark-ring
  modes
  comtabs
  windows
  display-start
  default-directory
  pathname
  truename
  alist
  local-bindings
  local-bindings-installed?
  auto-save-pathname
  auto-saved?
  save-length
  backed-up?
  modification-time
  )

(unparser/set-tagged-vector-method!
 %buffer-tag
 (unparser/standard-method 'BUFFER
   (lambda (state buffer)
     (unparse-object state (buffer-name buffer)))))

(define-variable buffer-creation-hook
  "An event distributor that is invoked when a new buffer is created.
The new buffer is passed as its argument.
The buffer is guaranteed to be deselected at that time."
  (make-event-distributor))

(define (make-buffer name mode directory)
  (let ((buffer (%make-buffer)))
    (let ((group (make-group (string-copy "") buffer)))
      (vector-set! buffer buffer-index:name name)
      (vector-set! buffer buffer-index:group group)
      (add-group-clip-daemon! group (buffer-clip-daemon buffer))
      (if (not (minibuffer? buffer))
	  (enable-group-undo! group))
      (vector-set! buffer
		   buffer-index:mark-ring
		   (make-ring (ref-variable mark-ring-maximum)))
      (ring-push! (buffer-mark-ring buffer) (group-start-mark group))
      (vector-set! buffer buffer-index:modes (list mode))
      (vector-set! buffer buffer-index:comtabs (mode-comtabs mode))
      (vector-set! buffer buffer-index:windows '())
      (vector-set! buffer buffer-index:display-start false)
      (vector-set! buffer buffer-index:default-directory directory)
      (vector-set! buffer buffer-index:pathname false)
      (vector-set! buffer buffer-index:truename false)
      (vector-set! buffer buffer-index:alist '())
      (vector-set! buffer buffer-index:local-bindings '())
      (vector-set! buffer buffer-index:local-bindings-installed? false)
      (vector-set! buffer buffer-index:auto-save-pathname false)
      (vector-set! buffer buffer-index:auto-saved? false)
      (vector-set! buffer buffer-index:save-length 0)
      (vector-set! buffer buffer-index:backed-up? false)
      (vector-set! buffer buffer-index:modification-time false)
      (set-buffer-major-mode! buffer mode)
      (event-distributor/invoke! (ref-variable buffer-creation-hook) buffer)
      buffer)))

(define (buffer-modeline-event! buffer type)
  (let loop ((windows (buffer-windows buffer)))
    (if (not (null? windows))
	(begin
	  (window-modeline-event! (car windows) type)
	  (loop (cdr windows))))))

(define (buffer-reset! buffer)
  (set-buffer-writable! buffer)
  (region-delete! (buffer-region buffer))
  (buffer-not-modified! buffer)
  (let ((group (buffer-group buffer)))
    (if (group-undo-data group)
	(undo-done! (group-point group))))
  (buffer-widen! buffer)
  (set-buffer-major-mode! buffer (buffer-major-mode buffer))
  (without-interrupts
   (lambda ()
     (vector-set! buffer buffer-index:pathname false)
     (vector-set! buffer buffer-index:truename false)
     (buffer-modeline-event! buffer 'BUFFER-PATHNAME)
     (vector-set! buffer buffer-index:auto-save-pathname false)
     (vector-set! buffer buffer-index:auto-saved? false)
     (vector-set! buffer buffer-index:save-length 0))))

(define (set-buffer-name! buffer name)
  (vector-set! buffer buffer-index:name name)
  (buffer-modeline-event! buffer 'BUFFER-NAME))

(define (set-buffer-default-directory! buffer directory)
  (vector-set! buffer
	       buffer-index:default-directory
	       (pathname-simplify directory)))

(define (set-buffer-pathname! buffer pathname)
  (vector-set! buffer buffer-index:pathname pathname)
  (if pathname
      (set-buffer-default-directory! buffer (directory-pathname pathname)))
  (buffer-modeline-event! buffer 'BUFFER-PATHNAME))

(define (set-buffer-truename! buffer truename)
  (vector-set! buffer buffer-index:truename truename)
  (buffer-modeline-event! buffer 'BUFFER-TRUENAME))

(define-integrable (set-buffer-auto-save-pathname! buffer pathname)
  (vector-set! buffer buffer-index:auto-save-pathname pathname))

(define-integrable (set-buffer-save-length! buffer)
  (vector-set! buffer buffer-index:save-length (buffer-length buffer)))

(define-integrable (set-buffer-backed-up?! buffer flag)
  (vector-set! buffer buffer-index:backed-up? flag))

(define-integrable (set-buffer-modification-time! buffer time)
  (vector-set! buffer buffer-index:modification-time time))

(define-integrable (set-buffer-comtabs! buffer comtabs)
  (vector-set! buffer buffer-index:comtabs comtabs))

(define (buffer-point buffer)
  (if (current-buffer? buffer)
      (current-point)
      (group-point (buffer-group buffer))))

(define-integrable (%set-buffer-point! buffer mark)
  (set-group-point! (buffer-group buffer) mark))

(define-integrable (minibuffer? buffer)
  (char=? (string-ref (buffer-name buffer) 0) #\Space))

(define-integrable (buffer-region buffer)
  (group-region (buffer-group buffer)))

(define-integrable (buffer-string buffer)
  (region->string (buffer-region buffer)))

(define-integrable (buffer-unclipped-region buffer)
  (group-unclipped-region (buffer-group buffer)))

(define-integrable (buffer-widen! buffer)
  (group-widen! (buffer-group buffer)))

(define-integrable (buffer-length buffer)
  (group-length (buffer-group buffer)))

(define-integrable (buffer-start buffer)
  (group-start-mark (buffer-group buffer)))

(define-integrable (buffer-end buffer)
  (group-end-mark (buffer-group buffer)))

(define-integrable (buffer-absolute-start buffer)
  (group-absolute-start (buffer-group buffer)))

(define-integrable (buffer-absolute-end buffer)
  (group-absolute-end (buffer-group buffer)))

(define (add-buffer-window! buffer window)
  (vector-set! buffer
	       buffer-index:windows
	       (cons window (vector-ref buffer buffer-index:windows))))

(define (remove-buffer-window! buffer window)
  (vector-set! buffer
	       buffer-index:windows
	       (delq! window (vector-ref buffer buffer-index:windows))))

(define-integrable (set-buffer-display-start! buffer mark)
  (vector-set! buffer buffer-index:display-start mark))

(define (buffer-visible? buffer)
  (there-exists? (buffer-windows buffer) window-visible?))

(define (buffer-get buffer key)
  (let ((entry (assq key (vector-ref buffer buffer-index:alist))))
    (and entry
	 (cdr entry))))

(define (buffer-put! buffer key value)
  (let ((entry (assq key (vector-ref buffer buffer-index:alist))))
    (if entry
	(set-cdr! entry value)
	(vector-set! buffer buffer-index:alist
		     (cons (cons key value)
			   (vector-ref buffer buffer-index:alist))))))

(define (buffer-remove! buffer key)
  (vector-set! buffer
	       buffer-index:alist
	       (del-assq! key (vector-ref buffer buffer-index:alist))))

(define-integrable (reset-buffer-alist! buffer)
  (vector-set! buffer buffer-index:alist '()))

(define (->buffer object)
  (cond ((buffer? object) object)
	((and (mark? object) (mark-buffer object)))
	((and (group? object) (group-buffer object)))
	(else (error "can't coerce to buffer:" object))))

;;;; Modification Flags

(define-integrable (buffer-modified? buffer)
  (group-modified? (buffer-group buffer)))

(define (buffer-not-modified! buffer)
  (without-interrupts
   (lambda ()
     (let ((group (buffer-group buffer)))
       (if (group-modified? group)
	   (begin
	     (set-group-modified! group false)
	     (buffer-modeline-event! buffer 'BUFFER-MODIFIED)
	     (vector-set! buffer buffer-index:auto-saved? false)))))))

(define (buffer-modified! buffer)
  (without-interrupts
   (lambda ()
     (let ((group (buffer-group buffer)))
       (if (not (group-modified? group))
	   (begin
	     (set-group-modified! group true)
	     (buffer-modeline-event! buffer 'BUFFER-MODIFIED)))))))

(define (set-buffer-auto-saved! buffer)
  (vector-set! buffer buffer-index:auto-saved? true)
  (set-group-modified! (buffer-group buffer) 'AUTO-SAVED))

(define-integrable (buffer-auto-save-modified? buffer)
  (eq? true (group-modified? (buffer-group buffer))))

(define (buffer-clip-daemon buffer)
  (lambda (group start end)
    group start end			;ignore
    (buffer-modeline-event! buffer 'CLIPPING-CHANGED)))

(define-integrable (buffer-read-only? buffer)
  (group-read-only? (buffer-group buffer)))

(define-integrable (buffer-writable? buffer)
  (not (buffer-read-only? buffer)))

(define (set-buffer-writable! buffer)
  (set-group-writable! (buffer-group buffer))
  (buffer-modeline-event! buffer 'BUFFER-MODIFIABLE))

(define (set-buffer-read-only! buffer)
  (set-group-read-only! (buffer-group buffer))
  (buffer-modeline-event! buffer 'BUFFER-MODIFIABLE))

(define (with-read-only-defeated mark thunk)
  (let ((group (mark-group mark))
	(outside)
	(inside false))
    (dynamic-wind (lambda ()
		    (set! outside (group-read-only? group))
		    (if inside
			(set-group-read-only! group)
			(set-group-writable! group)))
		  thunk
		  (lambda ()
		    (set! inside (group-read-only? group))
		    (if outside
			(set-group-read-only! group)
			(set-group-writable! group))))))

;;;; Local Bindings

(define (define-variable-local-value! buffer variable value)
  (check-variable-value-validity! variable value)
  (without-interrupts
   (lambda ()
     (let ((binding (search-local-bindings buffer variable)))
       (if binding
	   (set-cdr! binding value)
	   (vector-set! buffer
			buffer-index:local-bindings
			(cons (cons variable value)
			      (buffer-local-bindings buffer)))))
     (if (buffer-local-bindings-installed? buffer)
	 (vector-set! variable variable-index:value value))
     (invoke-variable-assignment-daemons! buffer variable))))

(define (undefine-variable-local-value! buffer variable)
  (without-interrupts
   (lambda ()
     (let ((binding (search-local-bindings buffer variable)))
       (if binding
	   (begin
	     (vector-set! buffer
			  buffer-index:local-bindings
			  (delq! binding (buffer-local-bindings buffer)))
	     (if (buffer-local-bindings-installed? buffer)
		 (vector-set! variable
			      variable-index:value
			      (variable-default-value variable)))
	     (invoke-variable-assignment-daemons! buffer variable)))))))

(define (variable-local-value buffer variable)
  (let ((binding (search-local-bindings (->buffer buffer) variable)))
    (if binding
	(cdr binding)
	(variable-default-value variable))))

(define (set-variable-local-value! buffer variable value)
  (cond ((variable-buffer-local? variable)
	 (define-variable-local-value! buffer variable value))
	((search-local-bindings buffer variable)
	 =>
	 (lambda (binding)
	   (check-variable-value-validity! variable value)
	   (without-interrupts
	    (lambda ()
	      (set-cdr! binding value)
	      (if (buffer-local-bindings-installed? buffer)
		  (vector-set! variable variable-index:value value))
	      (invoke-variable-assignment-daemons! buffer variable)))))
	(else
	 (set-variable-default-value! variable value))))

(define (set-variable-default-value! variable value)
  (check-variable-value-validity! variable value)
  (without-interrupts
   (lambda ()
     (vector-set! variable variable-index:default-value value)
     (if (not (search-local-bindings (current-buffer) variable))
	 (vector-set! variable variable-index:value value))
     (invoke-variable-assignment-daemons! false variable))))

(define-integrable (search-local-bindings buffer variable)
  (let loop ((bindings (buffer-local-bindings buffer)))
    (and (not (null? bindings))
	 (if (eq? (caar bindings) variable)
	     (car bindings)
	     (loop (cdr bindings))))))

(define (undo-local-bindings!)
  ;; Caller guarantees that interrupts are disabled.
  (let ((buffer (current-buffer)))
    (let ((bindings (buffer-local-bindings buffer)))
      (do ((bindings bindings (cdr bindings)))
	  ((null? bindings))
	(vector-set! (caar bindings)
		     variable-index:value
		     (variable-default-value (caar bindings))))
      (vector-set! buffer buffer-index:local-bindings '())
      (do ((bindings bindings (cdr bindings)))
	  ((null? bindings))
	(invoke-variable-assignment-daemons! buffer (caar bindings))))))

(define (with-current-local-bindings! thunk)
  (dynamic-wind (lambda ()
		  (install-buffer-local-bindings! (current-buffer)))
		thunk
		(lambda ()
		  (uninstall-buffer-local-bindings! (current-buffer)))))

(define (change-local-bindings! old-buffer new-buffer select-buffer!)
  ;; Assumes that interrupts are disabled and that OLD-BUFFER is selected.
  (uninstall-buffer-local-bindings! old-buffer)
  (select-buffer!)
  (install-buffer-local-bindings! new-buffer))

(define (install-buffer-local-bindings! buffer)
  (do ((bindings (buffer-local-bindings buffer) (cdr bindings)))
      ((null? bindings))
    (vector-set! (caar bindings) variable-index:value (cdar bindings)))
  (vector-set! buffer buffer-index:local-bindings-installed? true))

(define (uninstall-buffer-local-bindings! buffer)
  (do ((bindings (buffer-local-bindings buffer) (cdr bindings)))
      ((null? bindings))
    (vector-set! (caar bindings)
		 variable-index:value
		 (variable-default-value (caar bindings))))
  (vector-set! buffer buffer-index:local-bindings-installed? false))

(define (set-variable-value! variable value)
  (if within-editor?
      (set-variable-local-value! (current-buffer) variable value)
      (begin
	(check-variable-value-validity! variable value)
	(without-interrupts
	 (lambda ()
	   (vector-set! variable variable-index:default-value value)
	   (vector-set! variable variable-index:value value)
	   (invoke-variable-assignment-daemons! false variable))))))

(define (with-variable-value! variable new-value thunk)
  (let ((old-value))
    (dynamic-wind (lambda ()
		    (set! old-value (variable-value variable))
		    (set-variable-value! variable new-value)
		    (set! new-value)
		    unspecific)
		  thunk
		  (lambda ()
		    (set! new-value (variable-value variable))
		    (set-variable-value! variable old-value)
		    (set! old-value)
		    unspecific))))

;;;; Modes

(define-integrable (buffer-major-mode buffer)
  (car (buffer-modes buffer)))

(define (set-buffer-major-mode! buffer mode)
  (if (not (and (mode? mode) (mode-major? mode)))
      (error:wrong-type-argument mode "major mode" 'SET-BUFFER-MAJOR-MODE!))
  (if (buffer-get buffer 'MAJOR-MODE-LOCKED)
      (editor-error "The major mode of this buffer is locked: " buffer))
  (without-interrupts
   (lambda ()
     (let ((modes (buffer-modes buffer)))
       (set-car! modes mode)
       (set-cdr! modes '()))
     (set-buffer-comtabs! buffer (mode-comtabs mode))
     (vector-set! buffer buffer-index:alist '())
     (undo-local-bindings!)
     ((mode-initialization mode) buffer)
     (buffer-modeline-event! buffer 'BUFFER-MODES))))

(define-integrable (buffer-minor-modes buffer)
  (cdr (buffer-modes buffer)))

(define (buffer-minor-mode? buffer mode)
  (if (not (and (mode? mode) (not (mode-major? mode))))
      (error:wrong-type-argument mode "minor mode" 'BUFFER-MINOR-MODE?))
  (memq mode (buffer-minor-modes buffer)))

(define (enable-buffer-minor-mode! buffer mode)
  (if (not (minor-mode? mode))
      (error:wrong-type-argument mode "minor mode" 'ENABLE-BUFFER-MINOR-MODE!))
  (without-interrupts
   (lambda ()
     (let ((modes (buffer-modes buffer)))
       (if (not (memq mode (cdr modes)))
	   (begin
	     (set-cdr! modes (append! (cdr modes) (list mode)))
	     (set-buffer-comtabs! buffer
				  (cons (minor-mode-comtab mode)
					(buffer-comtabs buffer)))
	     ((mode-initialization mode) buffer)
	     (buffer-modeline-event! buffer 'BUFFER-MODES)))))))

(define (disable-buffer-minor-mode! buffer mode)
  (if (not (minor-mode? mode))
      (error:wrong-type-argument mode "minor mode"
				 'DISABLE-BUFFER-MINOR-MODE!))
  (without-interrupts
   (lambda ()
     (let ((modes (buffer-modes buffer)))
       (if (memq mode (cdr modes))
	   (begin
	     (set-cdr! modes (delq! mode (cdr modes)))
	     (set-buffer-comtabs! buffer
				  (delq! (minor-mode-comtab mode)
					 (buffer-comtabs buffer)))
	     (buffer-modeline-event! buffer 'BUFFER-MODES)))))))