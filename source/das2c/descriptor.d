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

/** @file descriptor.h */

module das2c.descriptor;

import das2c.util;
import das2c.buffer;
import das2c.defs;
import das2c.units;

extern (C):

/** enumeration of Descriptor types, used internally for type checking.
 * May have one of the following values:
 *    -# PLANE
 *    -# PACKET
 *    -# STREAM
 *    -# FUNCTION
 *    -# FUNC_SET
 */
enum DescriptorType
{
    UNK_DESC = 0,
    PLANE = 14001,
    PACKET = 14002,
    STREAM = 14003,
    VARIABLE = 1500,
    DATASET = 1501
}

alias desc_type_t = DescriptorType;

/** Base structure for Stream Header Items.
 *
 * Descriptors have properties associated with them.  Stream Descriptors,
 * Packet Descriptors, and Plane Descriptors are all extensions of this object
 * type, thus the functions for this structure may be used with any Descriptor
 * structure in the library.
 *
 * Note: <b>Properties Cascade</b>
 *
 * Properties @e cascade in Das2 Streams.  Thus if a particular descriptor
 * does not have a particular property then the various getProperty() functions
 * will search parent descriptors for requested property.  The descriptor
 * ownership hierarchy for Das2 Streams is:
 *
 *   - ::StreamDesc's have 1-N ::PktDesc's
 *   - ::PktDesc's have 1-N ::PlaneDesc's
 *
 * @todo Move child relationship into the descriptor base class, parent is there
 *       but the other direction is missing
 *
 * @todo This implementation is very inefficient requring many small malloc's
 *       and order(N) object lookups.  It also has types, keys and values all
 *       mixed together in the same array or the same value.  This makes object
 *       lookup a wierd i+=2 iteration with ":" searches.  We only get away with
 *       this because not much is stored in the properies arrays.
 *
 *       This class this is just a hobbled dictionary of objects plus some
 *       string conversion functions.  Using an actual C dictionary
 *       implementation would improve code quite a bit.  If I were going to go
 *       to the trouble to do that I would make it multi-lingual as well. -cwp
 *
 * @nosubgrouping
 */
struct das_descriptor
{
    desc_type_t type;
    char*[DAS_XML_MAXPROPS] properties;
    const(das_descriptor)* parent;
    bool bLooseParsing;
}

alias DasDesc = das_descriptor;

/** @name Descriptor Functions
 * These work for any type of Descriptor, including ::PlaneDesc ,
 * ::PktDesc, ::StreamDesc, ::DasDs and ::DasVar.
 * To make your compiler happy you will need to cast Plane, Packet and
 * Stream Descriptor pointers to just the generic type of Descriptor pointer
 * when using these functions. For example:
 * @code
 * PktDesc* pPktDesc;
 * hasProperty((Descriptor*)pPktDesc, "SomePropName");
 * @endcode
 * @member DasDesc
 */

/** @{ */
void DasDesc_init (DasDesc* pThis, desc_type_t type);

/* Make an 'Unknown' type descriptor, incase you like using descriptor objects
 * to store things in your code, not used by the library
 * @memberof DasDesc
 */
DasDesc* new_Descriptor ();

void DasDesc_freeProps (DasDesc* pThis);

/** Check to see if two descriptors contain the same properties
 * Note, the order of the properties may be different between the descriptors
 * but if the contents are the same then the descriptors are considered to be
 * equal.
 *
 * Note that parent descriptor properties are not checked when handling the
 * comparison.
 * @todo maybe check parents too.
 *
 * @param pOne The first descriptor
 * @param pTwo The second descriptor
 * @memberof DasDesc
 */
bool DasDesc_equals (const(DasDesc)* pOne, const(DasDesc)* pTwo);

/** The the parent of a Descriptor
 *
 * Plane descriptors are owned by packet descriptors and packet descriptors are
 * owned by stream descriptors.  This function lets you craw the ownership
 * hierarchy
 *
 * @param pThis
 * @return The owner of a descriptor, or NULL if this is a top level descriptor,
 *         (i.e. a Stream Descriptor)
 * @memberof DasDesc
 */
const(DasDesc)* DasDesc_parent (DasDesc* pThis);

/** Get the number of properties in a descriptor.
 *
 * Descriptor's have a hierarchy.  In general when a property is requested, if
 * a given Descriptor does not have a property the request is passed to the
 * parent descriptor.  This function @b only returns the number of properties
 * in the given descriptor.  It does not include properties owned by parents
 * or ancestors.
 *
 * This is useful when iterating over all properties in a descriptor.
 * @see DasDesc_getNameByIdx()
 * @see DasDesc_getValByIdx()
 * @see DasDesc_getTypeByIdx()
 *
 * @param pThis A pointer to the descriptor to query
 * @return The number of properties in this, and only this, descriptor.
 * @memberof DasDesc
 */
