/* -*-C-*-
   System file for HP-UX

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/s/Attic/hpux.h,v 1.7 1990/10/16 20:57:00 cph Exp $

Copyright (c) 1989, 1990 Massachusetts Institute of Technology

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

#define HAVE_TERMINFO

/* Define HAVE_STARBASE_GRAPHICS if you want Starbase graphics support. */
/* #define HAVE_STARBASE_GRAPHICS */

/* No special libraries are needed for debugging. */
#define LIB_DEBUG

#ifndef INSTALL_PROGRAM
#define INSTALL_PROGRAM cp
#endif

/* If the compiler defines __STDC__ this macro must also be
   defined or the include files don't define many necessary symbols.
   In any case this definition does no harm. */
#define C_SWITCH_SYSTEM -D_HPUX -D_HPUX_SOURCE
