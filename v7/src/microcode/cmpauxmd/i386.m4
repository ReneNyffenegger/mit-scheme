### -*-Midas-*-
###
###	$Id: i386.m4,v 1.36 1995/02/26 03:34:36 cph Exp $
###
###	Copyright (c) 1992-95 Massachusetts Institute of Technology
###
###	This material was developed by the Scheme project at the
###	Massachusetts Institute of Technology, Department of
###	Electrical Engineering and Computer Science.  Permission to
###	copy this software, to redistribute it, and to use it for any
###	purpose is granted, subject to the following restrictions and
###	understandings.
###
###	1. Any copy made of this software must include this copyright
###	notice in full.
###
###	2. Users of this software agree to make their best efforts (a)
###	to return to the MIT Scheme project any improvements or
###	extensions that they make, so that these may be included in
###	future releases; and (b) to inform MIT of noteworthy uses of
###	this software.
###
###	3. All materials developed as a consequence of the use of this
###	software shall duly acknowledge such use, in accordance with
###	the usual standards of acknowledging credit in academic
###	research.
###
###	4. MIT has made no warrantee or representation that the
###	operation of this software will be error-free, and MIT is
###	under no obligation to provide any services, by way of
###	maintenance, update, or otherwise.
###
###	5. In conjunction with products arising from the use of this
###	material, there shall be no use of the name of the
###	Massachusetts Institute of Technology nor of any adaptation
###	thereof in any advertising, promotional, or sales literature
###	without prior written consent from MIT in each case.
###

### Intel i386 assembly language part of the compiled code interface.
### See cmpint.txt, cmpint.c, cmpint-mc68k.h, and cmpgc.h for more
### documentation.
###
### This m4 source expands into either Unix (gas) source or DOS
### (masm) source.
###
### NOTE:
###	Assumptions:
###
###	0) Segment registers and paging are set up for 32-bit "flat"
###	operation.
###
###	1) All registers (except double floating point registers) and
###	stack locations hold a C long object.
###
###	2) The C compiler divides registers into three groups:
###	- Linkage registers, used for procedure calls and global
###	references.  On i386 (gcc and Zortech C): %ebp, %esp.
###	- super temporaries, not preserved accross procedure calls and
###	always usable. On i386 (gcc and Zortech C): %eax, %edx, %ecx.
###	- preserved registers saved by the callee if they are written.
###	On i386 (gcc and Zortech C): all others (%ebx, %esi, %edi).
###
###	3) Arguments, if passed on a stack, are popped by the caller
###	or by the procedure return instruction (as on the VAX).  Thus
###	most "leaf" procedures need not worry about them.  On i386,
###	arguments are passed on the stack.
###
###	4) There is a hardware or software maintained stack for
###	control.  The procedure calling sequence may leave return
###	addresses in registers, but they must be saved somewhere for
###	nested calls and recursive procedures.  On i386: saved on
###	the stack by the CALL instruction.
###
###	5) C procedures return long values in a super temporary
###	register.  Two word structures are returned differently,
###	depending on the C compiler used.  When using GCC, two-word
###	structures are returned in {%eax, %edx}.  When using a
###	compiler compatible with MicroSoft's C compiler (e.g. Zortech
###	C), two word structures are returned by returning in %eax the
###	address of a structure allocated statically.  If the Scheme
###	system ever becomes reentrant, this will have to change.
###	Note the assumption below is that all DOS compilers are
###	compatible with MicroSoft C.
###
###	6) Floating point registers are not preserved by this
###	interface.  The interface is only called from the Scheme
###	interpreter, which does not use floating point data.  Thus
###	although the calling convention would require us to preserve
###	them, they contain garbage.
###
### Compiled Scheme code uses the following register convention:
###	- %esp containts the Scheme stack pointer, not the C stack
###	pointer.
###	- %esi contains a pointer to the Scheme interpreter's "register"
###	block.  This block contains the compiler's copy of MemTop,
###	the interpreter's registers (val, env, exp, etc.),
###	temporary locations for compiled code, and the addresses
###	of various hooks defined in this file.
###	- %edi contains the Scheme free pointer.
###	- %ebp contains the Scheme datum mask.
###	The dynamic link (when needed) is in Registers[REGBLOCK_COMPILER_TEMP]
###	Values are returned in Registers[REGBLOCK_VAL]
###
###	All other registers (%eax, %edx, %ecx, %ebx) are available to
###	the compiler.  A caller-saves convention is used, so the
###	registers need not be preserved by subprocedures.

####	Utility macros and definitions

