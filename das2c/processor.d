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

/** @file processor.h Callback processing for das2 stream reads and writes
 *
 * These structure allow one to hook in Das2 Stream object processing that
 * is triggered when Headers and Data are read or written to a file.
 */

module das2c.processor;

import das2c.oob;
import das2c.packet;
import das2c.stream;

extern (C):

/** Definition of the callback function invoked when a stream header is
 * encountered in the input.
 * @param sd A pointer to the parsed StreamDesc
 * @param pd A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias StreamDescHandler = int function (StreamDesc* sd, void* ud);

/** Definition of the callback function invoked when a packet header is
 * encountered in the input.
 * @param sd A pointer to the parsed Stream Descriptor
 * @param pd A pointer to the parsed Packet Descriptor
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias PktDescHandler = int function (StreamDesc* sd, PktDesc* pd, void* ud);

/** Definition of the callback function invoked when a packet header is
 * going to be deleted.  This only occurs if streams re-define packet IDs
 * @param
 * @param sd A pointer to the parsed Stream Descriptor
 * @param pd A pointer to the parsed Packet Descriptor
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias PktRedefHandler = int function (StreamDesc* sd, PktDesc* pd, void* ud);

/** Callback function invoked when a data packet is encountered in the input.
 * @param sd A pointer to the parsed Packet Descriptor
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias PktDataHandler = int function (PktDesc* pd, void* ud);

/** Callback functions that invoked on Stream Close
 * callback function that is called at the end of the stream
 * @param sd A pointer to the parsed Stream Descriptor
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias CloseHandler = int function (StreamDesc* sd, void* ud);

/** Callback functions that handle exceptions
 * @param se A pointer to the parsed Exception
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias ExceptionHandler = int function (OobExcept* se, void* ud);

/** Callback functions that handle comments.
 * @param se A pointer to the parsed Comment
 * @param ud A pointer to a user data structure, may be NULL.
 * @see StreamHandler
 */
alias CommentHandler = int function (OobComment* se, void* ud);

/** A set of callbacks used for input and output stream processing
 * @interface StreamHandler
 * @ingroup streams
 */
struct _streamHandler
{
    /** The function to be called when the stream header is read in.
    	 * This is the header with the element \<stream\>\</stream\> in the input
    	 * file.
    	 */
    StreamDescHandler streamDescHandler;

    /** Sets the function to be called when each \<packet\>\</packet\> element
    	 * is read in.
    	 */
    PktDescHandler pktDescHandler;

    /** Sets the function to be called when a packet ID is about to be
    	 * re-defined before the old pkt descriptor object is deleted */
    PktRedefHandler pktRedefHandler;

    /** Sets the function to be called when each data packet is read in.
    	 */
    PktDataHandler pktDataHandler;

    /** Sets the function to be called when a stream exception is read in.
    	 * The default handler prints the exception and exits with a non-zero
    	 * value.
    	 */
    ExceptionHandler exceptionHandler;

    /** StreamCommentHandler receives stream annotations.
    	 *
    	 * These include progress messages, log files, informational messages, and
    	 * other messages humans might be interested in.  The default handler throws
    	 * out the comment.
    	 *
    	 * When handling Comments it is advisable to use Comment_isProgress() and
    	 * DasIO_forwardProgress() to handle progress message  This way progress
    	 * messages do make it out, but are rate limited and thus don't swamp the
    	 * output stream.
    	 */
    CommentHandler commentHandler;

    /** Sets the function to be called the reading of the stream is completed.
    	 */
    CloseHandler closeHandler;

    /** An optional User-data pointer that is passed along to all callbacks.
    	 * This value may be NULL.
    	 */
    void* userData;
}

alias StreamHandler = _streamHandler;

/** Initialize a stream processor with default callbacks.
 *
 * The library has builtin callbacks for the StreamExceptionHandler and the
 * StreamCommentHandler.  Calling this function will initialize a
 * StreamHandler structure with the defaults and set all other callback
 * pointers to NULL.  The User Data pointer will also be NULL.
 *
 * @param pThis The stream handler structure to initialize
 * @param pUserData A pointer that will be passed in to each callback, used
 *        to provide access to whatever state data you may need to reference.
 * @memberof StreamHandler
 */
void StreamHandler_init (StreamHandler* pThis, void* pUserData);

/** Create a new stream processor with default callbacks.
 *
 * The library has builtin callbacks for the StreamExceptionHandler and the
 * StreamCommentHandler.  Calling this function will initialize a
 * StreamHandler structure with the defaults and set all other callback
 * pointers to NULL.  The User Data pointer will also be NULL.
 *
 * @param pUserData The user data pointer will be set to this value.
 * @return A new StreamHandler allocated on the heap
 *
 * @memberof StreamHandler
 */
StreamHandler* new_StreamHandler (void* pUserData);

/* _das_processor_h_ */
