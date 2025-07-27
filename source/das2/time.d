module das2.time;

public import std.conv: ConvException;

import core.stdc.string;

import std.exception: enforce;
import std.format: format;
import std.math;
import std.string: lastIndexOf, toStringz;

import das2.util;  // force initilization of libdas2.so/.dll first

import das2c.time;
import das2c.das1;

import std.datetime: SysTime;

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
	import core.time: Duration, dur;  // hide import locally to avoid conflicts with .seconds
	import std.datetime: DateTime, DateTimeException, TimeZone, UTC;

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

	/** Construct a time value using a string */
	this(const(char)[] s){
		// Allow now and forever as times
		switch(s){
		case "now": dt_now(&dt); break;
		case "forever": 
			dt.year = 3000; 
			dt.month = 1;
			dt.mday = 1;
			dt.yday = 1;
			dt.hour = 0;
			dt.minute = 0;
			dt.second = 0.0;
			break;
		default:
			if(!dt_parsetime(s.toStringz(), &dt))
				throw new ConvException(format("Error parsing %s as a date-time", s));
			break;
		}
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
		dt.year = args[0];
		static if(args.length > 1) dt.month = args[1];
		static if(args.length > 2) dt.mday = args[2];
		static if(args.length > 3) dt.hour = args[3];
		static if(args.length > 4) dt.minute = args[4];
		static if(args.length > 5) dt.second = args[5];
		dt_tnorm(&dt);
	}

	this(const ref das_time dtOther){
		dt = dtOther;
	}

	string isoc(int fracdigits = 0) const{
		char[64] aBuf = '\0';
		dt_isoc(aBuf.ptr, 63, &dt, fracdigits);
		return aBuf.idup[0..strlen(aBuf.ptr)];
	}

	/++ Return an ISO-8601 day of month string with all unnecessary time
	 + components removed.  Will always retain at least the date part.
	 + The minutes part is retained *IF* the hours are no zero.  This is
	 + because many parsers look for at least ':' to find a time component.
	 + 
	 +  Examples:
	 +    2022-07-19T17:43:35.345789 -> 2022-07-19T17:43:35.345789
	 +    2022-07-19T17:43:35.340000 -> 2022-07-19T17:43:35.34
	 +    2022-07-19T17:43:35.000000 -> 2022-07-19T17:43:35
	 +    2022-07-19T17:43:00.000000 -> 2022-07-19T17:43
	 +    2022-07-19T17:00:00.000000 -> 2022-07-19T17:00  <-- not a typo
	 +    2022-07-19T00:00:00.000000 -> 2022-07-19
	 +/
	string isoShort() const{
		string s = isoc(9);

		// Maybe trim sub-seconds
		long iDot = lastIndexOf(s, '.');
		if(iDot < 0)
			iDot = lastIndexOf(s, ','); // also used in many locale's
		assert(iDot > 0); // Unless something radically changes we can depend on this
		long iEnd = s.length - 1;
		while(iEnd > iDot){
			if(s[iEnd] == '0') --iEnd;
			else break;
		}
		if((s[iEnd] == '.')||(s[iEnd] == ','))
			--iEnd; // Nix trailing '.' if no longer needed
		else
			return s[0..iEnd+1]; // have some sub-seconds

		// Maybe trim seconds
		if((s[iEnd-1] == '0') && (s[iEnd] == '0'))
			iEnd -= 3;
		else
			return s[0..iEnd+1]; // have seconds

		// Trim time of day
		if((s[iEnd-4]=='0') && (s[iEnd-3]=='0') && (s[iEnd-1]=='0') && (s[iEnd]=='0'))
			iEnd -= 6;
		
		return s[0..iEnd+1];
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

	int opCmp()(auto ref const(DasTime) other) const {
		return dt_compare(&dt, &(other.dt));
	}
	
	double opBinary(string op)(ref const(DasTime) other) const {
		static if(op == "-"){
			return dt_diff(&dt, &(other.dt));
		}
		else static assert(false, "Only subtraction is defined for two das2 times");
	}
	
	DasTime opBinary(string op)(double secs) const {
		static if(op == "+"){
			das_time dt_new = dt;
			dt_new.second += secs;
			dt_tnorm(&dt_new);
			return DasTime(dt_new);
		}
		else static if(op == "-"){
			das_time dt_new = dt;
			dt_new.second -= secs;
			dt_tnorm(&dt_new);
			return DasTime(dt_new);
		}
		else static assert(false, "Operator "~op~" not implemented");
	}

	void opOpAssign(string op)(double secs) {
		static if (op == "+"){
			dt.second += secs;
			dt_tnorm(&dt);
		}
		else static if (op == "-"){
			dt.second -= secs;
			dt_tnorm(&dt);	
		}
		else static assert(false, "Operator "~op~" not implemented");
	}

	long toTt2k() const {
		return dt_to_tt2k(&dt);
	}
};

