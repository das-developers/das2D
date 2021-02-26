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

/** @file buffer.h Utility to assist with encode and decode operations */

module das2c.buffer;

import core.stdc.stdio;

import das2c.defs;

extern (C):

/** @addtogroup utilities
 * @{
 */

/** Little buffer class to handle accumulating string data.
 *
 * DasBuf objects maintain a data buffer with a current write point, a current
 * read point and an end read point.  As data are written to the buffer the
 * write point is incremented as well as the end-of-read point.  This structure
 * is handy when multiple functions need to contribute encoded data to a single
 * memory buffer, or when multiple functions need to read from a buffer without
 * memory re-allocations or placing null values to stop parsing.
 *
 * It is hoped that the use of this class cuts down on alot of data copies and
 * sub-string allocations.
 */
struct das_buffer
{
    char* sBuf;
    size_t uLen;
    char* pWrite;
    const(char)* pReadBeg;
    const(char)* pReadEnd;
    size_t uWrap;
}

alias DasBuf = das_buffer;

/** @} */

/** Create a new Read-Write buffer on the heap
 * Allocates a new char buffer of the indicated size, call del_DasBuffer() when
 * finished
 * @param uLen The length of the raw buffer to allocate
 * @return a new ::DasBuf allocated on the heap.
 *
 * @memberof DasBuf
 */
DasBuf* new_DasBuf (size_t uLen);

/** Initialize a read-write buffer that points to an external byte array.
 * The write point is reset to the beginning and function zero's all data.  The
 * read point is also set to the beginning.
 *
 * @param pThis the buffer initialize
 * @param sBuf an pre-allocated character buffer to receive new data
 * @param uLen the length of the pre-allocated buffer
 *
 * @memberof DasBuf
 */
DasErrCode DasBuf_initReadWrite (DasBuf* pThis, char* sBuf, size_t uLen);

/** Initialize a read-only buffer than points to an external byte array.
 *
 * This function re-sets the read point for the buffer.
 *
 * @param pThis the buffer initialize
 * @param sBuf an pre-allocated character buffer to receive new data
 * @param uLen the length of the pre-allocated buffer
 */
DasErrCode DasBuf_initReadOnly (DasBuf* pThis, const(char)* sBuf, size_t uLen);

/** Re-initialize a buffer including read and write points
 * This version can be a little quicker than init_DasBuffer() because it only
 * zero's out the bytes that were written, not the entire buffer.
 *
 * @memberof DasBuf
 */
void DasBuf_reinit (DasBuf* pThis);

/** Free a buffer object along with it's backing store.
 * Don't use this if the DasBuf_initReadOnly or DasBuf_initReadWrite were
 * given pointers to buffers allocated on the stack. If so, your program will
 * crash.
 *
 * @param pThis The buffer to free.  It's good practice to set this pointer
 *         to NULL after this  function is called
 *
 * @memberof DasBuf
 */
void del_DasBuf (DasBuf* pThis);

/** Add a string to the buffer
 * @param pThis the buffer to receive the bytes
 * @param sStr the null-terminated string to write
 * @returns 0 if the operation succeeded, a positive error code otherwise.
 * @memberof DasBuf
 */
DasErrCode DasBuf_puts (DasBuf* pThis, const(char)* sStr);

/** Write formatted strings to the buffer
 * @param pThis the buffer to receive the bytes
 * @param sFmt an sprintf style format string
 * @returns 0 if the operation succeeded, a positive error code otherwise.
 * @memberof DasBuf
 */
DasErrCode DasBuf_printf (DasBuf* pThis, const(char)* sFmt, ...);

/** Add generic data to the buffer
 * @param pThis the buffer to receive the bytes
 * @param pData a pointer to the bytes to write
 * @param uLen the number of bytes to write
 * @returns 0 if the operation succeeded, a positive error code otherwise.
 * @memberof DasBuf
 */
DasErrCode DasBuf_write (DasBuf* pThis, const(void)* pData, size_t uLen);

/**  Write wrapped utf-8 text to the buffer
 *
 * With the exception of explicit newline characters, this function uses white
 * space only to separate words.  Words are not split thus new-lines start at
 * word boundaries.
 *
 * The mentality of the function is to produce horizontal "paragraphs" of
 * text that are space indented.
 *
 * @param pThis the buffer to receive the text
 * @param nIndent1 the start column for the first line of text
 * @param nIndent the start column for subsequent lines
 * @param nWrap the wrap column, using 80 is recommended
 * @param fmt A printf style format string, may contain utf-8 characters.
 * @returns 0 if the operation succeeded, a positive error code otherwise.
 */
