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

/** @file packet.h */

module das2c.packet;

import das2c.buffer;
import das2c.defs;
import das2c.descriptor;
import das2c.plane;

extern (C):

/** maximum planes allowed in a packet */
enum MAXPLANES = 100;

/** Holds information for a single packet type in a Das2 stream.
 *
 * A Das2 Stream may consist of up to 99 different types of \e packets.
 * In the following Das2 Stream snippet two different types of packets
 * are defined:
 * @code
 * [00]000234<stream>
 *   <properties xMonotonic="true" xLabel="Time (s)" yLabel="Frequency (s!U-1!N)"
 *               zLabel="Electric Field (V m!U-1!N)" title="Voyager 1 PWS SA"
 *               Datum:xTagWidth="256.0 s" double:zFill="0.0" />
 * </stream>
 * @endcode
 * @code
 * [01]000201<packet>
 *   <x type="time24" units="us2000" ></x>
 *   <yscan name="averages" nitems="5" type="ascii9" yUnits="Hz" zUnits="V/m"
 *          yTags="10.0,17.8,31.1,56.2,100.0">
 *     <properties zSummary="Average value within the interval"/>
 *   </yscan>
 * </packet>
 * @endcode
 * @code
 * [02]000201<packet>
 *   <x type="time24" units="us2000" ></x>
 *   <yscan name="peaks" nitems="5" type="ascii9" yUnits="Hz" zUnits="V/m"
 *          yTags="10.0,17.8,31.1,56.2,100.0">
 *     <properties zSummary="Peak value within the interval"/>
 *   </yscan>
 * </packet>
 * @endcode
 * @code
 * :01:2012-01-01T12:56:22.792 1.91e-06 8.92e-07 7.80e-07 6.04e-07 2.43e-07
 * :02:2012-01-01T12:56:22.792 3.12e-06 4.10e-06 2.47e-06 1.42e-06 9.36e-07
 * :01:2012-01-01T13:00:38.792 1.98e-06 4.63e-07 7.64e-07 7.56e-07 5.09e-07
 * :02:2012-01-01T13:00:38.792 2.91e-06 1.46e-06 2.97e-06 1.42e-06 1.55e-06
 * @endcode
 *
 * Each @b \<packet\> element above is a serialized PacketDescriptor.  This
 * structure and it's associated functions are responsible for:
 *
 *    -# Holding the definition of a single packet type within the stream
 *    -# Writing data values onto the stream
 *    -# Serializing data values from a stream
 *
 * To help them do their jobs, PacketDescriptors hold and array of
 * PlaneDescriptors, as well a byte field containing up to one data packet's
 * worth of bytes.
 *
 * <h3>Creating Packet Descriptors</h3>
 *
 * Packet Descriptors are part of a Das2 Stream.  To define a new packet type
 * call:
 * @code
 *  createPacketDescriptor(StreamDesc* sd, DataType xDataType, UnitType xUnits)
 * @endcode
 *
 * or a similar function.  This particular version creates a PacketDescriptor
 * that only has an \<x\> plane.  Using the following to add \<y\> and/or \<yscan\>
 * planes to the packet.
 *
 * @code
 *   addPlaneY()
 *   addPlaneYScan()
 * @endcode
 *
 * Optionally additions properties such as labels may be added to each \<y\> or
 * \<yscan\> plane using:
 *
 * @code
 *   setPropertyString()
 * @endcode
 *
 * and related functions.
 *
 * When reading Das2 Streams PacketDescriptors are created automatically
 * as the input is read by the processStream() method of the ::StreamHandler.
 *
 * <h3>Emitting Packet Data</h3>
 *
 * The PacketDiscriptor has a 1-Packet wide buffer.  This buffer is used to
 * build up the output data for a single packet.  To set the value for the
 * various planes use:
 *
 * @code
 * setDataPacketDouble()       // For <x> and <y> planes
 * setDataPacketYScanDouble()  // For <yscan> planes
 * @endcode
 *
 * and related functions.  Once that job is complete, transmit the data
 * packet using:
 *
 * @code
 * sendPacket()
 * @endcode
 *
 * The details of encoding the data according the format stored in the
 * packet descriptor are handled by the library.
 *
 * <h3>Reading Data</h3>
 *
 * @extends DasDesc
 * @nosubgrouping
 * @ingroup streams
 */
struct packet_descriptor
{
    DasDesc base;

