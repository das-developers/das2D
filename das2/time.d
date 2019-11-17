module das2.time;

import std.string;
import std.datetime;
import core.time;
import std.math;


// Das Times
extern(C) int parsetime (
	const char *string, int *year, int *month, int *day_month, int *day_year,
	int *hour, int *minute, double *second
);

struct das_time_t{
	int year;
	int month;
	int mday;
	int yday;
    int hour;
	int minute;
	double second;
};

extern (C) void dt_null(das_time_t* pDt);
extern (C) bool dt_parsetime(const char* string, das_time_t* dt);
extern (C) void dt_copy(das_time_t* pDest, const das_time_t* pSrc);
extern (C) int dt_compare(const das_time_t* pA, const das_time_t* pB);
extern (C) double dt_diff(const das_time_t* pA, const das_time_t* pB);
extern (C) char* dt_isoc(char* sBuf, size_t nLen, const das_time_t* pDt, int nFracSec);
extern (C) char* dt_isod(char* sBuf, size_t nLen, const das_time_t* pDt, int nFracSec);
extern (C) char* dt_dual_str(char* sBuf, size_t nLen, const das_time_t* pDt, int nFracSec);
extern (C) double dt_ttime(const das_time_t* dt);
extern (C) void dt_emitt (double tt, das_time_t* dt);
extern (C) void dt_tnorm(das_time_t* dt);  // Extra reminder, dt.yday is OUTPUT only !


/**************************************************************************
 * Parse a string representing a UTC time into a SysTime object D's
 * SysTime.fromISOExtString is pretty good, but it can't handle some formats
 * such as YYYY-DDD (day of year).  This function is just a wrapper than
 * understands more squirrly input.
 * Params:
 *   s = A string to parse.  Should be formatted as an ISO-8601 date,
 *       (i.e. YYYY-MM-DDTHH:MM:SS.sss).  ISO-8601 ordinal foramt dates
 *       (i.e. YYYY-DDDTHH:MM:SS.sss) dates are supported as well.
 * Returns: A SysTime object with the UTC timezone
 */
SysTime parsetime(string s){
	// A wart to get buy, make this a UTF-8 safe version of larry's parsetime
	// someday.

	const char* c_str = s.toStringz();

	int year, month, day_month, day_year, hour, minute, nSec, nHNSec;
	double rSec;
	int ret = 0;

	ret = parsetime(c_str, &year, &month, &day_month, &day_year, &hour,
	                  &minute, &rSec);
	if(ret != 0){
		throw new DateTimeException(
			format("'%s' could not be parsed as a datetime", s)
		);
	}

	nSec = cast(int) rSec;
	nHNSec = cast(int) ( (rSec - nSec) * 10_000_000);

	DateTime dt = DateTime(year, month, day_month, hour, minute, nSec);
	Duration frac = dur!"hnsecs"(nHNSec);
	immutable(TimeZone) tz = UTC();

	SysTime st = SysTime(dt, frac, tz);
	return st;
}

/**************************************************************************
 * Get a ISO-8601 Time string to at least seconds precision.
 * Params:
 *   nSecPrec = The number of significant digits in the fractional seconds
 *              field.  Use 0 for whole seconds.  The maximum value is 7
 *              or 100 nanoseconds, since this is the maximum precision of
 *              the underlying SysTime object.
 *
 * Returns: An ISO-8601 string with standard field separaters
 */
string isoString(SysTime st, int nSecPrec = 0){
	assert(nSecPrec >= 0 && nSecPrec <= 7);
	string sOut;
	if(nSecPrec > 0){
		auto sFmt = "%04d-%02d-%02dT%02d:%02d:%02d" ~
		               format(".%%0%dd", nSecPrec);
		long nFrac = st.fracSecs.total!("hnsecs") * 10^^nSecPrec;
		sOut = format(sFmt, st.year, st.month, st.day, st.hour, st.minute,
		              st.second, lround(nFrac / 10_000_000.0));
	}
	else{
		auto sFmt = "%04d-%02d-%02dT%02d:%02d:%02d";
		sOut = format(sFmt, st.year, st.month, st.day, st.hour, st.minute,
		              st.second);
	}
	return sOut;
}

/****************************************************************************
 * Return a nice human readable time string with both doy of month and
 * day of year indicated.
 * There is on inverse for this function, it's output for humans only.
 */
string rpwgString(SysTime st, int nSecPrec = 0){
	assert(nSecPrec >= 0 && nSecPrec <= 7);
	string sOut;
	if(nSecPrec > 0){
		string sFmt = "%04d-%02d-%02d (%03d) %02d:%02d:%02d" ~
		             format(".%%0%dd", nSecPrec);

		long rFrac = st.fracSecs.total!("hnsecs") * 10^^nSecPrec;
		sOut = format(sFmt, st.year, st.month, st.day, st.dayOfYear, st.hour,
		              st.minute, st.second, lround(rFrac / 10_000_000.0));
	}
	else{
		auto sFmt = "%04d-%02d-%02d (%03d) %02d:%02d:%02d";
		sOut = format(sFmt, st.year, st.month, st.day, st.dayOfYear, st.hour,
		              st.minute, st.second);
	}
	return sOut;
}