DasErrCode DasBuf_paragraph (
    DasBuf* pThis,
    int nIndent1,
    int nIndent,
    int nWrap,
    const(char)* fmt,
    ...);

/** Add generic data to the buffer from a file
 * @returns Then number of bytes actually read, or a negative error code if there
 *          was a problem reading from the file.
 */
int DasBuf_writeFrom (DasBuf* pThis, FILE* pIn, size_t uLen);

/** Add generic data to the buffer from a socket
 *
 * @param pThis The buffer
 * @param nFd The file descriptor associated with a readable socket
 * @param uLen The amount of data to read
 * @returns Then number of bytes actually read, or a negative error code if
 *        there was a problem reading from the socket.
 */
int DasBuf_writeFromSock (DasBuf* pThis, int nFd, size_t uLen);

/** Add generic data to the buffer from an OpenSSL object
 *
 * @param pThis The buffer
 * @param vpSsl A void pointer to an SSL structure
 * @param uLen The amount of data to read
 * @returns Then number of bytes actually read, or a negative error code if
 *        there was a problem reading from the socket.
 */
int DasBuf_writeFromSSL (DasBuf* pThis, void* vpSsl, size_t uLen);

/** Get the size of the data in the buffer.
 * @returns the number of bytes written to the buffer
 * @memberof DasBuf
 */
size_t DasBuf_written (const(DasBuf)* pThis);

/** Get the remaining write space in the buffer.
 *
 * @param pThis The buffer
 * @return The number of bytes that may be still be written to the buffer.
 */
size_t DasBuf_writeSpace (const(DasBuf)* pThis);

/** Get the number of bytes remaining from the read begin point to the read end
 * point.
 * Normally this returns the difference between the read point and the
 * write point but some operations such as DasBuf_strip() reduce the read
 * end point below the write point.
 *
 * @returns Read length remaining.
 * @memberof DasBuf
 */
size_t DasBuf_unread (const(DasBuf)* pThis);

/** Adjust read points so that the data starts and ends on non-space values.
 * This is handy if the buffer contains string data.
 *
 * @warning If any new bytes are added after the buffer has been stripped then
 * the right read point will be reset to the end of valid data.
 *
 * @returns The number of bytes left to read after moving the read boundaries.
 *          The return value is the same as what you would get by calling
 *          DasBuf_remaining() immediately after this function.
 * @memberof DasBuf
 */
size_t DasBuf_strip (DasBuf* pThis);

/** Read bytes from a buffer
 * Copies bytes out of a buffer and increments the read point.  As soon as the
 * read point hits the end of valid data no more bytes are copied.
 *
 * @returns The number of bytes copied out of the buffer.
 * @memberof DasBuf
 */
size_t DasBuf_read (DasBuf* pThis, char* pOut, size_t uOut);

/** Return a pointer to the start of the current line and advance the read
 * point to the start of the next line.
 *
 * The main use is for reading lines of character data, though any delimited
 * byte stream can be read with this function.
 *
 * @param pThis The DasBuf to read
 * @param sDelim the line delimiter, typically this is just a single character
 *         string, but any string may be considered the line deliminter
 * @param uDelimLen the length of the record deliminator in bytes
 * @param pLen A pointer to a location to receive the line length, excluding
 *         the delimiter.  The saved value will be zero for empty lines.
 * @return A pointer to the start of the current line, or NULL if no further
 *          lines are present in the buffer.
 */
const(char)* DasBuf_readRec (
    DasBuf* pThis,
    const(char)* sDelim,
    size_t uDelimLen,
    size_t* pLen);

/** Get the offset of the read position
 *
 * @param pThis - The buffer to query
 * @returns The difference between the read point and the base of the buffer
 */
size_t DasBuf_readOffset (const(DasBuf)* pThis);

/** Set the offset of the read position
 *
 * @param pThis - The buffer in question
 * @param uPos - The new read offset from be beginning of the buffer
 * @returns 0 on success an positive error code if uPos makes no sense for the
 *          buffers current state
 */
DasErrCode DasBuf_setReadOffset (DasBuf* pThis, size_t uPos);

/* _das_buffer_h_ */
