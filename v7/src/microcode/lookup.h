/* -*-C-*-

Copyright (c) 1988 Massachusetts Institute of Technology

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

/* $Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/lookup.h,v 9.41 1988/09/29 05:02:21 jinx Exp $ */

/* Macros and declarations for the variable lookup code. */

extern Pointer
  *deep_lookup(),
  *lookup_fluid(),
  *force_definition();

extern long
  deep_lookup_end(),
  deep_assignment_end();

extern Pointer
  unbound_trap_object[],
  uncompiled_trap_object[],
  illegal_trap_object[],
  fake_variable_object[];

#define GC_allocate_test(N)		GC_Check(N)

#define AUX_LIST_TYPE			TC_VECTOR

#define AUX_CHUNK_SIZE			20
#define AUX_LIST_COUNT			ENV_EXTENSION_COUNT
#define AUX_LIST_FIRST			ENV_EXTENSION_MIN_SIZE
#define AUX_LIST_INITIAL_SIZE		(AUX_LIST_FIRST + AUX_CHUNK_SIZE)

/* Variable compilation types. */

#define LOCAL_REF			TC_NULL
#define GLOBAL_REF			TC_UNINTERNED_SYMBOL
#define FORMAL_REF			TC_CHARACTER
#define AUX_REF				TC_FIXNUM
#define UNCOMPILED_REF			TC_TRUE

/* Common constants. */

#ifndef b32
#define UNCOMPILED_VARIABLE		Make_Non_Pointer(UNCOMPILED_REF, 0)
#else
#define UNCOMPILED_VARIABLE		0x08000000
#endif

/* Macros for speedy variable reference. */

#if (LOCAL_REF == 0)

#define Lexical_Offset(Ind)		((long) (Ind))
#define Make_Local_Offset(Ind)		((Pointer) (Ind))

#else

#define Lexical_Offset(Ind)		OBJECT_DATUM(Ind)
#define Make_Local_Offset(Ind)		Make_Non_Pointer(LOCAL_REF, Ind)

#endif

/* The code below depends on the following. */

/* Done as follows because of VMS. */

#define lookup_inconsistency_p						\
  ((VARIABLE_OFFSET == VARIABLE_COMPILED_TYPE) ||			\
   (VARIABLE_FRAME_NO != VARIABLE_COMPILED_TYPE))

#if (lookup_inconsistency_p)
#include "error: lookup.h inconsistency detected."
#endif

#define get_offset(hunk) Lexical_Offset(Fetch(hunk[VARIABLE_OFFSET]))

#ifdef PARALLEL_PROCESSOR

#define verify(type_code, variable, code, label)			\
{									\
  variable = code;							\
  if (OBJECT_TYPE(Fetch(hunk[VARIABLE_COMPILED_TYPE])) !=		\
      type_code)							\
    goto label;								\
}

#define verified_offset(variable, code)		variable

/* Unlike Lock_Cell, cell must be (Pointer *).  This currently does
   not matter, but might on a machine with address mapping.
 */

#define setup_lock(handle, cell)		handle = Lock_Cell(cell)
#define remove_lock(handle)			Unlock_Cell(handle)

/* This should prevent a deadly embrace if whole contiguous
   regions are locked, rather than individual words.
 */

#define setup_locks(hand1, cel1, hand2, cel2)				\
{									\
  if (LOCK_FIRST(cel1, cel2))						\
  {									\
    setup_lock(hand1, cel1);						\
    setup_lock(hand2, cel2);						\
  }									\
  else									\
  {									\
    setup_lock(hand2, cel2);						\
    setup_lock(hand1, cel1);						\
  }									\
}

#define remove_locks(hand1, hand2)					\
{									\
  remove_lock(hand2);							\
  remove_lock(hand1);							\
}

#else /* not PARALLEL_PROCESSOR */

#define verify(type_code, variable, code, label)
#define verified_offset(variable, code)		code
#define setup_lock(handle, cell)
#define remove_lock(ignore)
#define setup_locks(hand1, cel1, hand2, cel2)
#define remove_locks(ign1, ign2)

#endif /* PARALLEL_PROCESSOR */

/* This is provided as a separate macro so that it can be made
   atomic if necessary.
 */

#define update_lock(handle, cell)					\
{									\
  remove_lock(handle);							\
  setup_lock(handle, cell);						\
}

