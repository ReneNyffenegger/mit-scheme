/* -*-C-*-

$Id: memmag.c,v 9.49 1993/03/11 19:53:49 cph Exp $

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

/* Memory management top level.

   The memory management code is spread over 3 files:
   - memmag.c: initialization.
   - gcloop.c: main garbage collector loop.
   - purify.c: constant/pure space hacking.
   There is also a relevant header file, gccode.h.

   The object dumper, fasdump, shares properties and code with the
   memory management utilities.
 */

#include "scheme.h"
#include "prims.h"
#include "gccode.h"

/* Imports */

extern SCHEME_OBJECT *
  EXFUN (GCLoop, (SCHEME_OBJECT *, SCHEME_OBJECT **));

/* Exports */

extern void
  EXFUN (GCFlip, (void)),
  EXFUN (GC, (void));

extern void
  EXFUN (Clear_Memory, (int, int, int)),
  EXFUN (Setup_Memory, (int, int, int)),
  EXFUN (Reset_Memory, (void));

/* 	Memory Allocation, sequential processor:

   ------------------------------------------
   |         Control Stack        ||        |
   |                              \/        |
   ------------------------------------------
   |     Constant + Pure Space    /\        |
   |                              ||        |
   ------------------------------------------
   |                                        |
   |           Heap Space                   |
   ------------------------------------------

   Each area has a pointer to its starting address and a pointer to the
   next free cell.  In addition, there is a pointer to the top of the
   useable area of the heap (the heap is subdivided into two areas for
   the purposes of GC, and this pointer indicates the top of the half
   currently in use).

*/

/* Initialize free pointers within areas. Stack_Pointer is
   special: it always points to a cell which is in use. */

void
DEFUN (Clear_Memory,
       (Our_Heap_Size, Our_Stack_Size, Our_Constant_Size),
       int Our_Heap_Size AND int Our_Stack_Size AND int Our_Constant_Size)
{
  GC_Reserve = 4500;
  GC_Space_Needed = 0;
  Heap_Top = (Heap_Bottom + Our_Heap_Size);
  Local_Heap_Base = Heap_Bottom;
  Unused_Heap_Top = (Heap_Bottom + (2 * Our_Heap_Size));
  SET_MEMTOP (Heap_Top - GC_Reserve);
  Free = Heap_Bottom;
  Constant_Top = (Constant_Space + Our_Constant_Size);
  Initialize_Stack ();
  Free_Constant = Constant_Space;
  SET_CONSTANT_TOP ();
  return;
}

/* This procedure allocates and divides the total memory. */

void
DEFUN (Setup_Memory,
       (Our_Heap_Size, Our_Stack_Size, Our_Constant_Size),
       int Our_Heap_Size AND int Our_Stack_Size AND int Our_Constant_Size)
{
  SCHEME_OBJECT test_value;

  /* Consistency check 1 */
  if (Our_Heap_Size == 0)
  {
    fprintf (stderr, "Configuration won't hold initial data.\n");
    exit (1);
  }

  /* Allocate */
  Highest_Allocated_Address =
    ALLOCATE_HEAP_SPACE (Stack_Allocation_Size(Our_Stack_Size) +
			 (2 * Our_Heap_Size) +
			 Our_Constant_Size +
			 HEAP_BUFFER_SPACE);

  /* Consistency check 2 */
  if (Heap == NULL)
  {
    fprintf (stderr, "Not enough memory for this configuration.\n");
    exit (1);
  }

  /* Initialize the various global parameters */
  Heap += HEAP_BUFFER_SPACE;
  INITIAL_ALIGN_FLOAT (Heap);
  Unused_Heap = (Heap + Our_Heap_Size);
  ALIGN_FLOAT (Unused_Heap);
  Constant_Space = (Heap + (2 * Our_Heap_Size));
  ALIGN_FLOAT (Constant_Space);

  /* Consistency check 3 */

  test_value = (MAKE_POINTER_OBJECT (LAST_TYPE_CODE, Highest_Allocated_Address));

  if (((OBJECT_TYPE (test_value)) != LAST_TYPE_CODE) ||
      ((OBJECT_ADDRESS (test_value)) != Highest_Allocated_Address))
  {
    fprintf (stderr,
	     "Largest address does not fit in datum field of object.\n");
    fprintf (stderr,
	     "Allocate less space or re-configure without HEAP_IN_LOW_MEMORY.\n");
    exit (1);
  }

  Heap_Bottom = Heap;
  Clear_Memory (Our_Heap_Size, Our_Stack_Size, Our_Constant_Size);
  return;
}