    int id;

    size_t uPlanes;
    PlaneDesc*[MAXPLANES] planes;

    /* Set to true when encode is called, make sure data doesn't go
    	  * out the door unless the descriptor is sent first */
    bool bSentHdr;

    /* Packets with the same group identifier can be plotted together on
    	  * the same graph */
    char* sGroup;

    /** User data pointer.
    	  * The stream->packet->plane hierarchy provides a good organizational
    	  * structure for application data, especially for applications whose
    	  * purpose is to filter streams.  This pointer can be used to hold
    	  * a reference to information that is not serialized.  It is initialized
    	  * to NULL when a packet descriptor is created otherwise the library
    	  * doesn't deal with it in any other way. */
    void* pUser;
}

alias PktDesc = packet_descriptor;

/** Creates a packet descriptor with the default settings.
 *
 * @return A pointer to a new PktDesc allocated on the heap, or NULL on an error.
 * @memberof PktDesc
 */
PktDesc* new_PktDesc ();

/** Create a PktDesc from XML data
 *
 * @param pBuf The buffer to read.  Reading will start with the read point and
 *        will run until DasBuf_remaining() is 0 or the end tag is found, which
 *        ever comes first.
 * @param pParent The parent packet descriptor, this may be NULL
 * @param nPktId The packet's ID within it's parent's array. May be 0 if and
 *        only if the pParent is NULL
 * @return A pointer to a new PktDesc allocated on the heap, or NULL on an error.
 * @memberof PktDesc
 */
PktDesc* new_PktDesc_xml (DasBuf* pBuf, DasDesc* pParent, int nPktId);

/** Free a packet descriptor and all it's contained objects
 *
 * @param pThis The packet descriptor to free, the caller should set the
 *        pointer to NULL after this call.
 */
void del_PktDesc (PktDesc* pThis);

/** Check for packet descriptor format equality
 *
 * This function checks to see if two packet descriptors define the same data
 * note that the StreamDesc parent of each need not be the same, nor are the
 * descriptors required to have the same current data values.
 *
 * @param pPd1
 * @param pPd2
 * @return true if both packet descriptors provide the same definition, false
 *         otherwise
 */
bool PktDesc_equalFormat (const(PktDesc)* pPd1, const(PktDesc)* pPd2);

/** Get the packet ID for this packet.
 * Each packet type within a Das 2 Stream has a unique ID form 1 to 99
 * inclusive.  Note that ID's <b>can be reused</b>!  So processing code
 * must be on the lookout for re-definition packets.
 * @return the packet id, a number between 1 and 99 or -1 if there is on packet
 *         id assigned.
 * @memberof PktDesc
 */
int PktDesc_getId (const(PktDesc)* pThis);

/** Get the data group for this packet.
 *
 * Packets with the same group should be able to be plotted on the same graph.
 * This is the same as a join in QDataset terms
 *
 * @param pThis A pointer to a packet desciptor structure
 * @return NULL if the packet has no specified group, or the group string which
 *         follows the rules for valid identifers in das_assert_valid_id()
 * @memberof PktDesc
 */
const(char)* PktDesc_getGroup (const(PktDesc)* pThis);

/** Set the data group for this packet
 *
 * @param pThis A pointer to a packet descriptor structure
 * @param sGroup The new group name which must be a valid id.
 * @memberof PktDesc
 */
void PktDesc_setGroup (PktDesc* pThis, const(char)* sGroup);

/** Get the size of data records defined by a packet descriptor
 *
 * @param pThis The packet descriptor to query
 * @return The size in bytes of a single packet's worth of data.
 * @memberof PktDesc
 */
size_t PktDesc_recBytes (const(PktDesc)* pThis);

/** Get the number of planes in this type of packet
 * @param pThis the packet descriptor in question
 * @returns The number of planes defined in this packet.
 * @memberof PktDesc
 */
size_t PktDesc_getNPlanes (const(PktDesc)* pThis);

/** Get the number of planes of a particular type in a packet
 *
 * @param pThis The packet descriptor to check
 * @param pt the plane type to check
 * @return The number of planes of a particular type in this packet descriptor
 * @memberof PktDesc
 */
size_t PktDesc_getNPlanesOfType (const(PktDesc)* pThis, plane_type_t pt);

