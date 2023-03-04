/* Copyright (C) 2004-2017 Jeremy Faden <jeremy-faden@uiowa.edu>
 *                         Chris Piker <chris-piker@uiowa.edu>
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

/** @file io.h Reading and writing Das2 Stream objects to standard I/O.
 */

module das2c.io;

import core.stdc.config;
import core.stdc.stdio;

import das2c.buffer;
import das2c.defs;
import das2c.oob;
import das2c.packet;
import das2c.processor;
import das2c.stream;

extern (C):

/* max number of stream processor objects */
enum DAS2_MAX_PROCESSORS = 10;

enum DASIO_NAME_SZ = 128;

/** Tracks input and output operations for das2 stream headers and data.
 *
 * Members of this class handle overall stream operations reading writing
 * packets, checking packet lengths, passing XML string data off to descriptor
 * object constructors, triggering processing callbacks and most other general
 * Das2 Stream IO tasks.
 * @ingroup streams
 */
struct das_io_struct
{
    char rw; /* w' for write, 'r' for read */
    bool compressed; /* 1 if stream is compressed or should be compressed */

    int mode; /* STREAM_MODE_STRING, STREAM_MODE_FILE,
    								 * STREAM_MODE_SOCKET, STREAM_MODE_SSL */
    char[DASIO_NAME_SZ] sName; /* A human readable name for data source or sink */

    c_long offset; /* current offset for file reads */

    /* Socket I/O */
    int nSockFd; /* Socket file descriptor */

    /* SSL I/O */
    void* pSsl; /* OpenSSL connection */

    /* File I/O */
    FILE* file; /* input/output file  (File I/O) */

    /* Buffer IO */
    char* sBuffer; /* buffer for string input/output */
    int nLength; /* length of buffer pointed to by sbuffer */

    /* Compressed I/O */
    void* zstrm; /* z_stream for inflate/deflate operations */
    ubyte* inbuf; /* input buffer */
    ubyte* outbuf; /* output buffer */
    int zerr; /* error code for last stream operation */
    int eof; /* set if end of input file */

    /* data object processor's with callbacks  (Input / Output) */
    StreamHandler*[11] pProcs;
    bool bSentHeader;

    /* Sub Object Writing (output) */
    DasBuf* pDb; /* Sub-Object serializing buffer */

    int logLevel; /* to-stream logging level. (output) */

    int taskSize; /* progress indicator max value (output) */
    c_long tmLastProgMsg; /* Time the last progress message was emitted (output)*/

    OobComment cmt; /* Hold buffers for comments and logs */
}

alias DasIO = das_io_struct;

/** Create a new DasIO object from a standard C FILE.
 *
 * Create a DasIO object that reads or writes to C standard IO files.  The
 * C file object's read or write state should be compatible with the DasIO
 * state.  For example:
 * @code
 *  DasIO* dio = new_DasIO_cfile(stdin, "myprogram", "rc");
 * @endcode
 * is @b invalid, if standard input is not compressed, but the library has
 * no way to tell until read operations start.
 *
 * @param sProg A spot to store the name of the program creating the file
 *        this is useful for automatically generated error and log messages
 *
 * @param file a C standard IO file object.
 *
 * @param mode A string containing the mode, one of:
 *        - 'r' read
 *        - 'w' write uncompressed
 *        - 'wc' write compressed
 *
 * @memberof DasIO
 */
DasIO* new_DasIO_cfile (const(char)* sProg, FILE* file, const(char)* mode);

/** Create a new DasIO object from a shell command
 *
 * Create a DasIO object that reads from a sub command. The sub command is
 * run in the shell '/bin/sh' on POSIX systems
 *
 * @code
 *  DasIO* dio = new_DasIO_cmd("/my/das2/reader 2017-01-01 2017-01-02", "wc");
 * @endcode
 * is @b invalid, but the library has no way to tell until operations start.
 *
 * @param sProg A spot to store the name of the program running the command
 *        this is useful for automatically generated error and log messages
 *
 * @param sCmd the command line to run, will be started via popen
 *
 * @memberof DasIO
 */
DasIO* new_DasIO_cmd (const(char)* sProg, const(char)* sCmd);

