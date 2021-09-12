// Handle runtime initialization of the das2C lower level library
module das2.util;

import core.runtime;

import das2c.util;
import das2c.log;

shared static this()
{
	auto args = Runtime.cArgs;
	das_init(args.argv[0], DASERR_DIS_EXIT, 0, DASLOG_INFO, null);
}