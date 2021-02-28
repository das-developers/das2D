// das2 D interface

module das2;

import das2c.util;
import das2c.log;
import das2c.units;
import core.runtime;

public import das2.units;
public import das2.time;

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
