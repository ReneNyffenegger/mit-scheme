/* -*- C -*-

$Id: alpha.h,v 1.1 1992/08/29 12:13:47 jinx Exp $

Copyright (c) 1992 Digital Equipment Corporation (D.E.C.)

This software was developed at the Digital Equipment Corporation
Cambridge Research Laboratory.  Permission to copy this software, to
redistribute it, and to use it for any purpose is granted, subject to
the following restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to both the Digital Equipment Corporation Cambridge Research
Lab (CRL) and the MIT Scheme project any improvements or extensions
that they make, so that these may be included in future releases; and
(b) to inform CRL and MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. D.E.C. has made no warrantee or representation that the operation
of this software will be error-free, and D.E.C. is under no obligation
to provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Digital Equipment Corporation
nor of any adaptation thereof in any advertising, promotional, or
sales literature without prior written consent from D.E.C. in each
case. */

/*
 *
 * Compiled code interface macros.
 *
 * See cmpint.txt for a description of these fields.
 *
 * Specialized for the Alpha
 */

#ifndef CMPINT2_H_INCLUDED
#define CMPINT2_H_INCLUDED

#define COMPILER_NONE_TYPE			0
#define COMPILER_MC68020_TYPE			1
#define COMPILER_VAX_TYPE			2
#define COMPILER_SPECTRUM_TYPE			3
#define COMPILER_OLD_MIPS_TYPE			4
#define COMPILER_MC68040_TYPE			5
#define COMPILER_SPARC_TYPE			6
#define COMPILER_RS6000_TYPE			7
#define COMPILER_MC88K_TYPE			8
#define COMPILER_I386_TYPE			9
#define COMPILER_ALPHA_TYPE			10
#define COMPILER_MIPS_TYPE			11

/* Machine parameters to be set by the user. */

/* Processor type.  Choose a number from the above list, or allocate your own.
 */

#define COMPILER_PROCESSOR_TYPE			COMPILER_ALPHA_TYPE

/* Size (in long words) of the contents of a floating point register if
   different from a double.  For example, an MC68881 saves registers
   in 96 bit (3 longword) blocks.
   #define COMPILER_TEMP_SIZE			1
*/

/* Descriptor size.
   This is the size of the offset field, and of the format field.
   This definition probably does not need to be changed.
 */

typedef unsigned short format_word; /* 16 bits */

/* PC alignment constraint.
   Change PC_ZERO_BITS to be how many low order bits of the pc are
   guaranteed to be 0 always because of PC alignment constraints.
*/

#define PC_ZERO_BITS                    2

/* Utilities for manipulating absolute subroutine calls.
   On the ALPHA this is done with either
   	BR rtarget, displacement
        <absolute address of destination>
                   or
        JMP rtarget, closure_hook
        <absolute address of destination>
   The latter form is installed by the out-of-line code that allocates
   and initializes closures and execute caches.  The former is
   generated by the GC when the closure is close enough to the
   destination address to fit in a branch displacement (4 megabytes).

   Why does EXTRACT_ABSOLUTE_ADDRESS store into the execute cache or
   closure?  Because the GC (which calls it) assumes that if the
   destination is in constant space there will be no need to modify the
   cell, since the destination won't move.  Since the Alpha uses
   PC-relative addressing, though, the cell needs to be updated if the
   cell has moved even if the destination hasn't.
 */

#define EXTRACT_ABSOLUTE_ADDRESS(target, address)			\
  (target) = (* ((SCHEME_OBJECT *) (((int *) address) + 1)));		\
  /* The +1 skips over the instruction to the absolute address  */	\
  alpha_store_absolute_address(((void *) target), ((void *) address))


#define STORE_ABSOLUTE_ADDRESS(entry_point, address)	\
  alpha_store_absolute_address (((void *) entry_point), ((void *) address))

extern void EXFUN(alpha_store_absolute_address, (void *, void *));

#define opJMP			0x1A
#define fnJMP			0x00
#define JMP(linkage, dest, displacement)	\
  ((opJMP << 26) | ((linkage) << 21) |		\
   ((dest) << 16) | (fnJMP << 14) |		\
   (((displacement)>>PC_ZERO_BITS) & ((1<<14)-1)))

/* Compiled Code Register Conventions */
/* This must match the compiler and cmpaux-alpha.m4 */

