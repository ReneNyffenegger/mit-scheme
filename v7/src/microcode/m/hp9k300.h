/* -*-C-*-
   Machine file for HP9000 series 300 (or 200)

$Id: hp9k300.h,v 1.10 1992/11/18 15:33:39 gjr Exp $

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

/* In the following, it is assumed that the standard C compiler is the
   HP C compiler, and the "alternate" compiler is the GNU C compiler (GCC).
 */

/* Change this to PROC_TYPE_68000 if your machine is a series 200 or a
   model 310. 
 */
#ifndef PROC_TYPE
#define PROC_TYPE PROC_TYPE_68020
#endif /* PROC_TYPE */

/* The M4_SWITCH_MACHINE must contain -DHP if using HP C, -DGCC, if using
   GCC, and nothing special if using PCC.
 */

#if (PROC_TYPE == PROC_TYPE_68020)

#ifndef ALTERNATE_CC
#define M4_SWITCH_MACHINE -DMC68881 -DTYPE_CODE_LENGTH=6 -DHP
#else
#define M4_SWITCH_MACHINE -DMC68881 -DTYPE_CODE_LENGTH=6 -DGCC
#endif

#define AS_SWITCH_MACHINE +x -V 3

#else
#define M4_SWITCH_MACHINE
#define AS_SWITCH_MACHINE +X
#endif

#ifndef ALTERNATE_CC

/* For hp-ux version 6.5 or 7.0, uncomment this definition.  */
/* The full optimizer breaks some of the files in those versions.  */
/* #define C_OPTIMIZE_SWITCH +O1 */

#define C_SWITCH_MACHINE -Wp,-H512000
/* For hp-ux prior to 8.0, add the following switches to the previous line:
   -Wc,-Nt30000,-Ns3000  */

#else

#define C_SWITCH_MACHINE

#endif

#if defined(HAVE_STARBASE_GRAPHICS) && !defined(STARBASE_DEVICE_DRIVERS)
/* Add additional Starbase device drivers here. */
#define STARBASE_DEVICE_DRIVERS -ldd300h
#endif