/** Create a new DasIO object from a disk file.
 *
 * @param sProg A spot to store the name of the program creating the file
 *        this is useful for automatically generated error and log messages
 *
 * @param sFile the name of a file on disk.  If the file doesn't exist it
 *        is created.
 *
 * @param mode A string containing the mode, one of:
 *        - 'r' read (reads compressed and uncompressed files)
 *        - 'w' write uncompressed
 *        - 'wc' write compressed
 *
 * @memberof DasIO
 */
DasIO* new_DasIO_file (const(char)* sProg, const(char)* sFile, const(char)* mode);

/** Create a new DasIO object from a socket
 *
 * @param sProg A spot to store the name of the program creating the file
 *        this is useful for automatically generated error and log messages
 *
 * @param nSockFd The socket file descriptor used for recv/write calls
 *
 * @param mode A string containing the mode, one of:
 *        - 'r' read (reads compressed and uncompressed files)
 *        - 'w' write uncompressed
 *        - 'wc' write compressed
 *
 * @return A new DasIO object allocated on the heap
 * @memberof DasIO
 */
DasIO* new_DasIO_socket (const(char)* sProg, int nSockFd, const(char)* mode);

DasIO* new_DasIO_str (const(char)* sProg, char* sbuf, size_t len, const(char)* mode);

/** Create a new DasIO object using an encripted connection
 *
 * This class does not handle communications setup but can take over after a
 * connection has been established and all needed headers have been sent and
 * or read.
 *
 * It is also assumed that the SSL connection has been established
 * on a socket using BLOCKING I/O and is not sutiable for use as an action for
 * a select() or poll() statement.  To handle multiple connections at once in
 * a single program create more than one DasIO object.
 *
 * You should also setup the SSL connection with the SSL_MODE_AUTO_RETRY option
 * to SSL_set_mode or SSL_CTX_set_mode to let the openssl library handle
 * session renegotiation transparently.  The http_getBodySocket() call does
 * initialize any SSL structures it generates in auto-retry mode.
 *
 * @param sProg A spot to store the name of the program creating the file
 *        this is useful for automatically generated error and log messages
 *
 * @param pSsl A pointer to OpenSSL SSL structure referencing an open connection
 *        that has been initialized in BLOCKING mode.
 *
 * @param mode A string containing the mode, one of:
 *        - 'r' read (reads compressed and uncompressed files)
 *        - 'w' write uncompressed
 *        - 'wc' write compressed

 * @return
 * @memberof DasIO
 */
DasIO* new_DasIO_ssl (const(char)* sProg, void* pSsl, const(char)* mode);

/** Free resources associated with a DasIO structure
 * Typically you don't need to do this as heap memory is free'ed when the
 * program exits anyway.  But if you need a destructor, here it is.
 *
 * @param pThis The DasIO abject to delete.  Any associated file handles except
 *        for standard input and standard output are closed.  The pointer
 *        given to this function should be set to NULL after the function
 *        completes.
 */
void del_DasIO (DasIO* pThis);

/** Add a packet processor to be invoked during I/O operations
 *
 * A DasIO object may have 0 - DAS2_MAX_PROCESSORS packet processors attached
 * to it.  Each processor contains one or more callback functions that will
 * be invoked and provided with ::DasDesc objects.
 *
 * During stream read operations, processors are invoked after the header or
 * data have been serialized from disk.  During stream write operations
 * processors are invoked before the write operation is completed.
 *
 * @param pThis The DasIO object to receive the processor.
 * @param pProc The StreamProc object to add to the list of processors.
 * @return The number of packet processors attached to this DasIO object or
 *         a negative error value if there is a problem.
 *
 * @memberof DasIO
 */
int DasIO_addProcessor (DasIO* pThis, StreamHandler* pProc);

/** Starts the processing of the stream read from FILE* infile.
 *
 * This function does not return until all input has been read or an exception
 * condition has occurred.  If a ::StreamHandler has been set with
 * DasIO_setProcessor() then as each header packet and each data packet is read
 * callbacks specified in the stream handler will be invoked.  Otherwise all
 * data is merely parsed and then discarded.
 *
 * @returns a status code.  0 indicates that all processing ended with no
 *          errors, otherwise a non-zero value is returned.
 *
 * @memberof DasIO
 */
int DasIO_readAll (DasIO* pThis);

