/* -*-C-*-

$Id: c.h,v 1.6 1993/11/16 02:34:33 gjr Exp $

Copyright (c) 1992-1993 Massachusetts Institute of Technology

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

#ifndef CMPINTMD_H_INCLUDED
#define CMPINTMD_H_INCLUDED

#include "limits.h"
#include "cmptype.h"

#define COMPILER_PROCESSOR_TYPE			COMPILER_LOSING_C_TYPE

#define WRITE_LABEL_DESCRIPTOR(entry,kind,offset) do			\
{									\
  SCHEME_OBJECT * ent = ((SCHEME_OBJECT *) (entry));			\
									\
  COMPILED_ENTRY_FORMAT_WORD (entry) = (kind);				\
  COMPILED_ENTRY_OFFSET_WORD (entry) =					\
    (WORD_OFFSET_TO_OFFSET_WORD (offset));				\
} while (0)

#define CC_BLOCK_DISTANCE(block,entry)					\
  (((SCHEME_OBJECT *) (entry)) - ((SCHEME_OBJECT *) (block)))

typedef unsigned short format_word;

extern int pc_zero_bits;

#define PC_ZERO_BITS pc_zero_bits

/* arbitrary */
#define ENTRY_PREFIX_LENGTH		2

#define ADJUST_CLOSURE_AT_CALL(entry_point, location) do { } while (0)

#define COMPILED_CLOSURE_ENTRY_SIZE	((sizeof (SCHEME_OBJECT)) * 3)

#define EXTRACT_CLOSURE_ENTRY_ADDRESS(output,location) do		\
{									\
  (output) = (((SCHEME_OBJECT *) (location))[1]);			\
} while (0)

#define STORE_CLOSURE_ENTRY_ADDRESS(input,location) do			\
{									\
  ((SCHEME_OBJECT *) (location))[1] = ((SCHEME_OBJECT) (input));	\
} while (0)

#define MANIFEST_CLOSURE_COUNT(scan)					\
(((COMPILED_ENTRY_OFFSET_WORD (((SCHEME_OBJECT *) (scan)) + 1)) == 0)	\
 ? (COMPILED_ENTRY_FORMAT_WORD (((SCHEME_OBJECT *) (scan)) + 1))	\
 : 1)

#define FIRST_MANIFEST_CLOSURE_ENTRY(scan)				\
(((COMPILED_ENTRY_OFFSET_WORD (((SCHEME_OBJECT *) (scan)) + 1)) == 0)	\
 ? ((char *) (((SCHEME_OBJECT *) (scan)) + 2))				\
 : ((char *) (((SCHEME_OBJECT *) (scan)) + 1)))

/* Trampolines are implemented as tiny compiled code blocks that
   invoke the constant C procedure indexed by the number 0.
 */

#define TRAMPOLINE_ENTRY_SIZE		2	/* Words */

#define TRAMPOLINE_BLOCK_TO_ENTRY	3

#define TRAMPOLINE_ENTRY_POINT(tramp_block)				\
  (((SCHEME_OBJECT *) (tramp_block)) + TRAMPOLINE_BLOCK_TO_ENTRY)

#define TRAMPOLINE_STORAGE(tramp_entry)					\
  ((((SCHEME_OBJECT *) (tramp_entry)) - TRAMPOLINE_BLOCK_TO_ENTRY) +	\
   (2 + TRAMPOLINE_ENTRY_SIZE)) 

/* This depends on knowledge that the trampoline block is the first
   compiled code block.
 */

#define STORE_TRAMPOLINE_ENTRY(entry_address, index) do			\
{									\
  ((SCHEME_OBJECT *) (entry_address))[0] = ((SCHEME_OBJECT) (index));	\
} while (0)

/* An execute cache contains a compiled entry for the callee,
   and a number of arguments (+ 1).
 */

#define EXECUTE_CACHE_ENTRY_SIZE        2

#define EXTRACT_EXECUTE_CACHE_ARITY(target, address) do			\
{									\
  (target) = ((long) (((SCHEME_OBJECT *) (address))[1]));		\
} while (0)

#define EXTRACT_EXECUTE_CACHE_SYMBOL(target, address) do		\
{									\
  (target) = (((SCHEME_OBJECT *) (address))[0]);			\
} while (0)

#define EXTRACT_EXECUTE_CACHE_ADDRESS(target, address) do		\
{									\
  (target) = (((SCHEME_OBJECT *) (address)) [0]);			\
} while (0)

