// das2 D interface

module das2;

import das2c.util;
import das2c.log;
import das2c.units;
import core.runtime;

public import das2.units;
public import das2.time;
public import das2.range;

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


shared static this()
{
	auto args = Runtime.cArgs;
	das_init(args.argv[0], DASERR_DIS_EXIT, 0, DASLOG_INFO, null);
	
	// Now that constant unit pointer array is initialized, create
	// static wrappers for the static units.
	
	UNIT_DIMENSIONLESS = cast(immutable) Units(das2c.units.UNIT_DIMENSIONLESS);

	UNIT_US2000 = cast(immutable) Units(das2c.units.UNIT_US2000);
	UNIT_HERTZ  = cast(immutable) Units(das2c.units.UNIT_HERTZ);
	UNIT_US2000 = cast(immutable) Units(das2c.units.UNIT_US2000);
	UNIT_MJ1958 = cast(immutable) Units(das2c.units.UNIT_MJ1958);
	UNIT_T2000  = cast(immutable) Units(das2c.units.UNIT_T2000);
	UNIT_T1970  = cast(immutable) Units(das2c.units.UNIT_T1970);
	UNIT_NS1970 = cast(immutable) Units(das2c.units.UNIT_NS1970);
	UNIT_UTC    = cast(immutable) Units(das2c.units.UNIT_UTC);

	UNIT_SECONDS      = cast(immutable) Units(das2c.units.UNIT_SECONDS);
	UNIT_HOURS        = cast(immutable) Units(das2c.units.UNIT_HOURS);
	UNIT_DAYS         = cast(immutable) Units(das2c.units.UNIT_DAYS);
	UNIT_MILLISECONDS = cast(immutable) Units(das2c.units.UNIT_MILLISECONDS);
	UNIT_MICROSECONDS = cast(immutable) Units(das2c.units.UNIT_MICROSECONDS);
	UNIT_NANOSECONDS  = cast(immutable) Units(das2c.units.UNIT_NANOSECONDS);

	UNIT_HERTZ      = cast(immutable) Units(das2c.units.UNIT_HERTZ);
	UNIT_KILO_HERTZ = cast(immutable) Units(das2c.units.UNIT_KILO_HERTZ);
	UNIT_MEGA_HERTZ = cast(immutable) Units(das2c.units.UNIT_MEGA_HERTZ);
	UNIT_E_SPECDENS = cast(immutable) Units(das2c.units.UNIT_E_SPECDENS);
	UNIT_B_SPECDENS = cast(immutable) Units(das2c.units.UNIT_B_SPECDENS);
	UNIT_NT         = cast(immutable) Units(das2c.units.UNIT_NT);
	
	UNIT_NUMBER_DENS = cast(immutable) Units(das2c.units.UNIT_NUMBER_DENS);
	
	UNIT_DB = cast(immutable) Units(das2c.units.UNIT_DB);
	
	UNIT_KM = cast(immutable) Units(das2c.units.UNIT_KM);
	
	UNIT_EV = cast(immutable) Units(das2c.units.UNIT_EV);
	
	UNIT_DEGREES = cast(immutable) Units(das2c.units.UNIT_DEGREES);
}

