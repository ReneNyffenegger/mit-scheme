#| -*-Scheme-*-

Copyright (c) 1988, 1989, 1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; Support for tagged objects

(declare (usual-integrations))

(define-structure (vector-tag
		   (constructor %make-vector-tag (parent name index)))
  (parent false read-only true)
  (name false read-only true)
  (index false read-only true)
  (%unparser false)
  (description false)
  (method-alist '()))

(define make-vector-tag
  (let ((root-tag (%make-vector-tag false 'OBJECT false)))
    (set-vector-tag-%unparser!
     root-tag
     (lambda (state object)
       ((standard-unparser
	 (symbol->string (vector-tag-name (tagged-vector/tag object)))
	 false)
	state object)))
    (named-lambda (make-vector-tag parent name enumeration)
      (let ((tag
	     (%make-vector-tag (or parent root-tag)
			       name
			       (and enumeration
				    (enumeration/name->index enumeration
							     name)))))
	(unparser/set-tagged-vector-method! tag tagged-vector/unparse)
	tag))))

(define (define-vector-tag-unparser tag unparser)
  (set-vector-tag-%unparser! tag unparser)
  (vector-tag-name tag))

(define (vector-tag-unparser tag)
  (or (vector-tag-%unparser tag)
      (let ((parent (vector-tag-parent tag)))
	(if parent
	    (vector-tag-unparser parent)
	    (error "Missing unparser" tag)))))

(define (vector-tag-put! tag key value)
  (let ((entry (assq key (vector-tag-method-alist tag))))
    (if entry
	(set-cdr! entry value)
	(set-vector-tag-method-alist! tag
				      (cons (cons key value)
					    (vector-tag-method-alist tag))))))

(define (vector-tag-get tag key)
  (let ((value
	 (or (assq key (vector-tag-method-alist tag))
	     (let loop ((tag (vector-tag-parent tag)))
	       (and tag
		    (or (assq key (vector-tag-method-alist tag))
			(loop (vector-tag-parent tag))))))))
    (and value (cdr value))))

(define (define-vector-tag-method tag name method)
  (vector-tag-put! tag name method)
  name)

(define (vector-tag-method tag name)
  (or (vector-tag-get tag name)
      (error "Unbound method" name tag)))

(define-integrable make-tagged-vector
  vector)

(define-integrable (tagged-vector/tag vector)
  (vector-ref vector 0))

(define-integrable (tagged-vector/index vector)
  (vector-tag-index (tagged-vector/tag vector)))

(define-integrable (tagged-vector/unparser vector)
  (vector-tag-unparser (tagged-vector/tag vector)))

(define (tagged-vector? object)
  (and (vector? object)
       (not (zero? (vector-length object)))
       (vector-tag? (tagged-vector/tag object))))

(define (->tagged-vector object)
  (let ((object
	 (if (exact-nonnegative-integer? object)
	     (unhash object)
	     object)))
    (and (or (tagged-vector? object)
	     (named-structure? object))
	 object)))

(define (tagged-vector/predicate tag)
  (lambda (object)
    (and (vector? object)
	 (not (zero? (vector-length object)))
	 (eq? tag (tagged-vector/tag object)))))

(define (tagged-vector/subclass-predicate tag)
  (lambda (object)
    (and (vector? object)
	 (not (zero? (vector-length object)))
	 (let loop ((tag* (tagged-vector/tag object)))
	   (and (vector-tag? tag*)
		(or (eq? tag tag*)
		    (loop (vector-tag-parent tag*))))))))

(define (tagged-vector/description object)
  (cond ((named-structure? object)
	 named-structure/description)
	((tagged-vector? object)
	 (vector-tag-description (tagged-vector/tag object)))
	(else
	 (error "Not a tagged vector" object))))

(define (standard-unparser name unparser)
  (let ((name (string-append (symbol->string 'LIAR) ":" name)))
    (if unparser
	(unparser/standard-method name unparser)
	(unparser/standard-method name))))

(define (tagged-vector/unparse state vector)
  (fluid-let ((*unparser-radix* 16))
    ((tagged-vector/unparser vector) state vector)))