#define STORE_EXECUTE_CACHE_ADDRESS(address, entry) do			\
{									\
  ((SCHEME_OBJECT *) (address))[0] = ((SCHEME_OBJECT) (entry));		\
} while (0)

#define STORE_EXECUTE_CACHE_CODE(address) do { } while (0)

extern void EXFUN (interface_initialize, (void));

#define ASM_RESET_HOOK() interface_initialize ()

/* Derived parameters and macros.

   These macros expect the above definitions to be meaningful.
   If they are not, the macros below may have to be changed as well.
 */

#define COMPILED_ENTRY_OFFSET_WORD(entry) (((format_word *) (entry)) [-1])
#define COMPILED_ENTRY_FORMAT_WORD(entry) (((format_word *) (entry)) [-2])

/* The next one assumes 2's complement integers....*/
#define CLEAR_LOW_BIT(word)                     ((word) & ((unsigned long) -2))
#define OFFSET_WORD_CONTINUATION_P(word)        (((word) & 1) != 0)

#define WORD_OFFSET_TO_OFFSET_WORD(words)	((words) << 1)

#define BYTE_OFFSET_TO_OFFSET_WORD(bytes)				\
  WORD_OFFSET_TO_OFFSET_WORD ((bytes) / (sizeof (SCHEME_OBJECT)))

#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)				\
  ((sizeof (SCHEME_OBJECT)) * ((CLEAR_LOW_BIT (offset_word)) >> 1))

#define MAKE_OFFSET_WORD(entry, block, continue)                        \
  ((BYTE_OFFSET_TO_OFFSET_WORD(((char *) (entry)) -                     \
                               ((char *) (block)))) |                   \
   ((continue) ? 1 : 0))

#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) >> 1)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) << 1)

/* The first entry in a cc block is preceeded by 2 headers (block and nmv),
   a format word and a gc offset word.   See the early part of the
   TRAMPOLINE picture, above.
 */

#define CC_BLOCK_FIRST_ENTRY_OFFSET                                     \
  (2 * ((sizeof(SCHEME_OBJECT)) + (sizeof(format_word))))

/* Format words */

#define FORMAT_BYTE_EXPR                0xFF
#define FORMAT_BYTE_COMPLR              0xFE
#define FORMAT_BYTE_CMPINT              0xFD
#define FORMAT_BYTE_DLINK               0xFC
#define FORMAT_BYTE_RETURN              0xFB

#define FORMAT_WORD_EXPR        (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_EXPR))
#define FORMAT_WORD_CMPINT      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_CMPINT))
#define FORMAT_WORD_RETURN      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_RETURN))

/* This assumes that a format word is at least 16 bits,
   and the low order field is always 8 bits.
 */

#define MAKE_FORMAT_WORD(field1, field2)                                \
  (((field1) << 8) | ((field2) & 0xff))

#define SIGN_EXTEND_FIELD(field, size)                                  \
  (((field) & ((1 << (size)) - 1)) |                                    \
   ((((field) & (1 << ((size) - 1))) == 0) ? 0 :                        \
    ((-1) << (size))))

#define FORMAT_WORD_LOW_BYTE(word)                                      \
  (SIGN_EXTEND_FIELD ((((unsigned long) (word)) & 0xff), 8))

#define FORMAT_WORD_HIGH_BYTE(word)					\
  (SIGN_EXTEND_FIELD							\
   ((((unsigned long) (word)) >> 8),					\
    (((sizeof (format_word)) * CHAR_BIT) - 8)))

#define COMPILED_ENTRY_FORMAT_HIGH(addr)                                \
  (FORMAT_WORD_HIGH_BYTE (COMPILED_ENTRY_FORMAT_WORD (addr)))

#define COMPILED_ENTRY_FORMAT_LOW(addr)                                 \
  (FORMAT_WORD_LOW_BYTE (COMPILED_ENTRY_FORMAT_WORD (addr)))

#define FORMAT_BYTE_FRAMEMAX            0x7f

#define COMPILED_ENTRY_MAXIMUM_ARITY    COMPILED_ENTRY_FORMAT_LOW
#define COMPILED_ENTRY_MINIMUM_ARITY    COMPILED_ENTRY_FORMAT_HIGH

#endif /* CMPINTMD_H_INCLUDED */
