/* -*-C-*-

$Id: prims.h,v 9.44 1993/12/05 06:08:03 cph Exp $

Copyright (c) 1987-1993 Massachusetts Institute of Technology

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

/* This file contains some macros for defining primitives,
   for argument type or value checking, and for accessing
   the arguments. */

#ifndef SCM_PRIMS_H
#define SCM_PRIMS_H

#include "ansidecl.h"

/* Definition of primitives. */

#define DEFINE_PRIMITIVE(scheme_name, fn_name, min_args, max_args, doc)	\
extern SCHEME_OBJECT EXFUN (fn_name, (void));				\
SCHEME_OBJECT DEFUN_VOID (fn_name)

/* Can be used for `max_args' in `DEFINE_PRIMITIVE' to indicate that
   the primitive has no upper limit on its arity.  */
#define LEXPR (-1)

/* Primitives should have this as their first statement. */
#ifdef ENABLE_PRIMITIVE_PROFILING
#define PRIMITIVE_HEADER(n_args) record_primitive_entry (Fetch_Expression ())
#else
#define PRIMITIVE_HEADER(n_args) {}
#endif

/* Primitives return by performing one of the following operations. */
#define PRIMITIVE_RETURN(value)	return (value)
#define PRIMITIVE_ABORT abort_to_interpreter

extern void EXFUN (canonicalize_primitive_context, (void));
#define PRIMITIVE_CANONICALIZE_CONTEXT canonicalize_primitive_context

/* Various utilities */

#define Primitive_GC(Amount)						\
{									\
  Request_GC (Amount);							\
  signal_interrupt_from_primitive ();					\
}

#define Primitive_GC_If_Needed(Amount)					\
{									\
  if (GC_Check (Amount)) Primitive_GC (Amount);				\
}

#define CHECK_ARG(argument, type_p) do					\
{									\
  if (! (type_p (ARG_REF (argument))))					\
    error_wrong_type_arg (argument);					\
} while (0)

#define ARG_LOC(argument) (STACK_LOC (argument - 1))
#define ARG_REF(argument) (STACK_REF (argument - 1))
#define LEXPR_N_ARGUMENTS() (Regs [REGBLOCK_LEXPR_ACTUALS])

extern void EXFUN (signal_error_from_primitive, (long error_code));
extern void EXFUN (signal_interrupt_from_primitive, (void));
extern void EXFUN (error_wrong_type_arg, (int));
extern void EXFUN (error_bad_range_arg, (int));
extern void EXFUN (error_external_return, (void));
extern long EXFUN (arg_integer, (int));
extern long EXFUN (arg_nonnegative_integer, (int));
extern long EXFUN (arg_index_integer, (int, long));
extern long EXFUN (arg_integer_in_range, (int, long, long));
extern double EXFUN (arg_real_number, (int));
extern double EXFUN (arg_real_in_range, (int, double, double));
extern long EXFUN (arg_ascii_char, (int));
extern long EXFUN (arg_ascii_integer, (int));

#define UNSIGNED_FIXNUM_ARG(arg)					\
  ((FIXNUM_P (ARG_REF (arg)))						\
   ? (UNSIGNED_FIXNUM_TO_LONG (ARG_REF (arg)))				\
   : ((error_wrong_type_arg (arg)), 0))

#define STRING_ARG(arg)							\
  ((STRING_P (ARG_REF (arg)))						\
   ? ((char *) (STRING_LOC ((ARG_REF (arg)), 0)))			\
   : ((error_wrong_type_arg (arg)), ((char *) 0)))

#define BOOLEAN_ARG(arg) ((ARG_REF (arg)) != SHARP_F)

#define CELL_ARG(arg)							\
  ((CELL_P (ARG_REF (arg)))						\
   ? (ARG_REF (arg))							\
   : ((error_wrong_type_arg (arg)), ((SCHEME_OBJECT) 0)))

#define PAIR_ARG(arg)							\
  ((PAIR_P (ARG_REF (arg)))						\
   ? (ARG_REF (arg))							\
   : ((error_wrong_type_arg (arg)), ((SCHEME_OBJECT) 0)))

#define WEAK_PAIR_ARG(arg)						\
  ((WEAK_PAIR_P (ARG_REF (arg)))					\
   ? (ARG_REF (arg))							\
   : ((error_wrong_type_arg (arg)), ((SCHEME_OBJECT) 0)))

#define VECTOR_ARG(arg)							\
  ((VECTOR_P (ARG_REF (arg)))						\
   ? (ARG_REF (arg))							\
   : ((error_wrong_type_arg (arg)), ((SCHEME_OBJECT) 0)))

#define FLOATING_VECTOR_ARG(arg)					\
  ((FLONUM_P (ARG_REF (arg)))						\
   ? (ARG_REF (arg))							\
   : ((error_wrong_type_arg (arg)), ((SCHEME_OBJECT) 0)))

#endif /* SCM_PRIMS_H */
