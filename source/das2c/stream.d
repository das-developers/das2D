/* Copyright (C) 2004-2006 Jeremy Faden <jeremy-faden@uiowa.edu>
 *               2012-2017 Chris Piker <chris-piker@uiowa.edu>
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

/** @file stream.h Objects representing a Das2 Stream as a whole */

module das2c.stream;

import das2c.buffer;
import das2c.defs;
import das2c.descriptor;
import das2c.encoding;
import das2c.packet;
import das2c.units;

extern (C):

enum STREAMDESC_CMP_SZ = 48;
enum STREAMDESC_VER_SZ = 48;

enum MAX_PKTIDS = 100;

/** @defgroup streams Streams
 * Classes for handling interleaved self-describing data streams
 */

/** Describes the stream itself, in particular the compression used,
 * current packetDescriptors, etc.
 * @extends DasDesc
 * @nosubgrouping
 * @ingroup streams
 */
struct stream_descriptor
{
    /** The base structure */
    DasDesc base;

    /** An array of packet descriptors.
    	 * The lookup ID is the same value used as the PacketID in the stream.
    	 * Legal packet ID's are 1 to 99.  0 is reserved for the stream header
    	 * packet and thus item 0 in this array should always be NULL.
    	 *
    	 * Note that Das2 Streams can re-use packet ID's.  So the PacketDescriptor
    	 * at, for example, ID 2 may be completely different from one invocation
    	 * of a stream handler callback to another.
    	 */
    PktDesc*[MAX_PKTIDS] pktDesc;

    /* Common properties */
    char[STREAMDESC_CMP_SZ] compression;
    char[STREAMDESC_VER_SZ] version_;
    bool bDescriptorSent;

    /** User data pointer.
    	 * The stream->packet->plane hierarchy provides a good organizational
    	 * structure for application data, especially for applications whose
    	 * purpose is to filter streams.  This pointer can be used to hold
    	 * a reference to information that is not serialized.  It is initialized
    	 * to NULL when a PacketDescriptor is created otherwise the library
    	 * doesn't deal with it in any other way. */
    void* pUser;
}

alias StreamDesc = stream_descriptor;

/** Creates a new blank StreamDesc.
 * The returned structure has no packet descriptors, no properties are defined.
 * The compression attribute is set to 'none' and the version is set to 2.2
 *
 * @memberof StreamDesc
 */
StreamDesc* new_StreamDesc ();

StreamDesc* new_StreamDesc_str (DasBuf* pBuf);

/** Creates a deep-copy of an existing StreamDesc object.
 *
 * An existing stream descriptor, probably one initialized automatically by
 * reading standard input, can be used as a template for generating a second
 * stream descriptor. This is a deep copy, all owned objects are copied as well
 * and may be changed with out affecting the source object or it components.
 *
 * @param pThis The stream descriptor to copy
 * @return A new stream descriptor allocated on the heap with all associated
 *         packet descriptors attached and also allocated on the heap
 *
 * @memberof StreamDesc
 */
StreamDesc* StreamDesc_copy (const(StreamDesc)* pThis);

/** Delete a stream descriptor and all it's sub objects
 *
 * @param pThis The stream descriptor to erase, the pointer should be set
 *        to NULL by the caller.
 */
void del_StreamDesc (StreamDesc* pThis);

/** Get the number of packet descriptors defined for this stream
 *
 * @warning It is possible to have a non-contiguous set of Packet IDs.  Unless
 *          the application insures by some mechanism that packet IDs are not
 *          skipped when calling functions like StreamDesc_addPktDesc() then
 *          the results of this function will not useful for iteration.
 *
 * @param pThis The stream descriptor to query
 *
 * @return Then number of packet descriptors attached to this stream
 *         descriptor.  For better performance the caller should reused the
 *         return value as all possible packet ID's are tested to see home many
 *         are defined.
 */
size_t StreamDesc_getNPktDesc (const(StreamDesc)* pThis);

/** Attach a standalone packet descriptor to this stream.
 *
 * @param pThis The stream to receive the packet descriptor.  The PkdDesc object
 *        will have it's parent pointer set to this object.
 * @param pPd The stand alone packet descriptor, it's parent pointer must be null
 * @param nPktId The ID for the new packet descriptor.
 * @return 0 on success or a positive error code on failure.
 * @memberof StreamDesc
 */
DasErrCode StreamDesc_addPktDesc (StreamDesc* pThis, PktDesc* pPd, int nPktId);

/** Indicates if the xtags on the stream are monotonic, in which
 * case there might be optimal ways of processing the stream.
 * @memberof StreamDesc
 */
void StreamDesc_setMonotonic (StreamDesc* pThis, bool isMonotonic);

