/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/boot.c,v 9.40 1987/11/17 08:07:35 jinx Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

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

/* This file contains the code to support startup of
   the SCHEME interpreter.
  
 The command line (when not running a dumped executable version) may 
 take the following forms:

   scheme

   or

   scheme {band-name}

   or

   scheme {filespec}
          {-heap heap-size}
	  {-stack stack-size}
	  {-constant constant-size}
	  {-utabmd utab-filename} or {-utab utab-filename}
          {other arguments ignored by the core microcode}

   with filespec either {-band band-name} or {{-}fasl file-name}
   arguments are optional, numbers are in 1K units.  Default values
   are given above.  The arguments in the long for may appear in any
   order on the command line.  The allocation arguments (heap, stack,
   and constant) are ignored when scheme is an executable image.  A
   warning message is printed if the command line contains them.

   heap-size......number of cells to allocate for user heap; this will
                  be doubled to allow for 2 space GC.
   stack-size.....number of cells for control stack.  This primarily
                  controls maximum depth of recursion.  If the flag
		  USE_STACKLETS is defined, then this controls the
		  size of the stacklets (not the total stack) and
		  thus affects how often new stack segments must
		  be allocated.
   constant-size..number of cells for constant and pure space in the
                  system.
   utab-filename..name of an alternate utabmd file to use.

Additional arguments may exist for particular machines; see CONFIG.H
for details.  They are created by defining a macro Command_Line_Args.

*/

#include "scheme.h"
#include "primitive.h"
#include "version.h"
#include "character.h"
#ifndef islower
#include <ctype.h>
#endif

#define STRING_SIZE 512
#define BLOCKSIZE 1024
#define blocks(n) ((n)*BLOCKSIZE)

/* Utilities for command line parsing */

#define upcase(c) ((islower(c)) ? (toupper(c)) : c)

void
uppercase(to_where, from_where)
     fast char *to_where, *from_where;
{
  fast char c;

  while((c = *from_where++) != '\0')
  {
    *to_where++ = upcase(c);
  }
  *to_where = '\0';
  return;
}

int 
Parse_Option(opt_key, nargs, args, casep)
     char *opt_key, **args;
     Boolean casep;
     int nargs;
{
  int i;
  char key[STRING_SIZE], current[STRING_SIZE];

  if (casep)
  {
    uppercase(key, opt_key);
  }
  else
  {
    strcpy(key, opt_key);
  }
  for(i = 0; i < nargs; i++)
  {
    if (casep)
    {
      uppercase(current, args[i]);
    }
    else
    {
      strcpy(current, args[i]);
    }
    if (strcmp(key, current) == 0)
    {
      return i;
    }
  }
  return NOT_THERE;
}

long
Def_Number(key, nargs, args, def)
     char *key, **args;
     long def;
     int nargs;
{
  int position;
  
  position = Parse_Option(key, nargs, args, true);
  if ((position == NOT_THERE) || (position == (nargs-1)))
  {
    return def;
  }
  else
  {
    return atoi(args[position+1]);
  }
}  

/* Used to test whether it is a dumped executable version */

extern Boolean Was_Scheme_Dumped;
Boolean Was_Scheme_Dumped = false;

/* Exit is done in a different way on some operating systems (eg. VMS)  */

Exit_Scheme_Declarations;

forward void Start_Scheme();
extern void Clear_Memory(), Setup_Memory(), Reset_Memory();

/*
  THE MAIN PROGRAM
 */

