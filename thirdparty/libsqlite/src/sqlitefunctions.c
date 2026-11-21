/* OXT-Beyond (Seth Morrow, 2026): the SQL functions that revDB's SQLite
   driver adds to every connection it opens (SqliteDatabase::connect, in
   sqlitedataset.cpp). All of them are SQLite's own code, which is in the
   public domain:

   - the math functions: sqrt(), pi(), exp(), ln(), log(), log2(), log10(),
     pow() and power(), mod(), ceil() and ceiling(), floor(), trunc(),
     radians(), degrees(), and the trigonometric and hyperbolic functions,
     whose code below is SQLite 3.54.1's (src/func.c), unchanged;
   - regexp() and regexpi(), from SQLite 3.54.1's regexp extension
     (../ext/misc/regexp.c, unchanged). SQLite reads "X REGEXP Y" as
     regexp(Y, X), but has no regexp() of its own.

   LiveCode's SQLite, and OXT-Beyond's before 0.2.8-dp.3, had none of
   them: a query that used one failed with "no such function".

   They are not built into SQLite (SQLITE_ENABLE_MATH_FUNCTIONS), so that
   a stack that brings its own keeps them. A stack may open a database
   with revOpenDatabase's "extensions" option and load an extension with
   SELECT load_extension(...), for the math functions above or for REGEXP;
   extension-functions.c, the best known, has a log() that is the natural
   logarithm where SQLite's is base 10, and a ceil() that gives an
   integer. The extension adds its functions while that SELECT runs, and
   while a statement runs SQLite refuses to replace a function, built-in
   or added, that has the same name, number of arguments and text
   encoding (SQLITE_BUSY): the stack would quietly get SQLite's log()
   instead of its own. So each function here is added for any number of
   arguments (-1) and checks the number itself, as SQLite checks a
   built-in function's when it prepares a statement. A function that an
   extension adds with a fixed number of arguments is then another
   function to SQLite, which it adds without complaint and prefers for
   every call with that number. extension-functions.c and the REGEXP
   extensions add theirs with a fixed number (REGEXP always passes two);
   only one that added one of these names for any number of arguments
   would still be refused.

   tools/ci/tests/test_thirdparty_libraries.py holds this file to SQLite's
   code and to its table of built-in functions, the answers to those of
   SQLite's built-in math functions, and a loaded extension's functions
   to taking the place of these. */

/* regexp.c calls SQLite's functions directly, as code built into SQLite
   does, not through the table that a loaded extension is handed */
#define SQLITE_CORE 1

#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>

#include "sqlite3.h"
#include "sqlitefunctions.h"

/* Two macros of SQLite's internal header (sqliteInt.h): logFunc below
   reads its user data with the one, and oxt_sqlite_add_functions() makes
   that data with the other, as SQLite's table of built-in functions does */
#define SQLITE_INT_TO_PTR(X)  ((void*)(intptr_t)(X))
#define SQLITE_PTR_TO_INT(X)  ((int)(intptr_t)(X))

/* SQLite builds the code below in when SQLITE_ENABLE_MATH_FUNCTIONS is
   defined; it is here, in this file alone (sqlite3.c is compiled without
   it, so SQLite has no built-in math functions) */
#define SQLITE_ENABLE_MATH_FUNCTIONS 1

/******** SQLite 3.54.1, src/func.c: the math functions, unchanged ********/
/* Mathematical Constants */
#ifndef M_PI
# define M_PI   3.141592653589793238462643383279502884
#endif
#ifndef M_LN10
# define M_LN10 2.302585092994045684017991454684364208
#endif
#ifndef M_LN2
# define M_LN2  0.693147180559945309417232121458176568
#endif


