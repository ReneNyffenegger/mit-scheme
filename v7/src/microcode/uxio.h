/* -*-C-*-

$Id: uxio.h,v 1.4 1994/11/14 00:54:19 cph Exp $

Copyright (c) 1990-94 Massachusetts Institute of Technology

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

#ifndef SCM_UXIO_H
#define SCM_UXIO_H

#include "osio.h"

struct channel
{
  int descriptor;
  enum channel_type type;
  unsigned int internal : 1;
  unsigned int nonblocking : 1;
};

#define MARK_CHANNEL_CLOSED(channel) ((CHANNEL_DESCRIPTOR (channel)) = (-1))
#define CHANNEL_CLOSED_P(channel) ((CHANNEL_DESCRIPTOR (channel)) < 0)
#define CHANNEL_OPEN_P(channel) ((CHANNEL_DESCRIPTOR (channel)) >= 0)
#define CHANNEL_DESCRIPTOR(channel) ((channel_table [(channel)]) . descriptor)
#define CHANNEL_TYPE(channel) ((channel_table [(channel)]) . type)
#define CHANNEL_INTERNAL(channel) ((channel_table [(channel)]) . internal)
#define CHANNEL_NONBLOCKING(channel)					\
  ((channel_table [(channel)]) . nonblocking)

#define MAKE_CHANNEL(descriptor, type, receiver)			\
{									\
  Tchannel MAKE_CHANNEL_temp = (channel_allocate ());			\
  (CHANNEL_DESCRIPTOR (MAKE_CHANNEL_temp)) = (descriptor);		\
  (CHANNEL_TYPE (MAKE_CHANNEL_temp)) = (type);				\
  (CHANNEL_INTERNAL (MAKE_CHANNEL_temp)) = 0;				\
  (CHANNEL_NONBLOCKING (MAKE_CHANNEL_temp)) = 0;			\
  receiver (MAKE_CHANNEL_temp);						\
}

extern struct channel * channel_table;
extern Tchannel EXFUN (channel_allocate, (void));

#endif /* SCM_UXIO_H */