main_type
main(argc, argv)
     int argc;
     char **argv;
{
  Boolean FASL_It;
  char *File_Name;
  int Saved_Heap_Size, Saved_Stack_Size, Saved_Constant_Size;
  extern void compiler_initialize();

  FASL_It = false;
  File_Name = NULL;
  Saved_argc = argc;
  Saved_argv = argv;
  Init_Exit_Scheme();

  if (argc > 2)
  {
    int position;

    if (((position = Parse_Option("-band", argc, argv, true))
	 != NOT_THERE) &&
	(position != (argc-1)))
    {
      File_Name = argv[position+1];
    }
    else if ((((position = Parse_Option("-fasl", argc, argv, true))
	      != NOT_THERE) ||
	      ((position = Parse_Option("fasl", argc, argv, true))
	      != NOT_THERE)) &&
	     (position != (argc-1)))
    {
      File_Name = argv[position + 1];
      FASL_It = true;
    }
  }
  else if ((argc == 2) && (argv[1][0] != '-'))
  {
    File_Name = argv[1];
  }

  if (!Was_Scheme_Dumped)
  {
    Heap_Size = HEAP_SIZE;
    Stack_Size = STACK_SIZE;
    Constant_Size = CONSTANT_SIZE;
  }
  else
  {
    Saved_Heap_Size = Heap_Size;
    Saved_Stack_Size = Stack_Size;
    Saved_Constant_Size = Constant_Size;
  }

  Heap_Size = Def_Number("-heap", argc, argv, Heap_Size);
  Stack_Size = Def_Number("-stack", argc, argv, Stack_Size);
  Constant_Size = Def_Number("-constant", argc, argv, Constant_Size);

  if (Was_Scheme_Dumped)
  {
    Boolean warned;

    warned = false;
    printf("Executable Scheme");
    if ((Heap_Size != Saved_Heap_Size)		||
	(Stack_Size != Saved_Stack_Size)	||
	(Constant_Size != Saved_Constant_Size))
    {
      printf(".\n");
      fprintf(stderr,
"Warning: Allocation parameters (heap, stack, and constant) ignored.\n");
      Heap_Size = Saved_Heap_Size;
      Stack_Size = Saved_Stack_Size;
      Constant_Size = Saved_Constant_Size;
      warned = true;
    }
    if (File_Name == NULL)
    {
      if (!warned)
      {
	printf("; ");
      }
      printf("Microcode Version %d.%d\n", VERSION, SUBVERSION);
      OS_Init(true);
      Enter_Interpreter();
    }

/* main continues on the next page */

/* main, continued */

    else
    {
      if (!warned)
      {
	printf(".\n");
      }
      Clear_Memory(blocks(Heap_Size), blocks(Stack_Size),
		   blocks(Constant_Size));
      /* We are reloading from scratch anyway. */
      Was_Scheme_Dumped = false;
      Start_Scheme((FASL_It ? BOOT_FASLOAD : BOOT_LOAD_BAND), File_Name);
    }
  }

  if (File_Name == NULL)
  {
    File_Name = DEFAULT_BAND_NAME;
  }
  Command_Line_Hook();
	  
  Setup_Memory(blocks(Heap_Size), blocks(Stack_Size),
	       blocks(Constant_Size));
  compiler_initialize((long) FASL_It);
  Start_Scheme((FASL_It ? BOOT_FASLOAD : BOOT_LOAD_BAND), File_Name);
}

#define Default_Init_Fixed_Objects(Fixed_Objects)			\
{									\
  Fixed_Objects = make_fixed_objects_vector();				\
}

Pointer
make_fixed_objects_vector()
{
  fast Pointer fixed_objects_vector;
  Pointer Int_Vec, OB_Array, Error, Bad_Object,
          The_Queue, *Dummy_Hist, The_Utilities;
  fast long i;

  /* Interrupt vector */

  Int_Vec = (Make_Pointer (TC_VECTOR, Free));
  *Free++ = (Make_Non_Pointer (TC_MANIFEST_VECTOR,
			       (MAX_INTERRUPT_NUMBER + 2)));
  for (i = 0; (i <= (MAX_INTERRUPT_NUMBER + 1)); i += 1)
  {
    *Free++ = NIL;
  }
  
  /* Error vector is not needed at boot time */

  Error = NIL;

  /* Dummy History Structure */

  History = Make_Dummy_History();
  Dummy_Hist = Make_Dummy_History();

  /* OBArray */

  OB_Array = Make_Pointer(TC_VECTOR, Free);
  *Free++ = Make_Non_Pointer(TC_MANIFEST_VECTOR, OBARRAY_SIZE);
  for (i = 0; i < OBARRAY_SIZE; i++)
  {
    *Free++ = NIL;
  }

  /* Initial empty work queue */

  The_Queue = Make_Pointer(TC_LIST, Free);
  *Free++ = NIL;
  *Free++ = NIL;

  /* Empty utilities vector */

  The_Utilities = Make_Pointer(TC_VECTOR, Free);
  *Free++ = Make_Non_Pointer(TC_MANIFEST_VECTOR, 0);

  /* Cons the FIXED OBJECTS VECTOR */

  fixed_objects_vector = Make_Pointer(TC_VECTOR, Free);

  /* Create the vector with 4 extra slots for expansion and
     debugging.
   */

  *Free++ = Make_Non_Pointer(TC_MANIFEST_VECTOR, (NFixed_Objects + 4));
  for (i=1; i <= (NFixed_Objects + 4); i++)
  {
    *Free++ = NIL;
  }

  /* Initialize components */

  User_Vector_Set(fixed_objects_vector, Non_Object,
		  (Make_Non_Pointer (TC_TRUE, 2)));
  User_Vector_Set(fixed_objects_vector, System_Interrupt_Vector, Int_Vec);
  User_Vector_Set(fixed_objects_vector, System_Error_Vector, Error);
  User_Vector_Set(fixed_objects_vector, OBArray, OB_Array);
  User_Vector_Set(fixed_objects_vector, Dummy_History,
                  Make_Pointer(UNMARKED_HISTORY_TYPE, Dummy_Hist));
  User_Vector_Set(fixed_objects_vector, State_Space_Tag, TRUTH);
  User_Vector_Set(fixed_objects_vector, Bignum_One,
		  Fix_To_Big(Make_Unsigned_Fixnum(1)));
  User_Vector_Set(fixed_objects_vector, Me_Myself, fixed_objects_vector);
  User_Vector_Set(fixed_objects_vector, The_Work_Queue, The_Queue);
  User_Vector_Set(fixed_objects_vector, Utilities_Vector, The_Utilities);
  return fixed_objects_vector;
}

