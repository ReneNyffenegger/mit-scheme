/* -*-C-*-

$Id: uxselect.h,v 1.3 1993/03/10 17:55:54 cph Exp $

Copyright (c) 1991-93 Massachusetts Institute of Technology

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

#ifndef SCM_UXSELECT_H
#define SCM_UXSELECT_H

enum select_input
{
  select_input_argument,
  select_input_other,
  select_input_none,
  select_input_process_status,
  select_input_interrupt
};

extern CONST int UX_have_select_p;
extern enum select_input EXFUN (UX_select_input, (int fd, int blockp));
extern unsigned int EXFUN (UX_select_registry_size, (void));
extern unsigned int EXFUN (UX_select_registry_lub, (void));
extern void EXFUN (UX_select_registry_clear_all, (PTR fds));
extern void EXFUN (UX_select_registry_set, (PTR fds, unsigned int fd));
extern void EXFUN (UX_select_registry_clear, (PTR fds, unsigned int fd));
extern int EXFUN (UX_select_registry_is_set, (PTR fds, unsigned int fd));
extern enum select_input EXFUN
  (UX_select_registry_test, (PTR input_fds, PTR output_fds, int blockp));

#endif /* SCM_UXSELECT_H */
