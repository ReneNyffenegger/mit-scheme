#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/vax/instr2.scm,v 1.2 1987/08/18 08:10:44 jinx Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

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

;;;; VAX Instruction Set Description, Part 2

;;; The ordering is essentially that in "Vax Architecture Handbook" 1981.

(declare (usual-integrations))

(define-instruction CVT
  ((B W (? src ea-r-b) (? dst ea-w-w))
   (BYTE (8 #x99))
   (OPERAND B src)
   (OPERAND W dst))

  ((B L (? src ea-r-b) (? dst ea-w-l))
   (BYTE (8 #x98))
   (OPERAND B src)
   (OPERAND L dst))

  ((W B (? src ea-r-w) (? dst ea-w-b))
   (BYTE (8 #x33))
   (OPERAND W src)
   (OPERAND B dst))

  ((W L (? src ea-r-w) (? dst ea-w-l))
   (BYTE (8 #x32))
   (OPERAND W src)
   (OPERAND L dst))

  ((L B (? src ea-r-l) (? dst ea-w-b))
   (BYTE (8 #xF6))
   (OPERAND L src)
   (OPERAND B dst))

  ((L W (? src ea-r-l) (? dst ea-w-w))
   (BYTE (8 #xF7))
   (OPERAND L src)
   (OPERAND W dst))

  ((B F (? src ea-r-b) (? dst ea-w-f))
   (BYTE (8 #x4C))
   (OPERAND B src)
   (OPERAND F dst))

  ((B D (? src ea-r-b) (? dst ea-w-d))
   (BYTE (8 #x6C))
   (OPERAND B src)
   (OPERAND D dst))

  ((B G (? src ea-r-b) (? dst ea-w-g))
   (BYTE (16 #x4CFD))
   (OPERAND B src)
   (OPERAND G dst))

  ((B H (? src ea-r-b) (? dst ea-w-h))
   (BYTE (16 #x6CFD))
   (OPERAND B src)
   (OPERAND H dst))

  ((W F (? src ea-r-w) (? dst ea-w-f))
   (BYTE (8 #x4D))
   (OPERAND W src)
   (OPERAND F dst))

  ((W D (? src ea-r-w) (? dst ea-w-d))
   (BYTE (8 #x6D))
   (OPERAND W src)
   (OPERAND D dst))

  ((W G (? src ea-r-w) (? dst ea-w-g))
   (BYTE (16 #x4DFD))
   (OPERAND W src)
   (OPERAND G dst))

  ((W H (? src ea-r-w) (? dst ea-w-h))
   (BYTE (16 #x6DFD))
   (OPERAND W src)
   (OPERAND H dst))

  ((L F (? src ea-r-l) (? dst ea-w-f))
   (BYTE (8 #x4E))
   (OPERAND L src)
   (OPERAND F dst))

  ((L D (? src ea-r-l) (? dst ea-w-d))
   (BYTE (8 #x6E))
   (OPERAND L src)
   (OPERAND D dst))

  ((L G (? src ea-r-l) (? dst ea-w-g))
   (BYTE (16 #x4EFD))
   (OPERAND L src)
   (OPERAND G dst))

  ((L H (? src ea-r-l) (? dst ea-w-h))
   (BYTE (16 #x6EFD))
   (OPERAND L src)
   (OPERAND H dst))

  ((F B (? src ea-r-f) (? dst ea-w-b))
   (BYTE (8 #x48))
   (OPERAND F src)
   (OPERAND B dst))

  ((D B (? src ea-r-d) (? dst ea-w-b))
   (BYTE (8 #x68))
   (OPERAND D src)
   (OPERAND B dst))

  ((G B (? src ea-r-g) (? dst ea-w-b))
   (BYTE (16 #x48FD))
   (OPERAND G src)
   (OPERAND B dst))

  ((H B (? src ea-r-h) (? dst ea-w-b))
   (BYTE (16 #x68FD))
   (OPERAND H src)
   (OPERAND B dst))

  ((F W (? src ea-r-f) (? dst ea-w-w))
   (BYTE (8 #x49))
   (OPERAND F src)
   (OPERAND W dst))

  ((D W (? src ea-r-d) (? dst ea-w-w))
   (BYTE (8 #x69))
   (OPERAND D src)
   (OPERAND W dst))

  ((G W (? src ea-r-g) (? dst ea-w-w))
   (BYTE (16 #x49FD))
   (OPERAND G src)
   (OPERAND W dst))

  ((H W (? src ea-r-h) (? dst ea-w-w))
   (BYTE (16 #x69FD))
   (OPERAND H src)
   (OPERAND W dst))

  ((F L T (? src ea-r-f) (? dst ea-w-l))
   (BYTE (8 #x4A))
   (OPERAND F src)
   (OPERAND L dst))

  ((F L R (? src ea-r-f) (? dst ea-w-l))
   (BYTE (8 #x4B))
   (OPERAND F src)
   (OPERAND L dst))

  ((D L T (? src ea-r-d) (? dst ea-w-l))
   (BYTE (8 #x6A))
   (OPERAND D src)
   (OPERAND L dst))

  ((D L R (? src ea-r-d) (? dst ea-w-l))
   (BYTE (8 #x6B))
   (OPERAND D src)
   (OPERAND L dst))

  ((G L T (? src ea-r-g) (? dst ea-w-l))
   (BYTE (16 #x4AFD))
   (OPERAND G src)
   (OPERAND L dst))

  ((G L R (? src ea-r-g) (? dst ea-w-l))
   (BYTE (16 #x48FD))
   (OPERAND G src)
   (OPERAND L dst))

  ((H L T (? src ea-r-h) (? dst ea-w-l))
   (BYTE (16 #x6AFD))
   (OPERAND H src)
   (OPERAND L dst))

  ((H L R (? src ea-r-h) (? dst ea-w-l))
   (BYTE (16 #x6BFD))
   (OPERAND H src)
   (OPERAND L dst))

  ((F D (? src ea-r-f) (? dst ea-w-d))
   (BYTE (8 #x56))
   (OPERAND F src)
   (OPERAND D dst))

  ((F G (? src ea-r-f) (? dst ea-w-g))
   (BYTE (16 #x99FD))
   (OPERAND F src)
   (OPERAND G dst))

  ((F H (? src ea-r-f) (? dst ea-w-h))
   (BYTE (16 #x98FD))
   (OPERAND F src)
   (OPERAND H dst))

  ((D F (? src ea-r-d) (? dst ea-w-f))
   (BYTE (16 #x76))
   (OPERAND D src)
   (OPERAND F dst))

  ((D H (? src ea-r-d) (? dst ea-w-h))
   (BYTE (16 #x32FD))
   (OPERAND D src)
   (OPERAND H dst))

  ((G F (? src ea-r-g) (? dst ea-w-f))
   (BYTE (16 #x33FD))
   (OPERAND G src)
   (OPERAND F dst))

  ((G H (? src ea-r-g) (? dst ea-w-h))
   (BYTE (16 #x56FD))
   (OPERAND G src)
   (OPERAND H dst))

  ((H F (? src ea-r-h) (? dst ea-w-f))
   (BYTE (16 #xF6FD))
   (OPERAND H src)
   (OPERAND F dst))

  ((H D (? src ea-r-h) (? dst ea-w-d))
   (BYTE (16 #xF7FD))
   (OPERAND H src)
   (OPERAND D dst))

  ((H G (? src ea-r-h) (? dst ea-w-g))
   (BYTE (16 #x76FD))
   (OPERAND H src)
   (OPERAND G dst)))

(define-instruction CMP
  ((B (? src1 ea-r-b) (? src2 ea-r-b))
   (BYTE (8 #x91))
   (OPERAND B src1)
   (OPERAND B src2))

  ((W (? src1 ea-r-w) (? src2 ea-r-w))
   (BYTE (8 #xB1))
   (OPERAND W src1)
   (OPERAND W src2))

  ((L (? src1 ea-r-l) (? src2 ea-r-l))
   (BYTE (8 #xD1))
   (OPERAND L src1)
   (OPERAND L src2))

  ((F (? src1 ea-r-f) (? src2 ea-r-f))
   (BYTE (8 #x51))
   (OPERAND F src1)
   (OPERAND F src2))

  ((D (? src1 ea-r-d) (? src2 ea-r-d))
   (BYTE (8 #x71))
   (OPERAND D src1)
   (OPERAND D src2))

  ((G (? src1 ea-r-g) (? src2 ea-r-g))
   (BYTE (16 #x51FD))
   (OPERAND G src1)
   (OPERAND G src2))

  ((H (? src1 ea-r-h) (? src2 ea-r-h))
   (BYTE (16 #x71FD))
   (OPERAND H src1)
   (OPERAND H src2)))

(define-instruction MOVZ
  ((B W (? src ea-r-b) (? dst ea-w-w))
   (BYTE (8 #x9B))
   (OPERAND B src)
   (OPERAND W dst))

  ((B L (? src ea-r-b) (? dst ea-w-l))
   (BYTE (8 #x9A))
   (OPERAND B src)
   (OPERAND L dst))

  ((W L (? src ea-r-w) (? dst ea-w-l))
   (BYTE (8 #x3C))
   (OPERAND W src)
   (OPERAND L dst)))

(define-instruction TST
  ((B (? src ea-r-b))
   (BYTE (8 #x95))
   (OPERAND B src))

  ((W (? src ea-r-w))
   (BYTE (8 #xB5))
   (OPERAND W src))

  ((L (? src ea-r-l))
   (BYTE (8 #xD5))
   (OPERAND L src))

  ((F (? src ea-r-f))
   (BYTE (8 #x53))
   (OPERAND F src))

  ((D (? src ea-r-d))
   (BYTE (8 #x73))
   (OPERAND D src))

  ((G (? src ea-r-g))
   (BYTE (16 #x53FD))
   (OPERAND G src))

  ((H (? src ea-r-h))
   (BYTE (16 #x73FD))
   (OPERAND H src)))

(let-syntax
    ((define-arithmetic
       (macro (name digit)
	 `(define-instruction ,name
	    ((B (? op ea-r-b) (? res ea-m-b))
	     (BYTE (8 ,(+ #x80 digit)))
	     (OPERAND B op)
	     (OPERAND B res))

	    ((B (? op1 ea-r-b) (? op2 ea-r-b) (? res ea-w-b))
	     (BYTE (8 ,(+ #x81 digit)))
	     (OPERAND B op1)
	     (OPERAND B op2)
	     (OPERAND B res))

	    ((W (? op ea-r-w) (? res ea-m-w))
	     (BYTE (8 ,(+ #xA0 digit)))
	     (OPERAND W op)
	     (OPERAND W res))

	    ((W (? op1 ea-r-w) (? op2 ea-r-w) (? res ea-w-w))
	     (BYTE (8 ,(+ #xA1 digit)))
	     (OPERAND W op1)
	     (OPERAND W op2)
	     (OPERAND W res))

	    ((L (? op ea-r-l) (? res ea-m-l))
	     (BYTE (8 ,(+ #xC0 digit)))
	     (OPERAND L op)
	     (OPERAND L res))

	    ((L (? op1 ea-r-l) (? op2 ea-r-l) (? res ea-w-l))
	     (BYTE (8 ,(+ #xC1 digit)))
	     (OPERAND L op1)
	     (OPERAND L op2)
	     (OPERAND L res))

	    ((F (? op ea-r-f) (? res ea-m-f))
	     (BYTE (8 ,(+ #x40 digit)))
	     (OPERAND F op)
	     (OPERAND F res))

	    ((F (? op1 ea-r-f) (? op2 ea-r-f) (? res ea-w-f))
	     (BYTE (8 ,(+ #x41 digit)))
	     (OPERAND F op1)
	     (OPERAND F op2)
	     (OPERAND F res))

	    ((D (? op ea-r-d) (? res ea-m-d))
	     (BYTE (8 ,(+ #x60 digit)))
	     (OPERAND D op)
	     (OPERAND D res))

	    ((D (? op1 ea-r-d) (? op2 ea-r-d) (? res ea-w-d))
	     (BYTE (8 ,(+ #x61 digit)))
	     (OPERAND D op1)
	     (OPERAND D op2)
	     (OPERAND D res))

	    ((G (? op ea-r-g) (? res ea-m-g))
	     (BYTE (16 ,(+ #x40FD (* digit #x100))))
	     (OPERAND G op)
	     (OPERAND G res))

	    ((G (? op1 ea-r-g) (? op2 ea-r-g) (? res ea-w-g))
	     (BYTE (16 ,(+ #x41FD (* digit #x100))))
	     (OPERAND G op1)
	     (OPERAND G op2)
	     (OPERAND G res))

	    ((H (? op ea-r-h) (? res ea-m-h))
	     (BYTE (16 ,(+ #x60FD (* digit #x100))))
	     (OPERAND H op)
	     (OPERAND H res))

	    ((H (? op1 ea-r-h) (? op2 ea-r-h) (? res ea-w-h))
	     (BYTE (16 ,(+ #x61FD (* digit #x100))))
	     (OPERAND H op1)
	     (OPERAND H op2)
	     (OPERAND H res))))))

  (define-arithmetic ADD #x0)
  (define-arithmetic SUB #x2)
  (define-arithmetic MUL #x4)
  (define-arithmetic DIV #x6))

(define-instruction ADAWI
  (((? add ea-r-w) (? sum ea-m-w))
   (BYTE (8 #x58))
   (OPERAND W add)
   (OPERAND W sum)))

(define-instruction INC
  ((B (? sum ea-m-b))
   (BYTE (8 #x96))
   (OPERAND B sum))

  ((W (? sum ea-m-w))
   (BYTE (8 #xB6))
   (OPERAND W sum))

  ((L (? sum ea-m-l))
   (BYTE (8 #xD6))
   (OPERAND L sum)))

(define-instruction DEC
  ((B (? dif ea-m-b))
   (BYTE (8 #x97))
   (OPERAND B dif))

  ((W (? dif ea-m-w))
   (BYTE (8 #xB7))
   (OPERAND W dif))

  ((L (? dif ea-m-l))
   (BYTE (8 #xD7))
   (OPERAND L dif)))

(define-instruction ADWC
  (((? add ea-r-l) (? sum ea-m-l))
   (BYTE (8 #xD8))
   (OPERAND L add)
   (OPERAND L sum)))

(define-instruction SBWC
  (((? sub ea-r-l) (? dif ea-m-l))
   (BYTE (8 #xD9))
   (OPERAND L sub)
   (OPERAND L dif)))

(define-instruction EMUL
  (((? mul1 ea-r-l) (? mul2 ea-r-l) (? add ea-r-l) (? prod ea-w-q))
   (BYTE (8 #x7A))
   (OPERAND L mul1)
   (OPERAND L mul2)
   (OPERAND L add)
   (OPERAND Q prod)))

(define-instruction EDIV
  (((? divr ea-r-l) (? divd ea-r-q) (? quo ea-w-l) (? rem ea-w-l))
   (BYTE (8 #x7B))
   (OPERAND L divr)
   (OPERAND Q divd)
   (OPERAND L quo)
   (OPERAND L rem)))

(define-instruction EMOD
  ((F (? mulr ea-r-f) (? mulrx ea-r-b) (? muld ea-r-f)
      (? int ea-w-l) (? fract ea-w-f))
   (BYTE (8 #x54))
   (OPERAND F mulr)
   (OPERAND B mulrx)
   (OPERAND F muld)
   (OPERAND L int)
   (OPERAND F fract))

  ((D (? mulr ea-r-d) (? mulrx ea-r-b) (? muld ea-r-d)
      (? int ea-w-l) (? fract ea-w-d))
   (BYTE (8 #x74))
   (OPERAND D mulr)
   (OPERAND B mulrx)
   (OPERAND D muld)
   (OPERAND L int)
   (OPERAND D fract))

  ((G (? mulr ea-r-g) (? mulrx ea-r-w) (? muld ea-r-g)
      (? int ea-w-l) (? fract ea-w-g))
   (BYTE (16 #x54FD))
   (OPERAND G mulr)
   (OPERAND W mulrx)
   (OPERAND G muld)
   (OPERAND L int)
   (OPERAND G fract))

  ((H (? mulr ea-r-h) (? mulrx ea-r-w) (? muld ea-r-h)
      (? int ea-w-l) (? fract ea-w-h))
   (BYTE (16 #x74FD))
   (OPERAND H mulr)
   (OPERAND W mulrx)
   (OPERAND H muld)
   (OPERAND L int)
   (OPERAND H fract)))

(define-instruction BIT
  ((B (? mask ea-r-b) (? src ea-r-b))
   (BYTE (8 #x93))
   (OPERAND B mask)
   (OPERAND B src))

  ((W (? mask ea-r-w) (? src ea-r-w))
   (BYTE (8 #xB3))
   (OPERAND W mask)
   (OPERAND W src))

  ((L (? mask ea-r-l) (? src ea-r-l))
   (BYTE (8 #xD3))
   (OPERAND L mask)
   (OPERAND L src)))

(let-syntax
    ((define-bitwise
       (macro (name opcode)
	 `(define-instruction ,name
	    ((B (? mask ea-r-b) (? dst ea-m-b))
	     (BYTE (8 ,(+ #x80 opcode)))
	     (OPERAND B mask)
	     (OPERAND B dst))

	    ((B (? mask ea-r-b) (? src ea-r-b) (? dst ea-w-b))
	     (BYTE (8 ,(+ #x81 opcode)))
	     (OPERAND B mask)
	     (OPERAND B src)
	     (OPERAND B dst))

	    ((W (? mask ea-r-w) (? dst ea-m-w))
	     (BYTE (8 ,(+ #xA0 opcode)))
	     (OPERAND W mask)
	     (OPERAND W dst))

	    ((W (? mask ea-r-w) (? src ea-r-w) (? dst ea-w-w))
	     (BYTE (8 ,(+ #xA1 opcode)))
	     (OPERAND W mask)
	     (OPERAND W src)
	     (OPERAND W dst))
	    
	    ((L (? mask ea-r-l) (? dst ea-m-l))
	     (BYTE (8 ,(+ #xC0 opcode)))
	     (OPERAND L mask)
	     (OPERAND L dst))

	    ((L (? mask ea-r-l) (? src ea-r-l) (? dst ea-w-l))
	     (BYTE (8 ,(+ #xC1 opcode)))
	     (OPERAND L mask)
	     (OPERAND L src)
	     (OPERAND L dst))))))

  (define-bitwise BIS #x8)
  (define-bitwise BIC #xA)
  (define-bitwise XOR #xC))