/* Boot Scheme */

void
Start_Scheme(Start_Prim, File_Name)
     int Start_Prim;
     char *File_Name;
{
  extern Pointer make_primitive();
  Pointer FName, Init_Prog, *Fasload_Call, prim;
  fast long i;
  Boolean I_Am_Master;			/* Parallel processor test */

  I_Am_Master = (Start_Prim != BOOT_GET_WORK);
  if (I_Am_Master)
  {
    printf("Scheme Microcode Version %d.%d\n", VERSION, SUBVERSION);
  }
  OS_Init(I_Am_Master);
  if (I_Am_Master)
  {
    for (i = 0; i < FILE_CHANNELS; i++)
    {
      Channels[i] = NULL;
    }
    Init_Fixed_Objects();
  }

/* The initial program to execute is one of
        (SCODE-EVAL (BINARY-FASLOAD <file-name>) SYSTEM-GLOBAL-ENVIRONMENT),
	(LOAD-BAND <file-name>), or
	((GET-WORK))
	depending on the value of Start_Prim.
*/

  FName = C_String_To_Scheme_String(File_Name);
  Fasload_Call = Free;
  switch (Start_Prim)
  {
    case BOOT_FASLOAD:	/* (SCODE-EVAL (BINARY-FASLOAD <file>) GLOBAL-ENV) */
      *Free++ = make_primitive("BINARY-FASLOAD");
      *Free++ = FName;
      Init_Prog = Make_Pointer(TC_PCOMB2, Free);
      *Free++ = make_primitive("SCODE-EVAL");
      *Free++ = Make_Pointer(TC_PCOMB1, Fasload_Call);
      *Free++ = Make_Non_Pointer(GLOBAL_ENV, GO_TO_GLOBAL);
      break;

    case BOOT_LOAD_BAND:	/* (LOAD-BAND <file>) */
      *Free++ = make_primitive("LOAD-BAND");
      *Free++ = FName;
      Init_Prog = Make_Pointer(TC_PCOMB1, Fasload_Call);
      break;

    case BOOT_GET_WORK:		/* ((GET-WORK)) */
      *Free++ = make_primitive("GET-WORK");
      *Free++ = NIL;
      Init_Prog = Make_Pointer(TC_COMBINATION, Free);
      *Free++ = Make_Non_Pointer(TC_MANIFEST_VECTOR, 1);
      *Free++ = Make_Non_Pointer(TC_PCOMB1, Fasload_Call);
      break;

    default:
      fprintf(stderr, "Unknown boot time option: %d\n", Start_Prim);
      Microcode_Termination(TERM_BAD_PRIMITIVE);
      /*NOTREACHED*/
  }

/* Start_Scheme continues on the next page */

/* Start_Scheme, continued */

	/* Setup registers */

  INITIALIZE_INTERRUPTS();
  Env = Make_Non_Pointer(GLOBAL_ENV, 0);
  Trapping = false;
  Return_Hook_Address = NULL;

	/* Give the interpreter something to chew on, and ... */

 Will_Push(CONTINUATION_SIZE);
  Store_Return(RC_END_OF_COMPUTATION);
  Store_Expression(NIL);
  Save_Cont();
 Pushed();

  Store_Expression(Init_Prog);

	/* Go to it! */

  if ((Stack_Pointer <= Stack_Guard) || (Free > MemTop))
  {
    fprintf(stderr, "Configuration won't hold initial data.\n");
    Microcode_Termination(TERM_EXIT);
  }
  Entry_Hook();
  Enter_Interpreter();
  /*NOTREACHED*/
}