#define COMP_REG_UTILITY_CODE		1
#define COMP_REG_TRAMP_INDEX		COMP_REG_UTILITY_CODE
#define COMP_REG_STACK_POINTER		2
#define COMP_REG_MEMTOP			3
#define COMP_REG_FREE			4
#define COMP_REG_REGISTERS		9
#define COMP_REG_SCHEME_INTERFACE	10
#define COMP_REG_CLOSURE_HOOK		11
#define COMP_REG_LONGJUMP		COMP_REG_CLOSURE_HOOK
#define COMP_REG_FIRST_ARGUMENT		17
#define COMP_REG_LINKAGE		26
#define COMP_REG_TEMPORARY		28
#define COMP_REG_ZERO			31

#ifdef IN_CMPINT_C
#define PC_FIELD_SIZE		21
#define MAX_PC_DISPLACEMENT	(1<<(PC_FIELD_SIZE+PC_ZERO_BITS-1))
#define MIN_PC_DISPLACEMENT	(-MAX_PC_DISPLACEMENT)
#define opBR			0x30

void
DEFUN (alpha_store_absolute_address, (entry_point, address),
       void *entry_point AND void *address)
{
  extern void scheme_closure_hook (void);
  int *Instruction_Address = (int *) address;
  SCHEME_OBJECT *Addr = (SCHEME_OBJECT *) (Instruction_Address + 1);
  SCHEME_OBJECT *Entry_Point = (SCHEME_OBJECT *) entry_point;
  long offset = ((char *) Entry_Point) - ((char *) Addr);
  *Addr = (SCHEME_OBJECT) Entry_Point;
  if ((offset < MAX_PC_DISPLACEMENT) &&
      (offset >= MIN_PC_DISPLACEMENT))
    *Instruction_Address =
      (opBR << 26) | (COMP_REG_LINKAGE << 21) |
      ((offset>>PC_ZERO_BITS)  & ((1L<<PC_FIELD_SIZE)-1));
  else
    *Instruction_Address =
      JMP(COMP_REG_LINKAGE, COMP_REG_LONGJUMP,
	  (((char *) scheme_closure_hook) - ((char *) Addr)));
  return;
}
#endif

/* Interrupt/GC polling. */

/* Procedure entry points look like:

		CONTINUATIONS AND ORDINARY PROCEDURES

   GC_Handler: <code sequence 1> -- call interrupt handler
               <entry descriptor> (32 bits)
   label:      <code sequence 2> -- test for interrupts
               <code for procedure>
   Interrupt:  BR GC_Handler     -- to help branch predictor in
                                    code sequences 2

   It is a good idea to align the GC_Handler (hence the label) so that
   we dual issue nicely.

Code sequence 1 (call interrupt handler):
   LDA   UTILITY_CODE,#code(ZERO)
   JMP   LINKAGE,(SCHEME-TO-INTERFACE-JSR)

Code sequence 2 (test for interrupts):
   CMPLT FREE,MEMTOP,temp
   LDQ	 MEMTOP, 0(BLOCK)
   BEQ   temp,Interrupt

			       CLOSURES

              <entry descriptor> (32 bits)
   label:     <code sequence 3> -- test for interrupts
   merge:     <code for procedure>
   Internal-Label:
              <code sequence 4> -- test for interrupts, and
                                   branch to merge: if none
   Interrupt: <code sequence 5> -- call interrupt handler
                                   to help branch predictor in
                                   code sequence 3

Code sequence 3 (test for interrupts):
   ...SUBQ SP,#8,SP              -- in closure object before entry
   SUBQ  LINKAGE,#8,temp         -- bump ret. addr. back to entry point
   CMPLT FREE,MEMTOP,temp2       -- interrupt/gc check
   LDQ   MEMTOP,0(BLOCK)         -- Fill MemTop register
   BIS   CC_ENTRY_TYPE,temp,temp -- put tag on closure object
   STQ   temp,0(SP)              -- save closure on top of stack
   BEQ   temp2,Interrupt         -- possible interrupt ...  

Code sequence 4 (test for interrupts):
  *Note*: In most machines code sequence 3 and 4 are the same and are
  shared. We've carefully optimized sequence 3 for dual issue, so it
  differs from sequence 4.  Time over space ...
   CMPLT FREE,MEMTOP,temp        -- interrupt/gc check
   LDQ   MEMTOP,0(BLOCK)         -- Fill MemTop register
   BNE   temp,Merge              -- branch back if no interrupt

Code sequence 5 (call interrupt handler):
   LDA   UTILITY_CODE,#code(ZERO)
   JMP   LINKAGE,(SCHEME-TO-INTERFACE)

*/

