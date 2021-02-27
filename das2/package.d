// das2 D interface

public import das2.units;
public import das2.time;

import das2c.util;
import core.runtime;

shared static this()
{
	auto args = Runtime.cArgs;
	das_init(args.argv[0], DASERR_DIS_EXIT, 0, DASLOG_INFO, null);
}
