/* -*-C-*-
   Machine file for DEC Vax computers

$Id: vax.h,v 1.5 1992/11/18 15:56:17 gjr Exp $

Copyright (c) 1989-1992 Massachusetts Institute of Technology

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

/* This causes problems when generating xmakefile. */

#ifdef vax
#undef vax
#endif

#ifndef PROC_TYPE
#define PROC_TYPE PROC_TYPE_VAX
#endif /* PROC_TYPE */

/* The M4_SWITCH_MACHINE must contain -P "define(GCC,1)", if using GCC,
   -P "define(VMS,1)" if preparing the files for VMS Vax C,
    and nothing special if using PCC.
 */

#ifndef ALTERNATE_CC
#define M4_SWITCH_MACHINE -P "define(TYPE_CODE_LENGTH,6)"
#else
#define M4_SWITCH_MACHINE -P "define(TYPE_CODE_LENGTH,6)" -P "define(GCC,1)"
#endif

#define C_SWITCH_MACHINE