#define INSTRUCTIONS			*4 /* bytes/instruction */

/* The length of code sequence 1, above */
#define ENTRY_PREFIX_LENGTH		(2 INSTRUCTIONS)
/* Skip over this many BYTES to bypass the GC check code (ordinary
   procedures and continuations differ from closures) */
#define ENTRY_SKIPPED_CHECK_OFFSET 	(3 INSTRUCTIONS) /* Code Seq 2 */
#define CLOSURE_SKIPPED_CHECK_OFFSET 	(6 INSTRUCTIONS) /* Code Seq 3 */

/* Compiled closures */

/* On the Alpha (byte offsets from start of closure):

     -16: TC_MANIFEST_CLOSURE || length of object
     -8 : count of entry points
     -4 : Format word and GC offset
      0 : SUBQ SP,#8,SP
     +4 : BR or JMP instruction
     +8 : absolute target address
     +16: more entry points (i.e. repetitions from -8 through +8)
          and/or closed variables
     ...

  Note: On other machines, there is a different format used for one
  entry point closures and closures with more than one entry point.
  This is not needed on the Alpha, because we have a "wasted" 32 bit
  pad area in all closures.
*/

#define CLOSURE_OFFSET_OF_FIRST_ENTRY_POINT	16
/* Bytes from manifest header to SUBQ in first entry point code */

/* A NOP on machines where closure entry points are aligned at object */
/* boundaries, as on the Alpha.                                       */

#define ADJUST_CLOSURE_AT_CALL(entry_point, location)			\
do {									\
   } while (0)

/* Manifest closure entry block size.
   Size in bytes of a compiled closure's header excluding the
   TC_MANIFEST_CLOSURE header.

   On the Alpha this is 32 bits (one instruction) of padding, 16 bits
   of format_word, 16 bits of GC offset word, 2 32-bit instructions
   (SUBQ and JMP or BR), and a 64-bit absolute address.
 */

#define COMPILED_CLOSURE_ENTRY_SIZE     \
  ((1 INSTRUCTIONS) + (2*(sizeof(format_word)) + 		\
   (2 INSTRUCTIONS) + (sizeof(SCHEME_OBJECT *))))

/* Override the default definition of MANIFEST_CLOSURE_END in cmpgc.h */

#define MANIFEST_CLOSURE_END(start, count)				\
(((SCHEME_OBJECT *) (start)) +						\
 ((CHAR_TO_SCHEME_OBJECT (((count) * COMPILED_CLOSURE_ENTRY_SIZE)))-1))

/* Manifest closure entry destructuring.

   Given the entry point of a closure, extract the `real entry point'
   (the address of the real code of the procedure, ie. one indirection)
   from the closure.
*/

#define EXTRACT_CLOSURE_ENTRY_ADDRESS(returned_address, entry_point)	\
{ EXTRACT_ABSOLUTE_ADDRESS (returned_address,				\
			    (((unsigned int *) entry_point) + 1));	\
}

/* This is the inverse of EXTRACT_CLOSURE_ENTRY_ADDRESS.
   Given a closure's entry point and a code entry point, store the
   code entry point in the closure.
 */

#define STORE_CLOSURE_ENTRY_ADDRESS(address_to_store, entry_point)	\
{ STORE_ABSOLUTE_ADDRESS (address_to_store,				\
			  (((unsigned int *) entry_point) + 1));	\
}

/* Trampolines

   On the Alpha, here's a picture of a trampoline (offset in bytes
   from entry point)

     -24: MANIFEST vector header
     -16: NON_MARKED header
     - 8: 0
     - 4: Format word
     - 2: 0xC (GC Offset to start of block from .+2)
          Note the encoding -- divided by 2, low bit for
          extended distances (see OFFSET_WORD_TO_BYTE_OFFSET)
       0: BIS ZERO, #index, TRAMP_INDEX
       4: JMP Utility_Argument_1, (SCHEME_TO_INTERFACE)
       8: trampoline dependent storage (0 - 3 objects)

   TRAMPOLINE_ENTRY_SIZE is the size in longwords of the machine
   dependent portion of a trampoline, including the GC and format
   headers.  The code in the trampoline must store an index (used to
   determine which C SCHEME_UTILITY procedure to invoke) in a
   register, jump to "scheme_to_interface" and leave the address of
   the storage following the code in a standard location.

   TRAMPOLINE_ENTRY_POINT takes the address of the manifest vector
   header of a trampoline and returns the address of its first
   instruction.

   TRAMPOLINE_STORAGE takes the address of the first instruction in a
   trampoline (not the start of the trampoline block) and returns the
   address of the first storage word in the trampoline.

   STORE_TRAMPOLINE_ENTRY gets the address of the first instruction in
   the trampoline and stores the instructions.  It also receives the
   index of the C SCHEME_UTILITY to be invoked.
*/

