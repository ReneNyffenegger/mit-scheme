/* -*-C-*-

$Id: sysprim.c,v 9.45 1998/10/23 05:35:51 cph Exp $

Copyright (c) 1987-98 Massachusetts Institute of Technology

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

/* Random system primitives.  Most are implemented in terms of
   utilities in os.c */

#include "scheme.h"
#include "prims.h"
#include "ostty.h"
#include "ostop.h"

/* Pretty random primitives */

DEFINE_PRIMITIVE ("EXIT", Prim_non_restartable_exit, 0, 0,
  "Exit Scheme with no option to restart.")
{
  PRIMITIVE_HEADER (0);
  termination_normal (0);
  PRIMITIVE_RETURN (UNSPECIFIC);
}

DEFINE_PRIMITIVE ("EXIT-WITH-VALUE", 
		  Prim_non_restartable_exit_with_value, 1, 1,
  "Exit Scheme with no option to restart, returning integer argument\n\
as exit status.")
{
  PRIMITIVE_HEADER (1);
  termination_normal ((int) arg_integer (1));
  PRIMITIVE_RETURN (UNSPECIFIC);
}

DEFINE_PRIMITIVE ("HALT", Prim_restartable_exit, 0, 0,
  "Exit Scheme, suspending it to that it can be restarted.")
{
  PRIMITIVE_HEADER (0);
  OS_restartable_exit ();
  PRIMITIVE_RETURN (UNSPECIFIC);
}

DEFINE_PRIMITIVE ("UNDER-EMACS?", Prim_under_emacs_p, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT (OS_under_emacs_p ()));
}

DEFINE_PRIMITIVE ("SET-TRAP-STATE!", Prim_set_trap_state, 1, 1, 0)
{
  long result;
  extern long OS_set_trap_state();
  PRIMITIVE_HEADER (1);

  result = (OS_set_trap_state (arg_nonnegative_integer (1)));
  if (result < 0)
  {
    error_bad_range_arg (1);
    /*NOTREACHED*/
  }
  PRIMITIVE_RETURN (LONG_TO_UNSIGNED_FIXNUM (result));
}

DEFINE_PRIMITIVE ("HEAP-AVAILABLE?", Prim_heap_available_p, 1, 1, 
  "(N-WORDS)\n\
Tests to see if there are at least N-WORDS words of heap storage available")
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN
    (BOOLEAN_TO_OBJECT ((Free + (arg_nonnegative_integer (1))) < MemTop));
}

DEFINE_PRIMITIVE ("PRIMITIVE-GET-FREE", Prim_get_free, 1, 1,
  "(TYPE-CODE)\n\
Return the value of the free pointer tagged with TYPE-CODE")
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN
    (MAKE_POINTER_OBJECT ((arg_index_integer (1, (MAX_TYPE_CODE + 1))), Free));
}

DEFINE_PRIMITIVE ("PRIMITIVE-INCREMENT-FREE", Prim_increment_free, 1, 1,
  "(N-WORDS)\n\
Advance the free pointer by N-WORDS words")
{
  PRIMITIVE_HEADER (1);
  Free += (arg_nonnegative_integer (1));
  PRIMITIVE_RETURN (UNSPECIFIC);
}

#define CONVERT_ADDRESS(address)					\
  (long_to_integer (ADDRESS_TO_DATUM (address)))

DEFINE_PRIMITIVE ("GC-SPACE-STATUS", Prim_gc_space_status, 0, 0, 0)
{
  SCHEME_OBJECT * constant_low;
  SCHEME_OBJECT * constant_free;
  SCHEME_OBJECT * constant_high;
  SCHEME_OBJECT * heap_low;
  SCHEME_OBJECT * heap_free;
  SCHEME_OBJECT * heap_limit;
  SCHEME_OBJECT * heap_high;
#ifndef USE_STACKLETS
  SCHEME_OBJECT * stack_low;
  SCHEME_OBJECT * stack_free;
  SCHEME_OBJECT * stack_limit;
  SCHEME_OBJECT * stack_high;
#endif /* USE_STACKLETS */
  SCHEME_OBJECT result;
  PRIMITIVE_HEADER (0);

  constant_low = Constant_Space;
  constant_free = Free_Constant;
  constant_high = Constant_Top;
  heap_low = Heap_Bottom;
  heap_free = Free;
  heap_limit = MemTop;
  heap_high = Heap_Top;
#ifndef USE_STACKLETS
  stack_low = Stack_Bottom;
  stack_free = Stack_Pointer;
  stack_limit = Stack_Guard;
  stack_high = Stack_Top;
#endif /* USE_STACKLETS */

  result = (make_vector (12, SHARP_F, true));
  VECTOR_SET (result, 0, (LONG_TO_UNSIGNED_FIXNUM (sizeof (SCHEME_OBJECT))));
  VECTOR_SET (result, 1, (CONVERT_ADDRESS (constant_low)));
  VECTOR_SET (result, 2, (CONVERT_ADDRESS (constant_free)));
  VECTOR_SET (result, 3, (CONVERT_ADDRESS (constant_high)));
  VECTOR_SET (result, 4, (CONVERT_ADDRESS (heap_low)));
  VECTOR_SET (result, 5, (CONVERT_ADDRESS (heap_free)));
  VECTOR_SET (result, 6, (CONVERT_ADDRESS (heap_limit)));
  VECTOR_SET (result, 7, (CONVERT_ADDRESS (heap_high)));
#ifndef USE_STACKLETS
  VECTOR_SET (result, 8, (CONVERT_ADDRESS (stack_low)));
  VECTOR_SET (result, 9, (CONVERT_ADDRESS (stack_free)));
  VECTOR_SET (result, 10, (CONVERT_ADDRESS (stack_limit)));
  VECTOR_SET (result, 11, (CONVERT_ADDRESS (stack_high)));
#endif /* USE_STACKLETS */
  PRIMITIVE_RETURN (result);
}

DEFINE_PRIMITIVE ("SCHEME-PROGRAM-NAME", Prim_scheme_program_name, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  PRIMITIVE_RETURN (char_pointer_to_string ((char *) (scheme_program_name)));
}