Enter_Interpreter()
{
  jmp_buf Orig_Eval_Point;
  Back_To_Eval = (jmp_buf *) Orig_Eval_Point;

  Interpret(Was_Scheme_Dumped);
  fprintf(stderr, "\nThe interpreter returned to top level!\n");
  Microcode_Termination(TERM_EXIT);
  /*NOTREACHED*/
}

term_type
Microcode_Termination(code)
     long code;
{
  extern char *Term_Messages[];
  Pointer Term_Vector;
  long value;

  if ((code != TERM_HALT) &&
      (Valid_Fixed_Obj_Vector()) &&
      (Type_Code(Term_Vector =
		 Get_Fixed_Obj_Slot(Termination_Proc_Vector)) ==
       TC_VECTOR) &&
      (Vector_Length(Term_Vector) > code))
  { 
    extern long death_blow;
    Pointer Handler;

    Handler = User_Vector_Ref(Term_Vector, code);
    if (Handler != NIL)
    {
     Will_Push(CONTINUATION_SIZE + STACK_ENV_EXTRA_SLOTS +
 	       ((code == TERM_NO_ERROR_HANDLER) ? 5 : 4));
      Store_Return(RC_HALT);
      Store_Expression(Make_Unsigned_Fixnum(code));
      Save_Cont();
      if (code == TERM_NO_ERROR_HANDLER)
      {
	Push(MAKE_UNSIGNED_FIXNUM(death_blow));
      }
      Push(Val);			/* Arg 3 */
      Push(Fetch_Env());		/* Arg 2 */
      Push(Fetch_Expression());		/* Arg 1 */
      Push(Handler);			/* The handler function */
      Push(STACK_FRAME_HEADER + ((code == TERM_NO_ERROR_HANDLER) ? 4 : 3));
     Pushed();
      longjmp(*Back_To_Eval, PRIM_NO_TRAP_APPLY);
    }
  }

  putchar('\n');
  if ((code < 0) ||  (code > MAX_ERROR))
  {
    printf("Unknown termination code 0x%x\n", code);
  }
  else
  {
    printf("%s.\n", Term_Messages[code]);
  }

/* Microcode_Termination continues on the next page */

/* Microcode_Termination, continued */

  switch(code)
  {
    case TERM_HALT:
      value = 0;
      break;

    case TERM_END_OF_COMPUTATION:
      Print_Expression(Val, "Final result");
      putchar('\n');
      value = 0;
      break;

    case TERM_NON_EXISTENT_CONTINUATION:
      printf("Return code = 0x%x\n", Fetch_Return());
      goto normal_termination;

    case TERM_GC_OUT_OF_SPACE:
      printf("Memory: required = %d; available = %d\n",
	     Get_Integer(Fetch_Expression()), Space_Before_GC());
      goto normal_termination;

    case TERM_NO_ERROR_HANDLER:
      /* This does not print a back trace because it was printed before
	 getting here irrelevant of the state of Trace_On_Error.
       */
      value = 1;
      break;

    default:
    normal_termination:
      value = 1;
      if (Trace_On_Error)
      {
	printf("\n\n**** Stack trace ****\n\n");
	Back_Trace(stdout);
      }
      break;
  }
  OS_Flush_Output_Buffer();
  OS_Quit();
  Reset_Memory();
  Exit_Hook();
  Exit_Scheme(value);
  /*NOTREACHED*/
}

/* Utility primitives. */

#define IDENTITY_LENGTH 	20		/* Plenty of room */
#define ID_RELEASE		0		/* Scheme system release */
#define ID_MICRO_VERSION	1		/* Microcode version */
#define ID_MICRO_MOD		2		/* Microcode modification */
#define ID_PRINTER_WIDTH	3		/* Width of console (chars) */
#define ID_PRINTER_LENGTH	4		/* Height of console (chars) */
#define ID_NEW_LINE_CHARACTER	5		/* #\Newline */
#define ID_FLONUM_PRECISION	6		/* Flonum mantissa (bits) */
#define ID_FLONUM_EXPONENT	7		/* Flonum exponent (bits) */
#define ID_OS_NAME		8		/* OS name (string) */
#define ID_OS_VARIANT		9		/* OS variant (string) */

