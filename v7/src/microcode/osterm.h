/* -*-C-*-

$Id: osterm.h,v 1.10 1993/04/19 08:28:05 cph Exp $

Copyright (c) 1990-93 Massachusetts Institute of Technology

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

#ifndef SCM_OSTERM_H
#define SCM_OSTERM_H

#include "os.h"

extern Tchannel EXFUN (arg_channel, (int));
extern Tchannel EXFUN (arg_terminal, (int));

extern unsigned int EXFUN (OS_terminal_get_ispeed, (Tchannel channel));
extern unsigned int EXFUN (OS_terminal_get_ospeed, (Tchannel channel));
extern void EXFUN
  (OS_terminal_set_ispeed, (Tchannel channel, unsigned int baud));
extern void EXFUN
  (OS_terminal_set_ospeed, (Tchannel channel, unsigned int baud));
extern unsigned int EXFUN (arg_baud_index, (unsigned int argument));
extern unsigned int EXFUN (OS_baud_index_to_rate, (unsigned int index));
extern int EXFUN (OS_baud_rate_to_index, (unsigned int rate));
extern unsigned int EXFUN (OS_terminal_state_size, (void));
extern void EXFUN (OS_terminal_get_state, (Tchannel channel, PTR statep));
extern void EXFUN (OS_terminal_set_state, (Tchannel channel, PTR statep));
extern int EXFUN (OS_terminal_cooked_output_p, (Tchannel channel));
extern void EXFUN (OS_terminal_raw_output, (Tchannel channel));
extern void EXFUN (OS_terminal_cooked_output, (Tchannel channel));
extern int EXFUN (OS_terminal_buffered_p, (Tchannel channel));
extern void EXFUN (OS_terminal_buffered, (Tchannel channel));
extern void EXFUN (OS_terminal_nonbuffered, (Tchannel channel));
extern void EXFUN (OS_terminal_flush_input, (Tchannel channel));
extern void EXFUN (OS_terminal_flush_output, (Tchannel channel));
extern void EXFUN (OS_terminal_drain_output, (Tchannel channel));
extern int EXFUN (OS_job_control_p, (void));
extern int EXFUN (OS_have_ptys_p, (void));

#endif /* SCM_OSTERM_H */