#ifndef Future_Variable_Splice
#define Future_Variable_Splice(Vbl, Ofs, Val)
#endif

/* Pointer *cell, env, *hunk; */

#define lookup(cell, env, hunk, label)					\
{									\
  fast Pointer frame;							\
  long offset;								\
									\
label:									\
									\
  frame = Fetch(hunk[VARIABLE_COMPILED_TYPE]);				\
									\
  switch (OBJECT_TYPE(frame))						\
  {									\
    case GLOBAL_REF:							\
      /* frame is a pointer to the same symbol. */			\
      cell = Nth_Vector_Loc(frame, SYMBOL_GLOBAL_VALUE);		\
      break;								\
									\
    case LOCAL_REF:							\
      cell = Nth_Vector_Loc(env, Lexical_Offset(frame));		\
      break;								\
									\
    case FORMAL_REF:							\
      lookup_formal(cell, env, hunk, label);				\
									\
    case AUX_REF:							\
      lookup_aux(cell, env, hunk, label);				\
									\
    default:								\
      /* Done here rather than in a separate case because of		\
	 peculiarities of the bobcat compiler.				\
       */								\
      cell = ((OBJECT_TYPE(frame) == UNCOMPILED_REF) ?			\
	      uncompiled_trap_object :					\
	      illegal_trap_object);					\
      break;								\
 }									\
}

#define lookup_formal(cell, env, hunk, label)				\
{									\
  fast long depth;							\
									\
  verify(FORMAL_REF, offset, get_offset(hunk), label);			\
  depth = Get_Integer(frame);						\
  frame = env;								\
  while(--depth >= 0)							\
  {									\
    frame = Fast_Vector_Ref(Vector_Ref(frame, ENVIRONMENT_FUNCTION),	\
			    PROCEDURE_ENVIRONMENT);			\
  }									\
									\
  cell = Nth_Vector_Loc(frame,						\
			verified_offset(offset, get_offset(hunk)));	\
									\
  break;								\
}

#define lookup_aux(cell, env, hunk, label)				\
{									\
  fast long depth;							\
									\
  verify(AUX_REF, offset, get_offset(hunk), label);			\
  depth = Get_Integer(frame);						\
  frame = env;								\
  while(--depth >= 0)							\
  {									\
    frame = Fast_Vector_Ref(Vector_Ref(frame, ENVIRONMENT_FUNCTION),	\
			    PROCEDURE_ENVIRONMENT);			\
  }									\
									\
  frame = Vector_Ref(frame, ENVIRONMENT_FUNCTION);			\
  if (OBJECT_TYPE(frame) != AUX_LIST_TYPE)				\
  {									\
    cell = uncompiled_trap_object;					\
    break;								\
  }									\
  depth = verified_offset(offset, get_offset(hunk));			\
  if (depth > Vector_Length(frame))					\
  {									\
    cell = uncompiled_trap_object;					\
    break;								\
  }									\
  frame = Vector_Ref(frame, depth);					\
  if ((frame == NIL) ||							\
      (Fast_Vector_Ref(frame, CONS_CAR) != hunk[VARIABLE_SYMBOL]))	\
  {									\
    cell = uncompiled_trap_object;					\
    break;								\
  }									\
  cell = Nth_Vector_Loc(frame, CONS_CDR);				\
  break;								\
}

/* Macros and exports for incremental definition and hooks. */

extern long extend_frame();

#ifndef DEFINITION_RECACHES_EAGERLY

extern long compiler_uncache();

#define simple_uncache(cell, sym)		PRIM_DONE

#define shadowing_recache(cell, env, sym, value, shadowed_p)		\
  definition(cell, value, shadowed_p)

#define compiler_recache(old, new, env, sym, val, shadowed_p, link_p)	\
  PRIM_DONE

#else /* DEFINITION_RECACHES_EAGERLY */

extern long compiler_recache();

extern Pointer *shadowed_value_cell;

#define compiler_uncache(cell, sym)					\
  (shadowed_value_cell = cell, PRIM_DONE)

#define simple_uncache(cell, sym)					\
  compiler_uncache(cell, sym)

#define shadowing_recache(cell, env, sym, value, shadowed_p)		\
  compiler_recache(shadowed_value_cell, cell, env, sym, value,		\
	  	   shadowed_p, false)

#endif /* DEFINITION_RECACHES_EAGERLY */
