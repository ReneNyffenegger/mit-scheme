#| -*-Scheme-*-

$Id: make.scm,v 14.38 1992/11/03 22:41:13 jinx Exp $

Copyright (c) 1988-1992 Massachusetts Institute of Technology

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

;;;; Make Runtime System
;;; package: ()

(declare (usual-integrations))

((ucode-primitive set-interrupt-enables!) 0)

;; This definition is replaced when the 
;; later in the boot sequence.
(define apply (ucode-primitive apply 2))

(define system-global-environment (the-environment))

(let ((environment-for-package (let () (the-environment))))

(define-primitives
  (+ integer-add)
  (- integer-subtract)
  (< integer-less?)
  binary-fasload
  (channel-write 4)
  environment-link-name
  exit-with-value
  (file-exists? 1)
  garbage-collect
  get-fixed-objects-vector
  get-next-constant
  get-primitive-address
  get-primitive-name
  lexical-reference
  lexical-unreferenceable?
  microcode-identify
  scode-eval
  set-fixed-objects-vector!
  set-interrupt-enables!
  string->symbol
  string-allocate
  string-length
  substring=?
  substring-move-right!
  substring-downcase!
  (tty-output-channel 0)
  vector-ref
  vector-set!
  with-interrupt-mask)

(define microcode-identification (microcode-identify))
(define newline-char (vector-ref microcode-identification 5))
(define os-name-string (vector-ref microcode-identification 8))
(define tty-output-descriptor (tty-output-channel))

(define (tty-write-string string)
  (let ((end (string-length string)))
    (let loop ((start 0) (n-left end))
      (let ((n (channel-write tty-output-descriptor string start end)))
	(cond ((not n) (loop start n-left))
	      ((< n n-left) (loop (+ start n) (- n-left n))))))))

(define (tty-write-char char)
  (tty-write-string
   (let ((string (string-allocate 1)))
     (string-set! string 0 char)
     string)))

(define (fatal-error message)
  (tty-write-char newline-char)
  (tty-write-string message)
  (tty-write-char newline-char)
  (exit-with-value 1))

;;;; GC, Interrupts, Errors

(define safety-margin 4500)
(define constant-space/base (get-next-constant))

(let ((condition-handler/gc
       (lambda (interrupt-code interrupt-enables)
	 interrupt-code interrupt-enables
	 (with-interrupt-mask 0
	   (lambda (interrupt-mask)
	     interrupt-mask
	     (garbage-collect safety-margin)))))
      (condition-handler/stack-overflow
       (lambda (interrupt-code interrupt-enables)
	 interrupt-code interrupt-enables
	 (fatal-error "Stack overflow!")))
      (condition-handler/hardware-trap
       (lambda (escape-code)
	 escape-code
	 (fatal-error "Hardware trap!")))
      (fixed-objects (get-fixed-objects-vector)))
  (let ((interrupt-vector (vector-ref fixed-objects 1)))
    (vector-set! interrupt-vector 0 condition-handler/stack-overflow)
    (vector-set! interrupt-vector 2 condition-handler/gc))
  (vector-set! fixed-objects #x0C condition-handler/hardware-trap)
  (set-fixed-objects-vector! fixed-objects))

(set-interrupt-enables! #x0005)

;;;; Utilities

(define fasload-purification-queue
  '())

(define (fasload filename purify?)
  (tty-write-char newline-char)
  (tty-write-string filename)
  (let ((value (binary-fasload filename)))
    (tty-write-string " loaded")
    (if purify?
	(set! fasload-purification-queue
	      (cons (cons filename value)
		    fasload-purification-queue)))
    value))

(define (eval object environment)
  (let ((value (scode-eval object environment)))
    (tty-write-string " evaluated")
    value))

(define (package-initialize package-name procedure-name mandatory?)
  (define (print-name string)
    (tty-write-char newline-char)
    (tty-write-string string)
    (tty-write-string " (")
    (let loop ((name package-name))
      (if (not (null? name))
	  (begin
	    (if (not (eq? name package-name))
		(tty-write-string " "))
	    (tty-write-string (system-pair-car (car name)))
	    (loop (cdr name)))))
    (tty-write-string ")"))

  (let ((env (package-reference package-name)))
    (cond ((not (lexical-unreferenceable? env procedure-name))
	   (print-name "initialize:")
	   (if (not (eq? procedure-name 'INITIALIZE-PACKAGE!))
	       (begin
		 (tty-write-string " [")
		 (tty-write-string (system-pair-car procedure-name))
		 (tty-write-string "]")))
	   ((lexical-reference env procedure-name)))
	  ((not mandatory?)
	   (print-name "* skipping:"))
	  (else
	   ;; Missing mandatory package! Report it and die.
	   (print-name "Package")
	   (tty-write-string " is missing initialization procedure ")
	   (tty-write-string (system-pair-car procedure-name))
	   (fatal-error "Could not initialize a required package.")))))

(define (package-reference name)
  (package/environment (find-package name)))

(define (package-initialization-sequence specs)
  (let loop ((specs specs))
    (if (not (null? specs))
	(let ((spec (car specs)))
	  (if (or (not (pair? spec))
		  (symbol? (car spec)))
	      (package-initialize spec 'INITIALIZE-PACKAGE! false)
	      (package-initialize (car spec) (cadr spec) (caddr spec)))
	  (loop (cdr specs))))))

(define (string-append x y)
  (let ((x-length (string-length x))
	(y-length (string-length y)))
    (let ((result (string-allocate (+ x-length y-length))))
      (substring-move-right! x 0 x-length result 0)
      (substring-move-right! y 0 y-length result x-length)
      result)))

(define (string-downcase string)
  (let ((size (string-length string)))
    (let ((result (string-allocate size)))
      (substring-move-right! string 0 size result 0)
      (substring-downcase! result 0 size)
      result)))

(define (string=? string1 string2)
  (substring=? string1 0 (string-length string1)
	       string2 0 (string-length string2)))

(define (intern string)
  (string->symbol (string-downcase string)))

(define (implemented-primitive-procedure? primitive)
  (get-primitive-address (intern (get-primitive-name (object-datum primitive)))
			 #f))

(define map-filename
  (if (implemented-primitive-procedure? file-exists?)
      (lambda (filename)
	(let ((com-file (string-append filename ".com")))
	  (if (file-exists? com-file)
	      com-file
	      (string-append filename ".bin"))))
      (lambda (filename)
	(string-append filename ".bin"))))

;; Construct the package structure.
;; Lotta hair here to load the package code before its package is built.
(eval (fasload (map-filename "packag") #t) environment-for-package)
((access initialize-package! environment-for-package))
(let loop ((names
	    '(ENVIRONMENT->PACKAGE
	      FIND-PACKAGE
	      NAME->PACKAGE
	      PACKAGE/ADD-CHILD!
	      PACKAGE/CHILD
	      PACKAGE/CHILDREN
	      PACKAGE/ENVIRONMENT
	      PACKAGE/NAME
	      PACKAGE/PARENT
	      PACKAGE/REFERENCE
	      PACKAGE/SYSTEM-LOADER
	      PACKAGE?
	      SYSTEM-GLOBAL-PACKAGE)))
  (if (not (null? names))
      (begin
	(environment-link-name system-global-environment
			       environment-for-package
			       (car names))
	(loop (cdr names)))))
(package/add-child! system-global-package 'PACKAGE environment-for-package)
(eval (fasload "runtim.bcon" #f) system-global-environment)

;;; Global databases.  Load, then initialize.
(let ((sine-qua-non
       '(("gcdemn" . (RUNTIME GC-DAEMONS))
	 ("poplat" . (RUNTIME POPULATION))
	 ("prop1d" . (RUNTIME 1D-PROPERTY))
	 ("events" . (RUNTIME EVENT-DISTRIBUTOR))
	 ("gdatab" . (RUNTIME GLOBAL-DATABASE))
	 ("boot" . ())
	 ("queue" . ())
	 ("gc" . (RUNTIME GARBAGE-COLLECTOR))
	 ("equals" . ())
	 ("list" . (RUNTIME LIST))
	 ("record" . (RUNTIME RECORD)))))
  (let loop ((files sine-qua-non))
    (if (not (null? files))
	(begin
	  (eval (fasload (map-filename (car (car files))) #t)
		(package-reference (cdr (car files))))
	  (loop (cdr files)))))
  (package-initialize '(RUNTIME GC-DAEMONS) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME POPULATION) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME 1D-PROPERTY) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME EVENT-DISTRIBUTOR) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME GLOBAL-DATABASE) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME POPULATION) 'INITIALIZE-UNPARSER! true)
  (package-initialize '(RUNTIME 1D-PROPERTY) 'INITIALIZE-UNPARSER! true)
  (package-initialize '(RUNTIME EVENT-DISTRIBUTOR) 'INITIALIZE-UNPARSER! true)
  (package-initialize '(PACKAGE) 'INITIALIZE-UNPARSER! true)
  (package-initialize '(RUNTIME GARBAGE-COLLECTOR) 'INITIALIZE-PACKAGE! true)
  (lexical-assignment (package-reference '(RUNTIME GARBAGE-COLLECTOR))
		      'CONSTANT-SPACE/BASE
		      constant-space/base)
  (package-initialize '(RUNTIME LIST) 'INITIALIZE-PACKAGE! true)
  (package-initialize '(RUNTIME RECORD) 'INITIALIZE-PACKAGE! true)

;; Load everything else.
;; Note: The following code needs MAP* and MEMBER-PROCEDURE
;; from runtime/list. Fortunately that file has already been loaded.

  ((eval (fasload "runtim.bldr" #f) system-global-environment)
   (let ((to-avoid
	  (cons "packag"
		(map* (if (and (implemented-primitive-procedure? file-exists?)
			       (file-exists? "runtim.bad"))
			  (fasload "runtim.bad" #f)
			  '())
		      car
		      sine-qua-non)))
	 (string-member? (member-procedure string=?)))
     (lambda (filename environment)
       (if (not (string-member? filename to-avoid))
	   (eval (fasload (map-filename filename) #t) environment))
       unspecific))
   `((SORT-TYPE . MERGE-SORT)
     (OS-TYPE . ,(intern os-name-string))
     (OPTIONS . NO-LOAD))))

;;; Funny stuff is done.  Rest of sequence is standardized.
(package-initialization-sequence
 '(
   ;; Microcode interface
   ((RUNTIME MICROCODE-TABLES) READ-MICROCODE-TABLES! #t)
   (RUNTIME STATE-SPACE)
   (RUNTIME MICROCODE-TABLES)
   (RUNTIME APPLY)
   (RUNTIME PRIMITIVE-IO)
   (RUNTIME SAVE/RESTORE)
   (RUNTIME SYSTEM-CLOCK)
   ;; Basic data structures
   (RUNTIME NUMBER)
   (RUNTIME CHARACTER)
   (RUNTIME CHARACTER-SET)
   (RUNTIME GENSYM)
   (RUNTIME STREAM)
   (RUNTIME 2D-PROPERTY)
   (RUNTIME HASH)
   (RUNTIME RANDOM-NUMBER)
   ;; Microcode data structures
   (RUNTIME HISTORY)
   (RUNTIME LAMBDA-ABSTRACTION)
   (RUNTIME SCODE)
   (RUNTIME SCODE-COMBINATOR)
   (RUNTIME SCODE-WALKER)
   (RUNTIME CONTINUATION-PARSER)
   (RUNTIME PROGRAM-COPIER)
   ;; Condition System
   (RUNTIME ERROR-HANDLER)
   (RUNTIME MICROCODE-ERRORS)
   ;; Threads
   (RUNTIME THREAD)
   ;; System dependent stuff
   (() INITIALIZE-SYSTEM-PRIMITIVES! #f)
   ;; I/O
   (RUNTIME GENERIC-I/O-PORT)
   (RUNTIME FILE-I/O-PORT)
   (RUNTIME CONSOLE-I/O-PORT)
   (RUNTIME TRANSCRIPT)
   (RUNTIME STRING-INPUT)
   (RUNTIME STRING-OUTPUT)
   (RUNTIME TRUNCATED-STRING-OUTPUT)
   ;; These MUST be done before (RUNTIME PATHNAME) 
   ;; Typically only one of them is loaded.
   (RUNTIME PATHNAME UNIX)
   (RUNTIME PATHNAME DOS)
   (RUNTIME PATHNAME)
   (RUNTIME WORKING-DIRECTORY)
   (RUNTIME LOAD)
   ;; Syntax
   (RUNTIME PARSER)
   (RUNTIME UNPARSER)
   (RUNTIME SYNTAXER)
   (RUNTIME MACROS)
   (RUNTIME SYSTEM-MACROS)
   (RUNTIME DEFSTRUCT)
   (RUNTIME UNSYNTAXER)
   (RUNTIME PRETTY-PRINTER)
   (RUNTIME EXTENDED-SCODE-EVAL)
   ;; REP Loops
   (RUNTIME INTERRUPT-HANDLER)
   (RUNTIME GC-STATISTICS)
   (RUNTIME REP)
   ;; Debugging
   (RUNTIME COMPILER-INFO)
   (RUNTIME ADVICE)
   (RUNTIME DEBUGGER-COMMAND-LOOP)
   (RUNTIME DEBUGGER-UTILITIES)
   (RUNTIME ENVIRONMENT-INSPECTOR)
   (RUNTIME DEBUGGING-INFO)
   (RUNTIME DEBUGGER)
   (RUNTIME)
   (RUNTIME X-GRAPHICS)
   (RUNTIME STARBASE-GRAPHICS)
   ;; Emacs -- last because it installs hooks everywhere which must be initted.
   (RUNTIME EMACS-INTERFACE)
   ;; More debugging
   ((RUNTIME CONTINUATION-PARSER) INITIALIZE-SPECIAL-FRAMES! #f)))

(let ((filename (map-filename "site")))
  (if (file-exists? filename)
      (eval (fasload filename #t) system-global-environment)))

(environment-link-name (->environment '(RUNTIME ENVIRONMENT))
		       (->environment '(PACKAGE))
		       'PACKAGE-NAME-TAG)

(let ((roots
       (list->vector
	(let ((fasload/update-debugging-info!
	       (access fasload/update-debugging-info!
		       (->environment '(RUNTIME COMPILER-INFO))))
	      (load/purification-root
	       (access load/purification-root
		       (->environment '(RUNTIME LOAD)))))
	  (map (lambda (entry)
		 (let ((object (cdr entry)))
		   (fasload/update-debugging-info! object (car entry))
		   (load/purification-root object)))
	       fasload-purification-queue)))))
  (set! (access gc-boot-loading? (->environment '(RUNTIME GARBAGE-COLLECTOR)))
	false)
  (set! fasload-purification-queue)
  (newline console-output-port)
  (write-string "purifying..." console-output-port)
  ;; First, flush whatever we can.
  (gc-clean)
  ;; Then, really purify the rest.
  (purify roots true false)
  (write-string "done" console-output-port))

)

(package/add-child! system-global-package 'USER user-initial-environment)
(start-thread-timer)
(initial-top-level-repl)