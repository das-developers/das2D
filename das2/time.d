module das2.time;


import std.string;
import std.datetime;
import core.time;
import std.math;
import core.stdc.string;
public import std.conv: ConvException;

import das2c.time;
import das2c.das1;

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

	ret = das2c.das1.parsetime(
		c_str, &year, &month, &day_month, &day_year, &hour, &minute, &rSec
	);
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

/*****************************************************************************
 * Time handling class that drops time zone complexity and sub-second integer
 * units.  To make time handling platform independent, many das2 functions
 * take or receive instances of this structure.
 */
struct Time{
	int year = 0; 
	int month = 0; 
	int mday = 0; 
	int yday = 0;   // Typically read only except for normDoy()
	int hour = 0;   // redundant, but explicit beats implicit
	int minute = 0; // default value for ints is 0 
	double second = 0.0;

	/** Construct a time value using a string */
	this(const(char)[] s){
		int nRet;
		//infof("Parsting time string: %s", s);
		nRet = das2c.das1.parsetime(
			s.toStringz(), &year, &month, &mday, &yday, &hour, &minute, &second
		);
		if(nRet != 0)
			throw new ConvException(format("Error parsing %s as a date-time", s));
	}
	
	this(ref das_time dt){
		year = dt.year;
		month = dt.month;
		mday = dt.mday;
		yday = dt.yday;
		hour = dt.hour;
		minute = dt.minute;
		second = dt.second;
	}
	
	bool valid(){ return month != 0;}

	void setFromDt(das_time* pDt){
		year = pDt.year;
		month = pDt.month;
		mday = pDt.mday;
		yday = pDt.yday;
		hour = pDt.hour;
		minute = pDt.minute;
		second = pDt.second;
	}

	das_time toDt() const{
		das_time dt;
		dt.year = year;
		dt.month = month;
		dt.mday = mday;
		dt.yday = yday;
		dt.hour = hour;
		dt.minute = minute;
		dt.second = second;
		return dt;
	}

	/** Create a time using a vairable length tuple.
	 * 
	 * Up to 6 arguments will be recognized, at least one must be given
	 * year, month, day, hour, minute, seconds
	 * All items not initialized will recive default values which are
	 *  year = 1, month = 1, day = 1, hour = 0, minute = 0, seconds = 0.0
	 *
	 */
	
	this(T...)(T args){
		static assert(args.length > 0);
		year = args[0];
		static if(args.length > 1) month = args[1];
		static if(args.length > 2) mday = args[2];
		static if(args.length > 3) hour = args[3];
		static if(args.length > 4) minute = args[4];
		static if(args.length > 5) second = args[5];
	}

	string isoc(int fracdigits) const{
		char[64] aBuf = '\0';
		das_time dt = toDt();
		dt_isoc(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

  
	string toString() const{ return isoc(6); }
  

	void norm(){
		das_time dt = toDt(); 
		dt_tnorm(&dt);
		setFromDt(&dt);
	}

	string isod(int fracdigits) const{
		char[64] aBuf = '\0';
		das_time dt = toDt();
		dt_isod(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	string dual(int fracdigits) const{
		char[64] aBuf = '\0';
		das_time dt = toDt();
		dt_dual_str(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	int opCmp(in Time other) const {
		if(year < other.year) return -1; if(year > other.year) return 1;
		if(month < other.month) return -1; if(month > other.month) return 1;
		if(mday < other.mday) return -1; if(mday > other.mday) return 1;
		if(hour < other.hour) return -1; if(hour > other.hour) return 1;
		if(minute < other.minute) return -1; if(minute > other.minute) return 1;
		if(second < other.second) return -1; if(second > other.second) return 1;
		return 0;
	}
};