/* In this version, this does nothing. */

void
DEFUN_VOID (Reset_Memory)
{
  return;
}

/* Utilities for the garbage collector top level.
   The main garbage collector loop is in gcloop.c
*/

/* Flip into unused heap */

void
DEFUN_VOID (GCFlip)
{
  SCHEME_OBJECT *Temp;

  Temp = Unused_Heap;
  Unused_Heap = Heap_Bottom;
  Heap_Bottom = Temp;
  Temp = Unused_Heap_Top;
  Unused_Heap_Top = Heap_Top;
  Heap_Top = Temp;
  Free = Heap_Bottom;
  SET_MEMTOP(Heap_Top - GC_Reserve);
  Weak_Chain = EMPTY_LIST;
  return;
}

/* Here is the code which "prunes" objects from weak cons cells.  See
   the picture in gccode.h for a description of the structure built by
   the GC.  This code follows the chain of weak cells (in old space) and
   either updates the new copy's CAR with the relocated version of the
   object, or replaces it with SHARP_F.

   Note that this is the only code in the system, besides the inner garbage
   collector, which looks at both old and new space.
*/

SCHEME_OBJECT Weak_Chain;

void
DEFUN_VOID (Fix_Weak_Chain)
{
  fast SCHEME_OBJECT *Old_Weak_Cell, *Scan, Old_Car, Temp, *Old, *Low_Constant;

  Low_Constant = Constant_Space;
  while (Weak_Chain != EMPTY_LIST)
  {
    Old_Weak_Cell = OBJECT_ADDRESS (Weak_Chain);
    Scan = OBJECT_ADDRESS (*Old_Weak_Cell++);
    Weak_Chain = *Old_Weak_Cell;
    Old_Car = *Scan;
    Temp = (MAKE_OBJECT_FROM_OBJECTS (Weak_Chain, Old_Car));
    Weak_Chain = (OBJECT_NEW_TYPE (TC_NULL, Weak_Chain));

    switch(GC_Type(Temp))
    { case GC_Non_Pointer:
        *Scan = Temp;
	continue;

      case GC_Special:
	if (OBJECT_TYPE (Temp) != TC_REFERENCE_TRAP)
	{
	  /* No other special type makes sense here. */
	  goto fail;
	}
	if (OBJECT_DATUM (Temp) <= TRAP_MAX_IMMEDIATE)
	{
	  *Scan = Temp;
	  continue;
	}
	/* Otherwise, it is a pointer.  Fall through */

      /* Normal pointer types, the broken heart is in the first word.
         Note that most special types are treated normally here.
	 The BH code updates *Scan if the object has been relocated.
	 Otherwise it falls through and we replace it with a full SHARP_F.
	 Eliminating this assignment would keep old data (pl. of datum).
       */
      case GC_Cell:
      case GC_Pair:
      case GC_Triple:
      case GC_Quadruple:
      case GC_Vector:
	Old = OBJECT_ADDRESS (Old_Car);
	if (Old >= Low_Constant)
	{
	  *Scan = Temp;
	  continue;
	}
	Normal_BH(false, continue);
	*Scan = SHARP_F;
	continue;

      case GC_Compiled:
	Old = OBJECT_ADDRESS (Old_Car);
	if (Old >= Low_Constant)
	{
	  *Scan = Temp;
	  continue;
	}
	Compiled_BH(false, { *Scan = Temp; continue; });
	*Scan = SHARP_F;
	continue;

      case GC_Undefined:
	fprintf(stderr,
		"\nFix_Weak_Chain: Clearing bad object 0x%08lx.\n",
		Temp);
	*Scan = SHARP_F;
	continue;

      default:			/* Non Marked Headers and Broken Hearts */
      fail:
        fprintf(stderr,
		"\nFix_Weak_Chain: Bad Object: 0x%08lx.\n",
		Temp);
	Microcode_Termination(TERM_INVALID_TYPE_CODE);
	/*NOTREACHED*/
    }
  }
  return;
}

/* Here is the set up for the full garbage collection:

   - First it makes the constant space and stack into one large area
   by "hiding" the gap between them with a non-marked header.

   - Then it saves away all the relevant microcode registers into new
   space, making this the root for garbage collection.

   - Then it does the actual garbage collection in 4 steps:
     1) Trace constant space.
     2) Trace objects pointed out by the root and constant space.
     3) Trace the precious objects, remembering where consing started.
     4) Update all weak pointers.

   - Finally it restores the microcode registers from the copies in
   new space.
*/

