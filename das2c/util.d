/* Copyright (C) 1997-2020 Chris Piker <chris-piker@uiowa.edu>
 *                         Larry Granroth <larry-granroth@uiowa.edu>
 *                         Jeremy Faden <jeremy-faden@uiowa.edu>
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

/** @file util.h */
module das2c.util;


extern (C):

public import core.sys.posix.sys.types;

import core.stdc.stdio;
import core.stdc.stdlib;

import das2c.defs;


/** Used to indicate that errors should trigger program exit */
enum DASERR_DIS_EXIT = 0;

/** Used to indicate that errors should trigger library functions to return error values */
enum DASERR_DIS_RET = 1;

/** Used to indicate that errors should trigger program abort with a core dump */
enum DASERR_DIS_ABORT = 43;

/** Definition of a message handler function pointer.
 * Message handlers need to be prepared for any of the string pointers
 * sMsg, sDataStatus, or sStackTrace to be null.
 *
 * @param nLevel The message level.  If nLevel is equal to or greater than
 *  das_log_getlevel() then the message should be logged.
 *
 * @param sMsg The message, usually not null.
 *
 * @param bPrnTime The current system time should be included in the log
 *        output.
 */
alias das_log_handler_t = void function (int nLevel, const(char)* sMsg, bool bPrnTime);

/** Initialize any global structures in the Das2 library.
 *
 * This should be the first function your program calls before using any libdas2
 * functions.  In general libdas2 tries to avoid global structures but does use
 * them in three areas:
 *
 *   * Error and log handling - Since the error and logging disposition should
 *     be the same for all library calls handlers are set here
 *
 *   * Unit conversions - Since das_unit varibles should be comparible using a
 *     simple equality test, a global registry of const char pointers is needed
 *
 *   * FFTW plan mutexes - Since the FFTW library unfortunatly uses global
 *     plan memory
 *
 *   * OpenSSL Contex mutexes - The openssl library contex cannot be changed
 *     by multiple threads at the same time, a mutex is setup to prevent this
 *     from happening
 *
 * This function initializes defaults for the items above.
 *
 * @param sProgName The name of the program using the library.  Used in
 *        some error messages.
 *
 * @param nErrDis Set the behavior the library takes when an error is
 *        encountered.  May be one of DASERR_DIS_EXIT, call exit() when an
 *        error occurs; DASERR_DIS_RET, return with an error code; or
 *        DASERR_DIS_ABORT, call abort().  The value of DASERR_DIS_EXIT is
 *        0 so you can use that for the default behavior.  If DASERR_DIS_RET is
 *        used, the function das_get_error() can be used to retrieve the most
 *        recent error message.
 *
 * @param nErrBufSz If not zero, a global error message buffer will be allocated
 *        that is this many bytes long and error message will be saved into the
 *        buffer instead of being sent to the standard error channel.  Messages
 *        can be retrieved via das_get_error().
 *        If zero, these will be send to the standard error channel as soon as
 *        they occur.  Saving errors is only useful if the error disposition is
 *        DAS2_ERRDIS_RET as otherwise the program exits before the message can
 *        be output.
 *
 * @param nLevel Set the logging level to one of, DASLOG_TRACE, DASLOG_DEBUG,
 *        DASLOG_NOTICE, DASLOG_WARN, DASLOG_ERROR, DASLOG_CRITICAL.
 *
 * @param logfunc A callback for handling log messages.  The callback need not
 *        be thread safe as it will only be triggered inside mutual exclusion
 *        (mutex) locks.  If NULL messages are printed to the stardard error
 *        channel.
 *
 * The error disposition does not affect any errors that are encountered within
 * das_init.  Errors should not occur during initialization, any that do
 * trigger a call to exit()
 */
void das_init (
    const(char)* sProgName,
    int nErrDis,
    int nErrBufSz,
    int nLevel,
    das_log_handler_t logfunc);

/** A do nothing function on Unix, closes network sockets on windows */
void das_finish ();

DasErrCode das_error_func (
    const(char)* sFile,
    const(char)* sFunc,
    int nLine,
    DasErrCode nCode,
    const(char)* sFmt,
    ...);

DasErrCode das_error_func_fixed (
    const(char)* sFile,
    const(char)* sFunc,
    int nLine,
    DasErrCode nCode,
    const(char)* sMsg);