unittest{

	import std.stdio;

	string[] aExpect = [
		"2022-07-19T17:43:35.345789", "2022-07-19T17:43:35.345789", "2022-07-19T17:43:35,345789",
		"2022-07-19T17:43:35.340000", "2022-07-19T17:43:35.34",     "2022-07-19T17:43:35,34",
		"2022-07-19T17:43:35.000000", "2022-07-19T17:43:35",        "2022-07-19T17:43:35",
		"2022-07-19T17:43:00.000000", "2022-07-19T17:43",           "2022-07-19T17:43",
		"2022-07-19T17:00:00.000000", "2022-07-19T17:00", "2022-07-19T17:00", // <-- not a typo
		"2022-07-19T00:00:00.000000", "2022-07-19", "2022-07-19"
	];

	DasTime dt;
	string sTest;
	for(int i = 0; i < aExpect.length/3; ++i){
		dt = DasTime(aExpect[3*i]);

		sTest = dt.isoShort();
		assert(sTest == aExpect[3*i+1] || sTest == aExpect[3*i+2], 
		format!"ISO-shorten %s, expect %s (or %s), got %s"(
			aExpect[3*i], aExpect[3*i+1], aExpect[3*i+2], sTest
		));
		writefln("INFO: %s --> %s", aExpect[2*i], sTest);
	}
	writefln("INFO: das2.time unittest passed");
}

/+ Convert a single unix time to TT2000.
 + 
 + This function only works for positive unix times.  Points before 1970-01-01
 + are not handled.
 +/
long unixTott2k(int unix_sec, int micro_sec)
{
	// Desending order offset times.  Mapping between unix time and TT2000
	// proceeds at constant rate of 1e9 to 1 after each leap second.  The
	// Each line in the chart below represents the instant in time *after*
	// each leap second.  Prior to 1972-01-01 the rate of UNIX ticks to
	// TT2000 ticks is not 1e9, but some other value that I don't know.
	
	enum int nOffsets = 29;
	const long[2][nOffsets] offsets = [
		[ 1483228800L ,  536500869184000000L ], // 2017-01-01    0 
		[ 1435708800L ,  488980868184000000L ], // 2015-07-01    1
		[ 1341100800L ,  394372867184000000L ], // 2012-07-01    2
		[ 1230768000L ,  284040066184000000L ], // 2009-01-01    3
		[ 1136073600L ,  189345665184000000L ], // 2006-01-01    4
		[  915148800L ,  -31579135816000000L ], // 1999-01-01    5
		[  867715200L ,  -79012736816000000L ], // 1997-07-01    6
		[  820454400L , -126273537816000000L ], // 1996-01-01    7
		[  773020800L , -173707138816000000L ], // 1994-07-01    8
		[  741484800L , -205243139816000000L ], // 1993-07-01    9
		[  709948800L , -236779140816000000L ], // 1992-07-01   10
		[  662688000L , -284039941816000000L ], // 1991-01-01   11
		[  631152000L , -315575942816000000L ], // 1990-01-01   12
		[  567993600L , -378734343816000000L ], // 1988-01-01   13
		[  489024000L , -457703944816000000L ], // 1985-07-01   14
		[  425865600L , -520862345816000000L ], // 1983-07-01   15
		[  394329600L , -552398346816000000L ], // 1982-07-01   16
		[  362793600L , -583934347816000000L ], // 1981-07-01   17
		[  315532800L , -631195148816000000L ], // 1980-01-01   18
		[  283996800L , -662731149816000000L ], // 1979-01-01   19
		[  252460800L , -694267150816000000L ], // 1978-01-01   20
		[  220924800L , -725803151816000000L ], // 1977-01-01   21
		[  189302400L , -757425552816000000L ], // 1976-01-01   22
		[  157766400L , -788961553816000000L ], // 1975-01-01   23
		[  126230400L , -820497554816000000L ], // 1974-01-01   24
		[   94694400L , -852033555816000000L ], // 1973-01-01   25
		[   78796800L , -867931156816000000L ], // 1972-07-01   26
		[   63072000L , -883655957816000000L ], // 1972-01-01   27
		// Mapping is not linear for dates below Jan. 1st, 1972. The actual 
		// mapping is:
		//[          0L , -946727959814622001L ] // 1970-01-01   28
		// but we want a constant slope of 1e9, so using this value instead:
		[          0L , -946727958816000000L ] // 1970-01-01    28
	];

	int i;
	for(i = 0; i < nOffsets; ++i)
		if(unix_sec >= offsets[i][0]) break;

	long tt2k;
	if( i >= nOffsets ){
		// Handle negative times, since I guess that's a thing for really bad packets
		assert(unix_sec <= 0, "Time handling logic error");

		// Leap seconds weren't a thing before 1970, use whole unix time
		tt2k = unix_sec*1_000_000_000L + offsets[nOffsets-1][1];
	}
	else{
		tt2k = (unix_sec - offsets[i][0])*1_000_000_000L + offsets[i][1];
	}

	tt2k += micro_sec * 1000;
	return tt2k;
}

unittest {
	import std.stdio;

	// Check that the 2016-12-31T23:59:60 leap second is skipped, unixtime
	// can't actually represent a leap second, so check differences
	long ttPreLeap  = unixTott2k(1483228799, 0);
	long ttPostLeap = unixTott2k(1483228800, 0);
	writeln(ttPreLeap, "  ", ttPostLeap, "  ", ttPostLeap - ttPreLeap);
	enforce(ttPostLeap - ttPreLeap == 2_000_000_000, "Leap second not skipped");

}
