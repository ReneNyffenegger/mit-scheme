#| -*-Scheme-*-

$Id: redpkg.scm,v 1.5 1993/10/11 23:31:43 cph Exp $

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

;;;; Package Model Reader

(declare (usual-integrations)
	 (integrate-external "object"))

(define (read-package-model filename)
  (let ((model-pathname (merge-pathnames filename)))
    (with-values
	(lambda ()
	  (sort-descriptions
	   (map (lambda (expression)
		  (parse-package-expression expression))
		(read-package-description-file model-pathname))))
      (lambda (packages globals)
	(let ((pmodel (descriptions->pmodel packages model-pathname)))
	  (for-each
	   (let ((root-package (pmodel/root-package pmodel)))
	     (lambda (pathname)
	       (for-each (let ((expression
				(make-expression root-package
						 (->namestring pathname)
						 false)))
			   (lambda (name)
			     (bind! root-package name expression)))
			 (fasload
			  (merge-pathnames (pathname-new-type pathname "glob")
					   model-pathname)))))
	   globals)
	  pmodel)))))

(define (sort-descriptions descriptions)
  (let loop
      ((descriptions descriptions)
       (packages '())
       (globals '()))
    (cond ((null? descriptions)
	   (values (reverse! packages) globals))
	  ((package-description? (car descriptions))
	   (loop (cdr descriptions)
		 (cons (car descriptions) packages)
		 globals))
	  ((and (pair? (car descriptions))
		(eq? (car (car descriptions)) 'GLOBAL-DEFINITIONS))
	   (loop (cdr descriptions)
		 packages
		 (append globals (cdr (car descriptions)))))
	  (else
	   (error "Illegal description" (car descriptions))))))

(define (read-package-description-file pathname)
  (read-file (pathname-default-type pathname "pkg")))

(define (read-file-analyses! pmodel)
  (for-each (lambda (p&c)
	      (record-file-analysis! pmodel
				     (car p&c)
				     (analysis-cache/pathname (cdr p&c))
				     (analysis-cache/data (cdr p&c))))
	    (cache-file-analyses! pmodel)))

(define-structure (analysis-cache
		   (type vector)
		   (constructor make-analysis-cache (pathname time data))
		   (conc-name analysis-cache/))
  (pathname false read-only true)
  (time false)
  (data false))

(define (cache-file-analyses! pmodel)
  (let ((pathname (pathname-new-type (pmodel/pathname pmodel) "free")))
    (let ((result
	   (let ((caches (if (file-exists? pathname) (fasload pathname) '())))
	     (append-map! (lambda (package)
			    (map (lambda (pathname)
				   (cons package
					 (cache-file-analysis! pmodel
							       caches
							       pathname)))
				 (package/files package)))
			  (pmodel/packages pmodel)))))
      (fasdump (map cdr result) pathname)
      result)))

(define (cache-file-analysis! pmodel caches pathname)
  (let ((cache (analysis-cache/lookup caches pathname))
	(full-pathname
	 (merge-pathnames (pathname-new-type pathname "bin")
			  (pmodel/pathname pmodel))))
    (let ((time (file-modification-time full-pathname)))
      (if (not time)
	  (error "unable to open file" full-pathname))
      (if cache
	  (begin
	    (if (> time (analysis-cache/time cache))
		(begin
		  (set-analysis-cache/data! cache (analyze-file full-pathname))
		  (set-analysis-cache/time! cache time)))
	    cache)
	  (make-analysis-cache pathname time (analyze-file full-pathname))))))

(define (analysis-cache/lookup caches pathname)
  (let loop ((caches caches))
    (and (not (null? caches))
	 (if (pathname=? pathname (analysis-cache/pathname (car caches)))
	     (car caches)
	     (loop (cdr caches))))))

(define (record-file-analysis! pmodel package pathname entries)
  (for-each
   (let ((filename (->namestring pathname))
	 (root-package (pmodel/root-package pmodel))
	 (primitive-package (pmodel/primitive-package pmodel)))
     (lambda (entry)
       (let ((name (vector-ref entry 0))
	     (expression
	      (make-expression package filename (vector-ref entry 1))))
	 (for-each-vector-element (vector-ref entry 2)
	   (lambda (name)
	     (cond ((symbol? name)
		    (make-reference package name expression))
		   ((primitive-procedure? name)
		    (make-reference primitive-package
				    (primitive-procedure-name name)
				    expression))
		   ((access? name)
		    (if (access-environment name)
			(error "Non-root access" name))
		    (make-reference root-package
				    (access-name name)
				    expression))
		   (else
		    (error "Illegal reference name" name)))))
	 (if name
	     (bind! package name expression)))))
   entries))

(define (resolve-references! pmodel)
  (for-each (lambda (package)
	      (for-each resolve-reference!
			(package/sorted-references package)))
	    (pmodel/packages pmodel)))

(define (resolve-reference! reference)
  (let ((binding
	 (package-lookup (reference/package reference)
			 (reference/name reference))))
    (if binding
	(begin
	  (set-reference/binding! reference binding)
	  (set-binding/references! binding
				   (cons reference
					 (binding/references binding)))))))

;;;; Package Descriptions

(define (parse-package-expression expression)
  (if (not (pair? expression))
      (error "package expression not a pair" expression))
  (case (car expression)
    ((DEFINE-PACKAGE)
     (parse-package-description (parse-name (cadr expression))
				(cddr expression)))
    ((GLOBAL-DEFINITIONS)
     (let ((filenames (cdr expression)))
       (if (not (check-list filenames string?))
	   (error "illegal filenames" filenames))
       (cons 'GLOBAL-DEFINITIONS (map parse-filename filenames))))
    (else
     (error "unrecognized expression keyword" (car expression)))))

(define (parse-package-description name options)
  (let ((none "none"))
    (let ((file-cases '())
	  (parent none)
	  (initialization none)
	  (exports '())
	  (imports '()))
      (if (not (list? options))
	  (error "options not list" options))
      (for-each (lambda (option)
		  (if (not (pair? option))
		      (error "Illegal option" option))
		  (case (car option)
		    ((FILES)
		     (set! file-cases
			   (cons (parse-filenames (cdr option)) file-cases)))
		    ((FILE-CASE)
		     (set! file-cases
			   (cons (parse-file-case (cdr option)) file-cases)))
		    ((PARENT)
		     (if (not (eq? parent none))
			 (error "option reoccurs" option))
		     (if (not (and (pair? (cdr option)) (null? (cddr option))))
			 (error "illegal option" option))
		     (set! parent (parse-name (cadr option))))
		    ((EXPORT)
		     (set! exports (cons (parse-export (cdr option)) exports)))
		    ((IMPORT)
		     (set! imports (cons (parse-import (cdr option)) imports)))
		    ((INITIALIZATION)
		     (if (not (eq? initialization none))
			 (error "option reoccurs" option))
		     (set! initialization (parse-initialization (cdr option))))
		    (else
		     (error "unrecognized option keyword" (car option)))))
		options)
      (make-package-description
       name
       file-cases
       (if (eq? parent none) 'NONE parent)
       (if (eq? initialization none) '#F initialization)
       (reverse! exports)
       (reverse! imports)))))

(define (parse-name name)
  (if (not (check-list name symbol?))
      (error "illegal name" name))
  name)

(define (parse-filenames filenames)
  (if (not (check-list filenames string?))
      (error "illegal filenames" filenames))
  (list #F (cons 'ELSE (map parse-filename filenames))))

(define (parse-file-case file-case)
  (if (not (and (pair? file-case)
		(symbol? (car file-case))
		(check-list (cdr file-case)
		  (lambda (clause)
		    (and (pair? clause)
			 (or (eq? 'ELSE (car clause))
			     (check-list (car clause) symbol?))
			 (check-list (cdr clause) string?))))))
      (error "Illegal file-case" file-case))
  (cons (car file-case)
	(map (lambda (clause)
	       (cons (car clause)
		     (map parse-filename (cdr clause))))
	     (cdr file-case))))

(define-integrable (parse-filename filename)
  (->pathname filename))

(define (parse-initialization initialization)
  (if (not (and (pair? initialization) (null? (cdr initialization))))
      (error "illegal initialization" initialization))
  (car initialization))

(define (parse-import import)
  (if (not (and (pair? import) (check-list (cdr import) symbol?)))
      (error "illegal import" import))
  (cons (parse-name (car import)) (cdr import)))

(define (parse-export export)
  (if (not (and (pair? export) (check-list (cdr export) symbol?)))
      (error "illegal export" export))
  (cons (parse-name (car export)) (cdr export)))

(define (check-list items predicate)
  (let loop ((items items))
    (if (pair? items)
	(if (predicate (car items))
	    (loop (cdr items))
	    false)
	(null? items))))

;;;; Packages

(define (package-lookup package name)
  (let package-loop ((package package))
    (or (package/find-binding package name)
	(and (package/parent package)
	     (package-loop (package/parent package))))))

(define (name->package packages name)
  (list-search-positive packages
    (lambda (package)
      (symbol-list=? name (package/name package)))))

(define (descriptions->pmodel descriptions pathname)
  (let ((packages
	 (map (lambda (description)
		(make-package
		 (package-description/name description)
		 (package-description/file-cases description)
		 (package-description/initialization description)
		 'UNKNOWN))
	      descriptions))
	(extra-packages '()))
    (let ((root-package
	   (or (name->package packages '())
	       (make-package '() '() '#F false))))
      (let ((get-package
	     (lambda (name)
	       (if (null? name)
		   root-package
		   (or (name->package packages name)
		       (let ((package (make-package name '() #F 'UNKNOWN)))
			 (set! extra-packages (cons package extra-packages))
			 package))))))
	(for-each (lambda (package description)
		    (let ((parent
			   (let ((parent-name
				  (package-description/parent description)))
			     (and (not (eq? parent-name 'NONE))
				  (get-package parent-name)))))
		      (set-package/parent! package parent)
		      (if parent
			  (set-package/children!
			   parent
			   (cons package (package/children parent)))))
		    (for-each (lambda (export)
				(let ((destination (get-package (car export))))
				  (for-each (lambda (name)
					      (link! package name
						     destination name))
					    (cdr export))))
			      (package-description/exports description))
		    (for-each (lambda (import)
				(let ((source (get-package (car import))))
				  (for-each (lambda (name)
					      (link! source name package name))
					    (cdr import))))
			      (package-description/imports description)))
		  packages
		  descriptions))
      (make-pmodel root-package
		   (make-package primitive-package-name '() '() false)
		   packages
		   extra-packages
		   pathname))))

(define primitive-package-name
  (list (string->symbol "#[(cross-reference reader)primitives]")))

;;;; Binding and Reference

(define (bind! package name expression)
  (let ((value-cell (binding/value-cell (intern-binding! package name))))
    (set-expression/value-cell! expression value-cell)
    (set-value-cell/expressions!
     value-cell
     (cons expression (value-cell/expressions value-cell)))))

(define (link! source-package source-name destination-package destination-name)
  (if (package/find-binding destination-package destination-name)
      (error "Attempt to reinsert binding" destination-name))
  (let ((source-binding (intern-binding! source-package source-name)))
    (let ((destination-binding
	   (make-binding destination-package
			 destination-name
			 (binding/value-cell source-binding))))
      (rb-tree/insert! (package/bindings destination-package)
		       destination-name
		       destination-binding)
      (make-link source-binding destination-binding))))

(define (intern-binding! package name)
  (or (package/find-binding package name)
      (let ((binding
	     (let ((value-cell (make-value-cell)))
	       (let ((binding (make-binding package name value-cell)))
		 (set-value-cell/source-binding! value-cell binding)
		 binding))))
	(rb-tree/insert! (package/bindings package) name binding)
	binding)))

(define (make-reference package name expression)
  (let ((references (package/references package))
	(add-reference!
	 (lambda (reference)
	   (set-reference/expressions!
	    reference
	    (cons expression (reference/expressions reference)))
	   (set-expression/references!
	    expression
	    (cons reference (expression/references expression))))))
    (let ((reference (rb-tree/lookup references name #f)))
      (if reference
	  (begin
	    (if (not (memq expression (reference/expressions reference)))
		(add-reference! reference))
	    reference)
	  (let ((reference (%make-reference package name)))
	    (rb-tree/insert! references name reference)
	    (add-reference! reference)
	    reference)))))