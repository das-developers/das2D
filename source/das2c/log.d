/* Copyright (C) 2015-2017 Chris Piker <chris-piker@uiowa.edu>
 *
 * This file is part of libdas2, the Core Das2 C Library.
 *
 * Libdas2 is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License version 2.1 as published
 * by the Free Software Foundation.
 *
 * Libdas2 is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * version 2.1 along with libdas2; if not, see <http://www.gnu.org/licenses/>.
 */

/** @file log.h Simple message logging
 *
 * Generic thread safe logging.
 * By default messages are simply printed to standard error, use
 * das_log_sethandler() to send messages some where else.  All log messages
 * are sent via das_log(), however the following convience macros make for
 * less typing:
 *
 *  - das_trace(): Log a DAS_LL_TRACE level message.
 *  - das_trace_v(): Log a DAS_LL_TRACE level message using fprintf style varargs.
 *  - das_debug(): Log a DAS_LL_DEBUG level message.
 *  - das_debug_v(): Log a DAS_LL_DEBUG level message using fprintf style varargs.
 *  - das_notice(): Log a DAS_LL_NOTICE level message.
 *  - das_notice_v(): Log a DAS_LL_NOTICE level message using fprintf style varargs.
 *  - das_warn(): Log a DAS_LL_WARN level message.
 *  - das_warn_v(): Log a DAS_LL_WARN level message using fprintf style varargs.
 *  - das_error(): Log a DAS_LL_ERROR level message.
 *  - das_error_v(): Log a DAS_LL_ERROR level message using fprintf style varargs.
 *  - das_critical(): Log a DAS_LL_CRITICAL level message, these should be reserved for program exit conditions.
 *  - das_critical_v(): Log a DAS_LL_CRITICAL level message using fprintf style varargs, these should be reserved for program exit conditions.
 *
 * For example a log line such as:
 * @code
 *   das_warn_v("File %s, Pkt %05d: Header Block > 256 bytes", sFile, nIdx);
 * @endcode
 * is equivalent to:
 * @code
 *   das_log(DAS_LL_WARN, __FILE__, __LINE__,
 *           "File %s, Pkt %05d: Header Block > 256 bytes", sFile, nIdx);
 * @endcode
 * but shorter.
 */

/* Ported over from librpwgse which was laborously developed for Juno Waves
 * support.  Since logging is much different then just failing with an
 * error, this is a different falcility than the das_error_func from util.h
 * but the two items have common functionality that should be merged over time.
 * -cwp 2016-10-20
 */

module das2c.log;

import das2c.util;

extern (C):

/** @addtogroup utilities
 * @{
 */

enum DASLOG_NOTHING = 255;
enum DASLOG_CRIT = 100; /* same as java.util.logging.Level.SEVERE */
enum DASLOG_ERROR = 80;
enum DASLOG_WARN = 60; /* same as java.util.logging.Level.WARNING */
enum DASLOG_INFO = 40; /* same as java.util.logging.Level.INFO & CONFIG */
enum DASLOG_DEBUG = 20; /* same as java.util.logging.Level.FINE */
enum DASLOG_TRACE = 0; /* same as java.util.logging.Level.FINER & FINEST */

/** Get the log level.
 *
 * @returns one of: DAS_LL_CRIT, DAS_LL_ERROR, DAS_LL_WARN, DAS_LL_INFO,
 *                  DAS_LL_DEBUG, DAS_LL_TRACE
 */
int daslog_level ();

/** Set the logging level for this thread.
 *
 * @param nLevel Set to one of
 *   - DASLOG_TRACE
 *   - DASLOG_DEBUG
 *   - DASLOG_NOTICE
 *   - DASLOG_WARN
 *   - DASLOG_ERROR
 *   - DASLOG_CRITICAL
 *   - DASLOG_NOTHING
 *
 * @return The previous log level.
 */
int daslog_setlevel (int nLevel);

/** Output source file and line numbers for messages at or above this level */
bool daslog_set_showline (int nLevel);

/* Basic logging function, macros use this */
void daslog (int nLevel, const(char)* sSrcFile, int nLine, const(char)* sFmt, ...);

/** Macro wrapper around das_log() for TRACE messages with out variable args */
extern (D) auto daslog_trace(T)(auto ref T M)
{
    return daslog(DASLOG_TRACE, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for DEBUG messages with out variable args */
extern (D) auto daslog_debug(T)(auto ref T M)
{
    return daslog(DASLOG_DEBUG, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for INFO messages with out variable args */
extern (D) auto daslog_info(T)(auto ref T M)
{
    return daslog(DASLOG_INFO, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for WARNING messages with out variable args */
extern (D) auto daslog_warn(T)(auto ref T M)
{
    return daslog(DASLOG_WARN, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for ERROR messages with out variable args */
extern (D) auto daslog_error(T)(auto ref T M)
{
    return daslog(DASLOG_ERROR, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for CRITICAL messages with out variable args */
extern (D) auto daslog_critical(T)(auto ref T M)
{
    return daslog(DAS_LL_CRITICAL, __FILE__, __LINE__, M);
}

/** Macro wrapper around das_log() for TRACE messages with variable arguments */
/** Macro wrapper around das_log() for DEBUG messages with variable arguments */
/** Macro wrapper around das_log() for INFO messages with variable arguments */
/** Macro wrapper around das_log() for WARNING messages with variable arguments */
/** Macro wrapper around das_log() for ERROR messages with variable arguments */
/** Macro wrapper around das_log() for CRITICAL messages with variable arguments */

/** Install a new message handler function for this thread.
 * The default message handler just prints to stderr, which is not very
 * effecient, nor is it appropriate for GUI applications.
 *
 * @param new_handler The new message handler, or NULL to set to the default
 *        handler.
 * @return The previous message handler function pointer
 */
das_log_handler_t daslog_sethandler (das_log_handler_t new_handler);

/** @} */

/* _das_log_h_ */