/** Add a plane to a packet
 *
 * All data in a das2 stream are sent via packets, each packet type has 1-100
 * planes.  A plane can be a single column of numbers, which has one value
 * per data packet, or in the case of \<yscan\> planes they can be more like
 * sub-tables which have many values per packet.  The newly added plane will
 * have this PktDesc assigned as it's parent.
 *
 * Planes have types.  A Packet must have at least 1 \<x\> plane.  In general it
 * may have as many \<y\> \<yscan\> planes as it likes up to the plane limit.
 * For packets with \<z\> planes, no \<yscan\> planes are allowed and one and
 * only one \<y\> plane must be preset.  This function enforces the packet
 * formation rules.  In summary the following patterns are legal.
 *  - X [X]
 *  - X [X] Y [Y Y ...]
 *  - X [X] YScan [YScan YScan ...]
 *  - X [X] Y [Y Y ...] YScan [YScan YScan ...] (see note)
 *  - X [X] Z [Z Z ...]
 *
 * where [] indicates optional planes.  Note: Y and YScan planes can be
 * interleaved in any order.
 *
 * This function adds the plane after all existing planes.  Thus the index
 * of any existing planes is not altered.
 *
 * @param pThis The packet descriptor to receive the new plane definition
 * @param pPlane The plane to add
 * @return On success the index of the new plane is returned, or -1 on an error
 *
 * @memberof PktDesc
 */
int PktDesc_addPlane (PktDesc* pThis, PlaneDesc* pPlane);

/** Copy in all planes from another a packet descriptor
 *
 * Deepcopy's the plane descriptors in pOther and attaches the newly
 * allocated planes to this PktDesc object.  This packet descriptor must
 * not already have any planes defined or this function will fail.
 *
 * @param pThis the destination for the newly allocated PlaneDescriptors
 * @param pOther the source of the PlaneDescriptors
 * @returns 0 on success or a positive error number if there is a problem
 *
 * @memberof PktDesc
 */
DasErrCode PktDesc_copyPlanes (PktDesc* pThis, const(PktDesc)* pOther);

/** Check to see if a legal plane layout is present.
 *
 * Since not all checks for a legal packet layout can be made while the
 * sub-objects are being added to the packet descriptor, this function is
 * provided to check the layout after adding all planes to a packet.
 *
 * @see PktDesc_addPlane()
 * @param pThis The packet descriptor to check
 * @returns true if this packet descriptor has a legal set of planes, false
 * otherwise.
 * @memberof PktDesc
 */
bool PktDesc_validate (PktDesc* pThis);

/** Determine the type of plane by index
 *
 * @param pThis the packet descriptor to query
 * @param iPlane the index in question.  Valid values for this parameter are
 *        0 to MAXPLANES - 1
 * @returns If the index corresponds to a data plane, then one of the enum
 *          values is return:
 *          <ul><li>X</li>
 *          <li>Y</li>
 *          <li>YSCAN</li>
 *          <li>Z</li></ul>
 *          is returned, otherwise:
 *          <ul><li>Invalid</li></ul>
 *          is returned
 *
 * @memberof PktDesc
 */
plane_type_t PktDesc_getPlaneType (const(PktDesc)* pThis, int iPlane);

/** returns the PlaneDescriptor for plane number @a iplane
 * This can be used to query properties of the plane, such as units and
 * the name.
 *
 * @param pThis The packet descriptor to query
 * @param iplane The index of the plane to retrieve.  The 0th plane is
 *         an \<x\> plane if one is present in the stream.
 *
 * @memberof PktDesc
 */
PlaneDesc* PktDesc_getPlane (PktDesc* pThis, int iplane);

/** Get the plane number within this packet description
 * @param pThis the packet descriptor to query
 * @param pPlane a pointer to the plane who's index is required
 * @returns a number from 0 to 99 if successful or -1 if the plane pointed to
 *          by pPlane is not part of this packet description
 */
int PktDesc_getPlaneIdx (PktDesc* pThis, PlaneDesc* pPlane);

/** Get a Plane Descriptor for the plane with the name @a name
 *
 * @returns A pointer to the plane, or NULL if no plane with the
 *          given name is present in the packet descriptor
 */
PlaneDesc* PktDesc_getPlaneByName (PktDesc* pThis, const(char)* name);

