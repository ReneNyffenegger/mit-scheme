/* -*-C-*-

Copyright (c) 1987, 1988, 1989 Massachusetts Institute of Technology

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

/* $Id: trap.h,v 9.44 1995/07/27 00:23:31 adams Exp $ */

/* Kinds of traps:

   Note that for every trap there is a dangerous version.
   The danger bit is the bottom bit of the trap number,
   thus all dangerous traps are odd and viceversa.

   For efficiency, some traps are immediate, while some are
   pointer objects.  The type code is multiplexed, and the
   garbage collector handles it specially.
 */

/* The following are immediate traps: */

#define TRAP_UNASSIGNED				0
#define TRAP_UNASSIGNED_DANGEROUS		1
#define TRAP_UNBOUND				2
#define TRAP_UNBOUND_DANGEROUS			3
#define TRAP_ILLEGAL				4
#define TRAP_ILLEGAL_DANGEROUS			5
#define TRAP_EXPENSIVE				6
#define TRAP_EXPENSIVE_DANGEROUS		7

/* TRAP_MAX_IMMEDIATE is defined in const.h */

/* The following are not: */

#define TRAP_NOP				10
#define TRAP_DANGEROUS				11
#define TRAP_FLUID				12
#define TRAP_FLUID_DANGEROUS			13
#define TRAP_COMPILER_CACHED			14
#define TRAP_COMPILER_CACHED_DANGEROUS		15

/* These MUST be distinct */

#define TRAP_EXTENSION_TYPE			TC_QUAD
#define TRAP_REFERENCES_TYPE			TC_HUNK3

/* Trap utilities */

#define get_trap_kind(variable, what)					\
{									\
  variable = OBJECT_DATUM (what);					\
  if (variable > TRAP_MAX_IMMEDIATE)					\
    variable = OBJECT_DATUM (MEMORY_REF (what, TRAP_TAG));		\
}

/* Common constants */

#ifdef b32				/* 32 bit objects */

#if (TYPE_CODE_LENGTH == 8)
#define UNASSIGNED_OBJECT		0x1C000000
#define DANGEROUS_UNASSIGNED_OBJECT	0x1C000001
#define UNBOUND_OBJECT			0x1C000002
#define DANGEROUS_UNBOUND_OBJECT	0x1C000003
#define ILLEGAL_OBJECT			0x1C000004
#define DANGEROUS_ILLEGAL_OBJECT	0x1C000005
#define EXPENSIVE_OBJECT		0x1C000006
#define DANGEROUS_EXPENSIVE_OBJECT	0x1C000007
#endif /* (TYPE_CODE_LENGTH == 8) */

#if (TYPE_CODE_LENGTH == 6)
#define UNASSIGNED_OBJECT		0x70000000
#define DANGEROUS_UNASSIGNED_OBJECT	0x70000001
#define UNBOUND_OBJECT			0x70000002
#define DANGEROUS_UNBOUND_OBJECT	0x70000003
#define ILLEGAL_OBJECT			0x70000004
#define DANGEROUS_ILLEGAL_OBJECT	0x70000005
#define EXPENSIVE_OBJECT		0x70000006
#define DANGEROUS_EXPENSIVE_OBJECT	0x70000007
#endif /* (TYPE_CODE_LENGTH == 6) */

#if (TC_REFERENCE_TRAP != 0x1C)
#include "error: trap.h and types.h are inconsistent"
#endif

#endif /* b32 */

#ifndef UNASSIGNED_OBJECT		/* Safe version */
#define UNASSIGNED_OBJECT		MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_UNASSIGNED)
#define DANGEROUS_UNASSIGNED_OBJECT	MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_UNASSIGNED_DANGEROUS)
#define UNBOUND_OBJECT			MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_UNBOUND)
#define DANGEROUS_UNBOUND_OBJECT	MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_UNBOUND_DANGEROUS)
#define ILLEGAL_OBJECT			MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_ILLEGAL)
#define DANGEROUS_ILLEGAL_OBJECT	MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_ILLEGAL_DANGEROUS)
#define EXPENSIVE_OBJECT		MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_EXPENSIVE)
#define DANGEROUS_EXPENSIVE_OBJECT	MAKE_OBJECT (TC_REFERENCE_TRAP, TRAP_EXPENSIVE_DANGEROUS)
#endif /* UNASSIGNED_OBJECT */

#define NOP_OBJECT (LONG_TO_UNSIGNED_FIXNUM (TRAP_NOP))
#define DANGEROUS_OBJECT (LONG_TO_UNSIGNED_FIXNUM (TRAP_DANGEROUS))
#define REQUEST_RECACHE_OBJECT DANGEROUS_ILLEGAL_OBJECT
#define EXPENSIVE_ASSIGNMENT_OBJECT EXPENSIVE_OBJECT
