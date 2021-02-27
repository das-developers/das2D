/* Copyright (C) 2004-2017 Chris Piker <chris-piker@uiowa.edu>
 *                         Jeremy Faden <jeremy-faden@uiowa.edu>
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

/** @file units.h Defines units used for items in the stream, most notably
 * time units that reference an epoch and a step size.
 */
module das2c.units;

import core.stdc.time;
import das2c.time;

extern (C):

extern __gshared const(char)* UNIT_US2000; /* microseconds since midnight, Jan 1, 2000 */
extern __gshared const(char)* UNIT_MJ1958; /* days since midnight, Jan 1, 1958 */
extern __gshared const(char)* UNIT_T2000; /* seconds since midnight, Jan 1, 2000 */
extern __gshared const(char)* UNIT_T1970; /* seconds since midnight, Jan 1, 1970 */
extern __gshared const(char)* UNIT_NS1970; /* nanoseconds since midnight, Jan 1, 1970 */
extern __gshared const(char)* UNIT_UTC; /* Time strings on the Gregorian Calendar */

/* Other common units */
extern __gshared const(char)* UNIT_SECONDS;
extern __gshared const(char)* UNIT_HOURS;
extern __gshared const(char)* UNIT_DAYS;
extern __gshared const(char)* UNIT_MILLISECONDS;
extern __gshared const(char)* UNIT_MICROSECONDS;
extern __gshared const(char)* UNIT_NANOSECONDS;

extern __gshared const(char)* UNIT_HERTZ;
extern __gshared const(char)* UNIT_KILO_HERTZ;
extern __gshared const(char)* UNIT_MEGA_HERTZ;
extern __gshared const(char)* UNIT_E_SPECDENS;
extern __gshared const(char)* UNIT_B_SPECDENS;
extern __gshared const(char)* UNIT_NT;

extern __gshared const(char)* UNIT_NUMBER_DENS;

extern __gshared const(char)* UNIT_DB;

extern __gshared const(char)* UNIT_KM;

extern __gshared const(char)* UNIT_EV;

extern __gshared const(char)* UNIT_DEGREES;
extern __gshared const(char)* UNIT_DIMENSIONLESS;

/* color:  Color should be handled as as vector, we don't have
 * support for vectors at this time.   Also a datatype of
 * byte is needed for small values
 */
/* extern const char* UNIT_RGB; */

/** @defgroup units Units
 * General unit normalization and manipulation with a focus on SI units
 */

/** @addtogroup units
 * @{
 */

/** Enumeration of unit types, that correspond to physical unit types.
 *
 * Note that although these are strings, Units_fromStr() should be be
 * used to get a reference to the enumerated string since *pointer equality*
 * comparison is done in the code.  Thus UnitType objects created using the
 * functions in this module satisfy the rule:
 *
 * @code
 *   das_unit a;
 *   das_unit b;
 *
 *   if(a == b){
 *     // Units are equal
 *   }
 * @endcode
 *
 * The Epoch Time unit types understood by this library are:
 *
 *   - UNIT_US2000 - Non-Leap microseconds since midnight, January 1st 2000
 *   - UNIT_MJ1958 - Days since midnight January 1st 1958
 *   - UNIT_T2000  - Non-Leap seconds since midnight, January 1st 2000
 *   - UNIT_T1970  - Non-Leap seconds since midnight, January 1st 1970
 *   - UNIT_UTC    - Time strings on the gregorian calendar
 *   - UNIT_NS2020 - Non-Leap nanoseconds since midnight Jan 1st, 2020,
 *                   typically transmitted as signed 8-byte integers
 *
 * As it stands the library currently does not understand SI prefixes, so
 * each scaled unit has it's own entry.  This should change.
 *
 *   - UNIT_SECONDS - Seconds, a time span.
 *   - UNIT_HOURS - hours, a time span = 3600 seconds.
 *   - UNIT_MIRCOSECONDS - A smaller time span.
 *   - UNIT_HERTZ   - Hertz, a measure of frequency.
 *   - UNIT_KILO_HERTZ - KiloHertz, another measure of frequency.
 *   - UNIT_E_SPECDENS - Electric Spectral Density, V**2 m**-2 Hz**-1;
 *   - UNIT_B_SPECDENS - Magnetic Spectral Density, nT**2 Hz**-1;
 *   - UNIT_NT      - Magnetic Field intensity, nT
 *   - UNIT_NUMBER_DENS - Number density, the number of items in a cubic
		 centimeter
 *   - UNIT_DB      - Decibels, a ratio measure, typically versus 1.0.
 *   - UNIT_KM      - Kilometers, a unit of distance
 *   - UNIT_DEGREES - Degrees, a ratio measure on circles: (arch length / circumference) * 360
 *
 * And if you don't know what else to use, try this:
 *
 *   - UNIT_DIMENSIONLESS - I.E. No units
 *
 * @todo Redo units as small structures
 */
