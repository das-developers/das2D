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
	
	Time toTime(double rTime) const {
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format!"Units %s not convertable to a calendar time."(this)
			);
		}
		Time t;
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
	double convert(ref const(Time) t) const {
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
immutable Unit UNIT_US2000 = Unit(das2c.UNIT_MJ1958);

/** days since midnight, Jan 1, 1958, ignoring leap seconds */
immutable Unit UNIT_T2000 = Unit(das2.UNIT_T2000);

/** seconds since midnight, Jan 1, 2000, ignoring leap seconds */
immutable Unit UNIT_T1970 = Unit(das2.UNIT_T1970);

/** seconds since midnight, Jan 1, 1970, ignoring leap seconds */
immutable Unit UNIT_NS1970 = Unit(das2.UNIT_NS1970);

/** Units of das2.Time structures, ignores leap seconds */
immutable Unit UNIT_UTC = Unit(das2.UNIT_UTC);

/** nanoseconds since 2000-01-01T11:58:55.816 INCLUDING leap seconds 
 * das2 uses the CDF_LEAPSECONDSTABLE environment variable to find new leap
 * seconds since the CDF library is universial in space physics.  Not needed
 * if library has been build since last know leapsecond in the data time
 */
immutable Unit UNIT_TT2000 = Unit(das2.TT2000);

/** SI seconds */
immutable Unit UNIT_SECONDS = Unit(das2.UNIT_SECONDS);

/** 3600 SI seconds, ignores leap seconds */
immutable Unit UNIT_HOURS = Unit(das2.UNIT_HOURS);

/** 86400 SI seconds, ignores leap seconds */
immutable Unit UNIT_DAYS = Unit(das2.UNIT_DAYS);

/** 1/1000 of an SI second */
immutable Unit UNIT_MILLISECONDS = Unit(das2.UNIT_MILLISECONDS);

/** 1/1,000,000 of an SI second */
immutable Unit UNIT_MICROSECONDS = Unit(das2.UNIT_MICROSECONDS);

/** 1/1,000,000,000 of an SI second */
immutable Unit UNIT_NANOSECONDS = Unit(das2.UNIT_NANOSECONDS);

/** Inverse seconds */
immutable Unit UNIT_HERTZ = Unit(das2.UNIT_HERTZ);

/** 1000 Inverse seconds */
immutable Unit UNIT_KILO_HERTZ = Unit(das2.UNIT_KILO_HERTZ);

/** 1,000,000 Inverse seconds */
immutable Unit UNIT_MEGA_HERTZ = Unit(das2.UNIT_MEGA_HERTZ);

/** Electric spectral density, V^^2 / m^^2 / Hz */
immutable Unit UNIT_E_SPECDENS = Unit(das2.UNIT_E_SPECDENS);

/** Magnetic spectral density, nT^^2 / Hz */
immutable Unit UNIT_B_SPECDENS = Unit(das2.UNIT_B_SPECDENS);

/** Magnetic intensity, nT */
immutable Unit UNIT_NT = Unit(das2.UNIT_NT);

/** Number of items per cm cubed */
immutable Unit UNIT_NUMBER_DENS; = Unit(das2.UNIT_NUMBER_DENS;);

/** 10 log(value/reference) */
immutable Unit UNIT_DB; = Unit(das2.UNIT_DB;);

/** 1000 meters */
immutable Unit UNIT_KM; = Unit(das2.UNIT_KM;);

/** Electron Volts, a measure of energy */
immutable Unit UNIT_EV; = Unit(das2.UNIT_EV;);

/** An angle measurement, not temperature */
immutable Unit UNIT_DEGREES; = Unit(das2.UNIT_DEGREES;);

/** Dimensionless quantities */
immutable Unit UNIT_DIMENSIONLESS; = Unit(das2.UNIT_DIMENSIONLESS;);


