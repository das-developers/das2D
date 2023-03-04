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

/** @file oob.h Defines the "Out of Band" objects in a stream.  These are
 * comments and exceptions
 */

/** @file oob.h Building das Dataset objects from a stream */

/* Copyright 2003-2017 Chris Piker  <chris-piker@uiowa.edu>
 *                     Jeremy Faden <jeremy-faden@uiowa.edu>
 *
 * Licensed under the open source Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License. You may
 * obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module das2c.oob;

import das2c.buffer;
import das2c.defs;

extern (C):

/** Generic untyped exception */
enum EXCEPTION_UNTYPED = "";

/** Exception type for when no data is found in the requested interval. */
enum DAS2_EXCEPT_NO_DATA_IN_INTERVAL = "NoDataInInterval";
enum DAS2_EXCEPT_ILLEGAL_ARGUMENT = "IllegalArgument";
enum DAS2_EXCEPT_SERVER_ERROR = "ServerError";

enum oob_type
{
    OOB_EXCEPT = 0,
    OOB_COMMENT = 1
}

alias oob_t = oob_type;

/** A container for Out-of-Band data */
struct out_of_band
{
    oob_t pkttype;
    void function (out_of_band* pThis) clean;
}

alias OutOfBand = out_of_band;

/** Clean up extra memory allocated when an out of band object is initialized
 * @param pThis the out of band item to clean up.
 */
void OutOfBand_clean (OutOfBand* pThis);

/** describes an exception that can live in a stream.  They have
 * a type, and a human-consumable message.
 *
 * @extends OutOfBand
 * @ingroup streams
 */
struct stream_exception
{
    OutOfBand base;

    char* sType; /* NoDataInInterval, Exception */
    size_t uTypeLen;

    char* sMsg; /* May be altered by encode function to change " to ' */
    size_t uMsgLen;
}

alias OobExcept = stream_exception;

/** Initialize an Exception Structure
 * This only needs to be called once, the same structure will be reused each
 * time OutOfBand_decode() is called.  Memory is not re-allocated for each call,
 * it only expands as needed.
 *
 * @param pThis A pointer to the stream exception to initialize
 * @memberof OobExcept
 */
void OobExcept_init (OobExcept* pThis);

/** Set an exception structure to a particular exception
 *
 * @param pThis A pointer to the exception to initialize
 * @param sType The type of exception.  Usage of one of the strings:
 *          - DAS2_EXCEPT_NO_DATA_IN_INTERVAL
 *          - DAS2_EXCEPT_ILLEGAL_ARGUMENT
 *          - DAS2_EXCEPT_SERVER_ERROR
 *        is recommended.
 * @param sMsg The message for the exception, this is a human readable string.
 */
void OobExcept_set (OobExcept* pThis, const(char)* sType, const(char)* sMsg);

/** Parse text data into a stream exception
 * @memberof StreamExecpt
 */
DasErrCode OobExcept_decode (OobExcept* pThis, DasBuf* str);

/** Serialize a Das2 Stream Exception into a buffer
 *
 * @param pThis The exception to encode
 * @param pBuf The buffer to receive the bytes
 * @return 0 on success, a positive error code on failure.
 * @memberof StreamExecpt
 */
DasErrCode OobExcept_encode (OobExcept* pThis, DasBuf* pBuf);

/** describes human-consumable messages that exist on the stream.
 * One exception is progress messages, which utilize StreamComments
 * and are consumed on the client side by software.
 * @extends OutOfBand
 * @ingroup streams
 */
struct stream_comment
{
    OutOfBand base;

    /** The type of comment, for example log:info, taskProgress, taskSize, etc.*/
    char* sType;
    size_t uTypeLen;

    /** The source of the comment, typically the name of a program */
    char* sSrc;
    size_t uSrcLen;

    /** The Comment body, for some messages this is an ASCII value*/
    char* sVal;
    size_t uValLen;
}

alias OobComment = stream_comment;

/** Initialize an Exception Structure
 * This only needs to be called once, the same structure will be reused each
 * time OutOfBand_decode() is called.  Memory is not re-allocated for each call,
 * it only expands as needed.
 *
 * @param pThis A pointer to the stream comment object to initialize
 * @memberof OobComment
 */
void OobComment_init (OobComment* pThis);

/** Serialize a comment into a buffer.
 *
 * @param pThis The comment to save
 * @param pBuf The buffer to receive the data
 * @return 0 on success, a positive error code otherwise
 * @memberof StreamComment
 */
DasErrCode OobComment_encode (OobComment* pThis, DasBuf* pBuf);

/** Initialize a comment object form string data
 *
 * @param pThis
 * @param sbuf
 * @return
 * @memberof StreamComment
 */
DasErrCode OobComment_decode (OobComment* pThis, DasBuf* sbuf);

/** Factory function to produce out of band objects from general data
 *
 * Unlike Header packets which are read in-frequently, out of band objects may
 * occur frequently in the input stream.  To avoid alot of memory allocations
 * This factory function takes an array of pointers to out of band objects.
 *
 * If one of the given OOB's in the input array corresponds to the parsed object
 * then it is initialize with the values in the buffer.   If the out of band
 * object is a proper XML item but is not understood by this function it is
 * just ignored and @b which will be set to -1
 *
 * @param[in] pBuf a readable buffer containing up to one out of band object
 * @param[in] ppObjs a NULL terminated array of out of band objects to possibly
 *            populate with data
 * @param[out] which A pointer to an integer.  The integer will be set to
 *            -1 if the object was not parseable or if no structure was
 *            provided in ppObjs to hold the parsed item.
 *
 * @returns 0 on success or a positive error code if there is a problem.
 *
 * @memberof OutOfBand
 */
DasErrCode OutOfBand_decode (DasBuf* pBuf, OutOfBand** ppObjs, int* which);

/* _das_out_of_band_h_ */