alias das_units = const(char)*;

/** Basic constructor for das_unit's
 *
 * das_unit values are just char pointers, however they are singletons so
 * that equality operations are possible.  For proper operation of the
 * functions in the module it is assumed that one of the pre-defined
 * units are used, or that new unit types are created via this function.
 *
 * @returns a pointer to the singleton string representing these units.
 */
das_units Units_fromStr (const(char)* str);

/** Get the canonical string representation of a das_unit
 * Even though das_unit is a const char*, this function should be used in case
 * the das_unit implementation is changed in the future.
 * @see Units_toLabel()
 */
const(char)* Units_toStr (das_units unit);

/** Get label string representation das_units
 *
 * This function inserts formatting characters into the unit string returned
 * by Units_toStr().  The resulting output is suitable for use in Das2 labels
 * For example if Units_toStr() returns:
 *
 *    V**2 m**-2 Hz**-1
 *
 * this function would generate the string
 *
 *    V!a2!n m!a-2!n Hz!a-1!n
 *
 * Units that are an offset from some UTC time merely return "UTC"
 *
 * @param unit the unit object to convert to a label
 * @param sBuf a buffer to hold the UTF-8 label string
 * @param nLen the length of the buffer pointed to by sBuf
 * @return a pointer to sBuf, or NULL if nLen was too short to hold the label,
 *         or if the name contains a trailing '_' or there was more than one
 *         '_' characters in a unit name.
 */
char* Units_toLabel (das_units unit, char* sBuf, int nLen);

/** Invert the units, most commonly used for Fourier transform results
 *
 * Create the corresponding inverted unit from a given unit.  For example
 * seconds become Hz, milliseconds become kHz and so on.  This function does
 * <b>not</b> product the same output as calling:
 * @code
 *
 *   Units_exponentiate(unit, -1, 1);
 *
 * @endcode
 *
 * because a special lookup table is used for converting s**-1 (and related)
 * values to Hertz.
 *
 * For all other unit types, calling this function is equivalent to calling
 * Units_exponentiate(unit, -1, 1)
 *
 * @b Warning This function is not multi-thread safe.  It alters global
 *       library state data
 *
 * @param unit the input unit to invert
 *
 * @returns the inverted unit
 */
das_units Units_invert (das_units unit);

/** Combine units via multiplication
 *
 * Examples:
 * @pre
 *   A, B  ->  A B
 *
 *   A, A  ->  A**2
 *
 *   kg m**2 s**-1, kg**-1  ->  m**2 s**-1
 *
 * @param ut1 the first unit object
 * @param ut2 the second uint object
 * @return A new unit type which is the product of a and b.
 */
das_units Units_multiply (das_units ut1, das_units ut2);

/** Combine units via division
 *
 * This is just a convenience routine that has the effect of calling:
 *
 * @code
 *   Units_multiply( a, Units_power(b, -1) );
 * @endcode
 *
 * @param a the numerator units
 * @param b the denominator units
 * @return A new unit type which is the quotient of a divided by b
 */
das_units Units_divide (das_units a, das_units b);

/** Raise units to a power
 *
 * To invert a unit use the power -1.
 *
 * For units following the canonical pattern:
 *
 *   A**n B**m
 *
 * A new inverted unit:
 *
 *   A**-n B**-m
 *
 * is produced.
 */
das_units Units_power (das_units unit, int power);

/** Reduce units to a root
 *
 * Use this to reduce units to a integer root, for example:
 *
 *  Units_root( "m**2", 2 ) --> "m"
 *  Units_root( "nT / cm**2" ) --> "nT**1/2 cm**-1"
 *
 * @param unit The input unit
 * @param root A positive integer greater than 0
 *
 * @returns the new unit.
 */
das_units Units_root (das_units unit, int root);