#define TRAMPOLINE_ENTRY_SIZE		2
#define TRAMPOLINE_ENTRY_POINT(tramp)	\
  ((void *) (((SCHEME_OBJECT *) (tramp)) + 3))
#define TRAMPOLINE_STORAGE(tramp_entry)	\
  ((SCHEME_OBJECT *) (((char *) (tramp_entry)) + (2 INSTRUCTIONS)))

#define opBIS				0x11
#define opSUBQ				0x10
#define funcBIS				0x20
#define funcSUBQ			0x29

#define constantBIS(source, constant, target)	\
  ((opBIS << 26) | ((source) << 21) | 		\
   ((constant) << 13) | (1 << 12) | (funcBIS << 5) | (target))

#define constantSUBQ(source, constant, target)	\
  ((opSUBQ << 26) | ((source) << 21) | 		\
   ((constant) << 13) | (1 << 12) | (funcSUBQ << 5) | (target))

#define STORE_TRAMPOLINE_ENTRY(entry_address, index)	\
{ unsigned int *PC;					\
  extern void scheme_to_interface(void);		\
  PC = ((unsigned int *) (entry_address));		\
  *PC++ = constantBIS(COMP_REG_ZERO, index, COMP_REG_TRAMP_INDEX);\
  *PC = JMP(COMP_REG_FIRST_ARGUMENT,			\
	    COMP_REG_SCHEME_INTERFACE,			\
	    (((char *) scheme_to_interface) -		\
	     ((char *) (PC+1))));			\
  PC += 1;						\
}

/* Execute cache entries.

   Execute cache entry size in longwords.  The cache itself
   contains both the number of arguments provided by the caller and
   code to jump to the destination address.  Before linkage, the cache
   contains the callee's name instead of the jump code.

   On Alpha: 2 machine words (64 bits each).
 */

#define EXECUTE_CACHE_ENTRY_SIZE        2

/* Execute cache destructuring. */

/* Given a target location and the address of the first word of an
   execute cache entry, extract from the cache cell the number of
   arguments supplied by the caller and store it in target. */

/* For the Alpha, addresses in bytes from the start of the cache:

   Before linking
     +0:  number of supplied arguments, +1
     +4:  TC_FIXNUM | 0
     +8:  TC_SYMBOL || symbol address

   After linking
     +0: number of supplied arguments, +1
     +4: BR or JMP instruction
     +8: absolute target address
*/

#define EXTRACT_EXECUTE_CACHE_ARITY(target, address)			\
  (target) = ((long) (((unsigned int *) (address)) [0]))

#define EXTRACT_EXECUTE_CACHE_SYMBOL(target, address)			\
  (target) = ((SCHEME_OBJECT *) (address))[1]

/* Extract the target address (not the code to get there) from an
   execute cache cell.
 */

#define EXTRACT_EXECUTE_CACHE_ADDRESS(target, address)			\
{									\
  EXTRACT_ABSOLUTE_ADDRESS (target, (((unsigned int *)address)+1));	\
}

/* This is the inverse of EXTRACT_EXECUTE_CACHE_ADDRESS.
 */

#define STORE_EXECUTE_CACHE_ADDRESS(address, entry)			\
{									\
  STORE_ABSOLUTE_ADDRESS (entry, (((unsigned int *)address)+1));	\
}

/* This stores the fixed part of the instructions leaving the
   destination address and the number of arguments intact.  These are
   split apart so the GC can call EXTRACT/STORE...ADDRESS but it does
   NOT need to store the instructions back.  On this architecture the
   instructions may change due to GC and thus STORE_EXECUTE_CACHE_CODE
   is a no-op; all of the work is done by STORE_EXECUTE_CACHE_ADDRESS
   instead.
 */

#define STORE_EXECUTE_CACHE_CODE(address)	{ }

