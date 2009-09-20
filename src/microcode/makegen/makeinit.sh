#!/bin/sh

# Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
#     1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
#     2005, 2006, 2007, 2008, 2009 Massachusetts Institute of
#     Technology
#
# This file is part of MIT/GNU Scheme.
#
# MIT/GNU Scheme is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# MIT/GNU Scheme is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with MIT/GNU Scheme; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301, USA.

# Script to create "Makefile.in".
# Requires `gcc' and `scheme'.

# generate "config.h".
[ -f Makefile.in ] || touch Makefile.in
./configure --disable-native-code "$@"

# Generate "Makefile.in" from "Makefile.in.in".  Requires "config.h",
# because dependencies are generated by running GCC -M on the source
# files, which refer to "config.h".

${MIT_SCHEME_EXE:=mit-scheme} <<EOF
(begin
  (load "makegen/makegen.scm")
  (generate-makefile))
EOF

# Clean up.
# We need to generate "Makefile" to run the clean,
# but "make distclean" will delete it.
./config.status
make distclean
