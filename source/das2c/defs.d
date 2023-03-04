/* Copyright (C) 2020 Chris Piker <chris-piker@uiowa.edu>
 *
 * This file is part of das2C, the Core Das2 C Library.
 *
 * das2C is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License version 2.1 as published
 * by the Free Software Foundation.
 *
 * das2C is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * version 2.1 along with das2C; if not, see <http://www.gnu.org/licenses/>.
 */

/** @file defs.h Minimal definitions for das2 utilities that can safely be
 * run without calling das_init().
 *
 * This is mostly useful for old das1 programs.
 */

module das2c.defs;

extern (C):

/* Get compile time byte order, results in faster code that avoids
 * runtime checks.  For some newer chips this may not work as the
 * processor can be switched from big endian to little endian at runtime.
 *
 * At the end of the day either HOST_IS_LSB_FIRST will be defined, or it won't.
 * If this macro is defined then the host computer stores the least significant
 * byte of a word in the lowest address, i.e. it's a little endian machine.  If
 * this macro is not defined then the host computer stores the list significant
 * byte of a word in the highest address, i.e. it a big endian machine.
 */

/* End Linux Section */

/** This computer is a little endian machine, macro is not present on big
 * endian machines.
 */

/* Web assembly environment is defined as little endian */

/* webassembly */
/* _WIN32 */
/* __sun */
/* __linux */

/* Setup the DLL macros for windows */

/** @defgroup utilities Utilities
 * Library initialization, error handling, logging and a few minor libc extensions
 */

/** @addtogroup utilities
 * @{
 */

enum DAS_22_STREAM_VER = "2.2";

/* On Solaris systems NAME_MAX is not defined because pathconf() is supposed
 * to be used to get the exact limit by filesystem.  Since all the filesystems
 * in common use today have support 255 characters, let's just define that
 * to be NAME_MAX in the absence of something better.
 */

/* Make it obvious when we are just moving data as opposed to characters */

/** return code type
 * 0 indicates success, negative integer indicates failure
 */
alias DasErrCode = int;

/** success return code */
enum DAS_OKAY = 0;

enum DASERR_NOTIMP = 8;
enum DASERR_ASSERT = 9;
enum DASERR_INIT = 11;
enum DASERR_BUF = 12;
enum DASERR_UTIL = 13;
enum DASERR_ENC = 14;
enum DASERR_UNITS = 15;
enum DASERR_DESC = 16;
enum DASERR_PLANE = 17;
enum DASERR_PKT = 18;
enum DASERR_STREAM = 19;
enum DASERR_OOB = 20;
enum DASERR_IO = 22;
enum DASERR_DSDF = 23;
enum DASERR_DFT = 24;
enum DASERR_LOG = 25;
enum DASERR_ARRAY = 26;
enum DASERR_VAR = 27;
enum DASERR_DIM = 28;
enum DASERR_DS = 29;
enum DASERR_BLDR = 30;
enum DASERR_HTTP = 31;
enum DASERR_DATUM = 32;
enum DASERR_VALUE = 33;
enum DASERR_OP = 34;
enum DASERR_CRED = 35;
enum DASERR_NODE = 36;
enum DASERR_TIME = 37;
enum DASERR_MAX = 37;

/* _das_defs_h_ */