void 
DEFUN_VOID (GC)
{
  SCHEME_OBJECT
    *Root, *Result, *Check_Value,
    The_Precious_Objects, *Root2;

  /* Save the microcode registers so that they can be relocated */

  Terminate_Old_Stacklet ();
  SEAL_CONSTANT_SPACE ();
  Check_Value = (CONSTANT_SPACE_SEAL ());
  Root = Free;
  The_Precious_Objects = (Get_Fixed_Obj_Slot (Precious_Objects));
  Set_Fixed_Obj_Slot (Precious_Objects, SHARP_F);
  Set_Fixed_Obj_Slot (Lost_Objects_Base, SHARP_F);

  *Free++ = Fixed_Objects;
  *Free++ = (MAKE_POINTER_OBJECT (UNMARKED_HISTORY_TYPE, History));
  *Free++ = Undefined_Primitives;
  *Free++ = Undefined_Primitives_Arity;
  *Free++ = Get_Current_Stacklet ();
  *Free++ =
    ((Prev_Restore_History_Stacklet == NULL)
     ? SHARP_F
     : (MAKE_POINTER_OBJECT (TC_CONTROL_POINT, Prev_Restore_History_Stacklet)));
  *Free++ = Current_State_Point;
  *Free++ = Fluid_Bindings;

#ifdef ENABLE_GC_DEBUGGING_TOOLS
  if (gc_objects_referencing != SHARP_F)
    {
      MEMORY_SET
	(gc_objects_referencing, 0,
	 (MAKE_OBJECT
	  (TC_MANIFEST_NM_VECTOR,
	   (OBJECT_DATUM (MEMORY_REF (gc_objects_referencing, 0))))));
      {
	SCHEME_OBJECT * scan = (VECTOR_LOC (gc_objects_referencing, 0));
	SCHEME_OBJECT * end =
	  (VECTOR_LOC (gc_objects_referencing,
		       (VECTOR_LENGTH (gc_objects_referencing))));
	while (scan < end)
	  (*scan++) = SHARP_F;
      }
      *Free++ = gc_objects_referencing;
      gc_objects_referencing_count = 0;
      gc_objects_referencing_scan =
	(VECTOR_LOC (gc_objects_referencing, 1));
      gc_objects_referencing_end =
	(VECTOR_LOC (gc_objects_referencing,
		     (VECTOR_LENGTH (gc_objects_referencing))));
    }
#endif

  /* The 4 step GC */

  Result = (GCLoop (Constant_Space, &Free));
  if (Result != Check_Value)
  {
    fprintf (stderr, "\nGC: Constant Scan ended too early.\n");
    Microcode_Termination (TERM_BROKEN_HEART);
  }

  Result = (GCLoop (Root, &Free));
  if (Free != Result)
  {
    fprintf (stderr, "\nGC-1: Heap Scan ended too early.\n");
    Microcode_Termination (TERM_BROKEN_HEART);
  }

  Root2 = Free;
  *Free++ = The_Precious_Objects;
  Result = (GCLoop (Root2, &Free));
  if (Free != Result)
  {
    fprintf (stderr, "\nGC-2: Heap Scan ended too early.\n");
    Microcode_Termination (TERM_BROKEN_HEART);
  }

#ifdef ENABLE_GC_DEBUGGING_TOOLS
  if (gc_objects_referencing != SHARP_F)
    {
      UPDATE_GC_OBJECTS_REFERENCING ();
      MEMORY_SET
	(gc_objects_referencing, 0,
	 (MAKE_OBJECT
	  (TC_MANIFEST_VECTOR,
	   (OBJECT_DATUM (MEMORY_REF (gc_objects_referencing, 0))))));
      VECTOR_SET (gc_objects_referencing, 0,
		  (LONG_TO_UNSIGNED_FIXNUM (gc_objects_referencing_count)));
      {
	SCHEME_OBJECT * end = gc_objects_referencing_scan;
	Result = (GCLoop ((VECTOR_LOC (gc_objects_referencing, 1)), (&end)));
	if ((end != Result) || (end != gc_objects_referencing_scan))
	  {
	    fprintf (stderr, "\nGC-3: Heap Scan ended too early.\n");
	    Microcode_Termination (TERM_BROKEN_HEART);
	  }
      }
      gc_objects_referencing = SHARP_F;
      gc_object_referenced = SHARP_F;
    }
#endif

  Fix_Weak_Chain ();

  /* Make the microcode registers point to the copies in new-space. */

  Fixed_Objects = *Root++;
  Set_Fixed_Obj_Slot (Precious_Objects, *Root2);
  Set_Fixed_Obj_Slot
    (Lost_Objects_Base, (LONG_TO_UNSIGNED_FIXNUM (ADDRESS_TO_DATUM (Root2))));

  History = (OBJECT_ADDRESS (*Root++));
  Undefined_Primitives = *Root++;
  Undefined_Primitives_Arity = *Root++;

  Set_Current_Stacklet (*Root);
  Root += 1;
  if (*Root == SHARP_F)
  {
    Prev_Restore_History_Stacklet = NULL;
    Root += 1;
  }
  else
  {
    Prev_Restore_History_Stacklet = (OBJECT_ADDRESS (*Root++));
  }
  Current_State_Point = *Root++;
  Fluid_Bindings = *Root++;
  Free_Stacklets = NULL;
  COMPILER_TRANSPORT_END ();
  CLEAR_INTERRUPT (INT_GC);
  return;
}

