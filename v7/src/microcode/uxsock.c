/* -*-C-*-

$Id: uxsock.c,v 1.12 1993/09/09 18:21:59 gjr Exp $

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

#include "ux.h"
#include "osio.h"

#ifdef HAVE_SOCKETS

#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#ifdef HAVE_UNIX_SOCKETS
#include <sys/un.h>
#endif
#include "uxsock.h"
#include "uxio.h"
#include "prims.h"
#include "limits.h"

extern struct servent * EXFUN (getservbyname, (CONST char *, CONST char *));
extern struct hostent * EXFUN (gethostbyname, (CONST char *));

Tchannel
DEFUN (OS_open_tcp_stream_socket, (host, port), char * host AND int port)
{
  int s;
  STD_UINT_SYSTEM_CALL
    (syscall_socket, s, (UX_socket (AF_INET, SOCK_STREAM, 0)));
  {
    struct sockaddr_in address;
    (address . sin_family) = AF_INET;
    {
      char * scan = ((char*) (& (address . sin_addr)));
      char * end = (scan + (sizeof (address . sin_addr)));
      while (scan < end)
	(*scan++) = (*host++);
    }
    (address . sin_port) = port;
    STD_VOID_SYSTEM_CALL
      (syscall_connect, (UX_connect (s,
				     ((struct sockaddr *) (& address)),
				     (sizeof (address)))));
  }
  MAKE_CHANNEL (s, channel_type_tcp_stream_socket, return);
}

int
DEFUN (OS_get_service_by_name, (service_name, protocol_name),
       CONST char * service_name AND
       CONST char * protocol_name)
{
  struct servent * entry = (UX_getservbyname (service_name, protocol_name));
  return ((entry == 0) ? (-1) : (entry -> s_port));
}

unsigned int
DEFUN_VOID (OS_host_address_length)
{
  return (sizeof (struct in_addr));
}

char **
DEFUN (OS_get_host_by_name, (host_name), CONST char * host_name)
{
  struct hostent * entry = (UX_gethostbyname (host_name));
  if (entry == 0)
    return (0);
#ifndef USE_HOSTENT_ADDR
  return (entry -> h_addr_list);
#else
  {
    static char * addresses [2];
    (addresses[0]) = (entry -> h_addr);
    (addresses[1]) = 0;
    return (addresses);
  }
#endif
}

Tchannel
DEFUN (OS_open_unix_stream_socket, (filename), CONST char * filename)
{
#ifdef HAVE_UNIX_SOCKETS
  int s;
  extern char * EXFUN (strncpy, (char *, CONST char *, size_t));
  STD_UINT_SYSTEM_CALL
    (syscall_socket, s, (UX_socket (AF_UNIX, SOCK_STREAM, 0)));
  {
    struct sockaddr_un address;
    (address . sun_family) = AF_UNIX;
    strncpy ((address . sun_path), filename, (sizeof (address . sun_path)));
    STD_VOID_SYSTEM_CALL
      (syscall_connect, (UX_connect (s,
				     ((struct sockaddr *) (& address)),
				     (sizeof (address)))));
  }
  MAKE_CHANNEL (s, channel_type_unix_stream_socket, return);
#else /* not HAVE_UNIX_SOCKETS */
  error_unimplemented_primitive ();
  return (NO_CHANNEL);
#endif /* not HAVE_UNIX_SOCKETS */
}

#ifndef SOCKET_LISTEN_BACKLOG
#define SOCKET_LISTEN_BACKLOG 5
#endif

Tchannel
DEFUN (OS_open_server_socket, (port, ArgNo), unsigned int port AND int ArgNo)
{
  int s;

  if (((sizeof (unsigned int)) >
       (sizeof (((struct sockaddr_in *) 0)->sin_port))) &&
      (port >= (1 << (CHAR_BIT
		      * (sizeof (((struct sockaddr_in *) 0)->sin_port))))))
    error_bad_range_arg(ArgNo);    
  STD_UINT_SYSTEM_CALL
    (syscall_socket, s, (UX_socket (AF_INET, SOCK_STREAM, 0)));
  {
    struct sockaddr_in address;
    (address . sin_family) = AF_INET;
    (address . sin_addr . s_addr) = INADDR_ANY;
    (address . sin_port) = port;
    STD_VOID_SYSTEM_CALL
      (syscall_bind, (UX_bind (s,
			       ((struct sockaddr *) (& address)),
			       (sizeof (struct sockaddr_in)))));
  }
  STD_VOID_SYSTEM_CALL
    (syscall_listen, (UX_listen (s, SOCKET_LISTEN_BACKLOG)));
  MAKE_CHANNEL (s, channel_type_tcp_server_socket, return);
}

Tchannel
DEFUN (OS_server_connection_accept, (channel, peer_host, peer_port),
       Tchannel channel AND
       char * peer_host AND
       int * peer_port)
{
  static struct sockaddr_in address;
  int address_length = (sizeof (struct sockaddr_in));
  int s;

  while ((s = (UX_accept ((CHANNEL_DESCRIPTOR (channel)),
			  ((struct sockaddr *) (& address)),
			  (&address_length))))
	 < 0)
  {
    if (errno != EINTR)
    {
#ifdef EAGAIN
      if (errno == EAGAIN)
	return (NO_CHANNEL);
#endif
#ifdef EWOULDBLOCK
      if (errno == EWOULDBLOCK)
	return (NO_CHANNEL);
#endif
      error_system_call (errno, syscall_accept);
    }
  }
  if (peer_host != 0)
    {
      char * scan = ((char *) (& (address . sin_addr)));
      char * end = (scan + (sizeof (address . sin_addr)));
      while (scan < end)
	(*peer_host++) = (*scan++);
    }
  if (peer_port != 0)
    (*peer_port) = (address . sin_port);
  MAKE_CHANNEL (s, channel_type_tcp_stream_socket, return);
}

#else /* not HAVE_SOCKETS */

Tchannel
DEFUN (OS_open_tcp_stream_socket, (host, port), char * host AND int port)
{
  error_unimplemented_primitive ();
  return (NO_CHANNEL);
}

int
DEFUN (OS_get_service_by_name, (service_name, protocol_name),
       CONST char * service_name AND
       CONST char * protocol_name)
{
  error_unimplemented_primitive ();
  return (-1);
}

unsigned int
DEFUN_VOID (OS_host_address_length)
{
  error_unimplemented_primitive ();
  return (0);
}

char **
DEFUN (OS_get_host_by_name, (host_name), CONST char * host_name)
{
  error_unimplemented_primitive ();
  return (0);
}

Tchannel
DEFUN (OS_open_unix_stream_socket, (filename), CONST char * filename)
{
  error_unimplemented_primitive ();
  return (NO_CHANNEL);
}

Tchannel
DEFUN (OS_open_server_socket, (port, ArgNo), unsigned int port AND int ArgNo)
{
  error_unimplemented_primitive ();
  return (NO_CHANNEL);
}

Tchannel
DEFUN (OS_server_connection_accept, (channel, peer_host, peer_port),
       Tchannel channel AND
       char * peer_host AND
       int * peer_port)
{
  error_unimplemented_primitive ();
  return (NO_CHANNEL);
}

#endif /* not HAVE_SOCKETS */