/* Extra math functions that require linking with -lm
*/
#ifdef SQLITE_ENABLE_MATH_FUNCTIONS
/*
** Implementation SQL functions:
**
**   ceil(X)
**   ceiling(X)
**   floor(X)
**
** The sqlite3_user_data() pointer is a pointer to the libm implementation
** of the underlying C function.
*/
static void ceilingFunc(
  sqlite3_context *context,
  int argc,
  sqlite3_value **argv
){
  assert( argc==1 );
  switch( sqlite3_value_numeric_type(argv[0]) ){
    case SQLITE_INTEGER: {
       sqlite3_result_int64(context, sqlite3_value_int64(argv[0]));
       break;
    }
    case SQLITE_FLOAT: {
       double (*x)(double) = (double(*)(double))sqlite3_user_data(context);
       sqlite3_result_double(context, x(sqlite3_value_double(argv[0])));
       break;
    }
    default: {
       break;
    }
  }
}

/*
** On some systems, ceil() and floor() are intrinsic function.  You are
** unable to take a pointer to these functions.  Hence, we here wrap them
** in our own actual functions.
*/
static double xCeil(double x){ return ceil(x); }
static double xFloor(double x){ return floor(x); }

/*
** Some systems do not have log2() and log10() in their standard math
** libraries.
*/
#if defined(HAVE_LOG10) && HAVE_LOG10==0
# define log10(X) (0.4342944819032517867*log(X))
#endif
#if defined(HAVE_LOG2) && HAVE_LOG2==0
# define log2(X) (1.442695040888963456*log(X))
#endif


/*
** Implementation of SQL functions:
**
**   ln(X)       - natural logarithm
**   log(X)      - log X base 10
**   log10(X)    - log X base 10
**   log(B,X)    - log X base B
*/
static void logFunc(
  sqlite3_context *context,
  int argc,
  sqlite3_value **argv
){
  double x, b, ans;
  assert( argc==1 || argc==2 );
  switch( sqlite3_value_numeric_type(argv[0]) ){
    case SQLITE_INTEGER:
    case SQLITE_FLOAT:
      x = sqlite3_value_double(argv[0]);
      if( x<=0.0 ) return;
      break;
    default:
      return;
  }
  if( argc==2 ){
    switch( sqlite3_value_numeric_type(argv[0]) ){
      case SQLITE_INTEGER:
      case SQLITE_FLOAT:
        b = log(x);
        if( b<=0.0 ) return;
        x = sqlite3_value_double(argv[1]);
        if( x<=0.0 ) return;
        break;
     default:
        return;
    }
    ans = log(x)/b;
  }else{
    switch( SQLITE_PTR_TO_INT(sqlite3_user_data(context)) ){
      case 1:
        ans = log10(x);
        break;
      case 2:
        ans = log2(x);
        break;
      default:
        ans = log(x);
        break;
    }
  }
  sqlite3_result_double(context, ans);
}

/*
** Functions to converts degrees to radians and radians to degrees.
*/
static double degToRad(double x){ return x*(M_PI/180.0); }
static double radToDeg(double x){ return x*(180.0/M_PI); }

/*
** Implementation of 1-argument SQL math functions:
**
**   exp(X)  - Compute e to the X-th power
*/
static void math1Func(
  sqlite3_context *context,
  int argc,
  sqlite3_value **argv
){
  int type0;
  double v0, ans;
  double (*x)(double);
  assert( argc==1 );
  type0 = sqlite3_value_numeric_type(argv[0]);
  if( type0!=SQLITE_INTEGER && type0!=SQLITE_FLOAT ) return;
  v0 = sqlite3_value_double(argv[0]);
  x = (double(*)(double))sqlite3_user_data(context);
  ans = x(v0);
  sqlite3_result_double(context, ans);
}

/*
** Implementation of 2-argument SQL math functions:
**
**   power(X,Y)  - Compute X to the Y-th power
*/
static void math2Func(
  sqlite3_context *context,
  int argc,
  sqlite3_value **argv
){
  int type0, type1;
  double v0, v1, ans;
  double (*x)(double,double);
  assert( argc==2 );
  type0 = sqlite3_value_numeric_type(argv[0]);
  if( type0!=SQLITE_INTEGER && type0!=SQLITE_FLOAT ) return;
  type1 = sqlite3_value_numeric_type(argv[1]);
  if( type1!=SQLITE_INTEGER && type1!=SQLITE_FLOAT ) return;
  v0 = sqlite3_value_double(argv[0]);
  v1 = sqlite3_value_double(argv[1]);
  x = (double(*)(double,double))sqlite3_user_data(context);
  ans = x(v0, v1);
  sqlite3_result_double(context, ans);
}

