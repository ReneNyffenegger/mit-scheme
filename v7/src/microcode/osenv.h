/* -*-C-*-

$Id: osenv.h,v 1.3 1993/01/12 19:48:12 gjr Exp $

Copyright (c) 1990-1993 Massachusetts Institute of Technology

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

#ifndef SCM_OSENV_H
#define SCM_OSENV_H

#include "os.h"

struct time_structure
{
  unsigned int year;
  unsigned int month;
  unsigned int day;
  unsigned int hour;
  unsigned int minute;
  unsigned int second;
  unsigned int day_of_week;
};

extern time_t EXFUN (OS_encoded_time, ());
extern void EXFUN (OS_decode_time, (time_t, struct time_structure * ts));
extern time_t EXFUN (OS_encode_time, (struct time_structure * ts));
extern clock_t EXFUN (OS_process_clock, (void));
extern clock_t EXFUN (OS_real_time_clock, (void));
extern void EXFUN (OS_process_timer_set, (clock_t first, clock_t interval));
extern void EXFUN (OS_process_timer_clear, (void));
extern void EXFUN (OS_real_timer_set, (clock_t first, clock_t interval));
extern void EXFUN (OS_real_timer_clear, (void));
extern CONST char * EXFUN (OS_working_dir_pathname, (void));
extern void EXFUN (OS_set_working_dir_pathname, (CONST char * name));

#endif /* SCM_OSENV_H */
