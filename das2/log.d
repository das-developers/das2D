// Upper level wrapper for das2C logging functions

// We're wrapping the das2 C logger so that all loging goes through the same
// handler regardless of whether the code triggering the message is written
// in D or C.

module das2.log;

import std.format: format;
import std.string: toStringz, startsWith;
import std.exception;

import das2c.log;

void tracef(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_TRACE, file.toStringz(), line, format(args).toStringz());
}

void debugf(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_DEBUG, file.toStringz(), line, format(args).toStringz());
}

void infof(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_INFO, file.toStringz(), line, format(args).toStringz());
}

void warnf(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_WARN, file.toStringz(), line, format(args).toStringz());
}

void errorf(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_ERROR, file.toStringz(), line, format(args).toStringz());
}

void criticalf(string file=__FILE__, size_t line=__LINE__, T...)(T args)
{
	daslog(DASLOG_CRIT, file.toStringz(), line, format(args).toStringz());
}

/+ Set the global das logging level.
 +
 + This affects all threads.  The global log level is protected by 
 + a mutex lock.  In addition the logging function is protected by
 + a mutex lock.  Since only one thread can log at a time, constant
 + logging on multiple threads may slow down operations.
 +
 + The default logging level is "warning"
 +
 + Params:
 +  level = One of the strings "trace", "debug", "info", "warning", 
 +          "critical" or "nothing".
 +
 + Returns: The old logging level as an integer, see das2c/log.d for details.
 +/
int loglevel(string level)
{
	int nOld = daslog_level();

	if(level.startsWith('n')) daslog_setlevel(DASLOG_NOTHING);
	else if(level.startsWith('c')) daslog_setlevel(DASLOG_CRIT);
	else if(level.startsWith('e')) daslog_setlevel(DASLOG_ERROR);
	else if(level.startsWith('w')) daslog_setlevel(DASLOG_WARN);
	else if(level.startsWith('i')) daslog_setlevel(DASLOG_INFO);
	else if(level.startsWith('d')) daslog_setlevel(DASLOG_DEBUG);
	else if(level.startsWith('t')) daslog_setlevel(DASLOG_TRACE);
	else enforce(false, format!"Unknown logging level %s"(level));

	return nOld;
}

/+ Get the current logging level as an integer 
 + Returns: The current logging level as an integer, see das2c/log.d for details.
 +/
int loglevel(){ 
	return daslog_level();
}

unittest{
	import std.stdio;

	daslog_setlevel(DASLOG_INFO);
	infof("This should print the string \"two\" and the number 1: '%s %d'", "two", 1);
	debugf("This should not print at all");
	loglevel("trace");
	debugf("Now it should print");
}

