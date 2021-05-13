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
 *   st = A SysTyme object as defined in std.datetime.systime
 *
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
 * Wrap a das_time so that we end up with something that looks more like a 
 * standard D structure with functions 
 */
 
struct DasTime{
	das_time dt = {0, 1, 1, 1, 0, 0, 0.0};
	
	/** Construct a time value using a string */
	this(const(char)[] s){
		if(!dt_parsetime(s.toStringz(), &dt))
			throw new ConvException(format("Error parsing %s as a date-time", s));
	}
	
	/* pull-up properties of dt to this level */
	@property int    year()   const{ return dt.year;   }
	@property int    month()  const{ return dt.month;  }
	@property int    mday()   const{ return dt.mday;   }
	@property int    yday()   const{ return dt.yday;   }
	@property int    hour()   const{ return dt.hour;   }
	@property int    minute() const{ return dt.minute; }
	@property double second() const{ return dt.second; }

	@property void year(int n)  { dt.year = n; }
	@property void month(int n) { dt.month = n;}
	@property void mday(int n)  { dt.mday = n; }
	@property void hour(int n)  { dt.hour = n; }
	@property void minute(int n){ dt.minute = n; }
	@property void second(double n){ dt.second = n; }
		
	bool valid(){ return dt.month != 0;}

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
		dt.year = args[0];
		static if(args.length > 1) dt.month = args[1];
		static if(args.length > 2) dt.mday = args[2];
		static if(args.length > 3) dt.hour = args[3];
		static if(args.length > 4) dt.minute = args[4];
		static if(args.length > 5) dt.second = args[5];
		dt_tnorm(&dt);
	}

	string isoc(int fracdigits = 0) const{
		char[64] aBuf = '\0';
		dt_isoc(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	string toString() const{ return isoc(6); } 

	void norm(){
		dt_tnorm(&dt);
	}

	string isod(int fracdigits) const{
		char[64] aBuf = '\0';
		dt_isod(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	string dual(int fracdigits) const{
		char[64] aBuf = '\0';
		dt_dual_str(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	int opCmp(ref const(DasTime) other) const {
		return dt_compare(&dt, &(other.dt));
	}
	
	double opBinary(string op)(ref const(DasTime) other) const {
		static if(op == "-"){
			return dt_diff(&dt, &(other.dt));
		}
		else static assert(false, "Only subtraction is defined for two das2 times");
	}
	
	DasTime opBinary(string op)(double other) const {
		static if(op == "+"){
			das_time dt_new = dt;
			dt_new.seconds += other;
			dt_norm(dt_new);
			return DasTime(dt_new);
		}
		else static if(op == "-"){
			das_time dt_new = dt;
			dt_new.seconds -= other;
			dt_norm(dt_new);
			return DasTime(dt_new);
		}
		else static assert(false, "Operator "~op~" not implemented");
	}
};
