// Handle runtime initialization of the das2C lower level library
module das2.util;

import core.runtime;
import std.format: format;

import das2c.util;
import das2c.log;

version(SPICE){
	import das2c.spice;
}

/* ************************************************************************* */
/* Library initialization */
shared static this()
{
	auto args = Runtime.cArgs;
	das_init(args.argv[0], DASERR_DIS_EXIT, 0, DASLOG_INFO, null);

	version(SPICE){
		das_spice_err_setup();
	}
}

/* ************************************************************************* */
class DasException : Exception
{
package: // Only stuff in the das2 package can throw these
	this(	string msg, string file = __FILE__, size_t line = __LINE__) @safe pure {
		super(format("[%s,%s] %s", file, line, msg));
	}
}
