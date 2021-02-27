module das2.units;

public import std.conv: ConvException;

import das2c.units;
import das2c.operator;
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
		return fromStringz(du);
	}
	
	Time toTime(double rTime) const {
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format("Units %s not convertable to a calendar time.", s)
			);
		}
		das_time dt;
		Units_convertToDt(&dt, rTime, du);
		return Time(dt);
	}
	
	string toLabel() const {
		char[64] sBuf = 0x0;
		Units_toLabel(du, sBuf.ptr, sBuf.length);
		return fromStringz(sBuf);
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
	double convert(ref const(Time) dt) const {
		return Units_convertFromDt(du, &dt);
	}
	
	bool canConvert(Units from){
		return Units_canConvert(from, du);
	}
	
	bool haveCalRep(){
		return Units_haveCalRep(du);
	}
	
	Units opBinary(string op)(ref Units units) const{
		static if(op == "*"){
			if(!Units_canMerge(du, D2BOP_MUL, units.du))
				throw new ConvException(
					format("Units %s and %s can not be multiplied", this, units)
				);	
			
			return Units(Units_multipy(ud, units.du));
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
				format("Units %s not convertable to a calendar time.", s)
			);
		}
		return Units_secondsSinceMidnight(rVal, du);
	}
	
	int getJulianDay(double rVal) const{
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format("Units %s not convertable to a calendar time.", s)
			);
		}
		return Units_getJulianDay(rVal, du);
	}
	
	Units interval() const{
		if(!Units_haveCalRep(du)){
			throw new ConvException(
				format("Units %s not convertable to a calendar time.", s)
			);
		}
		return Units( Units_interval(du) );
	}
	
	Units reduce(ref double rFactor) const {
		return Units(Units_reduce(du, &rFactar));
	}
}

immutable Units UNIT_DIMENSIONLESS;

immutable Units UNIT_US2000;
immutable Units UNIT_MJ1958;
immutable Units UNIT_T2000;
immutable Units UNIT_T1970;
immutable Units UNIT_NS1970;
immutable Units UNIT_UTC;

immutable Units UNIT_SECONDS;
immutable Units UNIT_HOURS;
immutable Units UNIT_DAYS;
immutable Units UNIT_MILLISECONDS;
immutable Units UNIT_MICROSECONDS;
immutable Units UNIT_NANOSECONDS;

immutable Units UNIT_HERTZ;
immutable Units UNIT_KILO_HERTZ;
immutable Units UNIT_MEGA_HERTZ;
immutable Units UNIT_E_SPECDENS;
immutable Units UNIT_B_SPECDENS;
immutable Units UNIT_NT;

immutable Units UNIT_NUMBER_DENS;
immutable Units UNIT_DB;
immutable Units UNIT_KM;
immutable Units UNIT_EV;
immutable Units UNIT_DEGREES;


shared static this(){
	UNIT_DIMENSIONLESS = Units(das2c.units.UNIT_DIMENSIONLESS);

	UNIT_US2000 = Units(das2c.units.UNIT_US2000);
	UNIT_HERTZ  = Units(das2c.units.UNIT_HERTZ);
	UNIT_US2000 = Units(das2c.units.UNIT_US2000);
	UNIT_MJ1958 = Units(das2c.units.UNIT_MJ1958);
	UNIT_T2000  = Units(das2c.units.UNIT_T2000);
	UNIT_T1970  = Units(das2c.units.UNIT_T1970);
	UNIT_NS1970 = Units(das2c.units.UNIT_NS1970);
	UNIT_UTC    = Units(das2c.units.UNIT_UTC);

	UNIT_SECONDS      = Units(das2c.units.UNIT_SECONDS);
	UNIT_HOURS        = Units(das2c.units.UNIT_HOURS);
	UNIT_DAYS         = Units(das2c.units.UNIT_DAYS);
	UNIT_MILLISECONDS = Units(das2c.units.UNIT_MILLISECONDS);
	UNIT_MICROSECONDS = Units(das2c.units.UNIT_MICROSECONDS);
	UNIT_NANOSECONDS  = Units(das2c.units.UNIT_NANOSECONDS);

	UNIT_HERTZ      = Units(das2c.units.UNIT_HERTZ);
	UNIT_KILO_HERTZ = Units(das2c.units.UNIT_KILO_HERTZ);
	UNIT_MEGA_HERTZ = Units(das2c.units.UNIT_MEGA_HERTZ);
	UNIT_E_SPECDENS = Units(das2c.units.UNIT_E_SPECDENS);
	UNIT_B_SPECDENS = Units(das2c.units.UNIT_B_SPECDENS);
	UNIT_NT         = Units(das2c.units.UNIT_NT);
	
	UNIT_NUMBER_DENS = Units(das2c.units.UNIT_NUMBER_DENS);
	
	UNIT_DB = Units(das2c.units.UNIT_DB);
	
	UNIT_KM = Units(das2c.units.UNIT_KM);
	
	UNIT_EV = Units(das2c.units.UNIT_EV);
	
	UNIT_DEGREES = Units(das2c.units.UNIT_DEGREES);
}