/** Writes the data describing the stream to the output channel (e.g. File* ).
 *
 * This serializes the descriptor structure into XML and writes it out.
 * @param pThis The IO object, must be set up in a write mode
 * @param pSd The stream descriptor to serialize
 * @returns 0 on success a positive integer error code other wise.
 * @memberof DasIO
 */
DasErrCode DasIO_writeStreamDesc (DasIO* pThis, StreamDesc* pSd);

/** Writes the data describing a packet type to the output channel (e.g. File* ).
 *
 * This serializes the descriptor structure into XML and writes it out.  The
 * packet type will be assigned a number on the das2Stream, and data packets
 * will be tagged with this number.
 * @memberof DasIO
 */
DasErrCode DasIO_writePktDesc (DasIO* pThis, PktDesc* pd);

/** Sends the data packet on to the stream after checking validity.
 *
 * This check insures that all planes have been set via setDataPacket.
 *
 * @param pThis the IO object to use for sending the data
 * @param pPd a Packet Descriptor loaded with values for output.
 *
 * @returns 0 if the operation was successful or an positive value on an error.
 * @memberof DasIO
 */
DasErrCode DasIO_writePktData (DasIO* pThis, PktDesc* pPd);

/** Output an exception structure
 *
 * @memberof DasIO
 */
DasErrCode DasIO_writeException (DasIO* pThis, OobExcept* pSe);

/** Output a StreamComment
 * Stream comments are generally messages interpreted only by humans and may
 * change without affecting processes.  Progress messages are sent via stream
 * comments.
 * @memberof DasIO
 */
DasErrCode DasIO_writeComment (DasIO* pThis, OobComment* pSc);

enum LOGLVL_FINEST = 0;
enum LOGLVL_FINER = 300;
enum LOGLVL_FINE = 400;
enum LOGLVL_CONFIG = 500;
enum LOGLVL_INFO = 600;
enum LOGLVL_WARNING = 700;
enum LOGLVL_ERROR = 800;

/** Send a log message onto the stream at the given log level.
 * Note that messages sent at a level greater than INFO may be thrown out if
 * performance would be degraded.
 *
 * @memberof DasIO
 */
DasErrCode DasIO_sendLog (DasIO* pThis, int level, char* msg, ...);

/** Set the minimum log level that will be transmitted on the stream.
 * The point of the DasIO logging functions is not to handle debugging, but
 * to inform a client program what is going on by embedding messages in an
 * output stream.  Since the point of a stream is to transmit data, placing
 * too many comments in the stream will degrade performance.
 *
 * Unless this function is called, the default logging level is
 * @b LOGLEVEL_WARNING
 *
 * @param pThis the DasIO object who's log level will be altered.
 * @param minLevel A logging level, one of:
 *     - LOGLVL_ERROR - Only output messages that indicate improper operation.
 *     - LOGLVL_WARNING - Messages that indicate a problem but processing can
 *          continue
 *     - LOGLVL_INFO - Extra stuff the operator may want to know
 *     - LOGLVL_CONFIG - Include basic setup information as well
 *
 * @memberof DasIO
 */
void DasIO_setLogLvl (DasIO* pThis, int minLevel);

/** Get logging verbosity level
 * @param pThis a DasIO object to query
 * @returns A logging level as defined in DasIO_setLogLevel()
 * @memberof DasIO
 */
int DasIO_getLogLvl (const(DasIO)* pThis);

/** Returns a string identifying the log level.
 *
 * @param logLevel a log level value as defined in DasIO_setLogLvl()
 * @returns a string such as 'error', 'warning', etc.
 *
 */
const(char)* LogLvl_string (int logLevel);

/* Identifies the size of task for producing a stream, in arbitrary units.
 *
 * This number is used to generate a relative progress position, and also as
 * a weight if several Das2 Streams (implicitly of similar type) are combined.
 * See setTaskProgress().
 *
 * @memberof DasIO
 */
DasErrCode DasIO_setTaskSize (DasIO* pThis, int size);