/** Adds metadata into the property set of the StreamDesc.  These include
 * the creation time, the source Id, the process id, the command line, and
 * hostname.
 * @memberof StreamDesc
 */
void StreamDesc_addStdProps (StreamDesc* pThis);

/** Adds the command line into the property set of the StreamDesc.
 * This can be useful when debugging.
 * @memberof StreamDesc
 */
void StreamDesc_addCmdLineProp (StreamDesc* pThis, int argc, char** argv);

/** Creates a descriptor structure that for a stream packet type.
 *
 * Initially this descriptor will only have xtags, but additional data planes
 * are added.  The packet ID for the new descriptor is automatically assigned
 * so to be the lowest legal ID not currently in use.
 *
 * @param pThis The stream descriptor object that will receive the new packet
 *        type.
 *
 * @param xUnits is a UnitType (currently char *) that describes the data.
 *        Generally this is used to identify times (e.g.UNIT_MJ1958,UNIT_US2000)
 *        or is UNIT_DIMENSIONLESS, but other UnitTypes are defined (e.g.
 *        UNIT_HERTZ, UNIT_DB).
 *
 * @param pXEncoder The encoder for X-plane values on this stream. The
 *         StreamDesc object takes ownership of the encoder's memory.
 *
 * @returns A pointer to new PacketDescriptor object allocated on the heap.
 *        This pointer is also stored in the
 *        StreamDesc::packetDescriptors member variable of @a pThis.
 *
 * @memberof StreamDesc
 */
PktDesc* StreamDesc_createPktDesc (
    StreamDesc* pThis,
    DasEncoding* pXEncoder,
    das_units xUnits);

/** Make a deep copy of a PacketDescriptor on a new stream.
 * This function makes a deep copy of the given packet descriptor and
 * places it on the provided stream.  Note, packet ID's are not preserved
 * in this copy.  The newly allocated PacketDescriptor may not have the same
 * packet ID as the old one.
 *
 * @param pThis the stream to get the new packet descriptor
 * @param pd The packet descriptor to clone onto the stream
 * @returns The newly created packet descriptor
 * @memberof StreamDesc
 */
PktDesc* StreamDesc_clonePktDesc (StreamDesc* pThis, const(PktDesc)* pd);

/** Deepcopy a PacketDescriptor from one stream to another.
 * The copy made by this function handles recursing down to all the planes
 * and properties owned by the given packet descriptor.  Unlike the the
 * function clonePacketDescriptor() the packet ID is preserved across the copy.
 * @param pThis the stream descriptor to get the new packet descriptor
 * @param pOther the stream descriptor who's packet descriptor is copied
 * @param nPktId the id of the packet to copy, a value in the range of 0 to 99
 *        inclusive.
 * @returns The newly created packet descriptor, or NULL if there was no
 *          packet descriptor with that ID in the source.
 * @memberof StreamDesc
 */
PktDesc* StreamDesc_clonePktDescById (
    StreamDesc* pThis,
    const(StreamDesc)* pOther,
    int nPktId);

/** Check to see if an packet ID has been defined for the stream
 *
 * @param pThis The stream to check
 * @param nPktId The ID in question
 * @return true if a packet of that type is defined on the stream false
 *         otherwise
 */
bool StreamDesc_isValidId (const(StreamDesc)* pThis, int nPktId);

/** Get the packet descriptor associated with an ID.
 *
 * @param pThis The stream object which contains the packet descriptors.
 * @param id The numeric packet ID, a value from 1 to 99 inclusive.
 *
 * @returns NULL if there is no packet descriptor associated with the
 *          given Packet ID
 * @memberof StreamDesc
 */
PktDesc* StreamDesc_getPktDesc (const(StreamDesc)* pThis, int id);

/** Free any resources associated with this PacketDescriptor,
 * and release it's id number for use with a new PacketDescriptor.
  * @memberof StreamDesc
 */
DasErrCode StreamDesc_freePktDesc (StreamDesc* pThis, int nPktId);

/** An I/O function that makes sense to use for either operation
 * @memberof StreamDesc
 */
int StreamDesc_getOffset (StreamDesc* pThis);

/** Encode a StreamDesc to an XML string
 *
 * @param pThis The stream descriptor to encode
 * @param pBuf A DasBuffer item to receive the bytes
 * @return 0 if encoding succeeded, a non-zero error code otherwise
 * @memberof StreamDesc
 */
DasErrCode StreamDesc_encode (StreamDesc* pThis, DasBuf* pBuf);

/** Das2 Stream Descriptor Factory Function
 *
 * @returns Either a StreamDesc or a PktDesc object depending on the data
 *          received, or NULL if the input could not be parsed.
 */
DasDesc* Das2Desc_decode (DasBuf* pBuf);

/* _das_stream_h_ */
