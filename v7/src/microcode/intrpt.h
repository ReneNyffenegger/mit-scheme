/* -*-C-*-

$Id: intrpt.h,v 1.12 1993/06/29 22:53:52 cph Exp $

Copyright (c) 1987-93 Massachusetts Institute of Technology

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
MIT in each case. */

/* Interrupt manipulation utilities. */

/* Interrupt bits -- scanned from LSB (1) to MSB (16) */

#define INT_Stack_Overflow	1	/* Local interrupt */
#define INT_Global_GC		2
#define INT_GC			4	/* Local interrupt */
#define INT_Global_1		8
#define INT_Character		16	/* Local interrupt */
#define INT_AFTER_GC		32	/* Local interrupt */
#define INT_Timer		64	/* Local interrupt */
#define INT_Global_3		128
#define INT_Suspend		256	/* Local interrupt */
#define INT_Global_Mask		\
  (INT_Global_GC | INT_Global_1 | INT_Global_3)

#define Global_GC_Level		1
#define Global_1_Level		3
#define Global_3_Level		7
#define MAX_INTERRUPT_NUMBER	8

#define INT_Mask		((1 << (MAX_INTERRUPT_NUMBER + 1)) - 1)

/* Utility macros. */

#define PENDING_INTERRUPTS()						\
  ((FETCH_INTERRUPT_MASK ()) & (FETCH_INTERRUPT_CODE ()))

#define INTERRUPT_QUEUED_P(mask) (((FETCH_INTERRUPT_CODE ()) & (mask)) != 0)

#define INTERRUPT_ENABLED_P(mask) (((FETCH_INTERRUPT_MASK ()) & (mask)) != 0)

#define INTERRUPT_PENDING_P(mask) (((PENDING_INTERRUPTS ()) & (mask)) != 0)

#define COMPILER_SETUP_INTERRUPT()					\
{									\
  (Registers[REGBLOCK_MEMTOP]) =					\
    ((INTERRUPT_PENDING_P (INT_Mask))					\
     ? ((SCHEME_OBJECT) -1)						\
     : (INTERRUPT_ENABLED_P (INT_GC))					\
     ? ((SCHEME_OBJECT) MemTop)						\
     : ((SCHEME_OBJECT) Heap_Top));					\
  (Registers[REGBLOCK_STACK_GUARD]) =					\
    ((INTERRUPT_ENABLED_P (INT_Stack_Overflow))				\
     ? ((SCHEME_OBJECT) Stack_Guard)					\
     : ((SCHEME_OBJECT) Absolute_Stack_Base));				\
}

#define FETCH_INTERRUPT_MASK() ((long) (Registers[REGBLOCK_INT_MASK]))

#define SET_INTERRUPT_MASK(mask)					\
{									\
  (Registers[REGBLOCK_INT_MASK]) = ((SCHEME_OBJECT) (mask));		\
  COMPILER_SETUP_INTERRUPT ();						\
}

#define FETCH_INTERRUPT_CODE() ((long) (Registers[REGBLOCK_INT_CODE]))

#define REQUEST_INTERRUPT(code)						\
{									\
  (Registers[REGBLOCK_INT_CODE]) =					\
    ((SCHEME_OBJECT) ((FETCH_INTERRUPT_CODE ()) | (code)));		\
  COMPILER_SETUP_INTERRUPT ();						\
}

#define CLEAR_INTERRUPT(code)						\
{									\
  (Registers[REGBLOCK_INT_CODE]) =					\
    ((SCHEME_OBJECT) ((FETCH_INTERRUPT_CODE ()) &~ (code)));		\
  COMPILER_SETUP_INTERRUPT ();						\
}

#define INITIALIZE_INTERRUPTS()						\
{									\
  (Registers[REGBLOCK_INT_MASK]) = ((SCHEME_OBJECT) 0);			\
  (Registers[REGBLOCK_INT_CODE]) = ((SCHEME_OBJECT) 0);			\
  SET_INTERRUPT_MASK (INT_Mask);					\
  CLEAR_INTERRUPT (INT_Mask);						\
}