/* This flushes the Scheme portion of the I-cache.
   It is used after a GC or disk-restore.
   It's needed because the GC has moved code around, and closures
   and execute cache cells have absolute addresses that the
   processor might have old copies of.
 */

extern long EXFUN(Synchronize_Caches, (void));
extern void EXFUN(Flush_I_Cache, (void));

#if 1
#define FLUSH_I_CACHE() 		((void) Synchronize_Caches())
#else
#define	FLUSH_I_CACHE()			(Flush_I_Cache())
#endif

/* This flushes a region of the I-cache.
   It is used after updating an execute cache while running.
   Not needed during GC because FLUSH_I_CACHE will be used.
 */   

#define FLUSH_I_CACHE_REGION(address, nwords) FLUSH_I_CACHE()
#define PUSH_D_CACHE_REGION(address, nwords) FLUSH_I_CACHE()
#define SPLIT_CACHES

#ifdef IN_CMPINT_C
#include <sys/mman.h>
#include <sys/types.h>

#define VM_PROT_SCHEME (PROT_READ | PROT_WRITE | PROT_EXEC)

#define ASM_RESET_HOOK() interface_initialize((PTR) &utility_table[0])

#define REGBLOCK_EXTRA_SIZE		8 /* See lapgen.scm */
#define COMPILER_REGBLOCK_N_FIXED	16
#define REGBLOCK_FIRST_EXTRA			COMPILER_REGBLOCK_N_FIXED
#define REGBLOCK_ADDRESS_OF_STACK_POINTER	REGBLOCK_FIRST_EXTRA
#define REGBLOCK_ADDRESS_OF_FREE		REGBLOCK_FIRST_EXTRA+1
#define REGBLOCK_ADDRESS_OF_UTILITY_TABLE	REGBLOCK_FIRST_EXTRA+2
#define REGBLOCK_ALLOCATE_CLOSURE		REGBLOCK_FIRST_EXTRA+3
#define REGBLOCK_DIVQ				REGBLOCK_FIRST_EXTRA+4
#define REGBLOCK_REMQ				REGBLOCK_FIRST_EXTRA+5

void *
DEFUN (alpha_heap_malloc, (Size), long Size)
{ int pagesize;
  caddr_t Heap_Start_Page;
  void *Area;

  pagesize = getpagesize();
  Area = (void *) malloc(Size+pagesize);
  if (Area==NULL) return Area;
  Heap_Start_Page =
    ((caddr_t) (((((long) Area)+(pagesize-1)) /
		 pagesize) *
		pagesize));
  if (mprotect (Heap_Start_Page, Size, VM_PROT_SCHEME) == -1)
  { perror("compiler_reset: unable to change protection for Heap");
    fprintf(stderr, "mprotect(0x%lx, %d (0x%lx), 0x%lx)\n",
	    Heap_Start_Page, Size, Size, VM_PROT_SCHEME);
    Microcode_Termination (TERM_EXIT);
    /*NOTREACHED*/
  }
  return (void *) Heap_Start_Page;
}

/* ASSUMPTION: Direct mapped first level cache, with 
   shared secondary caches.  Sizes in bytes.
*/
#define DCACHE_SIZE		(8*1024)
#define DCACHE_LINE_SIZE	32
#define WRITE_BUFFER_SIZE	(4*DCACHE_LINE_SIZE)

long
DEFUN_VOID (Synchronize_Caches)
{ long Foo=0;

  Flush_I_Cache();
  { static volatile long Fake_Out[WRITE_BUFFER_SIZE/(sizeof (long))];
    volatile long *Ptr, *End, i=0;
    
    for (End = &(Fake_Out[WRITE_BUFFER_SIZE/(sizeof (long))]),
	   Ptr = &(Fake_Out[0]);
	 Ptr < End;
	 Ptr += DCACHE_LINE_SIZE/(sizeof (long)))
    { Foo += *Ptr;
      *Ptr = Foo;
      i += 1;
    }
  }
#if 0
  { static volatile long Fake_Out[DCACHE_SIZE/(sizeof (long))];
    volatile long *Ptr, *End;
    
    for (End = &(Fake_Out[DCACHE_SIZE/(sizeof (long))]),
	   Ptr = &(Fake_Out[0]);
	 Ptr < End;
	 Ptr += DCACHE_LINE_SIZE/(sizeof (long)))
      Foo += *Ptr;
  }
#endif
    return Foo;
}

