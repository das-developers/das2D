// Original author, Chris Piker <chris-piker@uiowa.edu> 
//
// This file is intended to demonstrate an interface.  This is free 
// and unencumbered software released into the public domain 
// 
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
// 
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// For more information, please refer to <http://unlicense.org/>

import std.stdio;
import std.string;
import das2.units;

int main(string[] args) {

	/* Exit on errors, log info messages and above */
	das_init(toStringz(args[0]), DASERR_DIS_EXIT, 0, DASLOG_INFO, null);
	
	/* Test singleton nature of unit values */
	units Hz1 = Units("Hz");
	string sHz2 = "Hz";
	units Hz2 = Units(sHz2);
	if( (Hz1 != Hz2) || (Hz2 != UNIT_HERTZ)){
		writef("ERROR: Test 1 Failed, %s != %s\n", Hz1, Hz2);
		return 15;
	}
	
	/* Test US2000 forward transformations */
	Units units = UNIT_US2000;
	Time dt = "2000-1-1T1:00";
	if(dt.valid)){
		writef("ERROR: Test 2 Failed, can't parse %s as a string\n", sTime);
		return 15;
	}	
	double rTime = units.fromTime(&dt);
	if( rTime != 3600000000.0){
		writef("ERROR: Test 2 Failed, %s != %f μs since 2000-01-01\n",
				sTime, rTime);
		return 15;
	}
	double ssm = secondsSinceMidnight(rTime, units);
	if(ssm != 3600.0 ){
		writef("ERROR: Test 2 Failed, %f US2000 is not %f seconds since midnight\n", 
				 rTime, ssm);
		return 15;
	}
	int jd = getJulianDay(rTime, units);
	if(jd != 2451545){
		writef("ERROR: Test 2 Failed, %s is not jullian day %d\n", sTime, jd);
		return 15;
	}

	/* Test US2000 backward transformations */
	dt = units.toTime(rTime);
	string sBuf = dt.isoc();
	if(sBuf != "2000-01-01T01:00:00"){
		writef("ERROR: Test 3 Failed, %s != %f US2000\n", sBuf, rTime);
		return 15;
	}

	/* Test MJ1958 units forward transformations */
	
	Units mj1958 = UNIT_MJ1958;
	dt = "2000-001T01:00";
	if(!dt.valid){
		writef("ERROR: Test 4 Failed, can't parse %s as a string\n", sTime);
		return 15;
	}	
	rTime = mj1958.convert(&dt);
	if( rTime != 15340.041666666666){
		writef("ERROR: Test 4 Failed, %s != %f MJ1958\n", sTime, rTime);
		return 15;
	}

	dt = "1958-01-01T13:00";
	if(!dt.valid)){
		writef("ERROR: Test 5 Failed, can't parse %s as a string\n", sTime);
		return 15;
	}	
	rTime = mj1958.convert(&dt);
	if( rTime != 0.5416666666666666){
		writef("ERROR: Test 5 Failed, %s != %f MJ1958\n", sTime, rTime);
		return 15;
	}
	
	/* Test conversion form MJ1958 to US2000 */
	double rUs2000 = mj1958.convert(UNIT_US2000, rTime, units);
	if( rUs2000 != -1325329200000000.0){ 
		writef("ERROR: Test 6 Failed, %f MJ1958 != %f US2000\n", rTime, rUs2000);
		return 15;
	}
	
	/* Test SSM and Julian Day */
	double rSsm = Units_secondsSinceMidnight(rTime, units);
	int nJd  = Units_getJulianDay(rTime, units);

	if( rSsm != 46800){
		writef("ERROR: Test 7 Failed, %f MJ1958 is not %f seconds since midnight\n",
				 rTime, rSsm);
		return 15;
	}
	if( nJd != 2436205 ){
		writef("ERROR: Test 7 Failed, %f MJ1958 is not %d Julian days\n", rTime, nJd);
		return 15;
	}
	
	
	/* Test MJ1958 backward transformation */
	rTime = 0.541667;
	das_time dt1 = {0};
	Units_convertToDt(&dt1, rTime, units);
	dt_isod(sBuf.ptr, sBuf.length, &dt1, 0);
	if(sBuf != "1958-001T13:00:00"){
		writef("ERROR: Test 8 Failed, %f MJ1958 is not %s UTC\n", rTime, sBuf);
		return 15;
	}
	
	/* Test basic string parsing into canonical representation without
	   unit reduction */
	das_units a = Units_fromStr("V/m");
	das_units b = Units_fromStr("V m^-1");
	das_units c = Units_fromStr("V m**-2/2"); /*<-- don't use this, but it does work */
	
	if( a != b ){ writef("ERROR: Test 8 Failed, '%s' != '%s' \n", a, b); return 15; }
	if( a != c ){ writef("ERROR: Test 8 Failed, '%s' != '%s' \n", a, c); return 15; }
	
	
	/* Test unit inversion */
	das_units d = Units_fromStr("m V**-1");
	das_units e = Units_invert(a);
	
	if( d != e ){ writef("ERROR: Test 9 Failed, '%s' != '%s' \n", d, e); return 15; }
	
	/* Test unit raise to power */
	das_units f = Units_fromStr("V**2 m**-2");
	das_units g = Units_power(a, 2);	
	
	if( f != g ){ writef("ERROR: Test 10 Failed, '%s' != '%s' \n", f, g); return 15; }
	
	/* Test unit multiplication */
	das_units h = UNIT_E_SPECDENS;
	
	das_units i = Units_multiply( Units_power(a, 2), Units_power(UNIT_HERTZ, -1));
	
	if( h != i ){ writef("ERROR: Test 11 Failed, '%s' != '%s' \n", h, i); return 15; }
	
	/* Test interval units for t2000 */
	das_units j = Units_interval(UNIT_T2000);
	das_units k = Units_invert( Units_fromStr("Hertz") );
	if( j != k ){ writef("ERROR: Test 12 Failed, '%s' != '%s' \n", j, k); return 15; }
	
	/* Test interval units for us2000 */
	das_units l = Units_interval(UNIT_US2000);
	das_units m = Units_invert( Units_fromStr("MHz") );
	if( l != m ){ writef("ERROR: Test 13 Failed, '%s' != '%s' \n", l, m); return 15; }
	
	
	/* Test unit conversions */
	das_units ms = Units_fromStr("microsecond");
	das_units delta = Units_invert( ms );
	double rFactor = Units_convertTo(UNIT_HERTZ, 1.0, delta);
	if( rFactor != 1.0e+6){ 
		write("ERROR: Test 14 Failed, '%s' to '%s' factor = %.1e, expected 1.0e+06\n", 
				 delta, UNIT_HERTZ, rFactor);
		return 15;
	}
	
	das_units perday = Units_fromStr("kilodonut/day");
	das_units persec = Units_fromStr("donut hertz");
	
	double rTo = Units_convertTo(persec, 86.4, perday);
	if( rTo != 1.0){
		writef("ERROR: Test 15 Failed, 86.4 %s is %.4f %s, expected 1.0\n", perday,
				 rTo, persec);
		return 15;
	}
	
	/* Test unit reduction, not done implicitly because that would mess up
	 * people's intended output, but it is needed for the convertTo() function
	 * to work properly.  Reduction collapses all units to basic types with no
	 * SI prefixes and then returns a factor that can be used to adjust values
	 * in the non-reduced units to the reduced representation */
	das_units O = Units_fromStr("ohms");
	das_units O_reduced = Units_reduce(O, &rFactor);
	das_units muO = Units_fromStr("μΩ");
	
	das_units muO_reduced = Units_reduce(muO, &rFactor);
	if(O_reduced != muO_reduced ){
		writef("ERROR: Test 16 Failed, %s != %s\n", O_reduced, muO_reduced);
		return 15;
	}
	if(rFactor != 1.0e-6){
		writef("ERROR: Test 17 Failed, 1.0 %s != %.1e %s\n", muO, rFactor, 
				 muO_reduced);
		return 15;
	}
	
	/* Test unicode decomposition for the special characters μ and Ω */
	das_units bad_microohms  = Units_fromStr("µΩ m^-1"); /* Depending on the font in your  */
	das_units good_microohms = Units_fromStr("μΩ m^-1"); /* editor you might not the       */
	                                                    /* difference, but it's there and */
	                                                    /* libdas2 handles it.            */
	if( bad_microohms != good_microohms){
		writef("ERROR: Test 18 Failed, decomposition failed %s != %s\n", bad_microohms,
		       good_microohms);
		return 15;
	}
	
	/* Test order preservation for unknown units.  Assume that the user wants
	 * units in the given order unless otherwise specified. */
	string sUnits = "cm**-2 keV**-1 s**-1 sr**-1";
	das_units flux = Units_fromStr(toStringz(sUnits));
	
	if(sUnits  flux) != 0){
		writef("ERROR: Test 19 Failed, unknown units are re-arranged by default. %s != %s\n",
				 sUnits, flux);
		return 15;
	}
	
	/* New unit strings are sticky.  Test that a new variation of the new units
	 * defined above reuses the first definition */
	const char* sSameUnits = "hertz / kiloelectronvolt / centimeters^2 / sterradian";
	das_units flux2 = Units_fromStr(sSameUnits);
	if( flux2 != flux){
		writef("ERROR: Test 20 Failed, repeated unknown units are not normalized to "~
				"first instance, %s != %s\n", flux2, flux);
		return 15;
	}
	
	/* Test that wierd unit strings don't crash the program */
	
	/* from Aspera reader... */
	sUnits = "eV/(cm**-2 s**1 sr**1 eV**1)";
	das_units energy_flux = Units_fromStr(sUnits);
	das_units test_e_flux = Units_fromStr("m**2 s**-1 sr**-1");
	das_units reduced_flux = Units_reduce(energy_flux, &rFactor);
	
	if( reduced_flux != test_e_flux){
		writef("ERROR: Test 21 Failed, eV did not cancel: %s (expected %s)\n",
				 reduced_flux, test_e_flux);
		return 15;
	}
	
	/* from Cassini density reader ... */
	sUnits = "electrons / cm ^ 3";
	das_units num_dens1 = Units_fromStr(sUnits);
	das_units num_dens2 = Units_fromStr("electrons cm**-3");
	if( num_dens1 != num_dens2){
		writef("ERROR: Test 22 Failed, %s != %s", num_dens1, num_dens2);
		return 15;
	}
	
	writef("INFO: All unit manipulation tests passed\n\n");
	return 0;
}

