/* Copyright (C) 1997-2017 Larry Granroth <larry-granroth@uiowa.edu>
 *                         Chris Piker <chris-piker@uiowa.edu>
 *
 * This file is part of libdas2, the Core Das2 C Library.
 *
 * Libdas2 is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License version 2.1 as published
 * by the Free Software Foundation.
 *
 * Libdas2 is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * version 2.1 along with libdas2; if not, see <http://www.gnu.org/licenses/>.
 */

/** @file time.h Das Time Utilities */
module das2c.time;

/** @defgroup time Time
 * Parsing and converting calendar dates and times
 */

/** @addtogroup time
 * @{
 */
 

extern (C):

/** Basic date-tmodule das2c.time;

ime structure used throughout the Das1 & Das2 utilities
 *
 * In all das rountines, times are assumed to be UTC.  Since we are
 * dealing with spacecraft far from Earth, local time zones are of no
 * consideration in almost all cases.
 */
struct das_time
{
    /** Calendar year number, cannot hold years before 1 AD */
    int year;

    /** Calendar month number, 1 = January */
    int month;

    /** Calender Day of month, starts at 1 */
    int mday;

    /** Integer Day of year, Jan. 1st = 1.
    	 *  This field is <b>output only</b> for most Das1 functions see the
    	 *  warning in dt_tnorm() */
    int yday;

    /** Hour of day, range is 0 to 23 */
    int hour;

    /** Minute of the hour, range 0 to 59 */
    int minute;

    /** Second of the minute, range 0.0 to 60.0 - epsilon.
    	 * Note, there is no provision for leap seconds in the library.  All
    	 * minutes are assumed to have 60 seconds.
    	 */
    double second;
}

/** Zero out all values in a das_time structrue
 *
 * Note, the resulting das_time is an *invalid* time, not a zero point.
 */
void dt_null (das_time* pDt);

/** Convert most human-parseable time strings to numeric components
 *
 * @param string - the string to convert to a numeric time
 * @param dt     - a pointer to the das_time structure to initialize
 * @returns true on success and false on failure
 *
 * @memberof das_time
 */
bool dt_parsetime (const(char)* string, das_time* dt);

/** Initialize a das_time to the current UTC time.
 *
 * Note: UTC is not your local time zone.
 */
bool dt_now (das_time* pDt);

/** Get a das time given days since 1958 and optional milliseconds of
 * day.  This format is common for many older spacecraft missions
 * @memberof das_time
 */
void dt_from_1958 (ushort daysSince1958, uint msOfDay, das_time* dt);

/** Convert a das time to integer nanoseconds since 1970-01-01
 *
 *
 * @param dt a das time
 * @param pDays days since Jan. 1st 1970 at midnight
 * @param pFrac fraction of a day.
 * @memberof das_time
 */
long dt_nano_1970 (const(das_time)* dt);

/** Test for time within a time range
 * The the standard exclusive upper bound test.
 *
 * @param begin The beginning time point for the range
 * @param end  The ending time point for the range
 * @param test The test time
 *
 * @returns true if begin <= test and test < end, false otherwise
 * @memberof das_time
 */
bool dt_in_range (
    const(das_time)* begin,
    const(das_time)* end,
    const(das_time)* test);

/** Simple helper to copy values from one das time to another
 *
 * @memberof das_time
 */
void dt_copy (das_time* pDest, const(das_time)* pSrc);

/** Simple helper to set values in a das time.
 *
 * Warning: This function does not cal tnorm, so you *can* use it to set
 *          invalid das times
 *
 * @memberof das_time
 */
void dt_set (
    das_time* pDt,
    int year,
    int month,
    int mday,
    int yday,
    int hour,
    int minute,
    double second
);

/** Compare to dastime structures.
 * Since we can't overload the numerical comparison operators in C, you
 * you get this function
 *
 * @param pA a pointer to a das_time structure
 * @param pB a pointer to a das_time structure
 *
 * @return an integer less than 0 if *pA is less that *pB, 0 if
 *         *pA is equal to *pB and greater than 0 if *pA is greater
 *         than *pB.
 * @memberof das_time
 */
int dt_compare(const(das_time)* pA, const(das_time)* pB);