/* (GARBAGE-COLLECT SLACK)
   Requests a garbage collection leaving the specified amount of slack
   for the top of heap check on the next GC.  The primitive ends by invoking
   the GC daemon if there is one.

   This primitive never returns normally.  It always escapes into
   the interpreter because some of its cached registers (eg. History)
   have changed.
*/

DEFINE_PRIMITIVE ("GARBAGE-COLLECT", Prim_garbage_collect, 1, 1, 0)
{
  long new_gc_reserve;
  extern unsigned long gc_counter;
  SCHEME_OBJECT GC_Daemon_Proc;
  PRIMITIVE_HEADER (1);
  PRIMITIVE_CANONICALIZE_CONTEXT ();

  STACK_SANITY_CHECK ("GC");
  new_gc_reserve = (arg_nonnegative_integer (1));
  if (Free > Heap_Top)
  {
    fprintf (stderr,
	     "\nGARBAGE-COLLECT: GC has been delayed too long!\n");
    fprintf (stderr,
	     "Free = 0x%lx; MemTop = 0x%lx; Heap_Top = 0x%lx\n",
	     Free, MemTop, Heap_Top);
    Microcode_Termination (TERM_NO_SPACE);
  }

  ENTER_CRITICAL_SECTION ("garbage collector");
  gc_counter += 1;
  GC_Reserve = new_gc_reserve;
  GCFlip ();
  GC ();
  POP_PRIMITIVE_FRAME (1);
  GC_Daemon_Proc = (Get_Fixed_Obj_Slot (GC_Daemon));

  RENAME_CRITICAL_SECTION ("garbage collector daemon");
  if (GC_Daemon_Proc == SHARP_F)
  {
   Will_Push (CONTINUATION_SIZE);
    Store_Return (RC_NORMAL_GC_DONE);
    Store_Expression (LONG_TO_UNSIGNED_FIXNUM (MemTop - Free));
    Save_Cont ();
   Pushed ();
    PRIMITIVE_ABORT (PRIM_POP_RETURN);
    /*NOTREACHED*/
  }
 Will_Push (CONTINUATION_SIZE + (STACK_ENV_EXTRA_SLOTS + 1));
  Store_Return (RC_NORMAL_GC_DONE);
  Store_Expression (LONG_TO_UNSIGNED_FIXNUM(MemTop - Free));
  Save_Cont ();
  STACK_PUSH (GC_Daemon_Proc);
  STACK_PUSH (STACK_FRAME_HEADER);
 Pushed ();
  PRIMITIVE_ABORT (PRIM_APPLY);
  /* The following comment is by courtesy of LINT, your friendly sponsor. */
  /*NOTREACHED*/
}

DEFINE_PRIMITIVE ("GC-TRACE-REFERENCES", Prim_gc_trace_references, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  {
    SCHEME_OBJECT objects_referencing = (ARG_REF (2));
    if (! ((objects_referencing == SHARP_F)
	   || ((VECTOR_P (objects_referencing))
	       && ((VECTOR_LENGTH (objects_referencing)) >= 1))))
      error_wrong_type_arg (2);
#ifdef ENABLE_GC_DEBUGGING_TOOLS
    gc_object_referenced = (ARG_REF (1));
    gc_objects_referencing = objects_referencing;
#else /* not ENABLE_GC_DEBUGGING_TOOLS */
    error_external_return ();
#endif /* not ENABLE_GC_DEBUGGING_TOOLS */
  }
  PRIMITIVE_RETURN (UNSPECIFIC);
}