/** Get the Ith plane of a given type
 *
 * @param pThis The packet descriptor to query
 * @param ptype The plane type, one X, Y, Z, YScan
 * @param iRelIndex The number of the plane of a given type to find.  The
 *        lowest index will be 0 for a given type.
 * @return A pointer to the plane, or NULL if there are not at least iRelIndex + 1
 *          planes of the given type in the packet
 */
PlaneDesc* PktDesc_getPlaneByType (
    PktDesc* pThis,
    plane_type_t ptype,
    int iRelIndex);

/** Gets the Nth plane of a given type.
 *
 * This is useful for iterating over all planes of a given type.
 *
 * @param pThis A packet descriptor structure pointer.
 *
 * @param ptype The plane type, one X, Y, Z, YScan
 *
 * @param iRelIndex The number of the plane of a given type to find.  The
 *        lowest index will be 0 for a given type.
 *
 * @return The absolute plane index for the Nth plane of a given type. If
 *        No planes of the given type are present, or iIndex is out of range
 *        -1 is returned.
 *
 * @memberof PktDesc
 */
int PktDesc_getPlaneIdxByType (
    const(PktDesc)* pThis,
    plane_type_t ptype,
    int iRelIndex);

/** returns the plane number for the named plane.
 * @param pThis The packet descriptor to query.
 * @param name The name in of the plane to find
 * @param planeType if not set to 0, then PlaneType must also match.
 * Note that typically the 0th plane is typically the \<x\> plane.
 * @memberof PktDesc
 */
int PktDesc_getPlaneIdxByName (
    PktDesc* pThis,
    const(char)* name,
    plane_type_t planeType);

/** returns the PlaneDescriptor for the 1st X Tag plane.
 * @memberof PktDesc
 */
PlaneDesc* PktDesc_getXPlane (PktDesc* pThis);

/** Serialize a packet descriptor as XML data
 *
 * @param pThis The packet descriptor to store as string data
 * @param pBuf A buffer object to received the string data
 * @return 0 if successful, or a positive integer if not.
 *
 * @memberof PktDesc
 */
DasErrCode PktDesc_encode (const(PktDesc)* pThis, DasBuf* pBuf);

/** Serialize a packet's current data
 * In addition to holding the format information for Das2 Stream packets
 * PktDesc objects also hold a a single packet's worth of data.  Use this
 * function to encode the current data values for output.
 *
 * @param pThis The packet descriptor that has been loaded with data
 * @param pBuf A buffer to receive the encoded bytes
 * @returns 0 if successful, or a positive integer if not.
 *
 * @memberof PktDesc
 */
DasErrCode PktDesc_encodeData (const(PktDesc)* pThis, DasBuf* pBuf);

/** Decode 1 packet's worth of data from a buffer.
 * @param pThis the packet descriptor to handle decoding
 * @param pBuf The buffer with the data, data will be read from the current
 *        read point.
 * @returns 0 if successful, or a positive integer if not.
 * @memberof PktDesc
 */
DasErrCode PktDesc_decodeData (PktDesc* pThis, DasBuf* pBuf);

/** Convenience function for setting a single value in a plane
 * This is just a shortcut for:
 * @code
 * PlaneDesc* pPlane = PktDesc_getPlane(pPkt, uPlane);
 * PlaneDesc_setValue(pPlane, uItem, value);
 * @endcode
 * @param pThis The packet descriptor in question.
 * @param uPlane The index of the plane to receive the values
 * @param uItem The index of the item in the plane to be set to the new value
 * @param val The new value for this item in this plane.
 * @return 0 on success or a positive error code if there is a problem
 * @memberof PktDesc
 */
DasErrCode PktDesc_setValue (
    PktDesc* pThis,
    size_t uPlane,
    size_t uItem,
    double val);

/** Convenience function for setting an array of values in a plane
 * This is just a shortcut for:
 * @code
 * PlaneDesc* pPlane = PktDesc_getPlane(pPkt, uPlane);
 * PlaneDesc_setValues(pPlane, pVals);
 * @endcode
 * @param pThis The packet descriptor in question.
 * @param uPlane The index of the plane to receive the values
 * @param pVals The array of values to set.  The array is assumed to be the
 *        same length as the number of items in plane @a uPlane
 * @return 0 on success or a positive error code if there is a problem
 * @memberof PktDesc
 */
DasErrCode PktDesc_setValues (
    PktDesc* pThis,
    size_t uPlane,
    const(double)* pVals);

/* _das_packet_h_ */