ifdef(`DOS',
      `define(IFDOS,`$1')',
      `define(IFDOS,`')')

ifdef(`DOS',
      `define(IFNDOS,`')',
      `define(IFNDOS,`$1')')

ifdef(`OS2',
      `define(IFOS2,`$1')',
      `define(IFOS2,`')')

ifdef(`DISABLE_387',
      `define(IF387,`')',
      `define(IF387,`$1')')

ifdef(`DISABLE_387',
      `define(IFN387,`$1')',
      `define(IFN387,`')')

	IFNDOS(`.file	"cmpaux-i386.s"')

ifdef(`DOS',
      `define(use_external_data,`	extrn _$1':dword)',
      `define(use_external_data,`')')

ifdef(`DOS',
      `define(use_external_code,`	extrn _$1:near')',
      `define(use_external_code,`')')

ifdef(`OS2',
      `define(external_data_reference,`$1')',
      `define(external_data_reference,`_$1')')

define(EDR,`external_data_reference($1)')

ifdef(`OS2',
      `define(external_code_reference,`$1')',
      `define(external_code_reference,`_$1')')

ifdef(`DOS',
      `define(define_code,`	public _$1')',
      `define(define_code,`	.globl external_code_reference($1)')')

ifdef(`DOS',
      `define(define_data,`	public _$1')',
      `define(define_data,`	.globl external_code_reference($1)')')

define(define_c_label,
`define_code($1)
external_code_reference($1):')

ifdef(`DOS',
      `define(define_debugging_label,`	public $1
$1:')',
      `define(define_debugging_label,`	.globl $1
$1:')')

ifdef(`DOS',
      `define(DECLARE_DATA_SEGMENT,`	.data')',
      `define(DECLARE_DATA_SEGMENT,`	.data')')

ifdef(`DOS',
      `define(DECLARE_CODE_SEGMENT,`	.code')',
      `define(DECLARE_CODE_SEGMENT,`	.text')')

ifdef(`DOS',
      `define(declare_alignment,`')',
      `define(declare_alignment,`	.align $1')')

ifdef(`DOS',
      `define(allocate_word,`_$1 dw 0')',
      `define(allocate_word,`	.comm EDR($1),2')')

ifdef(`DOS',
      `define(allocate_longword,`_$1 dd 0')',
      `define(allocate_longword,`	.comm EDR($1),4')')

ifdef(`DOS',
      `define(allocate_space,`_$1 db $2 dup (0)')',
      `define(allocate_space,`EDR($1):
	.space $2')')

ifdef(`DOS',
      `define(HEX, `0$1H')',
      `define(HEX, `0x$1')')

ifdef(`DOS',
      `define(OP,`$1$3')',
      `define(OP,`$1$2')')

ifdef(`DOS',
      `define(TW,`$2,$1')',
      `define(TW,`$1,$2')')

ifdef(`DOS',
      `define(ABS, `dword ptr $1')',
      `define(ABS, `$1')')

ifdef(`DOS',
      `define(IMM, `$1')',
      `define(IMM, `$$1')')

ifdef(`DOS',
      `define(REG,`$1')',
      `define(REG,`%$1')')

ifdef(`DOS',
      `define(ST,`st($1)')',
      `define(ST,`%st ($1)')')

ifdef(`DOS',
      `define(IND,`dword ptr [$1]')',
      `define(IND,`($1)')')

ifdef(`DOS',
      `define(BOF,`byte ptr $1[$2]')',
      `define(BOF,`$1($2)')')

ifdef(`DOS',
      `define(WOF,`word ptr $1[$2]')',
      `define(WOF,`$1($2)')')

ifdef(`DOS',
      `define(LOF,`dword ptr $1[$2]')',
      `define(LOF,`$1($2)')')

ifdef(`DOS',
      `define(DOF,`qword ptr $1[$2]')',
      `define(DOF,`$1($2)')')

ifdef(`DOS',
      `define(IDX,`dword ptr [$1] [$2]')',
      `define(IDX,`($1,$2)')')

ifdef(`DOS',
      `define(SDX,`dword ptr $1[$2*$3]')',
      `define(SDX,`$1(,$2,$3)')')

ifdef(`DOS',
      `define(IJMP,`$1')',
      `define(IJMP,`*$1')')

IFDOS(`define(TYPE_CODE_LENGTH,6)')
IFOS2(`define(TYPE_CODE_LENGTH,6)')

define(TC_LENGTH, ifdef(`TYPE_CODE_LENGTH', TYPE_CODE_LENGTH, 8))
define(DATUM_LENGTH, eval(32 - TC_LENGTH))
define(DATUM_SHIFT, eval((2 ** DATUM_LENGTH)))
define(ADDRESS_MASK, eval((DATUM_SHIFT - 1)))
define(TAG, ($2 + ($1 * DATUM_SHIFT)))

define(TC_FALSE,0)
define(TC_FLONUM,6)
define(TC_TRUE,8)
define(TC_FIXNUM,26)
define(TC_MANIFEST_NM_VECTOR,39)
define(TC_COMPILED_ENTRY,40)

define(REGBLOCK_VAL,8)
define(REGBLOCK_COMPILER_TEMP,16)
define(REGBLOCK_LEXPR_ACTUALS,28)
define(REGBLOCK_PRIMITIVE,32)
define(REGBLOCK_CLOSURE_FREE,36)

define(REGBLOCK_DLINK,REGBLOCK_COMPILER_TEMP)
define(REGBLOCK_UTILITY_ARG4,REGBLOCK_CLOSURE_FREE)

define(COMPILER_REGBLOCK_N_FIXED,16)
define(COMPILER_REGBLOCK_N_HOOKS,80)
define(COMPILER_REGBLOCK_N_TEMPS,256)
define(COMPILER_FIXED_SIZE,1)
define(COMPILER_HOOK_SIZE,1)
define(COMPILER_TEMP_SIZE,3)
define(REGBLOCK_SIZE_IN_OBJECTS,
       eval((COMPILER_REGBLOCK_N_FIXED*COMPILER_FIXED_SIZE)
	    +(COMPILER_REGBLOCK_N_HOOKS*COMPILER_HOOK_SIZE)
	    +(COMPILER_REGBLOCK_N_TEMPS*COMPILER_TEMP_SIZE)))

define(regs,REG(esi))
define(rfree,REG(edi))
define(rmask,REG(ebp))

IFDOS(`.386
.model tiny')

DECLARE_DATA_SEGMENT()
declare_alignment(2)

use_external_data(Free)
use_external_data(Ext_Stack_Pointer)
use_external_data(utility_table)

ifdef(`WINNT',
`	extrn _RegistersPtr:dword',
`ifdef(`DOS',
`use_external_data(Registers)',
`define_data(Regstart)
allocate_space(Regstart,128)
define_data(Registers)
allocate_space(Registers,eval(REGBLOCK_SIZE_IN_OBJECTS*4))')')

ifdef(`WINNT',
`	extrn _winnt_address_delta:dword')

define_data(i387_presence)
allocate_longword(i387_presence)

define_data(C_Stack_Pointer)
allocate_longword(C_Stack_Pointer)

define_data(C_Frame_Pointer)
allocate_longword(C_Frame_Pointer)

ifdef(`WINNT',`define_data(Scheme_Transfer_Address)
allocate_longword(Scheme_Transfer_Address)')

ifdef(`WINNT',`define_data(Scheme_Code_Segment_Selector)
allocate_word(Scheme_Code_Segment_Selector)
define_data(Scheme_Data_Segment_Selector)
allocate_word(Scheme_Data_Segment_Selector)
define_data(Scheme_Stack_Segment_Selector)
allocate_word(Scheme_Stack_Segment_Selector)
define_data(C_Code_Segment_Selector)
allocate_word(C_Code_Segment_Selector)
define_data(C_Data_Segment_Selector)
allocate_word(C_Data_Segment_Selector)
define_data(C_Extra_Segment_Selector)
allocate_word(C_Extra_Segment_Selector)
define_data(C_Stack_Segment_Selector)
allocate_word(C_Stack_Segment_Selector)',
`IFDOS(`define_data(C_Stack_Segment_Selector)
allocate_word(C_Stack_Segment_Selector)
define_data(Scheme_Stack_Segment_Selector)
allocate_word(Scheme_Stack_Segment_Selector)')')

DECLARE_CODE_SEGMENT()
declare_alignment(2)

define_c_label(i386_interface_initialize)
	OP(push,l)	REG(ebp)
	OP(mov,l)	TW(REG(esp),REG(ebp))

							# Initialize selectors
ifdef(`WINNT',
`	lea	eax,cross_segment_transfer_point
	mov	_Scheme_Transfer_Address,eax
	mov	_C_Extra_Segment_Selector,es		; This assumes it is constant

	mov	_C_Code_Segment_Selector,cs
	mov	ax,_Scheme_Code_Segment_Selector
	cmp	ax,0
	jne	skip_code_assignment
	mov	_Scheme_Code_Segment_Selector,cs
skip_code_assignment:

	mov	_C_Data_Segment_Selector,ds
	mov	ax,_Scheme_Data_Segment_Selector
	cmp	ax,0
	jne	skip_data_assignment
	mov	_Scheme_Data_Segment_Selector,ds
skip_data_assignment:')

IFDOS(`	OP(mov,w)	TW(REG(ss),EDR(C_Stack_Segment_Selector))
	OP(mov,w)	TW(EDR(Scheme_Stack_Segment_Selector),REG(ax))
	OP(cmp,w)	TW(IMM(0),REG(ax))
	jne		skip_stack_assignment
	OP(mov,w)	TW(REG(ds),EDR(Scheme_Stack_Segment_Selector))
skip_stack_assignment:')

	OP(xor,l)	TW(REG(eax),REG(eax))		# No 387 available

# Unfortunately, the `movl cr0,ecx' instruction is privileged.
# Use the deprecated `smsw cx' instruction instead.

IF387(`	
#	OP(mov,l)	TW(REG(cr0),REG(ecx))		# Test for 387 presence
	smsw		REG(cx)
	OP(mov,l)	TW(IMM(HEX(12)),REG(edx))
	OP(and,l)	TW(REG(edx),REG(ecx))
	OP(cmp,l)	TW(REG(edx),REG(ecx))
	jne	i386_initialize_no_fp
	OP(inc,l)	REG(eax)			# 387 available
	OP(sub,l)	TW(IMM(4),REG(esp))
	fclex
	fnstcw	WOF(-2,REG(ebp))
	# On Unix, set rounding mode to round-to-even, precision control to
	# double, mask the inexact result exception, and unmask the other exceptions.
	# On DOS, set rounding mode to round-to-even, precision control to
	# double and and mask all exceptions.
	OP(and,w)	TW(IMM(HEX(f0e0)),WOF(-2,REG(ebp)))
	ifdef(`DOS',
	      `OP(or,w)	TW(IMM(HEX(023f)),WOF(-2,REG(ebp)))',
	      `OP(or,w)	TW(IMM(HEX(0220)),WOF(-2,REG(ebp)))')
	fldcw	WOF(-2,REG(ebp))

i386_initialize_no_fp:')
	OP(mov,l)	TW(REG(eax),EDR(i387_presence))
	leave
	ret

define_c_label(C_to_interface)
	OP(push,l)	REG(ebp)			# Link according
	OP(mov,l)	TW(REG(esp),REG(ebp))		#  to C's conventions
	OP(push,l)	REG(edi)			# Save callee-saves
	OP(push,l)	REG(esi)			#  registers
	OP(push,l)	REG(ebx)
	OP(mov,l)	TW(LOF(8,REG(ebp)),REG(edx))	# Entry point
							# Preserve frame ptr
	OP(mov,l)	TW(REG(ebp),EDR(C_Frame_Pointer))
							# Preserve stack ptr
	OP(mov,l)	TW(REG(esp),EDR(C_Stack_Pointer))
							# Register block = %esi
							# Scheme offset in NT

	ifdef(`WINNT',
	`mov	esi,dword ptr _RegistersPtr
	sub	esi,_winnt_address_delta',	
	`OP(lea,l)	TW(ABS(EDR(Registers)),regs)')
	jmp	external_code_reference(interface_to_scheme)

define_c_label(asm_trampoline_to_interface)
define_debugging_label(trampoline_to_interface)
	OP(pop,l)	REG(ecx)			# trampoline storage
	jmp	scheme_to_interface

define_c_label(asm_scheme_to_interface_call)
define_debugging_label(scheme_to_interface_call)
	OP(pop,l)	REG(ecx)			# arg1 = ret. add
	OP(add,l)	TW(IMM(4),REG(ecx))		# Skip format info
#	jmp	scheme_to_interface

define_c_label(asm_scheme_to_interface)
define_debugging_label(scheme_to_interface)
ifdef(`WINNT',
`	push	dword ptr 36[esi]			; 4th utility arg
	push	eax					; Save utility index

	mov	ax,es					; C ds
	mov	ds,ax

	mov	ax,_C_Extra_Segment_Selector		; C es
	mov	es,ax
	add	edi,_winnt_address_delta		; Map Free to C data space
	mov	_Free,edi

	mov	eax,esp					; Map SP to C data space
	add	eax,_winnt_address_delta
	mov	_Ext_Stack_Pointer,eax

	mov	ss,_C_Stack_Segment_Selector		; Switch stack segment
	mov	esp,_C_Stack_Pointer
	mov	ebp,_C_Frame_Pointer

	xor	eax,eax
	mov	ax,_C_Code_Segment_Selector
	push	eax
	push	_Scheme_Transfer_Address
	db	0cbh					; retf

cross_segment_transfer_point:

	mov	eax,_Ext_Stack_Pointer
	push	dword ptr 4[eax]			; 4th utility arg
	add	_Ext_Stack_Pointer,8
	mov	eax, dword ptr [eax]			; utility index
',

`	OP(mov,l)	TW(REG(esp),EDR(Ext_Stack_Pointer))
	OP(mov,l)	TW(rfree,EDR(Free))

IFDOS(`	OP(mov,w)	TW(EDR(C_Stack_Segment_Selector),REG(ss))')	# Swap stack segments

	OP(mov,l)	TW(EDR(C_Stack_Pointer),REG(esp))
	OP(mov,l)	TW(EDR(C_Frame_Pointer),REG(ebp))

IFOS2(`	OP(sub,l)	TW(IMM(8),REG(esp))	# alloc space for struct return
')
	OP(push,l)	LOF(REGBLOCK_UTILITY_ARG4(),regs) # Utility args
')
	OP(push,l)	REG(ebx)
	OP(push,l)	REG(edx)
	OP(push,l)	REG(ecx)

IFOS2(`	OP(mov,l)	TW(REG(esp),REG(ecx))	# push pointer to struct return
	OP(add,l)	TW(IMM(16),REG(ecx))
	OP(push,l)	REG(ecx)
')

	OP(xor,l)	TW(REG(ecx),REG(ecx))
	OP(mov,b)	TW(REG(al),REG(cl))
	OP(mov,l)	TW(SDX(EDR(utility_table),REG(ecx),4),REG(eax))
	call	IJMP(REG(eax))

define_debugging_label(scheme_to_interface_return)
IFOS2(`	OP(add,l)	TW(IMM(4),REG(esp))	# pop pointer to struct return
')
	OP(add,l)	TW(IMM(16),REG(esp))		# Pop utility args

	ifdef(`WINNT',
	`',
`IFDOS(`OP(mov,l)	TW(LOF(4,REG(eax)),REG(edx))
	OP(mov,l)	TW(IND(REG(eax)),REG(eax))')')

IFOS2(`	OP(pop,l)	REG(eax)	# Pop struct return into registers
	OP(pop,l)	REG(edx)')

	jmp	IJMP(REG(eax))				# Invoke handler

define_c_label(interface_to_scheme)
IF387(`
	OP(cmp,l)	TW(IMM(0),EDR(i387_presence))
	je	interface_to_scheme_proceed
	ffree	ST(0)					# Free floating "regs"
	ffree	ST(1)
	ffree	ST(2)
	ffree	ST(3)
	ffree	ST(4)
	ffree	ST(5)
	ffree	ST(6)
	ffree	ST(7)
interface_to_scheme_proceed:')
ifdef(`WINNT',
`	mov	edi,_Free				; Free pointer = %edi
	sub	edi,_winnt_address_delta		; as a scheme offset

	mov	ebp,67108863				; pointer mask #x03ffffff

	mov	eax,_Ext_Stack_Pointer			; Switch stacks
	sub	eax,_winnt_address_delta
	mov	ss,_Scheme_Stack_Segment_Selector
	mov	esp,eax
				
	sub	edx,_winnt_address_delta		; Entry point to new space
	xor	ecx,ecx					; Setup cross-segment jump
	mov	cx,_Scheme_Code_Segment_Selector

	mov	ax,ds					; Store C ds in es,
	mov	es,ax					;  unused by Scheme.
	mov	ax,_Scheme_Data_Segment_Selector	; Switch data segments
	mov	ds,ax
							
	push	ecx
	push	edx

	mov	eax,dword ptr 8[esi]			; Value/dynamic link
	mov	ecx,eax					; Preserve if used
	and	ecx,ebp					; Restore potential
							;  dynamic link
	mov	dword ptr 16[esi],ecx
	db	0cbh					; retf
',
`	OP(mov,l)	TW(EDR(Free),rfree)		# Free pointer = %edi
							# Value/dynamic link
	OP(mov,l)	TW(LOF(REGBLOCK_VAL(),regs),REG(eax))
	OP(mov,l)	TW(IMM(ADDRESS_MASK),rmask)	# = %ebp

							# Swap stack segments
IFDOS(`	OP(mov,w)	TW(EDR(Scheme_Stack_Segment_Selector),REG(ss))')

	OP(mov,l)	TW(EDR(Ext_Stack_Pointer),REG(esp))
	OP(mov,l)	TW(REG(eax),REG(ecx))		# Preserve if used
	OP(and,l)	TW(rmask,REG(ecx))		# Restore potential
							#  dynamic link
	OP(mov,l)	TW(REG(ecx),LOF(REGBLOCK_DLINK(),regs))
	jmp	IJMP(REG(edx))')

ifdef(`WINNT',
`	extrn	_WinntExceptionTransferHook:near

	public	_callWinntExceptionTransferHook
_callWinntExceptionTransferHook:
	call	_WinntExceptionTransferHook
	mov	edx,eax')

define_c_label(interface_to_C)
IF387(`
	OP(cmp,l)	TW(IMM(0),EDR(i387_presence))
	je	interface_to_C_proceed
	ffree	ST(0)					# Free floating "regs"
	ffree	ST(1)
	ffree	ST(2)
	ffree	ST(3)
	ffree	ST(4)
	ffree	ST(5)
	ffree	ST(6)
	ffree	ST(7)
interface_to_C_proceed:')

	OP(mov,l)	TW(REG(edx),REG(eax))		# Set up result
	OP(pop,l)	REG(ebx)			# Restore callee-saves
	OP(pop,l)	REG(esi)			#  registers
	OP(pop,l)	REG(edi)
	leave
	ret

###	Assembly language hooks used to reduce code size.
###	There is no time advantage to using these over using
###	scheme_to_interface (or scheme_to_interface_call), but the
###	code generated by the compiler can be somewhat smaller.

define(define_jump_indirection,
`define_c_label(asm_$1)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface')
	
define(define_call_indirection,
`define_c_label(asm_$1)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface_call')
	
define_call_indirection(interrupt_procedure,1a)
define_call_indirection(interrupt_continuation,1b)
define_jump_indirection(interrupt_closure,18)
define_jump_indirection(interrupt_continuation_2,3b)

define_c_label(asm_interrupt_dlink)
	OP(mov,l)	TW(LOF(REGBLOCK_DLINK(),regs),REG(edx))
	OP(mov,b)	TW(IMM(HEX(19)),REG(al))
	jmp	scheme_to_interface_call

###
###	This saves even more instructions than primitive_apply
###	When the PC is not available.  Instead of jumping here,
###	a call instruction is used, and the longword offset to
###	the primitive object follows the call instruction.
###	This code loads the primitive object and merges with
###	apply_primitive
###

declare_alignment(2)
define_c_label(asm_short_primitive_apply)
	OP(pop,l)	REG(edx)			# offset pointer
	OP(mov,l)	TW(IND(REG(edx)),REG(ecx))	# offset
							# Primitive object
	OP(mov,l)	TW(IDX(REG(edx),REG(ecx)),REG(ecx))
							# Merge
	jmp	external_code_reference(asm_primitive_apply)

declare_alignment(2)
define_jump_indirection(primitive_apply,12)

define_jump_indirection(primitive_lexpr_apply,13)
define_jump_indirection(error,15)
define_call_indirection(link,17)
define_call_indirection(assignment_trap,1d)
define_call_indirection(reference_trap,1f)
define_call_indirection(safe_reference_trap,20)
define_call_indirection(primitive_error,36)

###	Assembly language hooks used to increase speed.

# define_jump_indirection(sc_apply,14)
# 
# define(define_apply_fixed_size,
# `define_c_label(asm_sc_apply_size_$1)
# 	OP(mov,l)	TW(IMM($1),REG(edx))
# 	OP(mov,b)	TW(IMM(HEX(14)),REG(al))
# 	jmp	scheme_to_interface')

declare_alignment(2)
define_c_label(asm_sc_apply)
	OP(mov,l)	TW(REG(ecx),REG(eax))		# Copy for type code
	OP(mov,l)	TW(REG(ecx),REG(ebx))		# Copy for address
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))	# Select type code
	OP(and,l)	TW(rmask,REG(ebx))		# Select datum
	OP(cmp,b)	TW(IMM(TC_COMPILED_ENTRY),REG(al))
	jne	asm_sc_apply_generic
	OP(movs,bl,x)	TW(BOF(-4,REG(ebx)),REG(eax))	# Extract frame size
	OP(cmp,l)	TW(REG(eax),REG(edx))		# Compare to nargs+1
	jne	asm_sc_apply_generic
	jmp	IJMP(REG(ebx))				# Invoke

define_debugging_label(asm_sc_apply_generic)
	OP(mov,l)	TW(IMM(HEX(14)),REG(eax))
	jmp	scheme_to_interface	

define(define_apply_fixed_size,
`declare_alignment(2)
define_c_label(asm_sc_apply_size_$1)
	OP(mov,l)	TW(REG(ecx),REG(eax))		# Copy for type code
	OP(mov,l)	TW(REG(ecx),REG(ebx))		# Copy for address
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))	# Select type code
	OP(and,l)	TW(rmask,REG(ebx))		# Select datum
	OP(cmp,b)	TW(IMM(TC_COMPILED_ENTRY),REG(al))
	jne	asm_sc_apply_generic_$1
	OP(cmp,b)	TW(IMM($1),BOF(-4,REG(ebx)))	# Compare frame size
	jne	asm_sc_apply_generic_$1	# to nargs+1
	jmp	IJMP(REG(ebx))

asm_sc_apply_generic_$1:
	OP(mov,l)	TW(IMM($1),REG(edx))
	OP(mov,b)	TW(IMM(HEX(14)),REG(al))
	jmp	scheme_to_interface')

define_apply_fixed_size(1)
define_apply_fixed_size(2)
define_apply_fixed_size(3)
define_apply_fixed_size(4)
define_apply_fixed_size(5)
define_apply_fixed_size(6)
define_apply_fixed_size(7)
define_apply_fixed_size(8)

###	The following code is used by generic arithmetic
###	whether the fixnum case is open-coded in line or not.
###	This takes care of fixnums and flonums so that the common
###	numeric types are much faster than the rare ones
###	(bignums, ratnums, recnums)

IF387(`declare_alignment(2)
asm_generic_flonum_result:
	OP(mov,l)	TW(IMM(eval(TAG(TC_MANIFEST_NM_VECTOR,2))),IND(rfree))
	OP(mov,l)	TW(rfree,REG(eax))
	OP(fstp,l)	DOF(4,rfree)			# fstpd
	OP(or,l)	TW(IMM(eval(TAG(TC_FLONUM,0))),REG(eax))
	OP(and,l)	TW(rmask,IND(REG(esp)))
	OP(add,l)	TW(IMM(12),rfree)
	OP(mov,l)	TW(REG(eax),LOF(REGBLOCK_VAL(),regs))
	ret

declare_alignment(2)
asm_generic_fixnum_result:
	OP(and,l)	TW(rmask,IND(REG(esp)))
	OP(or,b)	TW(IMM(TC_FIXNUM),REG(al))
	OP(ror,l)	TW(IMM(TC_LENGTH),REG(eax))
	OP(mov,l)	TW(REG(eax),LOF(REGBLOCK_VAL(),regs))
	ret

declare_alignment(2)
asm_generic_return_sharp_t:
	OP(and,l)	TW(rmask,IND(REG(esp)))
	OP(mov,l)	TW(IMM(eval(TAG(TC_TRUE,0))),LOF(REGBLOCK_VAL(),regs))
	ret

declare_alignment(2)
asm_generic_return_sharp_f:
	OP(and,l)	TW(rmask,IND(REG(esp)))
	OP(mov,l)	TW(IMM(eval(TAG(TC_FALSE,0))),LOF(REGBLOCK_VAL(),regs))
	ret')

define(define_unary_operation,
`declare_alignment(2)
define_c_label(asm_generic_$1)
	OP(pop,l)	REG(edx)
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(al))
	je	asm_generic_$1_fix
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(al))
	jne	asm_generic_$1_fail
	OP(and,l)	TW(rmask,REG(edx))
	fld1
	OP($4,l)	DOF(4,REG(edx))
	jmp	asm_generic_flonum_result

asm_generic_$1_fix:
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(eax))
	OP($3,l)	TW(IMM(eval(2 ** TC_LENGTH)),REG(eax))
	jno	asm_generic_fixnum_result

asm_generic_$1_fail:
	OP(push,l)	REG(edx)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface')

define(define_unary_predicate,
`declare_alignment(2)
define_c_label(asm_generic_$1)
	OP(pop,l)	REG(edx)
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(al))
	je	asm_generic_$1_fix
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(al))
	jne	asm_generic_$1_fail
	OP(and,l)	TW(rmask,REG(edx))
	OP(fld,l)	DOF(4,REG(edx))
	ftst
	fstsw	REG(ax)
	fstp	ST(0)
	sahf
	$4	asm_generic_return_sharp_t
	jmp	asm_generic_return_sharp_f

asm_generic_$1_fix:
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(eax))
	OP(cmp,l)	TW(IMM(0),REG(eax))
	$3	asm_generic_return_sharp_t
	jmp	asm_generic_return_sharp_f

asm_generic_$1_fail:
	OP(push,l)	REG(edx)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface')

define(define_binary_operation,
`declare_alignment(2)
define_c_label(asm_generic_$1)
	OP(pop,l)	REG(edx)
	OP(pop,l)	REG(ebx)
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(ecx))
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(al))
	je	asm_generic_$1_fix
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(al))
	jne	asm_generic_$1_fail
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	je	asm_generic_$1_flo_flo
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(cl))
	jne	asm_generic_$1_fail
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ebx))
	OP(and,l)	TW(rmask,REG(edx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(ebx))
	OP(fld,l)	DOF(4,REG(edx))			# fldd
	OP(mov,l)	TW(REG(ebx),IND(rfree))
	OP($5,l)	IND(rfree)				# fisubl
	jmp	asm_generic_flonum_result

asm_generic_$1_fix:
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	je	asm_generic_$1_fix_flo
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(cl))
	jne	asm_generic_$1_fail
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(eax))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ecx))
	OP($3,l)	TW(REG(ecx),REG(eax))		# subl
	jno	asm_generic_fixnum_result

asm_generic_$1_fail:
	OP(push,l)	REG(ebx)
	OP(push,l)	REG(edx)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface

asm_generic_$1_flo_flo:
	OP(and,l)	TW(rmask,REG(edx))
	OP(and,l)	TW(rmask,REG(ebx))
	OP(fld,l)	DOF(4,REG(edx))			# fldd
	OP($6,l)	DOF(4,REG(ebx))			# fsubl
	jmp	asm_generic_flonum_result	

asm_generic_$1_fix_flo:
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(edx))
	OP(and,l)	TW(rmask,REG(ebx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(edx))
	OP(fld,l)	DOF(4,REG(ebx))			# fldd
	OP(mov,l)	TW(REG(edx),IND(rfree))
	OP($4,l)	IND(rfree)			# fisubrl
	jmp	asm_generic_flonum_result')

IF387(`declare_alignment(2)
define_c_label(asm_generic_divide)
	OP(pop,l)	REG(edx)
	OP(pop,l)	REG(ebx)
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(ecx))
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(al))
	je	asm_generic_divide_fix
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(al))
	jne	asm_generic_divide_fail
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	je	asm_generic_divide_flo_flo
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(cl))
	jne	asm_generic_divide_fail
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ecx))
	je	asm_generic_divide_fail
	OP(and,l)	TW(rmask,REG(edx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(ecx))
	OP(fld,l)	DOF(4,REG(edx))			# fldd
	OP(mov,l)	TW(REG(ecx),IND(rfree))
	OP(fidiv,l)	IND(rfree)
	jmp	asm_generic_flonum_result

asm_generic_divide_fix:
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	jne	asm_generic_divide_fail
	OP(mov,l)	TW(REG(edx),REG(ecx))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ecx))
	je	asm_generic_divide_fail
	OP(and,l)	TW(rmask,REG(ebx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(ecx))
	OP(fld,l)	DOF(4,REG(ebx))			# fldd
	OP(mov,l)	TW(REG(ecx),IND(rfree))
	OP(fidivr,l)	IND(rfree)
	jmp	asm_generic_flonum_result

asm_generic_divide_flo_flo:
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(and,l)	TW(rmask,REG(ecx))
	OP(fld,l)	DOF(4,REG(ecx))			# fldd
	ftst
	fstsw	REG(ax)
	sahf
	je	asm_generic_divide_by_zero
	OP(and,l)	TW(rmask,REG(edx))
	OP(fdivr,l)	DOF(4,REG(edx))
	jmp	asm_generic_flonum_result	

asm_generic_divide_by_zero:
	fstp	ST(0)					# Pop second arg

asm_generic_divide_fail:
	OP(push,l)	REG(ebx)
	OP(push,l)	REG(edx)
	OP(mov,b)	TW(IMM(HEX(23)),REG(al))
	jmp	scheme_to_interface')

define(define_binary_predicate,
`declare_alignment(2)
define_c_label(asm_generic_$1)
	OP(pop,l)	REG(edx)
	OP(pop,l)	REG(ebx)
	OP(mov,l)	TW(REG(edx),REG(eax))
	OP(mov,l)	TW(REG(ebx),REG(ecx))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(eax))
	OP(shr,l)	TW(IMM(DATUM_LENGTH),REG(ecx))
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(al))
	je	asm_generic_$1_fix
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(al))
	jne	asm_generic_$1_fail
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	je	asm_generic_$1_flo_flo
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(cl))
	jne	asm_generic_$1_fail
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ebx))
	OP(and,l)	TW(rmask,REG(edx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(ebx))
	OP(fld,l)	DOF(4,REG(edx))			# fldd
	OP(mov,l)	TW(REG(ebx),IND(rfree))
	OP(ficomp,l)	IND(rfree)
	fstsw	REG(ax)
	sahf
	$5	asm_generic_return_sharp_t
	jmp	asm_generic_return_sharp_f

asm_generic_$1_fix:
	OP(cmp,b)	TW(IMM(TC_FLONUM),REG(cl))
	je	asm_generic_$1_fix_flo
	OP(cmp,b)	TW(IMM(TC_FIXNUM),REG(cl))
	jne	asm_generic_$1_fail
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(edx))
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(ebx))
	OP(cmp,l)	TW(REG(ebx),REG(edx))
	$3	asm_generic_return_sharp_t	
	jmp	asm_generic_return_sharp_f

asm_generic_$1_flo_flo:
	OP(and,l)	TW(rmask,REG(edx))
	OP(and,l)	TW(rmask,REG(ebx))
	OP(fld,l)	DOF(4,REG(edx))			# fldd
	OP(fcomp,l)	DOF(4,REG(ebx))
	fstsw	REG(ax)
	sahf
	$6	asm_generic_return_sharp_t
	jmp	asm_generic_return_sharp_f

asm_generic_$1_fix_flo:
	OP(shl,l)	TW(IMM(TC_LENGTH),REG(edx))
	OP(and,l)	TW(rmask,REG(ebx))
	OP(sar,l)	TW(IMM(TC_LENGTH),REG(edx))
	OP(mov,l)	TW(REG(edx),IND(rfree))
	OP(fild,l)	IND(rfree)
	OP(fcomp,l)	DOF(4,REG(ebx))
	fstsw	REG(ax)
	sahf
	$4	asm_generic_return_sharp_t
	jmp	asm_generic_return_sharp_f

asm_generic_$1_fail:
	OP(push,l)	REG(ebx)
	OP(push,l)	REG(edx)
	OP(mov,b)	TW(IMM(HEX($2)),REG(al))
	jmp	scheme_to_interface')

IF387(`define_unary_operation(decrement,22,sub,fsubr)
define_unary_operation(increment,26,add,fadd)

define_unary_predicate(negative,2a,jl,jb)
define_unary_predicate(positive,2c,jg,ja)
define_unary_predicate(zero,2d,je,je)

# define_binary_operation(name,index,fix*fix,fix*flo,flo*fix,flo*flo)
# define_binary_operation(  $1,   $2,     $3,     $4,     $5,     $6)
define_binary_operation(add,2b,add,fiadd,fiadd,fadd)
define_binary_operation(subtract,28,sub,fisubr,fisub,fsub)
define_binary_operation(multiply,29,imul,fimul,fimul,fmul)
# Divide needs to check for 0, so we cant really use the following
# define_binary_operation(divide,23,NONE,fidivr,fidiv,fdiv)

# define_binary_predicate(name,index,fix*fix,fix*flo,flo*fix,flo*flo)
define_binary_predicate(equal,24,je,je,je,je)
define_binary_predicate(greater,25,jg,ja,ja,ja)
define_binary_predicate(less,27,jl,jb,jb,jb)')

IFN387(`define_jump_indirection(generic_decrement,22)
define_jump_indirection(generic_divide,23)
define_jump_indirection(generic_equal,24)
define_jump_indirection(generic_greater,25)
define_jump_indirection(generic_increment,26)
define_jump_indirection(generic_less,27)
define_jump_indirection(generic_subtract,28)
define_jump_indirection(generic_multiply,29)
define_jump_indirection(generic_negative,2a)
define_jump_indirection(generic_add,2b)
define_jump_indirection(generic_positive,2c)
define_jump_indirection(generic_zero,2d)')

# These don't currently differ according to whether there
# is a 387 or not.

define_jump_indirection(generic_quotient,37)
define_jump_indirection(generic_remainder,38)
define_jump_indirection(generic_modulo,39)

define_jump_indirection(nofp_decrement,22)
define_jump_indirection(nofp_divide,23)
define_jump_indirection(nofp_equal,24)
define_jump_indirection(nofp_greater,25)
define_jump_indirection(nofp_increment,26)
define_jump_indirection(nofp_less,27)
define_jump_indirection(nofp_subtract,28)
define_jump_indirection(nofp_multiply,29)
define_jump_indirection(nofp_negative,2a)
define_jump_indirection(nofp_add,2b)
define_jump_indirection(nofp_positive,2c)
define_jump_indirection(nofp_zero,2d)
define_jump_indirection(nofp_quotient,37)
define_jump_indirection(nofp_remainder,38)
define_jump_indirection(nofp_modulo,39)

IFDOS(`end')

### Edwin Variables:
### comment-column: 56
### End:
