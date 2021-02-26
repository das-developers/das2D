module das2.log;

import das2.util : das_log_handler_t;
import std.string, std.conv;

/** Enumerated values for the das2_init log level (nLevel) */
enum int DASLOG_NOTHING = 255, DASLOG_CRIT = 100, DASLOG_ERROR = 80,
         DASLOG_WARN = 60, DASLOG_INFO = 40, DASLOG_DEBUG = 20,
         DASLOG_TRACE = 0;

extern (C) int daslog_level();

extern (C) int daslog_setlevel(int nLevel);

extern (C) bool daslog_set_showline(int nLevel);

extern (C) extern __gshared int das_nMinLevel;

extern (C) void daslog(
	int nLevel, const char* sSrcFile, int nLine, const char* sFmt, ...
);

void dasTrace(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_TRACE){
		daslog(DASLOG_TRACE, toStringz(file), to!int(line), toStringz(sMsg));
	}
}

void dasDebug(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_DEBUG){
		daslog(DASLOG_TRACE, toStringz(file), to!int(line), toStringz(sMsg));
	}
}

void dasInfo(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_DEBUG){
		daslog(DASLOG_TRACE, toStringz(file), to!int(line), toStringz(sMsg));
	}
}

void dasWarn(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_DEBUG){
		daslog(DASLOG_TRACE, toStringz(file), to!int(line), toStringz(sMsg));
	}
}

/** Log an error
 * Typically an error is an unrecoverable problem with a particular run of
 * a program.  The end user may be able to fix the problem by choosing a
 * different input file, etc.  No matter the issuer this run of the program
 * is finished.
 */
void dasError(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_DEBUG){
		daslog(DASLOG_TRACE, toStringz(file), to!int(line), toStringz(sMsg));
	}
}

/** Log a critical issue
 * This should only be used for code bug reports, basically if only a
 * programmer can fix the error, it's a critical error
 */
void dasCritical(T...)(
	lazy string sMsg, string file = __FILE__, size_t line = __LINE__
){
	if(das_nMinLevel >= DASLOG_DEBUG){
		daslog(DASLOG_TRACE, file, line, toStringz(sMsg));
	}
}

/** Allow switching the log handler after library initialization */
extern(C) das_log_handler_t daslog_sethandler(das_log_handler_t new_handler);