/** Place rate-limited progress comments on an output stream.
 *
 * Messages are decimated dynamically to try to limit the stream comment rate to
 * about 10 per second (see targetUpdateRateMilli).  If Note the tacit assumption
 * that is the stream is
 * reread, it will be reread at a faster rate than it was written.  Processes
 * reducing a stream should take care to call setTaskProgress themselves
 * instead of simply forwarding the progress comments, so that the new stream
 * is not burdened by excessive comments.  See setTaskSize().
 *
 * @memberof DasIO
 */
DasErrCode DasIO_setTaskProgress (DasIO* pThis, int progress);

/** Set the logging level */

/** Close and free an output stream with an exception.
 *
 * Call this to notify stream consumers that there was an exceptional condition
 * that prevents completion of the stream.  For example, this might be used to
 * indicate that no input files were available.  This is a convenience function
 * for the calls:
 *
 *   - DasIO_writeStreamDesc()
 *   - DasIO_writeException()
 *   - DasIO_close()
 *   - del_DasIO()
 *
 * @param pThis the output object to receive the exception packet
 * @param pSd The stream descriptor.  All Das2 Streams have to start with a
 *        stream header.  If this header hasn't been output then this object
 *        will be serialized to create a stream header.
 * @param type the type of exception may be one of the pre-defined strings:
 *   - DAS2_EXCEPT_NO_DATA_IN_INTERVAL
 *   - DAS2_SERVER_ERROR
 *   or some other short type string of your choice.
 * @param msg a longer message explaining what went wrong.
 *
 * @memberof DasIO
 */
void DasIO_throwException (
    DasIO* pThis,
    StreamDesc* pSd,
    const(char)* type,
    char* msg);

/** Normal stream close with no unusual condiditons
 * Closes the output file descriptor, flushes a gzip buffer, etc.
 * May possibly send a stream termination comment as well.
 *
 * @param pThis
 * @memberof DasIO
 */
void DasIO_close (DasIO* pThis);

/** Throw a server exception and close the stream
 *
 * If no stream descriptor has been sent then a stub descriptor is
 * output first.  The output is encoded for XML transport so there
 * is no need to escape the text prior to sending.  The total mesage
 * may not exceed 2047 UTF-8 bytes.
 *
 * If this function is called on an input stream the program will
 * immediately exit with the value 10.
 *
 * @returns The value 11
 */
int DasIO_serverExcept (DasIO* pThis, const(char)* fmt, ...);

/** Throw a bad query exception and close the stream
 *
 * If no stream descriptor has been sent then a stub descriptor is
 * output first.  The output is encoded for XML transport so there
 * is no need to escape the text prior to sending.  The total mesage
 * may not exceed 2047 UTF-8 bytes.
 *
 * Not having any data for the requested parameter range is not
 * cause for throwing an exception.  Send a no data in interval
 * response instead.
 *
 * If this function is called on an input stream the program will
 * immediately exit with the value 10.
 *
 * @returns The value 11
 */
int DasIO_queryExcept (DasIO* pThis, const(char)* fmt, ...);

/** Send a "no data in interval" message and close the stream
 *
 * If no stream descriptor has been sent then a stub descriptor is
 * output first.  The output is encoded for XML transport so there
 * is no need to escape the text prior to sending.  The total mesage
 * may not exceed 2047 UTF-8 bytes.
 *
 * Not having any data for the requested parameter range is not
 * cause for throwing an exception.  Send a no data in interval
 * response instead.
 *
 * If this function is called on an input stream the program will
 * immediately exit with the value 10.
 *
 * @returns The value 0
 */
int DasIO_closeNoData (DasIO* pThis, const(char)* fmt, ...);

/** Print a string with a format specifier (Low-level API)
 * This works similar to the C printf function.
 *
 * @param pThis
 * @param format
 * @param ... The variables to print
 * @returns The number of characters printed.
 * @memberof DasIO
 */
int DasIO_printf (DasIO* pThis, const(char)* format, ...);

/** Anolog of fwrite (Low-level API)
 * @memberof DasIO
 */
size_t DasIO_write (DasIO* pThis, const(char)* data, int length);

/** Analog of fread (Low-level API)
 * @memberof DasIO
 */
int DasIO_read (DasIO* pThis, DasBuf* pBuf, size_t nBytes);

/** Analog of getc (Low-level API)
 *
 * @memberof DasIO
 */
int DasIO_getc (DasIO* pThis);

/* _das_io_h_ */