/** Get the difference of two das_time structures in seconds.
 *
 * Handle time subtractions in a way that is sensitive to small differences.
 * Thus, do not go out to tnorm and back.
 *
 * Time difference in seconds is returned.  This method should be valid
 * as long as you are using the gegorian calendar, but doesn't account
 * for leap seconds.
 *
 * Credit: http://stackoverflow.com/questions/12862226/the-implementation-of-calculating-the-number-of-days-between-2-dates
 *
 * @returns Time A - Time B in seconds.
 * @memberof das_time
 */
double dt_diff (const(das_time)* pA, const(das_time)* pB);

/** Print an ISOC standard time string given a das_time structure
 *
 * The output has the format:
 *
 *   yyyy-mm-ddThh:mm:ss[.sssss]
 *
 * Where the number of fractional seconds digits to print is variable and
 * may be set to 0
 *
 * @param sBuf the buffer to hold the output
 * @param nLen the length of the output buffer
 * @param pDt the dastime to print
 * @param nFracSec the number of fractional seconds digits in the output
 *        must be a number from 0 to 15 inclusive
 * @memberof das_time
 */
char* dt_isoc (char* sBuf, size_t nLen, const(das_time)* pDt, int nFracSec);

/** Print an ISOD standard time string given a das_time structure
 *
 * The output has the format:
 *
 *   yyyy-dddThh:mm:ss[.sssss]
 *
 * Where the number of fractional seconds digits to print is variable and
 * may be set to 0
 *
 * @param sBuf the buffer to hold the output
 * @param nLen the length of the output buffer
 * @param pDt the dastime to print
 * @param nFracSec the number of fractional seconds digits in the output
 *        must be a number from 0 to 15 inclusive
 * @memberof das_time
 */
char* dt_isod (char* sBuf, size_t nLen, const(das_time)* pDt, int nFracSec);

/** Print time a string that provides both day of month and day of year given a
 *  das_time structure
 *
 * The output has the format:
 *
 *   yyyy-mm-dd (ddd) hh:mm:ss[.sssss]
 *
 * Where the number of fractional seconds digits to print is variable and
 * may be set to 0
 *
 * @param sBuf the buffer to hold the output
 * @param nLen the length of the output buffer
 * @param pDt the dastime to print
 * @param nFracSec the number of fractional seconds digits in the output
 *        must be a number from 0 to 15 inclusive
 * @memberof das_time
 */
char* dt_dual_str (char* sBuf, size_t nLen, const(das_time)* pDt, int nFracSec);

/* Julian Day at January 1, 1958, 12:00:00 UT */
enum EPOCH = 2436205;

/** Convert time components to double seconds since January 1st 1958
 *
 * converts time components to a double precision floating point value
 * (seconds since the beginning of 1958, ignoring leap seconds) and normalize
 * inputs.  Note that this floating point value should only be used for
 * "internal" purposes.  (There's no need to propagate yet another time
 * system, plus I want to be able to change/fix these values.)
 *
 * There is no accomodation for calendar adjustments, for example the
 * transition from Julian to Gregorian calendar, so I wouldn't recommend
 * using these routines for times prior to the 1800's.  Sun IEEE 64-bit
 * floating point preserves millisecond accuracy past the year 3000.
 * For various applications, it may be wise to round to nearest millisecond
 * (or microsecond, etc.) after the value is returned.
 *
 * @memberof das_time
 */
double dt_ttime (const(das_time)* dt);

/** convert double seconds since epoch to time components.
 *
 * emitt (ttime backwards) converts double precision seconds (since the
 * beginning of 1958, ignoring leap seconds) to date and time components.
 * @memberof das_time
 */
void dt_emitt (double tt, das_time* dt);

/** Normalize date and time components
 *
 *  Call this function after manipulating time structure values directly
 *  to insure that any overflow or underflow from various fields are
 *  caried over into to more significant fields.  After calling this function
 *  a das_time sturcture is again normalized into a valid date-time.
 *
 * @warning The das_time.yday member is OUTPUT only.  To add a day to
 *  a time, increment mday as much as needed and then call tnorm.
 * @memberof das_time
 */
void dt_tnorm (das_time* dt);

/* return Julian Day number given year, month, and day, not exported no purpose */
int jday (int year, int month, int day);

/** @} */

/* _das_time_h_ */