extern char *EXFUN(allocate_closure, (long, char *));

static void
DEFUN (interface_initialize, (table),
       PTR table)
{ extern void __divq();
  extern void __remq();

  Registers[REGBLOCK_ADDRESS_OF_STACK_POINTER] =
    ((SCHEME_OBJECT) &Ext_Stack_Pointer);
  Registers[REGBLOCK_ADDRESS_OF_FREE] =
    ((SCHEME_OBJECT) &Free);
  Registers[REGBLOCK_ADDRESS_OF_UTILITY_TABLE] =
    ((SCHEME_OBJECT) table);
  Registers[REGBLOCK_ALLOCATE_CLOSURE] =
    ((SCHEME_OBJECT) allocate_closure);
  Registers[REGBLOCK_DIVQ] = ((SCHEME_OBJECT) __divq);
  Registers[REGBLOCK_REMQ] = ((SCHEME_OBJECT) __remq);
  return;
}

#define CLOSURE_ENTRY_WORDS			\
  (COMPILED_CLOSURE_ENTRY_SIZE / (sizeof (SCHEME_OBJECT)))

static long closure_chunk = (1024 * CLOSURE_ENTRY_WORDS);
static long last_chunk_size;

#define REGBLOCK_CLOSURE_LIMIT	REGBLOCK_CLOSURE_SPACE

char *
DEFUN (allocate_closure, (size, this_block),
       long size AND char *this_block)
/* size in Scheme objects of the block we need to allocate.
   this_block is a pointer to the first entry point in the block we
              didn't manage to allocate.
*/
{ long space;
  SCHEME_OBJECT *free_closure, *limit;

  free_closure = (SCHEME_OBJECT *)
    (this_block-CLOSURE_OFFSET_OF_FIRST_ENTRY_POINT);
  limit = ((SCHEME_OBJECT *) Registers[REGBLOCK_CLOSURE_LIMIT]);
  space =  limit - free_closure;
  if (size > space)
  { SCHEME_OBJECT *ptr;
    unsigned int *wptr;
    /* Clear remaining words from last chunk so that the heap can be scanned
       forward.
     */
    if (space > 0)
    { for (ptr = free_closure; ptr < limit; ptr++) *ptr = SHARP_F;
      /* We can reformat the closures (from JMPs to BRs) using
	 last_chunk_size.  The start of the area is
	 (limit - last_chunk_size), and all closures are contiguous
	 and have appropriate headers.
      */
    }
    free_closure = Free;
    if ((size <= closure_chunk) && (!(GC_Check (closure_chunk))))
    { limit = (free_closure + closure_chunk);
    }
    else
    { if (GC_Check (size))
      { if ((Heap_Top - Free) < size)
	{ /* No way to back out -- die. */
	  fprintf (stderr, "\nC_allocate_closure (%d): No space.\n", size);
	  Microcode_Termination (TERM_NO_SPACE);
	  /* NOTREACHED */
	}
	Request_GC (0);
      }
      else if (size <= closure_chunk)
      { Request_GC (0);
      }
      limit = (free_closure + size);
    }
    Free = limit;
    last_chunk_size = limit-free_closure; /* For next time, maybe. */
    for (wptr = (unsigned int *) free_closure;
	 wptr < (unsigned int *) limit;)
    { extern void scheme_closure_hook (void);
      *wptr++ = constantSUBQ (COMP_REG_STACK_POINTER,
			      8,
			      COMP_REG_STACK_POINTER);
      *wptr = JMP(COMP_REG_LINKAGE, COMP_REG_LONGJUMP,
		  (((char *) scheme_closure_hook) -
		   ((char *) (wptr + 1))));
      wptr += 1;
    }
    PUSH_D_CACHE_REGION (free_closure, last_chunk_size);
    Registers[REGBLOCK_CLOSURE_LIMIT] = (SCHEME_OBJECT) limit;
  }
  Registers[REGBLOCK_CLOSURE_FREE] = (SCHEME_OBJECT) (free_closure+size);
  return (((char *) free_closure)+CLOSURE_OFFSET_OF_FIRST_ENTRY_POINT);
}
#endif /* IN_CMPINT_C */

/* Derived parameters and macros.

   These macros expect the above definitions to be meaningful.
   If they are not, the macros below may have to be changed as well.
 */

#define COMPILED_ENTRY_OFFSET_WORD(entry) (((format_word *) (entry)) [-1])
#define COMPILED_ENTRY_FORMAT_WORD(entry) (((format_word *) (entry)) [-2])