/*
** Implementation of 0-argument pi() function.
*/
static void piFunc(
  sqlite3_context *context,
  int argc,
  sqlite3_value **argv
){
  assert( argc==0 );
  (void)argv;
  sqlite3_result_double(context, M_PI);
}

#endif /* SQLITE_ENABLE_MATH_FUNCTIONS */
/******************** End of SQLite 3.54.1, src/func.c ********************/

/* SQLite 3.54.1's regexp extension, unchanged: re_sql_func() is both its
   regexp() and its regexpi(), which ignores the case of ASCII letters
   when its user data is not null. (Its sqlite3_regexp_init(), which would
   add them for two arguments only, is not called.) */
#include "../ext/misc/regexp.c"

/* oxt_sql_<name>(): the SQL function <name>, which takes from nMin to nMax
   arguments. As SQLite checks the number for a built-in function when it
   prepares a statement, with the same words, this checks it when the
   function is called, then calls SQLite's implementation of it. */
#define OXT_SQL_FUNCTION(zName, nMin, nMax, xImpl) \
	static void oxt_sql_##zName(sqlite3_context *pContext, int argc, \
	                            sqlite3_value **argv) \
	{ \
		if (argc < (nMin) || argc > (nMax)) \
		{ \
			sqlite3_result_error(pContext, "wrong number of arguments to " \
			                     "function " #zName "()", -1); \
			return; \
		} \
		xImpl(pContext, argc, argv); \
	}

/* As SQLite's table of built-in functions has them (FUNCTION and
   MFUNCTION in sqlite3.c, under SQLITE_ENABLE_MATH_FUNCTIONS), where log()
   is two entries, for one argument and for two */
OXT_SQL_FUNCTION(ceil, 1, 1, ceilingFunc)
OXT_SQL_FUNCTION(ceiling, 1, 1, ceilingFunc)
OXT_SQL_FUNCTION(floor, 1, 1, ceilingFunc)
OXT_SQL_FUNCTION(trunc, 1, 1, ceilingFunc)
OXT_SQL_FUNCTION(ln, 1, 1, logFunc)
OXT_SQL_FUNCTION(log, 1, 2, logFunc)
OXT_SQL_FUNCTION(log10, 1, 1, logFunc)
OXT_SQL_FUNCTION(log2, 1, 1, logFunc)
OXT_SQL_FUNCTION(exp, 1, 1, math1Func)
OXT_SQL_FUNCTION(pow, 2, 2, math2Func)
OXT_SQL_FUNCTION(power, 2, 2, math2Func)
OXT_SQL_FUNCTION(mod, 2, 2, math2Func)
OXT_SQL_FUNCTION(acos, 1, 1, math1Func)
OXT_SQL_FUNCTION(asin, 1, 1, math1Func)
OXT_SQL_FUNCTION(atan, 1, 1, math1Func)
OXT_SQL_FUNCTION(atan2, 2, 2, math2Func)
OXT_SQL_FUNCTION(cos, 1, 1, math1Func)
OXT_SQL_FUNCTION(sin, 1, 1, math1Func)
OXT_SQL_FUNCTION(tan, 1, 1, math1Func)
OXT_SQL_FUNCTION(cosh, 1, 1, math1Func)
OXT_SQL_FUNCTION(sinh, 1, 1, math1Func)
OXT_SQL_FUNCTION(tanh, 1, 1, math1Func)
OXT_SQL_FUNCTION(acosh, 1, 1, math1Func)
OXT_SQL_FUNCTION(asinh, 1, 1, math1Func)
OXT_SQL_FUNCTION(atanh, 1, 1, math1Func)
OXT_SQL_FUNCTION(sqrt, 1, 1, math1Func)
OXT_SQL_FUNCTION(radians, 1, 1, math1Func)
OXT_SQL_FUNCTION(degrees, 1, 1, math1Func)
OXT_SQL_FUNCTION(pi, 0, 0, piFunc)

/* As sqlite3_regexp_init() has them */
OXT_SQL_FUNCTION(regexp, 2, 2, re_sql_func)
OXT_SQL_FUNCTION(regexpi, 2, 2, re_sql_func)

int oxt_sqlite_add_functions(sqlite3 *db)
{
	const int kFlags = SQLITE_UTF8 | SQLITE_DETERMINISTIC | SQLITE_INNOCUOUS;
	int rc = SQLITE_OK;

	/* Each for any number of arguments (-1; see the top of this file),
	   with the user data that SQLite gives it: the C function that
	   ceilingFunc, math1Func and math2Func call; for logFunc, the
	   logarithm of one argument (0 natural, 1 base 10, 2 base 2), which
	   log(B,X) does not read; for re_sql_func, whether to ignore case
	   (the connection, as sqlite3_regexp_init() gives regexpi(), or
	   null). Added when the connection is opened, before any statement
	   runs, so nothing refuses them. */
#define OXT_ADD_SQL_FUNCTION(zName, pUserData) \
	if (rc == SQLITE_OK) \
		rc = sqlite3_create_function(db, #zName, -1, kFlags, \
		                             (void *) (pUserData), oxt_sql_##zName, \
		                             NULL, NULL)

	OXT_ADD_SQL_FUNCTION(ceil, xCeil);
	OXT_ADD_SQL_FUNCTION(ceiling, xCeil);
	OXT_ADD_SQL_FUNCTION(floor, xFloor);
	OXT_ADD_SQL_FUNCTION(trunc, trunc);
	OXT_ADD_SQL_FUNCTION(ln, SQLITE_INT_TO_PTR(0));
	OXT_ADD_SQL_FUNCTION(log, SQLITE_INT_TO_PTR(1));
	OXT_ADD_SQL_FUNCTION(log10, SQLITE_INT_TO_PTR(1));
	OXT_ADD_SQL_FUNCTION(log2, SQLITE_INT_TO_PTR(2));
	OXT_ADD_SQL_FUNCTION(exp, exp);
	OXT_ADD_SQL_FUNCTION(pow, pow);
	OXT_ADD_SQL_FUNCTION(power, pow);
	OXT_ADD_SQL_FUNCTION(mod, fmod);
	OXT_ADD_SQL_FUNCTION(acos, acos);
	OXT_ADD_SQL_FUNCTION(asin, asin);
	OXT_ADD_SQL_FUNCTION(atan, atan);
	OXT_ADD_SQL_FUNCTION(atan2, atan2);
	OXT_ADD_SQL_FUNCTION(cos, cos);
	OXT_ADD_SQL_FUNCTION(sin, sin);
	OXT_ADD_SQL_FUNCTION(tan, tan);
	OXT_ADD_SQL_FUNCTION(cosh, cosh);
	OXT_ADD_SQL_FUNCTION(sinh, sinh);
	OXT_ADD_SQL_FUNCTION(tanh, tanh);
	OXT_ADD_SQL_FUNCTION(acosh, acosh);
	OXT_ADD_SQL_FUNCTION(asinh, asinh);
	OXT_ADD_SQL_FUNCTION(atanh, atanh);
	OXT_ADD_SQL_FUNCTION(sqrt, sqrt);
	OXT_ADD_SQL_FUNCTION(radians, degToRad);
	OXT_ADD_SQL_FUNCTION(degrees, radToDeg);
	OXT_ADD_SQL_FUNCTION(pi, NULL);
	OXT_ADD_SQL_FUNCTION(regexp, NULL);
	OXT_ADD_SQL_FUNCTION(regexpi, db);

#undef OXT_ADD_SQL_FUNCTION
	return rc;
}
