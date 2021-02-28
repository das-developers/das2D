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
		das_time dt;
		Units_convertToDt(&dt, rTime, du);
		return Time(dt);
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
	double convert(ref const(Time) dt) const {
		das_time cstruct = dt.toDt();
		return Units_convertFromDt(du, &cstruct);
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