/* The next one assumes 2's complement integers....*/
#define CLEAR_LOW_BIT(word)                     ((word) & ((unsigned long) -2))
#define OFFSET_WORD_CONTINUATION_P(word)        (((word) & 1) != 0)

#if (PC_ZERO_BITS == 0)
/* Instructions aligned on byte boundaries */
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      ((offset) << 1)
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  ((CLEAR_LOW_BIT(offset_word)) >> 1)
#endif

#if (PC_ZERO_BITS == 1)
/* Instructions aligned on word (16 bit) boundaries */
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      (offset)
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  (CLEAR_LOW_BIT(offset_word))
#endif

#if (PC_ZERO_BITS >= 2)
/* Should be OK for =2, but bets are off for >2 because of problems
   mentioned earlier!
*/
#define SHIFT_AMOUNT                            (PC_ZERO_BITS - 1)
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      ((offset) >> (SHIFT_AMOUNT))
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  ((CLEAR_LOW_BIT(offset_word)) << (SHIFT_AMOUNT))
#endif

#define MAKE_OFFSET_WORD(entry, block, continue)                        \
  ((BYTE_OFFSET_TO_OFFSET_WORD(((char *) (entry)) -                     \
                               ((char *) (block)))) |                   \
   ((continue) ? 1 : 0))

#if (EXECUTE_CACHE_ENTRY_SIZE == 2)
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) >> 1)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) << 1)
#endif

#if (EXECUTE_CACHE_ENTRY_SIZE == 4)
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) >> 2)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) << 2)
#endif

#if (!defined(EXECUTE_CACHE_COUNT_TO_ENTRIES))
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) / EXECUTE_CACHE_ENTRY_SIZE)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) * EXECUTE_CACHE_ENTRY_SIZE)
#endif

/* The first entry in a cc block is preceeded by 2 headers (block and nmv),
   a format word and a gc offset word.   See the early part of the
   TRAMPOLINE picture, above.
 */

#define CC_BLOCK_FIRST_ENTRY_OFFSET                                     \
  (2 * ((sizeof(SCHEME_OBJECT)) + (sizeof(format_word))))

/* Format words */

#define FORMAT_BYTE_EXPR                0xFF
#define FORMAT_BYTE_COMPLR              0xFE
#define FORMAT_BYTE_CMPINT              0xFD
#define FORMAT_BYTE_DLINK               0xFC
#define FORMAT_BYTE_RETURN              0xFB

#define FORMAT_WORD_EXPR        (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_EXPR))
#define FORMAT_WORD_CMPINT      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_CMPINT))
#define FORMAT_WORD_RETURN      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_RETURN))

/* This assumes that a format word is at least 16 bits,
   and the low order field is always 8 bits.
 */

#define MAKE_FORMAT_WORD(field1, field2)                                \
  (((field1) << 8) | ((field2) & 0xff))

#define SIGN_EXTEND_FIELD(field, size)                                  \
  (((field) & ((1 << (size)) - 1)) |                                    \
   ((((field) & (1 << ((size) - 1))) == 0) ? 0 :                        \
    ((-1) << (size))))

#define FORMAT_WORD_LOW_BYTE(word)                                      \
  (SIGN_EXTEND_FIELD ((((unsigned long) (word)) & 0xff), 8))

#define FORMAT_WORD_HIGH_BYTE(word)					\
  (SIGN_EXTEND_FIELD							\
   ((((unsigned long) (word)) >> 8),					\
    (((sizeof (format_word)) * CHAR_BIT) - 8)))

#define COMPILED_ENTRY_FORMAT_HIGH(addr)                                \
  (FORMAT_WORD_HIGH_BYTE (COMPILED_ENTRY_FORMAT_WORD (addr)))

#define COMPILED_ENTRY_FORMAT_LOW(addr)                                 \
  (FORMAT_WORD_LOW_BYTE (COMPILED_ENTRY_FORMAT_WORD (addr)))

#define FORMAT_BYTE_FRAMEMAX            0x7f

#define COMPILED_ENTRY_MAXIMUM_ARITY    COMPILED_ENTRY_FORMAT_LOW
#define COMPILED_ENTRY_MINIMUM_ARITY    COMPILED_ENTRY_FORMAT_HIGH

#endif /* CMPINT2_H_INCLUDED */
