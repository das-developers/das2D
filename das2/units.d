module das2.units;

public import std.conv: ConvException;
import std.format;
import std.string;
import std.conv;

import das2c.units;
import das2c.operator;
import das2c.time;

import das2.time;

/** Wrapper around das2c.das_units objects.  Ineroperable with them */
struct Units {
	das_units du = null;
	
	this(das2c.units.das_units ou) {
		du = ou;
	}
	
	this(string str){
		du = Units_fromStr(toStringz(str));
	}
	
	string toString() const {
		return to!string(du);
	}
	
	DasTime toTime(double rTime) const {
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format!"Units %s not convertable to a calendar time."(this)
			);
		}
		DasTime t;
		Units_convertToDt(&(t.dt), rTime, du);
		return t;
	}
	
	string toLabel() const {
		char[64] sBuf;
		Units_toLabel(du, sBuf.ptr, sBuf.length);
		return to!string(sBuf);
	}
	
	/+ Generic value conversion utility
	 +
	 + Converts a value in one set of different set of units to a value in 
	 + these units.
	 +
	 + params:
	 +   rVal = The value to convert, to get a conversion factor from one unit
	 +          type to another set this to 1.0.
	 +
	 +   fromUnits = The original units of the value
	 +
	 + returns:
	 +   The new value as a double.
	 +/
	double convert(double rVal, Units from) const {
		if(from.du == du) return rVal;  // short circuit
		return Units_convertTo(du, rVal, from.du);
	}
	
	/++ Encode a broken down das2 Time as an epoch time in these units 
	 +/
	double convert(ref const(DasTime) t) const {
		return Units_convertFromDt(du, &(t.dt));
	}
	
	bool canConvert(Units other) const {
		return Units_canConvert(other.du, du);
	}
	
	bool haveCalRep() const {
		return Units_haveCalRep(du);
	}
	
	Units opBinary(string op)(const(Units) other) const{
		static if(op == "*"){
			if(!Units_canMerge(du, D2BOP_MUL, other.du))
				throw new ConvException(
					format!"Units %s and %s can not be multiplied"( this, other)
				);	
			
			return Units(Units_multiply(du, other.du));
		}
		else static assert(false, "Operator "~op~" not implemented");
	}
		
	/** Raise a unit to a positive or negative power.
	 * To invert the units raise them to the -1 power.
	 */
	Units opBinary(string op)(int nPow) const{
		static if(op == "^^"){
			return Units(Units_power(du, nPow));
		}
		else static assert(false, "Operator "~op~" not implemented");
	}
	
	bool opEquals()(auto ref const Units other) const{
		return (du == other.du);
	}
	
	/** Reduce units to a root
	 *
	 * Use this to reduce units to a integer root, for example:
	 *
	 *  Units("m**2").root(2)       == Units("m")
	 *  Units("nT / cm**2").root(2) == Units("nT**1/2 cm**-1")
	 *
	 % params:
	 *   root = A positive integer greater than 0
	 *
	 * returns: a new units structure
	 */
	Units root(int root) const {
		return Units( Units_root(du, root));
	}
	
	Units invert() const {
		return Units( Units_invert(du));
	}
	
	double secondsSinceMidnight(double rVal) const{
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format!"Units %s not convertable to a calendar time."(this)
			);
		}
		return Units_secondsSinceMidnight(rVal, du);
	}
	
	int getJulianDay(double rVal) const{
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format!"Units %s not convertable to a calendar time."(this)
			);
		}
		return Units_getJulianDay(rVal, du);
	}
	
	Units interval() const{
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format!"Units %s not convertable to a calendar time."(this)
			);
		}
		return Units( Units_interval(du) );
	}
	
	Units reduce(ref double rFactor) const {
		return Units(Units_reduce(du, &rFactor));
	}
}

/** Pre-defined units, others can be generated at will.  Unit values are
    always thread safe singletons.  A mutex lock in the das2C library 
	 prevents simulaneous creation, but there is no lock on reade */
	 
/** microseconds since midnight, Jan 1, 2000, ignoring leap seconds */
const Units UNIT_US2000;

/** days since midnight, Jan 1, 1958, ignoring leap seconds */
const Units UNIT_T2000;