size_t DasDesc_length (const(DasDesc)* pThis);

/** Get a property name by an index
 *
 * This is useful when iterating over all properties in a Descriptor.  Only
 * properties owed by a descriptor are queried in this manner.  Parent
 * descriptors are not consulted.
 *
 * @see DasDesc_length()
 * @param pThis A pointer to the descriptor to query
 * @param uIdx The index of the property, will be a value between 0 and
 *        the return value from Desc_getNProps()
 * @return A pointer the requested property name or NULL if there is no
 *        property at the given index.
 * @memberof DasDesc
 */
const(char)* DasDesc_getNameByIdx (const(DasDesc)* pThis, size_t uIdx);

/** Get a property value by an index
 *
 * This is useful when iterating over all properties in a Descriptor.  Only
 * properties owned by a descriptor are queried in this manner.  Parent
 * descriptors are not consulted.
 *
 * @see DasDesc_length()
 * @param pThis A pointer to the descriptor to query
 * @param uIdx The number of the property, will be a value from 0 and 1 less
 *        than the return value from Desc_getNProps()
 * @return A pointer the requested property value or NULL if there is no
 *        property at the given index.
 * @memberof DasDesc
 */
const(char)* DasDesc_getValByIdx (const(DasDesc)* pThis, size_t uIdx);

/** Get a data type of a property by an index
 * @memberof DasDesc
 */
const(char)* DasDesc_getTypeByIdx (const(DasDesc)* pThis, size_t uIdx);

/** Determine if a property is present in a Descriptor or it's ancestors.
 *
 * @param pThis the descriptor object to query
 * @param propertyName  the name of the property to retrieve.
 * @returns true if the descriptor or one of it's ancestors has a property
 *          with the given name, false otherwise.
 * @memberof DasDesc
 */
bool DasDesc_has (const(DasDesc)* pThis, const(char)* propertyName);

/** Generic property setter
 *
 * All properties are stored internally as strings.  The various typed
 * Desc_setProp* functions all call this function after converting their
 * arguments to strings.
 *
 * @warning To insure that the string to type conversions are consistent it is
 * strongly recommended that you use one of the typed functions instead of this
 * generic version unless you have no choice.
 *
 * @param pThis The Descriptor to receive the property
 * @param sType The Type of property should be one of the strings:
 *    - @b boolean
 *    - @b double
 *    - @b doubleArray
 *    - @b Datum
 *    - @b DatumRange
 *    - @b int
 *    - @b String
 *    - @b Time
 *    - @b TimeRange
 * @param sName The property name, which cannot contain spaces
 * @param sVal The value, which may be anything including NULL
 * @return 0 on success or a positive error code if there is a problem.
 * @memberof DasDesc
 */
DasErrCode DasDesc_set (
    DasDesc* pThis,
    const(char)* sType,
    const(char)* sName,
    const(char)* sVal);

const(char)* DasDesc_getType (const(DasDesc)* pThis, const(char)* sKey);
const(char)* DasDesc_get (const(DasDesc)* pThis, const(char)* sKey);

/** Remove a property from a descriptor, if preset
 *
 * It is safe to call this function for properties not present on the
 * descriptor, it simply does nothing and returns false.
 *
 * @returns false if the property wasn't present to begin with, true
 *          otherwise
 * @memberof DasDesc
 * */
bool DasDesc_remove (DasDesc* pThis, const(char)* propretyName);

/** read the property of type String named propertyName.
 * @memberof DasDesc
 */
const(char)* DasDesc_getStr (const(DasDesc)* pThis, const(char)* propertyName);

/** SetProperty methods add properties to any Descriptor (stream,packet,plane).
 * The typed methods (e.g. setPropertyDatum) property tag the property with
 * a type so that it will be parsed into the given type.
 * @memberof DasDesc
 */
DasErrCode DasDesc_setStr (
    DasDesc* pThis,
    const(char)* sName,
    const(char)* sVal);

/** Set a string property in the manner of sprintf
 * @memberof DasDesc
 */
DasErrCode DasDesc_vSetStr (
    DasDesc* pThis,
    const(char)* sName,
    const(char)* sFmt,
    ...);

/** Read the property of type double named propertyName.
 * The property value is parsed using sscanf.
 * @memberof DasDesc
 */
double DasDesc_getDouble (const(DasDesc)* pThis, const(char)* propertyName);

/** Set property of type double.
 * @memberof DasDesc
 */
DasErrCode DasDesc_setDouble (
    DasDesc* pThis,
    const(char)* propertyName,
    double value);

