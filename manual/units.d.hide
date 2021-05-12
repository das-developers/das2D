module das2.units;

import das2.time;

// Units
alias UnitType = const(char)*; // No class for units, just manipulates unsafe 
                               // string pointers


extern(C) extern const(char*) UNIT_US2000; /* microseconds since midnight, Jan 1, 2000 */

extern(C) extern const(char*) UNIT_T2000;
extern(C) extern const(char*) UNIT_T1970;


extern (C) UnitType Units_fromStr(const char* string);
extern (C) const (char)* Units_toStr(UnitType unit);
extern (C) char* Units_toLabel(UnitType unit, char* sBuf, int nLen);
extern (C) UnitType Units_invert(UnitType unit);
extern (C) UnitType Units_multiply(UnitType ut1, UnitType ut2);
extern (C) UnitType Units_divide(UnitType a, UnitType b);
extern (C) UnitType Units_power(UnitType unit, int power);
extern (C) UnitType Units_root(UnitType unit, int root );
extern (C) UnitType Units_interval(UnitType unit);
extern (C) bool Units_canConvert(UnitType fromUnits , UnitType toUnits);
extern (C) bool Units_haveCalRep(UnitType unit);
extern (C) void Units_convertToDt(das_time* pDt, double value, UnitType epoch_units);
extern (C) double Units_convertFromDt(UnitType epoch_units, const das_time* pDt);