/** seconds since midnight, Jan 1, 2000, ignoring leap seconds */
const Units UNIT_T1970;

/** seconds since midnight, Jan 1, 1970, ignoring leap seconds */
const Units UNIT_NS1970;

/** Units of das2.das_time structures, ignores leap seconds */
const Units UNIT_UTC;

/** nanoseconds since 2000-01-01T11:58:55.816 INCLUDING leap seconds 
 * das2 uses the CDF_LEAPSECONDSTABLE environment variable to find new leap
 * seconds since the CDF library is universial in space physics.  Not needed
 * if library has been build since last know leapsecond in the data time
 */
const Units UNIT_TT2000;

/** SI seconds */
const Units UNIT_SECONDS;

/** 3600 SI seconds, ignores leap seconds */
const Units UNIT_HOURS;

/** 86400 SI seconds, ignores leap seconds */
const Units UNIT_DAYS;

/** 1/1000 of an SI second */
const Units UNIT_MILLISECONDS;

/** 1/1,000,000 of an SI second */
const Units UNIT_MICROSECONDS;

/** 1/1,000,000,000 of an SI second */
const Units UNIT_NANOSECONDS;

/** Inverse seconds */
const Units UNIT_HERTZ;

/** 1000 Inverse seconds */
const Units UNIT_KILO_HERTZ;

/** 1,000,000 Inverse seconds */
const Units UNIT_MEGA_HERTZ;

/** Electric spectral density, V^^2 / m^^2 / Hz */
const Units UNIT_E_SPECDENS;

/** Magnetic spectral density, nT^^2 / Hz */
const Units UNIT_B_SPECDENS;

/** Magnetic intensity, nT */
const Units UNIT_NT;

/** Number of items per cm cubed */
const Units UNIT_NUMBER_DENS;

/** 10 log(value/reference) */
const Units UNIT_DB;

/** 1000 meters */
const Units UNIT_KM;

/** Electron Volts, a measure of energy */
const Units UNIT_EV;

/** An angle measurement, not temperature */
const Units UNIT_DEGREES;

/** Dimensionless quantities */
const Units UNIT_DIMENSIONLESS;


shared static this() {
	
	UNIT_US2000 = Units(das2c.units.UNIT_MJ1958);
	UNIT_T2000 = Units(das2c.units.UNIT_T2000);
	UNIT_T1970 = Units(das2c.units.UNIT_T1970);
	UNIT_NS1970 = Units(das2c.units.UNIT_NS1970);
	UNIT_UTC = Units(das2c.units.UNIT_UTC);
	UNIT_TT2000 = Units(das2c.units.UNIT_TT2000);
	UNIT_SECONDS = Units(das2c.units.UNIT_SECONDS);
	UNIT_HOURS = Units(das2c.units.UNIT_HOURS);
	UNIT_DAYS = Units(das2c.units.UNIT_DAYS);
	UNIT_MILLISECONDS = Units(das2c.units.UNIT_MILLISECONDS);
	UNIT_MICROSECONDS = Units(das2c.units.UNIT_MICROSECONDS);
	UNIT_NANOSECONDS = Units(das2c.units.UNIT_NANOSECONDS);
	UNIT_HERTZ = Units(das2c.units.UNIT_HERTZ);
	UNIT_KILO_HERTZ = Units(das2c.units.UNIT_KILO_HERTZ);
	UNIT_MEGA_HERTZ = Units(das2c.units.UNIT_MEGA_HERTZ);
	UNIT_E_SPECDENS = Units(das2c.units.UNIT_E_SPECDENS);
	UNIT_B_SPECDENS = Units(das2c.units.UNIT_B_SPECDENS);
	UNIT_NT = Units(das2c.units.UNIT_NT);
	UNIT_NUMBER_DENS = Units(das2c.units.UNIT_NUMBER_DENS);
	UNIT_DB = Units(das2c.units.UNIT_DB);
	UNIT_KM = Units(das2c.units.UNIT_KM);
	UNIT_EV = Units(das2c.units.UNIT_EV);
	UNIT_DEGREES = Units(das2c.units.UNIT_DEGREES);
	UNIT_DIMENSIONLESS = Units(das2c.units.UNIT_DIMENSIONLESS);
}