/** Get the a numeric property in the specified units.
 *
 * Descriptor properties my be provided as Datums.  Datums are a double value
 * along with a specified measurement unit.
 * @param pThis The Descriptor containing the property in question.
 * @param sPropName The name of the property to retrieve.
 * @param units The units of measure in which the return value will be
 *        represented.  If the property value is stored in a different set of
 *        units than those indicated by this parameter than the output will be
 *        converted to the given unit type.
 * @returns The converted value or @b DAS_FILL_VALUE if conversion to the desired
 *        units is not possible.
 * @memberof DasDesc
 */
double DasDesc_getDatum (
    DasDesc* pThis,
    const(char)* sPropName,
    das_units units);

/** Set property of type Datum (double, UnitType pair)
 *
 * If a property with this name already exists it is 1st deleted and then the
 * new property is added in its place.
 *
 * @param pThis The descriptor to receive the property
 * @param sName The name of the property to set
 * @param rVal The numeric value of the property
 * @param units The units of measure for the property
 *
 * @memberof DasDesc
 */
DasErrCode DasDesc_setDatum (
    DasDesc* pThis,
    const(char)* sName,
    double rVal,
    das_units units);

/** Get the values of an array property
 *
 * Space for the array is allocated by getDoubleArrayFromString.
 * and nitems is set to indicate the size of the array.
 *
 * @param[in] pThis the descriptor object to query
 * @param[in] propertyName the name of the proprety to retrieve
 * @param[out] nitems a pointer to a an integer containing the number of
 *        values in the returned array.
 *
 * @returns A pointer to a double array allocated on the heap.  It is the
 *          caller's responsibility to depose of the memory when it is no
 *          longer needed.  If the named property doesn't exist
 *          the program exits.
 *
 * @see hasProperty()
 *
 * @memberof DasDesc
 */
double* DasDesc_getDoubleAry (
    DasDesc* pThis,
    const(char)* propertyName,
    int* nitems);

/** Set the property of type double array.
 * @memberof DasDesc
 */
DasErrCode DasDesc_setDoubleArray (
    DasDesc* pThis,
    const(char)* propertyName,
    int nitems,
    double* value);

/** Get a property integer value
 *
 * @param pThis the descriptor object to query
 * @param propertyName the name of the proprety to retrieve
 * @returns The value of the named property or exits the program if the
 *          named proprety doesn't exist in this descriptor.
 *
 * @see hasProperty()
 * @memberof DasDesc
 */
int DasDesc_getInt (const(DasDesc)* pThis, const(char)* propertyName);

/** Set the property of type int.
 * @memberof DasDesc
 */
DasErrCode DasDesc_setInt (DasDesc* pThis, const(char)* sName, int nVal);

/** Get a property boolean value
 *
 * @param pThis the descriptor object to query
 * @param sPropName the name of the proprety to retrieve
 * @returns True if the value is "true", or any positive integer, false otherwise.
 * @memberof DasDesc
 */
bool DasDesc_getBool (DasDesc* pThis, const(char)* sPropName);

/** Set a boolean property
 * Encodes the value as either the string "true" or the string "false"
 * @param pThis The descriptor to receive the property
 * @param sPropName the name of the property
 * @param bVal either true or false.
 */
DasErrCode DasDesc_setBool (DasDesc* pThis, const(char)* sPropName, bool bVal);

/** Set property of type DatumRange (double, double, UnitType triple)
 * @memberof DasDesc
 */
DasErrCode DasDesc_setDatumRng (
    DasDesc* pThis,
    const(char)* sName,
    double beg,
    double end,
    das_units units);

/** Get a property of type DatumRange with unconverted strings.
 *
 * This version is handy if you just want to know the intrinsic units of
 * the range without converting the values to some specific type of double
 * value.
 * @memberof DasDesc
 */
DasErrCode DasDesc_getStrRng (
    DasDesc* pThis,
    const(char)* sName,
    char* sMin,
    char* sMax,
    das_units* pUnits,
    size_t uLen);

/** Set the property of type float array.
 * Note the array is cast to a double array before encoding.
 * @memberof DasDesc
 */
DasErrCode DasDesc_setFloatAry (
    DasDesc* pThis,
    const(char)* propertyName,
    int nitems,
    float* value);

/** Deepcopy properties into a descriptor
 * @param pThis the descriptor to receive a copy of the properties
 * @param source the descriptor with the properties to be copied.
 * @memberof DasDesc
 */
void DasDesc_copyIn (DasDesc* pThis, const(DasDesc)* source);

/** Encode a generic set of properties to a buffer
 *
 * @param pThis The descriptors who's properties should be encoded
 * @param pBuf A buffer object to receive the XML data
 * @param sIndent An indent level for the property strings, makes 'em look nice
 * @return 0 if the operation succeeded, a non-zero return code otherwise.
 * @memberof DasDesc
 */
DasErrCode DasDesc_encode (DasDesc* pThis, DasBuf* pBuf, const(char)* sIndent);
/** @} */

/* _descriptor_h_ */
