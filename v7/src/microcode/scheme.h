/* -*-C-*-

$Id: scheme.h,v 9.35 1993/06/24 06:22:01 gjr Exp $

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

/* General declarations for the SCode interpreter.  This
   file is INCLUDED by others and contains declarations only. */

/* Certain debuggers cannot really deal with variables in registers.
   When debugging, NO_REGISTERS can be defined. */

#ifdef NO_REGISTERS
#define fast
#else
#define fast			register
#endif

#ifdef ENABLE_DEBUGGING_TOOLS
#define Consistency_Check	true
#define ENABLE_PRIMITIVE_PROFILING
#else
#define Consistency_Check	false
#ifdef ENABLE_PRIMITIVE_PROFILING
#undef ENABLE_PRIMITIVE_PROFILING
#endif
#endif

#ifdef COMPILE_STEPPER
#define Microcode_Does_Stepping	true
#else
#define Microcode_Does_Stepping	false
#endif

#define forward		extern	/* For forward references */

#include <stdio.h>

#include "oscond.h"	/* Identify the operating system */
#include "ansidecl.h"	/* Macros to support ANSI declarations */
#include "dstack.h"	/* Dynamic stack support package */
#include "obstack.h"	/* Obstack package */
#include "config.h"	/* Machine and OS configuration info */
#include "types.h"	/* Type code numbers */
#include "const.h"	/* Various named constants */
#include "object.h"	/* Scheme object representation */
#include "intrpt.h"	/* Interrupt processing macros */
#include "critsec.h"	/* Critical sections */
#include "gc.h"		/* Memory management related macros */
#include "scode.h"	/* Scheme scode representation */
#include "sdata.h"	/* Scheme user data representation */
#include "futures.h"	/* Support macros, etc. for FUTURE */
#include "errors.h"	/* Error code numbers */
#include "returns.h"	/* Return code numbers */
#include "fixobj.h"	/* Format of fixed objects vector */
#include "stack.h"	/* Macros for stack (stacklet) manipulation */
#include "interp.h"	/* Macros for interpreter */

#ifdef butterfly
#include "butterfly.h"
#endif

#include "outf.h"	/* Formatted output for errors */
#include "bkpt.h"	/* Shadows some defaults */
#include "default.h"	/* Defaults for various hooks. */
#include "extern.h"	/* External declarations */
#include "bignum.h"	/* Bignum declarations */
#include "prim.h"	/* Declarations for primitives. */
#include "float.h"	/* Floating-point parameters */
#if (FLT_RADIX != 2)
#include "error: floating point radix not 2!  Arithmetic won't work."
#endif

