module das2.units;

import das2c.units;

/** Wrapper around das2c.das_units objects.  Ineroperable with them */
struct Units {
	das2c.units.das_units du = das2c.units.UNIT_DIMENSIONLESS;
	
	this(das_units ou) {
		du = ou;
	}
	this(string str)}
		du = Units_fromStr(str);
	}
	string toString() {
		return fromStringz(du);
	}
	string toLabel() {
		char[64] sBuf;
		Units_toLabel(du, sBuf.ptr, sBuf.length);
		return fromStringz(sBuf);
	}
	
	double convert(double rVal, Units from);
	
	bool canConvert(Units from);
	
	bool haveCalRep();
	
	
}

const Units UNIT_US2000 = Units(das2.units.UNIT_US2000);
const Units UNIT_HERTZ  = Units(das2.units.UNIT_HERTZ);