Built_In_Primitive (Prim_Microcode_Identify, 0, "MICROCODE-IDENTIFY", 0xE5)
Define_Primitive (Prim_Microcode_Identify, 0, "MICROCODE-IDENTIFY")
{
  Pointer *Result;
  long i;
  Primitive_0_Args ();

  Primitive_GC_If_Needed (IDENTITY_LENGTH + VECTOR_DATA);
  Result = Free;
  *Free++ = (Make_Non_Pointer (TC_MANIFEST_VECTOR, IDENTITY_LENGTH));
  for (i = 0; (i < IDENTITY_LENGTH); i += 1)
  {
    *Free++ = NIL;
  }
  Result[(ID_RELEASE + VECTOR_DATA)]
    = (C_String_To_Scheme_String (RELEASE));
  Result[(ID_MICRO_VERSION + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (VERSION));
  Result[(ID_MICRO_MOD + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (SUBVERSION));
  Result[(ID_PRINTER_WIDTH + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (NColumns ()));
  Result[(ID_PRINTER_LENGTH + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (NLines ()));
  Result[(ID_NEW_LINE_CHARACTER + VECTOR_DATA)]
    = (c_char_to_scheme_char ('\n'));
  Result[(ID_FLONUM_PRECISION + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (FLONUM_MANTISSA_BITS));
  Result[(ID_FLONUM_EXPONENT + VECTOR_DATA)]
    = (Make_Unsigned_Fixnum (FLONUM_EXPT_SIZE));
  Result[(ID_OS_NAME + VECTOR_DATA)]
    = (C_String_To_Scheme_String (OS_Name));
  Result[(ID_OS_VARIANT + VECTOR_DATA)]
    = (C_String_To_Scheme_String (OS_Variant));
  PRIMITIVE_RETURN(Make_Pointer (TC_VECTOR, Result));
}

Built_In_Primitive(Prim_Microcode_Tables_Filename,
		   0, "MICROCODE-TABLES-FILENAME", 0x180)
Define_Primitive(Prim_Microcode_Tables_Filename,
		   0, "MICROCODE-TABLES-FILENAME")
{
  fast char *From, *To;
  char *Prefix, *Suffix;
  fast long Count;
  long position;
  Pointer Result;
  Primitive_0_Args();

  if ((((position = Parse_Option("-utabmd", Saved_argc, Saved_argv, true))
	!= NOT_THERE) &&
       (position != (Saved_argc - 1))) ||
      (((position = Parse_Option("-utab", Saved_argc, Saved_argv, true))
	!= NOT_THERE) &&
       (position != (Saved_argc - 1))))
  {
    Prefix = "";
    Suffix = Saved_argv[position + 1];
  }
  else
  {
    Prefix = SCHEME_SOURCES_PATH;
    Suffix = UCODE_TABLES_FILENAME;
  }

  /* Find the length of the combined string, and allocate. */

  Count = 0;
  for (From = Prefix; *From++ != '\0'; )
  {
    Count += 1;
  }
  for (From = Suffix; *From++ != '\0'; )
  {
    Count += 1;
  }
  Primitive_GC_If_Needed(STRING_CHARS +
			 ((Count + sizeof(Pointer)) /
			  sizeof(Pointer)));

  /* Append both substrings. */

  Result = Make_Pointer(TC_CHARACTER_STRING, Free);
  To = (char *) &(Free[STRING_CHARS]);
  for (From = &(Prefix[0]); *From != '\0'; )
  {
    *To++ = *From++;
  }
  for (From = &(Suffix[0]); *From != '\0'; )
  {
    *To++ = *From++;
  }
  *To = '\0';
  Free += STRING_CHARS + ((Count + sizeof(Pointer)) / sizeof(Pointer));
  Vector_Set(Result, STRING_LENGTH, ((Pointer) Count));
  Vector_Set(Result, STRING_HEADER,
    Make_Non_Pointer(TC_MANIFEST_NM_VECTOR,
		     ((Free - Get_Pointer(Result)) - 1)));
  PRIMITIVE_RETURN(Result);
}

Built_In_Primitive(Prim_Get_Command_Line, 0, "GET-COMMAND-LINE", 0x25)
Define_Primitive(Prim_Get_Command_Line, 0, "GET-COMMAND-LINE")
{
  fast int i;
  Pointer result;
  Primitive_0_Args();

  Primitive_GC_If_Needed(1 + Saved_argc);

  result = Make_Pointer(TC_VECTOR, Free);
  *Free = Make_Non_Pointer(TC_MANIFEST_VECTOR, Saved_argc);
  Free += (1 + Saved_argc);

  for (i = 0; i < Saved_argc; i++)
  {
    User_Vector_Set(result, i, C_String_To_Scheme_String(Saved_argv[i]));
  }
  PRIMITIVE_RETURN(result);
}
