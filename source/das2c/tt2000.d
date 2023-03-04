/** @file tt2000.h Helpers for units.h and time.h for dealing with TT2000 times
 * not intended as a public interface */

module das2c.tt2000;

extern (C):

/* das2 TT2000 functions in general are thread-safe but the initilization
 * function are *NOT* This is this is called from das2_init() to insure
 * leapsecond tables are initialized before using any of teh conversion
 * functions.
 *
 * NOTE: You can avoid the external leapsecond load hit on das2 startup
 *       if the environment variable: CDF_LEAPSECONDSTABLE is not defined,
 *       Though that means you have to get a new copy of the library before
 *       each leapsecond is added.
 */
bool das_tt2K_init (const(char)* sProgName);

/** Re-initialize the leap second table.
 *
 * Mostly provided for testing.  Do NOT call this function if other treads
 * could possibily be running unit conversions at the same time. */
bool das_tt2k_reinit (const(char)* sProgName);

/* Renamed CDF UTC to TT2000 handling function to avoid namespace
 * conflicts.  Roughly corresponds to computeTT2000 in original sources.
 *
 * Var Arg Warning!  This function expects DOUBLES.  Since it's a var-arg
 *   function it will accept *any* argument after the day value but it will
 *   blindly treat all arguments as doubles.  Up casting will *not* be
 *   preformed!  This function is legacy code from the CDF libraries.
 *   use the safer alternative:
 *
 *     das_time dt;
 *     tt = Units_convertFromDt(&dt, UNIT_TT2000);
 *
 *   instead. You have been warned.
 *
 * Thread Safety: Function is thread safe so long as das_tt2k_init() or
 * das_tt2k_reinit() are *not* called from another thread.
 */
long das_utc_to_tt2K (double year, double month, double day, ...);

/* Renamed CDF TT2000 to UTC function, renamed to avoid nomespace conflicts.
 * Corresponds to breakdownTT2000 in original sources.
 *
 * Var Arg Warning!  This function expects DOUBLES.  Since it's a var-arg
 *   function it will accept *any* argument after the day value but it will
 *   blindly treat all arguments as pointers to doubles.  Up casting will
 *   *not* be preformed!  This function is legacy code from the CDF libraries.
 *   use the safer alternative:
 *
 *     das_time dt;
 *     Units_convertToDt(&dt, tt, UNIT_TT2000);
 *
 *   instead. You have been warned.
 *
 * Thread Safety: Function is thread safe so long as das_tt2k_init() or
 * das_tt2k_reinit() are *not* called from another thread.
 */
void das_tt2K_to_utc (
    long nanoSecSinceJ2000,
    double* ly,
    double* lm,
    double* ld,
    ...);

/* Convert a UNIT_TT2000 double to UNIT_US2000 double
 *
 * This is a direct conversion of value on the UNIT_TT2000 scale to values on
 * the UNIT_US2000 scale without a round trip through UTC broken out times.
 *
 * Used by conversion functions in units.c.
 *
 * WARNING: US2000 has no leap seconds so near a leap second two different
 *          TT2000 times will convert to the same US2000 time
 *
 * Does not check the TT2000 mutex, thread safe so long as das_tt2k_init()
 * or das_tt2k_reinit() are not called from another thread.
 */
double das_tt2K_to_us2K (double tt2000);

/* Convert a UNIT_US2000 double to UNIT_TT2000 double
 *
 * This is a direct conversion of value on the UNIT_US2000 scale to values on
 * the UNIT_TT2000 scale without a round trip through UTC broken out times.
 *
 * Used by conversion functions in units.c.
 *
 * NOTE: Near a leap second two US2000 values that are 1 second apart will
 *       appear as 2 seconds appart on the TT2000 scale.
 *
 *
 * Does not check the TT2000 mutex, thread safe so long as das_tt2k_init()
 * or das_tt2k_reinit() are not called from another thread.
 */
double das_us2K_to_tt2K (double us2000);

/* _tt2000_h_ */
