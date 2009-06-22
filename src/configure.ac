dnl Process this file with autoconf to produce a configure script.

AC_INIT([MIT/GNU Scheme], [7.7.91], [bug-mit-scheme@gnu.org], [mit-scheme])
AC_REVISION([$Id: configure.ac,v 1.20 2008/01/30 20:01:40 cph Exp $])
AC_CONFIG_SRCDIR([microcode/boot.c])
AC_PROG_MAKE_SET

AC_COPYRIGHT(
[Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008 Massachusetts Institute of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.
])

AC_ARG_ENABLE([native-code],
    AS_HELP_STRING([--enable-native-code],
	[Support native compiled code if available [[yes]]]))
: ${enable_native_code='yes'}

case ${enable_native_code} in
c)
    ALL_TARGET=all-liarc
    INSTALL_COM=:
    INSTALL_LIARC_BUNDLES=install-liarc-bundles
    AUXDIR_NAME=mit-scheme-c
    ;;
*)
    ALL_TARGET=all-native
    INSTALL_COM='$(INSTALL_DATA)'
    INSTALL_LIARC_BUNDLES=
    AUXDIR_NAME=mit-scheme
    ;;
esac
AUXDIR='$(libdir)'/${AUXDIR_NAME}

AC_SUBST([ALL_TARGET])
AC_SUBST([INSTALL_COM])
AC_SUBST([INSTALL_LIARC_BUNDLES])
AC_SUBST([AUXDIR])

AC_PROG_INSTALL
AC_PROG_LN_S
if test "`${INSTALL} --help 2> /dev/null | fgrep -e --preserve-timestamps`"
then
    INSTALL="${INSTALL} --preserve-timestamps"
fi

etc/create-makefiles.sh "${enable_native_code}"

AC_CONFIG_SUBDIRS([microcode compiler])
AC_CONFIG_FILES([
Makefile
6001/Makefile
compiler/Makefile
cref/Makefile
edwin/Makefile
imail/Makefile
runtime/Makefile
sf/Makefile
sos/Makefile
ssp/Makefile
star-parser/Makefile
win32/Makefile
xdoc/Makefile
xml/Makefile
])
AC_OUTPUT

if test x${enable_native_code} = xc; then
    BN=liarc-cc
    (cd lib; rm -f ${BN}; ${LN_S} ../microcode/${BN} .)
    BN=liarc-ld
    (cd lib; rm -f ${BN}; ${LN_S} ../microcode/${BN} .)
    for BN in star-parser; do
        (cd lib; rm -f ${BN}; ${LN_S} ../${BN} .)
    done
    for BUNDLE in 6001 compiler cref edwin imail sf sos ssp star-parser xdoc xml; do
    	SO=${BUNDLE}.so
	(cd lib/lib; rm -f ${SO}; ${LN_S} ../../${BUNDLE}/${SO} .)
    done
fi