/** Get the unit type for intervals between data points of a given unit type.
 *
 * This is confusing, but basically some data points, such as calendar times
 * and various other Das epoch based values cannot represent differences, only
 * absolute positions.  Use this to get the unit type of the subtraction of
 * two points.
 *
 * For example the units of 2017-10-14 UTC - 2017-10-13 UTC is seconds.
 *
 * @param unit The unit type for which the difference type is desired
 *
 * @returns the interval unit type.  Basic units such as meters have no
 *       standard epoch and thus they are just their own interval type.
 */
das_units Units_interval (das_units unit);

/** Reduce arbitrary units to the most basic know representation
 *
 * Units such as days can be represented as 86400 seconds, likewise units such
 * as km**2 can be represented as 10e6 m**2.  Use this function to reduce units
 * to the most basic type known by this library and return the scaling factor
 * that would be needed to convert data in the given units to the reduced units.
 *
 * This handles all SI units (except candela) and allows for metric
 * prefix names on arbitrary items, but not metric prefix symbols on
 * arbitrary unit tyes.  For example 'microcows' are reduced to '1e-6 cows',
 * but 'μcows' are not converted to 'cows'.
 *
 * @param[in] orig the original unit type
 *
 * @param[out] pFactor a pointer to a double which will hold the scaling factor,
 *             for units that are already in the most basic form this factor
 *             is 1.0.
 * @returns    the new UnitType, which may just be the old unit type if the
 *             given units are already in their most basic form
 */
das_units Units_reduce (das_units orig, double* pFactor);

/** Determine if given units are interchangeable
 * Though not as good a solution as using UDUNITS2 works for common space
 * physics quantities as well as SI units.  Units are convertible if:
 *
 *   1. They are both known time offset units.
 *   2. They have a built in conversion factor (ex: 1 day = 24 hours)
 *   3. Both unit sets use SI units, including Hz
 *   4. When reduced to base units the exponents of each unit are the same.
 *
 */
bool Units_canConvert (das_units fromUnits, das_units toUnits);

/** Generic unit conversion utility
 *
 * @param toUnits The new units that the value should be represented in
 *
 * @param rVal The value to convert, to get a conversion factor from one unit
 *              type to another set this to 1.0.
 *
 * @param fromUnits The original units of the value
 *
 * @note: Thanks Wikipedia.  This code incorporates the algorithm on page
 *        http://en.wikipedia.org/wiki/Julian_day
 */
double Units_convertTo (das_units toUnits, double rVal, das_units fromUnits);

/** Determine if the units in question can be converted to date-times
 *
 * If this function returns true, then the following functions may be
 * used on this unit type:
 *
 *  Units_convertToDt()
 *  Units_convertFromDt()
 *  Units_secondsSinceMidnight()
 *  Units_getJulianDay()
 *
 * Furthermore a call to Units_interval() returns a different unittype then
 * the given units.
 *
 * @param unit The units to check possible mapping to calendar dates.
 *
 */
bool Units_haveCalRep (das_units unit);

/** Convert a value in time offset units to a calendar representation
 *
 * @param[out] pDt a pointer to a das_time structure to receive the broken
 *            down time.
 *
 * @param[in] value the double value representing time from the epoch in some
 *            scale

 * @param[in] epoch_units Unit string
 */
void Units_convertToDt (das_time* pDt, double value, das_units epoch_units);

/** Convert a calendar representation of a time to value in time offset units
 *
 * @param epoch_units The units associated with the return value
 * @param pDt the calendar time object from which to derive the value
 * @return the value as a floating point offset from the epoch associated with
 *         epoch_units, or DAS_FILL_VALUE on an error
 */
double Units_convertFromDt (das_units epoch_units, const(das_time)* pDt);

/** Get seconds since midnight for some value of an epoch time unit
 * @param rVal the value of the epoch time
 * @param epoch_units so type of epoch time unit.
 * @returns the number of floating point second since midnight
 */
double Units_secondsSinceMidnight (double rVal, das_units epoch_units);

/* Get the Julian day for the Datum (double,unit) */
int Units_getJulianDay (double timeDouble, das_units epoch_units);

/** Determine if the units of values in a binary expression are compatible
 *
 * @param right
 * @param op
 * @param left
 * @return
 */
bool Units_canMerge (das_units left, int op, das_units right);

/** @} */

/* _das_units_h_ */