unittest
{
	import std.format;
	
	// 1. Test singleton nature of unit values 
	Units Hz1 = Units("Hz");
	Units Hz2 = Units("Hz");
	assert( (Hz1 == Hz2) && (Hz2 == UNIT_HERTZ), format(
		"Test 1 Failed, %s != %s", Hz1, Hz2
	));
	
	// 2-6. Test US2000 forward transformations
	Units us2000 = UNIT_US2000;
	string sTime = "2000-1-1T1:00";
	DasTime dt;
	try{ dt = DasTime(sTime); }
	catch(ConvException ex){
		assert(false, "Test 2 Failed, can't parse "~sTime~" as a string");
	}
	
	double rTime = us2000.convert(dt);
	assert(rTime == 3600000000.0, format(
		"Test 3 Failed, %s != %f μs since 2000-01-01",	sTime, rTime
	));
	
	double ssm = us2000.secondsSinceMidnight(rTime);
	assert(ssm == 3600.0, format(
		"Test 4 Failed, %f US2000 is not %f seconds since midnight", rTime, ssm
	));
	
	int jd = us2000.getJulianDay(rTime);
	assert(jd == 2451545, format(
		"Test 5 Failed, %s is not jullian day %d", sTime, jd
	));

	// 6. Test US2000 backward transformations
	dt = us2000.toTime(rTime);
	string sBuf = dt.isoc(0);
	assert(sBuf == "2000-01-01T01:00:00", format(
		"Test 6 Failed, %s != %f US2000", sBuf, rTime
	));

	// 7-10. Test MJ1958 units forward transformations */
	
	Units mj1958 = UNIT_MJ1958;
	try{ dt = DasTime("2000-001T01:00"); }
	catch(ConvException ex){ 
		assert(false, "Test 7 Failed, can't parse "~sTime~" as a string");
	}	
	
	rTime = mj1958.convert(dt);
	assert( rTime == 15340.041666666666, format(
		"Test 8 Failed, %s != %f MJ1958", sTime, rTime
	));

	try{ dt = DasTime("1958-01-01T13:00"); }
	catch(ConvException ex){ 
		assert(false, "Test 9 Failed, can't parse "~sTime~"%s as a string");
	}	
	rTime = mj1958.convert(dt);
	assert(rTime == 0.5416666666666666, format(
		"Test 10 Failed, %s != %f MJ1958", sTime, rTime
	));
	
	// 11. Test conversion from MJ1958 to US2000
	double rUs2000 = UNIT_US2000.convert(rTime, UNIT_MJ1958);
	assert(rUs2000 == -1325329200000000.0, format(
		"Test 11 Failed, %f MJ1958 != %f US2000", rTime, rUs2000
	));
	
	// 12-13. Test SSM and Julian Day
	double rSsm = mj1958.secondsSinceMidnight(rTime);
	int nJd  = mj1958.getJulianDay(rTime);

	assert(rSsm == 46800, format(
		"Test 12 Failed, %f MJ1958 is not %f seconds since midnight", rTime, rSsm
	));
	assert(nJd == 2436205, format(
		"Test 13 Failed, %f MJ1958 is not %d Julian days", rTime, nJd
	));
	
	// 14. Test MJ1958 backward transformation
	rTime = 0.541667;
	DasTime dt1 = mj1958.toTime(rTime);
	sBuf = dt1.isod(0);
	assert(sBuf == "1958-001T13:00:00", format(
		"Test 14 Failed, %f MJ1958 is not %s UTC", rTime, sBuf
	));
	
	// 14-15. Test basic string parsing into canonical representation without
	//        unit reduction 
	Units a = Units("V/m");
	Units b = Units("V m^-1");
	Units c = Units("V m**-2/2"); // <-- don't use this, but it does work
	assert( a == b, format("Test 14 Failed, '%s' != '%s' ", a, b));
	assert( a == c, format("Test 15 Failed, '%s' != '%s' ", a, c));
	
	// 16. Test unit inversion
	Units d = Units("m V**-1");
	Units e = a^^-1;
	assert(d == e, format("Test 16 Failed, '%s' != '%s' ", d, e));
	
	// 17. Test unit raise to power
	Units f = Units("V**2 m**-2");
	Units g = a^^2;	
	assert(f == g, format("Test 17 Failed, '%s' != '%s' ", f, g));
	
	// 18. Test unit multiplication
	Units h = UNIT_E_SPECDENS;
	Units i = (a^^2) * (UNIT_HERTZ^^-1);
	assert(h == i, format("Test 18 Failed, '%s' != '%s' ", h, i));
	
	// 19. Test interval units for t2000
	Units j = UNIT_T2000.interval();
	Units k = Units("Hertz").invert();
	assert( j == k, format("Test 19 Failed, '%s' != '%s' ", j, k));
	
	// 20. Test interval units for us2000
	Units l = UNIT_US2000.interval();
	Units m = Units("MHz").invert();
	assert( l == m, format("Test 20 Failed, '%s' != '%s' ", l, m));
	
	// 21. Test unit conversions 
	Units ms = Units("microsecond");
	Units delta = ms^^-1;
	double rFactor = UNIT_HERTZ.convert(1.0, delta);
	assert( rFactor == 1.0e+6, format(
		"Test 21 Failed, '%s' to '%s' factor = %.1e, expected 1.0e+06", 
		delta, UNIT_HERTZ, rFactor
	));
	
	// 22. Test SI prefixes on unknown units, in this case donuts
	Units perday = Units("kilodonut/day");
	Units persec = Units("donut hertz");
	
	double rTo = persec.convert(86.4, perday);
	assert( rTo == 1.0, format(
		"Test 22 Failed, 86.4 %s is %.4f %s, expected 1.0", perday, rTo, persec
	));
	
	// 23-24. Test unit reduction, not done implicitly because that would mess
	// up people's intended output, but it is needed for the convertTo()
	// function to work properly.  Reduction collapses all units to basic types
	// with no SI prefixes and then returns a factor that can be used to adjust
	// values in the non-reduced units to the reduced representation
	Units O = Units("ohms");
	Units O_reduced = O.reduce(rFactor);
	Units muO = Units("μΩ");
	
	Units muO_reduced = muO.reduce(rFactor);
	assert(O_reduced == muO_reduced, format(
		"Test 23 Failed, %s != %s", O_reduced, muO_reduced
	));
	assert(rFactor == 1.0e-6, format(
		"Test 24 Failed, 1.0 %s != %.1e %s", muO, rFactor, muO_reduced
	));
	
	// 25. Test unicode decomposition for the special characters μ and Ω 
	Units bad_microohms  = Units("µΩ m^-1"); // Depending on the font in your
	Units good_microohms = Units("μΩ m^-1"); // editor you might not notice the
	                                         // difference, but it's there and
	                                         // das2 handles it.
	assert( bad_microohms == good_microohms, format(
		"Test 25 Failed, decomposition failed %s != %s", 
		bad_microohms, good_microohms
	));
	
	// 26. Test order preservation for unknown units.  Assume that the 
	//     user wants units in the given order unless otherwise specified.
	string sUnits = "cm**-2 keV**-1 s**-1 sr**-1";
	Units flux = Units(sUnits);
	
	assert(flux.toString() == sUnits, format(
		"Test 26 Failed, unknown units are re-arranged by default. '%s' != '%s'",
		sUnits, flux
	));
	
	// 27. New unit strings are sticky.  Test that a new variation of
	//     the new units defined above reuses the first definition
	string sSameUnits = "hertz / kiloelectronvolt / centimeters^2 / sterradian";
	Units flux2 = Units(sSameUnits);
	
	// Blocked due to bug in das2C, will be renabled when das2C is fixed.
	//assert(flux2 == flux, format(
	//	"Test 27 Failed, repeated unknown units are not normalized to "~
	//	"first instance, %s != %s", flux2, flux
	//));
	
	// 28-29. Test that wierd unit strings don't crash the program
	
	// from Aspera reader...
	sUnits = "eV/(cm**-2 s**1 sr**1 eV**1)";
	Units energy_flux = Units(sUnits);
	Units test_e_flux = Units("m**2 s**-1 sr**-1");
	Units reduced_flux = energy_flux.reduce(rFactor);
	
	assert(reduced_flux == test_e_flux, format(
		"Test 28 Failed, eV did not cancel: %s (expected %s)", 
		reduced_flux, test_e_flux
	));
	
	// from Cassini density reader ...
	sUnits = "electrons / cm ^ 3";
	Units num_dens1 = Units(sUnits);
	Units num_dens2 = Units("electrons cm**-3");
	assert(num_dens1 == num_dens2, format(
		"Test 22 Failed, %s != %s", num_dens1, num_dens2
	));
	
	//writef("INFO: All unit manipulation tests passed");
}