/** Signal an error condition.
 *
 * This routine is called throughout the code when an error condition arrises.
 *
 * The default handler for error conditions prints the message provided to
 * the standard error channel and then calls exit(nErrCode).  To have the library
 * call your handler instead use the das_set_error_handler() function.  To have
 * the library abort with a core dump on an error use das_abort_on_error().
 *
 * Each source file in the code has it's own error code.  Though it's probably
 * not that useful to end users, the codes are provided here:
 *
 *  - @b  8 : Not yet implemented - DASERR_NOTIMP
 *  - @b  9 : Assertion Failures  - DASERR_ASSERT
 *  - @b 10 : das1.c        - D1ERR
 *  - @b 11 : Lib initialization errors - DASERR_INIT
 *  - @b 12 : buffer.c      - DASERR_BUF
 *  - @b 13 : util.c        - DASERR_UTIL
 *  - @b 14 : encoding.c    - DASERR_ENC
 *  - @b 15 : units.c       - DASERR_UNITS
 *  - @b 16 : descriptor.c  - DASERR_DESC
 *  - @b 17 : plane.c       - DASERR_PLANE
 *  - @b 18 : packet.c      - DASERR_PKT
 *  - @b 19 : stream.c      - DASERR_STREAM
 *  - @b 20 : oob.c         - DASERR_OOB
 *  - @b 21 : io.c          - DASERR_IO
 *  - @b 22 : dsdf.c        - DASERR_DSDF
 *  - @b 23 : dft.c         - DASERR_DFT
 *  - @b 24 : log.c         - DASERR_LOG
 *  - @b 25 : array.c       - DASERR_ARRAY
 *  - @b 26 : variable.c    - DASERR_VAR
 *  - @b 27 : dimension.c   - DASERR_DIM
 *  - @b 28 : dataset.c     - DASERR_DS
 *  - @b 29 : builder.c     - DASERR_BLDR
 *  - @b 30 : http.c        - DASERR_HTTP
 *  - @b 31 : datum.c       - DASERR_DATUM
 *  - @b 32 : value.c       - DASERR_VALUE
 *  - @b 34 : operater.c    - DASERR_OP
 *  - @b 35 : credentials.c - DASERR_CRED
 *  - @b 36 : catalog.c     - DASERR_CAT
 *
 * Application programs are recommended to use values 64 and above to avoid
 * colliding with future das2 error codes.
 *
 * @param nErrCode The value to return to the shell, should be one of the above.
 * @return By default this function never returns but if the libdas2 error
 *         disposition has been set to DAS2_ERRDIS_RET then the value of
 *         nErrCode is returned.
 */

/** Error handling: Trigger Core Dumps
 *
 * Call this function to have the library exit via an abort() call instead of
 * using exit(ErrorCode).  On most systems this will trigger the generation of
 * a core file that can be used for debugging.
 * @warning: Calling this function prevents open file handles from being flushed
 *           to disk which will typically result in corrupted output.
 */
void das_abort_on_error ();

/** Error handling: Normal Exit
 * Set the library to call exit(ErrorCode) when a problem is detected.  This is
 * usually what you want and the library's default setting.
 */
void das_exit_on_error ();

/** Error handling: Normal Return
 * Set the library to return normally to the calling function with a return value
 * that indicates a problem has occurred.  This will be the new default, but is
 * not yet tested.
 */
void das_return_on_error ();

/** Error handling: get the library's error disposition
 * @returns one of the following integers:
 *    - DAS2_ERRDIS_EXIT - Library exits when there is a problem
 *    - DAS2_ERRDIS_ABORT - Library aborts, possibly with core dump on a problem
 *    - DAS2_ERRDIS_RET - Library returns normally with an error code
 */
int das_error_disposition ();

/** Error handling: Print formatted error to standard error stream
 * Set the library to ouput formatted error messages to the processes
 * standard error stream. This is the default.
 */
void das_print_error ();

/** Error handling: Save formatted error in a message buffer.
 * Set the library to save formatted error message to a message buffer.
 *
 * @param maxmsg maximum message size. The buffer created will be maxmsg in
 *        length, meaning any formatted messages longer than the available
 *        buffer size will be truncated to maxmsg-1
 *
 * @returns true if error buffer setup was successful, false otherwise.
 */
bool das_save_error (int maxmsg);

/** Structure returned from das_get_error().
 *
 * To get error messages libdas2 must be set to an error dispostition of
 * DAS2_ERRDIS_RET
 */
struct das_error_message
{
    int nErr;
    char* message;
    size_t maxmsg;
    char[256] sFile;
    char[64] sFunc;
    int nLine;
}

alias das_error_msg = das_error_message;

/** Return the saved das2 error message buffer.
 * @returns an instance of Das2ErrorMessage. The struct returned contains
 *          the error code, formatted message, max message size, and the
 *          source file, function name, and line number of where the
 *          message originated.
 * @memberof das_error_msg
 */
das_error_msg* das_get_error ();

/** Free an error message structure allocated on the heap
 *
 * @param pMsg the message buffer to free
 * @memberof das_error_msg
 */
void das_error_free (das_error_msg* pMsg);

/** Check to see if two floating point values are within an epsilon of each
 * other */
extern (D) auto das_within(T0, T1, T2)(auto ref T0 A, auto ref T1 B, auto ref T2 E)
{
    return fabs(A - B) < E ? true : false;
}

/** limit of number of properties per descriptor. */
enum DAS_XML_MAXPROPS = 400;

/** The limit on xml packet length, in bytes.  (ascii encoding.) */
enum DAS_XML_BUF_LEN = 1000000;

/** The limit of xml element name length, in bytes. */
enum DAS_XML_NODE_NAME_LEN = 256;

/** Get the library version
 *
 * @returns the version tag string for the das2 core library, or
 * the string "untagged" if the version is unknown
 */
const(char)* das_lib_version ();

/** The size of an char buffer large enough to hold valid object IDs */
enum DAS_MAX_ID_BUFSZ = 64;

/** Check that a string is suitable for use as an object ID
 *
 * Object ID strings are ascii strings using only characters from the set
 * a-z, A-Z, 0-9, and _.  They do not start with a number.  They are no more
 * than 63 bytes long.  Basically they can be used as variable names in most
 * programming languages.
 *
 * If the das_error_disposition is set to exit this function never returns.
 *
 * @param sId
 * @return True if the string can be used as an ID, false otherwise.
 */
bool das_assert_valid_id (const(char)* sId);

/** Store string in a buffer that is reallocated if need be
 *
 * @param psDest a pointer to the storage location
 * @param puLen a pointer to the size of the storage location
 * @param sSrc the source string to store.
 */
void das_store_str (char** psDest, size_t* puLen, const(char)* sSrc);

/** Allocate a new string on the heap and format it
 *
 * Except for using das_error on a failure, this is a copy of the
 * code out of man 3 printf on Linux.
 *
 * @returns A pointer to the newly allocated and formatted string on
 *          the heap, or NULL if the function failed and the das2 error
 *          disposition allows for continuation after a failure
 */
char* das_string (const(char)* fmt, ...);

/** Copy a string into a new buffer allocated on the heap
 *
 * @param sIn the string to copy
 * @return a pointer to the newly allocated buffer containing the same
 *          characters as the input string or NULL if the input length was
 *          zero
 */
char* das_strdup (const(char)* sIn);

/** A memset that handles multi-byte items
 *
 * Uses memcpy because the amount of data written in each call goes up
 * exponentially and memcpy is freaking fast, much faster than a linear
 * write loop for large arrays.
 *
 * @param pDest The destination area must not overlap with pSrc
 * @param pSrc  A location for an individual element to repeat in pDest
 * @param uElemSz The size in bytes of a single element
 * @param uCount The number of elements to repeat in pDest
 * @return The input pDest pointer.  There is no provision for a NULL return
 *         as this function should not fail since the memory is pre-allocated
 *         by the caller
 *
 */
ubyte* das_memset (
    ubyte* pDest,
    const(ubyte)* pSrc,
    size_t uElemSz,
    size_t uCount);

/** Store a formatted string in a newly allocated buffer
 *
 * This version is suitable for calling from variable argument functions.
 *
 * Except for using das_error on a failure, this is a copy of the
 * code out of man 3 printf on Linux.
 *
 * @param fmt - a printf format string
 * @param ap A va_list list, see vfprintf or stdarg.h for details
 *
 * @returns A pointer to the newly allocated and formatted string on
 *          the heap, or NULL if the function failed and the das2 error
 *          disposition allows for continuation after a failure
 */
/* char* das_vstring (const(char)* fmt, va_list ap); */

/** Is the path a directory.
 * @param path The directory in question, passed to stat(2)
 * @return true if @b path can be determined to be a directory, false otherwise
 */
bool das_isdir (const(char)* path);

/** Copy a file to a distination creating directories as needed.
 *
 * If the files exists at the destination it in overwritten.  Directories are
 * created as needed.  Directory permissions are are the same as the file
 * with the addition that for each READ permission in the mode, directory
 * EXEC permission is added.
 *
 * @param src - name of file to copy
 * @param dest - name of destination
 * @param mode - the permission mode of the destitation file, 0664 is
 *               recommened if you can descide on the output permissions mode.
 *               (mode argument not present in WIN32 version)
 *
 * @returns - true if the copy was successful, false otherwise.
 *
 */

bool das_copyfile (const(char)* src, const(char)* dest, mode_t mode);

/** Is the path a file.
 * @param path The file in question, passed to stat(2)
 * @return true if @b path can be determined to be a file, false otherwise
 */
bool das_isfile (const(char)* path);

/** Get a sorted directory listing
 *
 * @param sPath    The path to the directory to read.
 *
 * @param ppDirList A pointer to a 2-D character array where the first index is
 *                 the directory item and the second index is the character
 *                 position.  The max value of the second index @b must be
 *                 = NAME_MAX - 1. The value NAME_MAX is defined in the POSIX
 *                 header limits.h
 *
 * @param uMaxDirs The maximum number of directory entries that may be stored
 * *
 * @param cType May be used to filter the items returned.  If cType = 'f' only
 *        files will be return, if cType = 'd' then only directories will be
 *        returned.  Any other value, including 0 will return both.
 *
 * @return On success the number of items in the directory not counting '.' and
 *         '..' are returned, on failure a negative error code is returned.
 *         Item names are sorted before return.
 */
int das_dirlist (
    const(char)* sPath,
    ref char[256]* ppDirList,
    size_t uMaxDirs,
    char cType);

/** @} */

/* _das_util_h_ */
