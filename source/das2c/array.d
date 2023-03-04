/* Copyright (C) 2017-2020 Chris Piker <chris-piker@uiowa.edu>
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

/** @file array.h A dynamic buffer with multi-dimensional array style access */

/* I'm sure this kind of buffer has been done many times before, but I haven't
 * seen an implementation that handles arbitrarily ragged arrays.  Thanks to
 * Larry Granroth, and Matt Leifert for helping me talk through the issues
 * around this class.
 * -cwp
 */

module das2c.array;

import das2c.util;
import das2c.units;
import das2c.value;

extern (C):

/** The maximum number of array indices in das2 */
enum DASIDX_MAX = 16;

/* WARNING!  If the values below change, update das_varindex_merge */
/*           and update das_varlength_merge */

enum DASIDX_RAGGED = -1;
enum DASIDX_FUNC = -2;
enum DASIDX_UNUSED = -3;

/** Used to indicate degenerate axis in das variables */
enum DEGEN = -3;

/** Global instance of unused array, suitable for memcpy */

extern __gshared const(ptrdiff_t)[DASIDX_MAX] g_aShapeUnused;
extern __gshared const(ptrdiff_t)[DASIDX_MAX] g_aShapeZeros;
extern __gshared const(char)[DASIDX_MAX] g_sIdxLower;
extern __gshared const(char)[DASIDX_MAX] g_sIdxUpper;

/** Print shape information using symbols i,j,k etc for index positions
 *
 * @param pShape pointer to an array containing shape information
 * @param iFirstInternal the index of the first internal index.  The index notation
 *        changes at this point to use I,J,K instead of i,j,k and the index
 *        count reverts back to 0.
 * @param nShapeLen An index 1 past the last unsed index in the shape array.
 * @param sBuf a buffer to recieve the shape info
 * @param nBufLen the length of the buffer.  The function will not print past
 *        this value - 1 to insure null terminiation.
 * @return The a pointer to the position in the buffer sBuf after all text
 *         was written.
 */
char* das_shape_prnRng (
    ptrdiff_t* pShape,
    int iFirstInternal,
    int nShapeLen,
    char* sBuf,
    int nBufLen);

/** print a generice set of ptrdiff_t values to a character array */
char* das_idx_prn (int nRank, ptrdiff_t* pIdx, size_t uLen, char* sBuf);

enum DIM1 = 1;
enum DIM2 = 2;
enum DIM3 = 3;
enum DIM4 = 4;
enum DIM5 = 5;
enum DIM6 = 6;
enum DIM7 = 7;

/** Calculate a strided array shape from a min/max range.
 *
 * Used to calculate the memory requirements for a subset of a strided array
 * range.   The output range will often have fewer axes than the the input
 * shape.  This is common when slicing.
 *
 * @param nRngRank The length of the min an max location arrays
 *
 * @param pMin The inclusive lower bound for the range in each array dimension.
 *
 * @param pMax The *exclusive* upper bound for the range in each array dimension.
 *          For each element of pMax that is just 1 value larger than pMin the
 *          output shape is collapsed by one dimension.
 *
 * @param[out] pShape The output range.  Not that if the return rank is 0 then
 *          this has no usable elements.  At most nRngRank elements will be
 *          written into pShape.
 *
 * @returns The rank of the shape.  This can be 0 if the given range collapses
 *          to a single value.  Returns -1 if pMin or pMax are invalid (also
 *          calls das_error, so the function may not return at all).
 */
int das_rng2shape (
    int nRngRank,
    const(ptrdiff_t)* pMin,
    const(ptrdiff_t)* pMax,
    size_t* pShape);

/** @} */

/* Higher dimensions are handled by index buffers.  These are the elements for
 * the index buffers */
struct child_info_t
{
    ptrdiff_t nOffset; /* Start of child elements data in child buffer */
    size_t uCount; /* The count child elements in child buffer     */
}

alias das_idx_info = child_info_t;

struct dyna_buf
{
    ubyte* pBuf; /* The beginning a continuous buffer uSize long */
    ubyte* pHead; /* The beginning of valid values in the buffer  */
    /*byte* pWrite;*/ /* The beginning of the append point for the buffer */
    size_t uSize; /* The amount of space in the backing buffer    */
    size_t uValid; /* The number of valid elements in this buffer  */
    size_t uElemSz; /* The number of bytes occupied by each element */

    ubyte* pFill; /* Pointer to fill value buffer */
    ubyte[16] fillBuf; /* Storage for short fill items */

    size_t uChunkSz; /* Alloc helper, if set, allocate in even chunks
       * of this size. */
    size_t uShape; /* Qube helper, how many items in this array per
    										 * parent item, 0 means ragged */
    das_val_type etype; /* The element type */

    bool bRollParent; /* The end mark.  If set, adding data to the array
    										 * will clear the end mark and trigger creation of
    										 * a new parent.  If this is set on all indexes
    										 * attempting to add data will fail */

    bool bKeepMem; /* If true memory will not be deleted when the
    									   * buffer is deleted */
}

alias DynaBuf = dyna_buf;

/** Dynamic recursive ragged arrays
 *
 * This class maps any number of indices, (i,j,k...) to elements stored into a
 * continuous array.  Any or all particular indexes of the array may be ragged
 * if desired, though typically for fixed record size data streams, only the
 * first index has an arbitrary length.
 *
 * The backing buffers for the array grow as needed when new elements are
 * appended.  Individual elements may be arbitrary composite types, though
 * extra capabilites are provided for a handful of known types.
 *
 * Handling ragged data comes at a cost in that the length of each continuous
 * run of elements must also be stored in an ancillary array since address
 * strides are not necessarily constant.  This cost is 8 to 16 bytes times the
 * size of all indexes, except the last.  For example, an array of shape
 * (10,100,40) would use 10*100*16 extra bytes compared to a simple strideable
 * array, though this is typically much smaller than the 10*100*40*element_size
 * bytes used by the primary data buffer.
 *
 * Handling ragged data also comes at a cost in terms of potential cache misses.
 * For example to lookup a value in a rank 3 array requires accessing three
 * dynamically allocated buffers. One for each dimension of the array.  The
 * first two are offset value buffers, the last is the actual data buffer.
 *
 * Automatically switching to more efficent strided index calculations in cases
 * where all records are of a constant size has yet to be implemented, though
 * the DasAry_stride() function can be used to stride across the raw data buffer
 * efficently if desired.
 *
 * @code
 *
 * // For this example, assume the file below consists of big endian floats
 * const char* my_file = "my_big_endian_datafile.dat";
 * FILE* in_file = fopen(my_file, "rb");
 *
 * // The following Rank 2 array is initially 0 records long and has
 * // 152 values per record.  Thus it starts as a 0 by 152 array
 * Array* pAry = new_Array("amplitudes", etFloat, 0, NULL, RANK_2(0, 152));
 *
 * // Set byte order for input values.  This will trigger swapping if host
 * // byte order is different from input order.  Note that this only works
 * // for the types in the element_type enumeration.  For unknown types you'll
 * // have to do your own byte swapping.
 * DasAry_inputBO(pAry, DAS2ARY_BIG_ENDIAN);
 *
 * // Read values into the array
 * float buf[152] = {0.0f};
 * while(fread(buf, sizeof(float), 152, in_file) == 152)
 *   DasAry_append(pAry, buf, 152);
 *
 * // Get the shape of the first index.
 * printf("%d records read from %s\n", DasAry_lengthIn(pAry, DIM0), my_file);
 *
 * // Print the values in the array, loop below works with ragged arrays and
 * // reduces function call overhead by accessing a full record at a time
 * float* pVals;
 * size_t uVals;
 * for(size_t i = 0; i < DasAry_lengthIn(pAry, DIM0); ++i){
 *    pVals = DasAry_getFloatsIn(pAry, DIM1_AT(i), &uVals);
 *    for(size_t j = 0; j < uVals; ++j){
 *      if( j > 0) printf(", ");
 *      printf("%.4e", pVals[j]);
 *    }
 *    printf("\n");
 * }
 * @endcode
 * @ingroup datasets
 */
struct das_array
{
    char[DAS_MAX_ID_BUFSZ] sId; /* A text identifier of this instance of the array */
    int nRank; /* The number of index dimensions for the array */
    das_idx_info* pIdx0; /* top lever container, may not point here */

    /* bool      bTopOwned;*/ /* Same as pIdx0 == &index0 */
    das_idx_info index0; /* Storage for element 0 of buffer 0, if needed */

    /* Pointers to item arrays.  One array is needed for each dimension,
    	 * these may point to internal locations if the array is owned */
    DynaBuf*[DASIDX_MAX] pBufs;

    /* bool     bOwned[16]; */ /* Same as pBufs[i] == &(bufs[i]) */
    DynaBuf[DASIDX_MAX] bufs; /* Storage for dynamic buffers, if needed */

    /* Current compare function, set automatically if a known type is used,
    	 * otherwise user needs to supply their own */
    int function (const(ubyte)* vpFirst, const(ubyte)* vpSecond) compare;

    /* Where to send/read data when streaming */
    int nSrcPktId;
    size_t uStartItem;
    size_t uItems;

    /* Since so many datasets and functions can reference the same array,
    	 * a reference count is needed to make sure they aren't deleted if
    	 * still in use. */
    int refcount;

    /* Used to notify the owner of my memory that I'm not using it anymore. */
    das_array* pMemOwner;

    uint uFlags; /* Store flags indicating intended use */

    das_units units;
}

alias DasAry = das_array;

/** Creates a new dynamic array buffer
 *
 * @param id The name of this array.  This may be used as a lookup key if
 *        an array pointer is stored in a lookup table.
 *
 * @param et The element type, for arbitrary element storage use UNKNOWN,
 *        specific types are provided in enum element_type.
 *
 * @param sz_each The size of each element in the array in bytes.  This
 *        parameter is only used when the element type is unknown.
 *
 * @param fill A pointer to the value for initializing all empty array records.
 *        The value should be size_each bytes long.  These bytes are copied into
 *        the array and this pointer need not remain valid after the constructor
 *        call.
 *        For unknown types (et = etUnknown) this is a required, non NULL
 *        parameter.  For known types you can use NULL to automatically set
 *        fill to the following values, based on the element_type:
 *
 *           - etByte                          0
 *           - etUShort                    65535
 *           - etShort                    -32767
 *           - etInt                 -2147483647
 *           - etLong       -9223372036854775807L
 *           - etFloat                   -1.0e31
 *           - etDouble                  -1.0e31
 *           - etTime    0000-01-01T00:00:00.000
 *
 *        pFill can point to stack memory as the fill bytes are copied in.
 *
 * @param rank The number of dimensions in the array.  This sets the number
 *        of arguments needed in the get() function call.  To make your code
 *        easier to read, the defines RANK_1, RANK_2, ... RANK_16 are provided.
 *
 * @param shape The initial shape of the array.  One integer is needed here
 *        for each dimension in the array.  Use the value 0 to set a dimension
 *        to be unbounded.  Multi-dimension arrays used to hold an arbitrarily
 *        long set of records are typically only unbounded in the first index,
 *        though see the example in DasAry_markEnd for handling multiply ragged
 *        arrays.
 *
 * @returns A new array buffer allocated on the heap.
 *
 *
 * @code
 *    // Create a rank 3 array that is ragged only in the first index, with a
 *    // fill value of -1.0f, useful for storing a stream of fixed size MARSIS
 *    // AIS records
 *    float fill = -1.0f;
 *    Array* pA = new_Array("fee", etFloat, 0, &fill, RANK_3(0,160,80));
 *
 *    // Create an empty Rank 2 array, that is ragged in both indices.
 *    // (Useful for Cassini WBR data)
 *    Array* pA = new_Array("fi", etFloat, 0, NULL, RANK_2(0,0));
 *
 *    // Theoretical example of creating a triply ragged array to hold
 *    // text from a document, where the first index is the page the
 *    // second is the line and the third is the byte in a line
 *    Array* pA = new_Array("text", etByte, 0, NULL, RANK_3(0,0,0));
 *
 * @endcode
 *
 * @warning The number of shape parameters must be equal to the rank
 *        of the array.  The compiler @b can't check this, but you <b> will get
 *        segfaults </b> if the value of rank does not match the number of shape
 *        values.  To help avoid this the use of the RANK_* macros is highly
 *        recommended.
 *
 * @memberof DasAry
 */
DasAry* new_DasAry (
    const(char)* id,
    das_val_type et,
    size_t sz_each,
    const(ubyte)* fill,
    int rank,
    size_t* shape,
    das_units units);

/** This array's elements aren't intended to be addressed to the last index,
 * instead each run of the last index should be used as if it were a complete
 * an individual entity.  */
enum D2ARY_AS_SUBSEQ = 0x00000001;

/** A stronger condition that D2ARY_AS_SUBSEQ.
 * Not only should the last index be ignored when using this array, in addition
 * for each run of the fastest moving index a FILL value is always inserted as
 * the last element. */
enum D2ARY_FILL_TERM = 0x00000003;

/** A still stronger condition than D2ARY_FILL_TERM.
 * This flag indicates not only that the last index shouldn't be addressed
 * and that each fast-index run is FILL terminated, the fill value is 0.
 * This flag is useful for UTF-8 string data. */
enum D2ARY_AS_STRING = 0x00000007;

/** Set usage flags to assist arbitrary consumers understand how to use this
 * array.
 *
 * Das2  arrays can store co-opertive flags, these do not change the array API
 * but do indicate how the array should be used.  The following two usage flags
 * are currently defined:
 *
 *   - D2ARY_AS_SUBSEQ : Contains Sub-sequences
 *   - D2ARY_FILL_TERM : Contains FILL terminated sub-sequences
 *   - D2ARY_AS_STRING : Contains FILL terminated sub-sequences and FILL is 0
 *
 * @param pThis
 * @param uFlags A flag value to set
 * @return The old flag setting
 * @memberof DasAry
 */
uint DasAry_setUsage (DasAry* pThis, uint uFlags);

/** Returns the usage flags for this array
 * @memberof DasAry
 */
uint DasAry_getUsage (DasAry* pThis);

/** Increment the count of objects using this Das Array.
 * @returns The new count.
 * @memberof DasAry
 */
int inc_DasAry (DasAry* pThis);

/** Return the reference count of objects using this array.
 * @memberof DasAry
 */
int ref_DasAry (const(DasAry)* pThis);

/** Maybe remove the array.
 *
 * Calling this function decrements the reference count for the array.  If the
 * count reaches zero all backing buffers (owned by this array) are deleted.
 *
 * @memberof DasAry
 */
void dec_DasAry (DasAry* pThis);

/** Take ownership of array element memory
 *
 * Internally all Das Array elements are stored in a single continuous 1-D
 * buffer.  When the Das Array is deleted, this buffer is removed as well,
 * if it's owned by the das array.
 *
 * @param pThis A pointer to a das array structure
 *
 * @param pLen A pointer to a variable to hold the length of the element
 *         array in elements (not bytes).  If the array had no values
 *         then length is set to 0
 *
 * @param  pOffset Where to store the offset in elements (not bytes) to
 *         the start of valid values.  Internally arrays may have invalid
 *         values in the memory buffer before valid values start.
 *
 * @return A pointer to the raw 1-D element buffer if the Array actually owned
 *         the elements, NULL otherwise.  If not NULL the returned pointer
 *         may be passed to the free() function.
 *         See additional return notes below.
 *
 * Return Notes:
 *   Buffer memory is not allocated until elements are inserted (lazy
 *   allocation) thus an empty array WILL NOT own any elements.  So this
 *   this function will ALWAYS return NULL for an empty array.  Use the value
 *   returned by pLen to see if the NULL return was because the array didn't
 *   own it's elements or if there were no elements to own.
 *
 *   Once elements are disowed, they can't be disowned again.  Calling
 *   disownElements twice in succession in a single threaded program will
 *   always return NULL on the second call.
 *
 * Implementation detail:  The internal ragged index tracking arrays may still
 * be owned by the DasAry object and will be deleted when the overall structure
 * is deleted
 *
 * @memberof DasAry
 */
ubyte* DasAry_disownElements (DasAry* pThis, size_t* pLen, size_t* pOffset);

/** Does this array own it's own memory?
 *
 * If an array owns it's element memory then DasAry_disownElements will
 * return a valid memory buffer if there are any valid values.
 *
 * @return true if the array owns it's element memory, false otherwise.
 * @memberof DasAry
 */
bool DasAry_ownsElements (const(DasAry)* pThis);

/** Get the name of an array
 *
 * @param pThis A constant pointer to this array structure
 * @returns A constant pointer to the identifier for the array
 * @memberof DasAry
 */
const(char)* DasAry_id (const(DasAry)* pThis);

/** Get the number of dimensions in an array
 *
 * @param pThis a pointer to a das array structure
 * @return a value greater than 0 giving the number of dimensions in the array
 * @memberof DasAry
 */
extern (D) auto DasAry_rank(T)(auto ref T pThis)
{
    return pThis.nRank;
}

/* DAS_API int DasAry_rank(const DasAry* pThis); */

/** Get the units for the values in the array
 * @memberof DasAry
 */
das_units DasAry_units (const(DasAry)* pThis);

/** Get the type of value stored in the array if known
 *
 * This function is used by dataset objects to know how to cast pointers
 * to different data array values.
 *
 * @param pThis A constant pointer to this array structure
 * @returns A constant pointer to string containing the name for the values in
 *          the array, or NULL if the value type has not been set.
 * @memberof DasAry
 */
das_val_type DasAry_valType (const(DasAry)* pThis);

/** Get the type of value stored in the array as a text string
 * @memberof DasAry
 */
const(char)* DasAry_valTypeStr (const(DasAry)* pThis);

/** Get a informational string representing the array.
 *
 * @param pThis The Array in question
 * @param sInfo pointer to the destination to hold the info string
 * @param uLen the length of the sInfo buffer
 * @return the pointer sInfo
 * @memberof DasAry
 */
char* DasAry_toStr (const(DasAry)* pThis, char* sInfo, size_t uLen);

/** Get the total number of data values in an array, regardless of it's shape.
 *
 * @param pThis A constant pointer to this array structure
 * @returns The total number of items stored in the array, regardless
 *          of it's shape.
 * @memberof DasAry
 */
size_t DasAry_size (const(DasAry)* pThis);

/** Get the size in bytes of each element stored in the das array
 *
 * @param pThis The Array in question
 * @return The size of each element in bytes
 * @memberof DasAry
 */
size_t DasAry_valSize (const(DasAry)* pThis);

/** Return the current max value + 1 for any index
 *
 * This is a more general version of DasAry_shape that works for both cubic arrays
 * and those with ragged dimensions.  For any index to be inspected, the value
 * of all previous indices must be given.  This is less confusing then it sounds,
 * see the example below
 *
 * @see DasAry_shape For simple arrays that are only ragged in the first index.
 *
 * @param pThis A pointer to an array object
 *
 * @param nIdx The number of location indices, should be less than the rank
 *             in order to get the length of a range of values. The macros
 *             DIM0, DIM1_AT, DIM2_AT, etc. are provided which combine
 *             this argument and the one below to make calling code more
 *             readable, see the example below.
 *
 * @param pLoc  A list of the values for previous indices.  The macros DIM1,
 *              DIM2_AT, DIM3_AT etc. are provided which combine this argument
 *              with the one above to make calling code more readable, see the
 *              example below.
 *
 * @return The current maximum valid value for the <i>i<sup>th</sup></i>
 *         index at current location in the previous indices.
 *
 * @code
 *
 * // Here pWBR is a ragged array of all waveform amplitudes taken in a single
 * // capture.  Dimension 0 corresponds to the capture time point and dimension
 * // 1 corresponds to each sample in a capture.
 *
 * // Print the number of samples in each waveform.
 * size_t uWaveforms = DasAry_lengthIn(pWBR, DIM0);
 * for(size_t u = 0; u &lt; uWaveforms; ++u)
 *	   print("Capture %zu has %zu samples\n", u, DasAry_lengthIn(pWBR, DIM1_AT(u)));
 * @endcode
 *
 * @see DasAry_getAt to obtain both the length and a pointer to a continuous
 *      range of data values an once.
 * @memberof DasAry
 */
size_t DasAry_lengthIn (const(DasAry)* pThis, int nIdx, ptrdiff_t* pLoc);

/** Return current valid ranges for this array indices.
 *
 * @see DasAry_lengthIn
 *
 * @param pThis pointer to an array object
 *
 * @param[out] pShape pointer to an array to received the current number of
 *        entries in each dimension, should be at least RANK in length.  Each
 *        element of the output array will be one of the following.
 *
 *        * An integer from 0 to LONG_MAX to indicate a valid index range
 *
 *        * The value DASIDX_RAGGED to indicate that the valid index is variable
 *          and depends on the values of other indices.
 *
 * @returns The rank of the array.
 *
 * @memberof DasAry
 */
int DasAry_shape (const(DasAry)* pThis, ptrdiff_t* pShape);

/** Return the strides used for offest calculations.
 *
 * To support fast iteration over array data it's often useful to get a raw
 * pointer and then stride across the 1-D array using an index calculation.
 * Ragged arrays do not have a uniform stride, but many arrays are not
 * ragged and sub-sections of ragged arrays may not be ragged.  Use this
 * function to get the stride coefficents.
 *
 * @param pThis pointer to an array object
 *
 * @param[out] pShape The extent of the array in each index.  The total number
 *        of elements is just the multiple of all values in this array up to
 *        the rank.
 *
 * @param[out] pStride pointer to an array to recive the number of elements to
 *        increment for each successive value of this index.   Note that this
 *        is *not* the number of bytes to stride.  Use DasAry_valSize() to
 *        get the size of each element.
 *
 * @returns the rank of the array, or -1 if an input error is detected.
 *
 * @memberof DasAry
 */
int DasAry_stride (const(DasAry)* pThis, ptrdiff_t* pShape, ptrdiff_t* pStride);

/** Return the fill value for this array
 *
 * The caller is responsible for casting to the proper type
 */
const(ubyte)* DasAry_getFill (const(DasAry)* pThis);

/** Change the fill value for this array
 *
 * Set the fill value but don't re-write the data in the array.  Any data
 * locations in the array will still have the fill value.  To change them
 * iterate over the array looking for the old fill value an replace them in a
 * loop.
 *
 * @param pThis The array to structure to alter
 * @param pFill Pointer to the relpacement fill value, use NULL to set this
 *              to the connonical fill value for this type.
 * @param vt The element type for the new fill value.  This is used as a cross
 *        check.  The element type of the new fill value must match the old
 *        one.
 * @returns true if fill setting succeeded, false otherwise.
 * @memberof DasAry
 */
bool DasAry_setFill (DasAry* pThis, das_val_type vt, const(ubyte)* pFill);

/** Is a valid item located at a complete index
 *
 * @param pThis A pointer to the array
 *
 * @param pLoc  An array of indices of length RANK.  A rank 1 Das Array
 *              requires two indices to access an element, a rank 2 requires
 *              three, etc.  The macros LOC_1, LOC_2, etc have been provided
 *              to make code more readable.  See the example below.
 *
 * @returns true the location list refers to a valid array index set.  False
 *          otherwise.  Not that the actual value at the index may be a fill
 *          value.
 * @code
 * Array* pAry = new_Array("amplitudes", FLOAT, NULL, RANK_3(0, 160, 80));
 *
 * size_t uRec = 0;
 * // See if we have a complete MARSIS frame for this record...
 * if(! DasAry_validAt(pAry, IDX3(uRec, 159, 79)))
 *    fprintf(stderr, "Error: Short frame count in record %zu", uRec);
 * @endcode
 * @memberof DasAry
 */
bool DasAry_validAt (const(DasAry)* pThis, ptrdiff_t* pLoc);

/** Get a pointer to an element at a complete index
 *
 * For type safety the macros DasAry_getFloat, DasAry_getDouble, etc have been
 * provided and should be used instead of the base function here.
 *
 * @param pThis A pointer to the array
 *
 * @param et    The element type pointer expected at the given location, this
 *              is used by the type checking macros DasAry_getFloat and
 *              friends.
 *
 * @param pLoc  An array of indices of length RANK.  A rank 2 Das Array
 *              requires two indices to access an element, a rank 3 requires
 *              three, etc.  The macros IDX1, IDX2, IDX3, etc have been provided
 *              to make code more readable.  See the example below.
 *
 * @returns a pointer to value at the given indices, or NULL if that location
 *          is not valid and das_return_on_error() has been called.
 *
 * @code
 * // Uses type checking macro's
 * das_time_t dt = DasAry_getTimeAt(pAry, IDX1(uRec));
 *
 * // Get last event, whereever it is
 * const char* sEvent = DasAry_getTextAt(pAry, IDX1(-1));
 * @endcode
 *
 * @see DasAry_getIn to access multiple values at once avoiding function call
 *      overhead in tight loops.
 * @memberof DasAry
 */
const(ubyte)* DasAry_getAt (const(DasAry)* pThis, das_val_type et, ptrdiff_t* pLoc);

/** Wrapper around DasAry_get for IEEE-754 binary32 (float)
 * @memberof DasAry */
extern (D) auto DasAry_getFloatAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(float*) DasAry_getAt(pThis, das_val_type_e.vtFloat, pLoc));
}

/** Wrapper around DasAry_get for IEEE-754 binary64 (double)
 * @memberof DasAry */
extern (D) auto DasAry_getDoubleAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(double*) DasAry_getAt(pThis, das_val_type_e.vtDouble, pLoc));
}

/** Wrapper around DasAry_get for unsigned bytes
 * @memberof DasAry */
extern (D) auto DasAry_getByteAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(ubyte*) DasAry_getAt(pThis, das_val_type_e.vtByte, pLoc));
}

/** Wrapper around DasAry_get for unsigned 16-bit integers
 * @memberof DasAry */
extern (D) auto DasAry_getUShortAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(ushort*) DasAry_getAt(pThis, etUint16, pLoc));
}

/** Wrapper around DasAry_get for signed 16-bit integers
 * @memberof DasAry */
extern (D) auto DasAry_getShortAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(short*) DasAry_getAt(pThis, etInt16, pLoc));
}

/** Wrapper around DasAry_get for 32-bit integers
 * @memberof DasAry */
extern (D) auto DasAry_getIntAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(int*) DasAry_getAt(pThis, etInt32, pLoc));
}

/** Wrapper around DasAry_get for signed 64-bit integers
 * @memberof DasAry */
extern (D) auto DasAry_getLongAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(long*) DasAry_getAt(pThis, etInt64, pLoc));
}

/** Wrapper around DasAry_get for das_time_t structures
 * @memberof DasAry */
extern (D) auto DasAry_getTimeAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(das_time*) DasAry_getAt(pThis, das_val_type_e.vtTime, pLoc));
}

/** Wrapper around DasAry_get for  pointers to null-terminated strings
 * @memberof DasAry */
extern (D) auto DasAry_getTextAt(T0, T1)(auto ref T0 pThis, auto ref T1 pLoc)
{
    return *(cast(char**) DasAry_getAt(pThis, das_val_type_e.vtText, pLoc));
}

/** Set values starting at a complete index
 *
 * Note, this will not expand the size of the array.  Use the function
 * append() to automatically grow the array to store the desired number of
 * items.
 *
 * @param pThis A pointer to the array
 * @param pStart The complete index to the starting point to write values, use
 *        the macros IDX1, IDX2, etc. to make calling code more readable
 * @param pVals The values to write
 * @param uVals The number of values to write
 * @returns true if the items could be written, false if the array is not large
 *          enough to hold all the values or if any other error is encountered
 * @memberof DasAry
 */
bool DasAry_putAt (DasAry* pThis, ptrdiff_t* pStart, const(ubyte)* pVals, size_t uVals);

/** Get a pointer to the elements contained by a partial index
 *
 * @param pThis A Array containing the data of interest
 *
 * @param et The expected type of element to be returned.  This is used by the
 *        type safe macros DasAry_getDoubleAt, DasAry_getTextAt, etc.
 *
 * @param nDim The number of location indices, should be less than the rank
 *             in order to get the length of a range of values. The macros
 *              DIM0, DIM1_AT, DIM2_AT, etc. are provided which combine
 *              this argument and the one below to make calling code more
 *              readable, see the example below.
 *
 * @param pLoc An array of location indices, nDim long.  Use the macros
 *             DIM0, DIM1_AT, DIM2_AT, etc. for cleaner code.
 *
 * @param pCount A pointer to a variable to hold the number of elements under
 *        the given index.  If nIndices is equal to the array rank the returned
 *        value will be at most 1.
 *
 * @return A pointer a continuous subset of elements, or NULL if no elements are
 *         located at the given index set.  You will have to cast this pointer
 *         to the element type.
 *
 * @code
 * // Print all the events in an array
 * size_t uVals;
 * char** events = DasAry_getTextIn(pAry, DIM1, &uVals);
 * for(size_t u = 0; u < uVals; ++u)
 *    printf("Event %06zu: %s\n", u, events[u]);
 * @endcode
 *
 * @code
 * // Print all the magnetic amplitudes for a single time slice at index 117
 * size_t uVals;
 * float* pAmp = DasAry_getFloatsIn(pAry, DIM2_AT(117), &uVals);
 * for(size_t u = 0; u < uVals; ++u)
 *    printf("Amp at freq %03zu: %s nT**2/Hz \n", u, events[u]);
 *
 * @endcode
 * @memberof DasAry
 */
const(ubyte)* DasAry_getIn (
    const(DasAry)* pThis,
    das_val_type et,
    int nDim,
    ptrdiff_t* pLoc,
    size_t* pCount);

/** This is the writable pointer version of DasAry_getIn
 *
 * See the argument list form DasAry_getIn()
 * @return A raw byte pointer suitable for direct value insertion.  Not that
 *         the amount of space for writing is *pCount times the element size
 *         from DasAry_valSize().
 */
ubyte* DasAry_getBuf (
    DasAry* pThis,
    das_val_type et,
    int nDim,
    ptrdiff_t* pLoc,
    size_t* pCount);

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof Array */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */

/** Get a lower rank array that is a sub-set of the current array.
 *
 * For some given number of indices, produce a sub-array.  This is similar to
 * DasAry_getAt but produces a whole new Array object whose data are provided
 * stored in a separate Array.
 *
 * @code
 * // Get all data for the 10th record of a 2-D dataset, would often be a
 * // time slice for das2 streams.
 * Array* pRec = DasAry_subSetIn(pAllData, INDEX_0, 10);
 *
 * // Get the time delays for frequency index 100 for time point 22 of a
 * // MARSIS AIS data stream
 * Array* pDelays = DasAry_subSetIn(pAllData, "rec_22", DIM2_AT(22, 100));
 * @endcode
 *
 * @param pThis A pointer to the array to subset.  It is not a constant
 *              pointer due to the need to increment the reference count.
 *
 * @param id A identifying name for the new sub-array
 *
 * @param nIndices The number of location indices, should be less than the rank
 *               in order to get a range of values. Use the macros DIM0,
 *               DIM1_AT, DIM2_AT, etc. for cleaner code.
 *
 * @param pLoc An array of location indices, nIndices long.  Use the macros
 *             DIM0, DIM1_AT, DIM2_AT, etc. for cleaner code.
 *
 * @return A new Array allocated on the heap that does not own it's backing
 *         buffer.
 *
 * @memberof DasAry
 */
DasAry* DasAry_subSetIn (
    DasAry* pThis,
    const(char)* id,
    int nIndices,
    ptrdiff_t* pLoc);

/** Use fill values to make sure the last subset in a dimension is a QUBE
 *
 * @param pThis the array
 *
 * @param iRecDim The dimension to qube, typically the last dimension in the
 *        array, dimensions are numbered starting from 0.  Use the macro's DIM1,
 *        DIM2, etc. to make the code more readable.  Dimension 0 can't be
 *        marked as ended and the macro DIM0 will not work here.
 *
 * @returns the number of fill values added to the array
 *
 * @code
 * Array* pAry = new_Array("marsis", etFloat, 0, NULL, RANK_3(0, 160, 80));
 *
 * //Example 1: Read a complete sets of delay times
 * float buf[80];
 * size_t uRead = fread(buf, sizeof(float), 80, stdin);
 * DasAry_append(pAry, buf, uRead);
 * DasAry_qubeIn(pAry, DIM2);
 *
 * //Example 2: Read in complete ionograms
 * float buf[160*80];
 * size_t uRead = fread(buf, sizeof(float), 80*160, stdin);
 * DasAry_append(pAry, buf, uRead);
 * DasAry_qubeIn(pAry, DIM1);
 *
 * @endcode
 *
 * @see DasAry_append
 * @memberof DasAry
 */
size_t DasAry_qubeIn (DasAry* pThis, int iRecDim);

/** Append some number of items to the end of the array.
 * This works as you would expect for all arrays that are only ragged in the
 * 0th dimension.
 *
 * @see DasAry_markEnd.  Arrays that are ragged in dimension other that the 0th
 * need some way to know that it's time to roll the index back to 0 on the next
 * append operation, DasAry_markEnd sets the needed flags.
 *
 * @param pThis The array which should copy in the new values.
 * @param pVals A constant pointer to values to add
 * @param uCount The number of values to add
 * @returns true if uCount items were appended to the array, false otherwise
 *
 * @memberof DasAry
 */
bool DasAry_append (DasAry* pThis, const(ubyte)* pVals, size_t uCount);

/** Mark a ragged dimension as finished
 *
 * @param pThis The das array
 *
 * @param iDim The dimension which should have it's index rolled back to zero
 *              on the next insert.  Marking the end of a low index (say 1)
 *              automatically marks the end of any higher indices (ex 2,3).
 * @code
 * // Read in lines of text into an array that stores data by page number,
 * // line number and the byte number.  Input processing is simplistic in
 * // order to focus on Array calls.
 *
 * byte fill = 0;
 * Array* pAry = new_Array("source", etByte, 0, &fill, RANK_3(0,0,0));
 * char sBuf[1024] = {'\0'};
 * size_t uLen = 0;
 * while(!eof(stdin)){
 *    while(fgets(sBuf, 1024, stdin)){
 *       uLen = strlen(sBuf);
 *       if(sBuf[0] == 0x0C) DasAry_markEnd(pAry, DIM1);        // end page
 *	      DasAry_append(pAry, sBuf, uLen+1);        // keep NULL terminators
 *	      if(sBuf[uLen - 1] == '\n') DasAry_markEnd(pAry, DIM2); // end line
 *    }
 * }
 * @endcode
 * @memberof DasAry
 */
void DasAry_markEnd (DasAry* pThis, int iDim);

/* Remove some number of records in a given index.
 *
 * This does not actually delete any data it just removes references to it.
 * Thus any subsets of this array will still reference the existing values.
 *
 * @see rmLastRec() for the definition of a record
 */
/* size_t DasAry_rmHead(Array* pThis, size_t uCount, int nIndex);*/

/* Remove N records from the end of the array
 *
 * For rank 1 arrays, a 'record' is just a single value, for higher rank
 * arrays a record is the number of values represented by a change in the
 * first index.  For example, for the array:
 * @code
 *    a[][10][4]
 * @endcode
 * calling
 * @code
 *   rmTail(pArray, 2)
 * @endcode
 * will result in 80 individual values being remove from the array.
 *
 * @param pThis the array to change
 * @param uRecs the number of records to remove.  If uRecs is greater than
 *        the shape of the first index, everything is removed and an error
 *        is thrown.
 * @returns The new size of the array
 * @memberof DasAry
 */
/* size_t DasAry_rmTail(Array* pThis, size_t uRecs); */

/** Clear all values from the array
 *
 * This operation internally just resets the count of items to 0 in all
 * arrays it does not free memory.
 * Dimensions above the 0th retain their shape.
 *
 * @param pThis The array to clear
 * @returns then number of items cleared
 * @memberof DasAry
 */
size_t DasAry_clear (DasAry* pThis);

/** Compare two items of the type in the array.
 *
 * @returns A value less than zero if *pFirst is less than *pSecond, a
 *  value greater than zero if *pFirst is greater than *pSecond and 0 if
 *  both values are equal
 *
 *  @memberof DasAry
 */
int DasAry_cmp (DasAry* pThis, const(ubyte)* vpFirst, const(ubyte)* vpSecond);

/** Record which packets contain data destine for this array
 *
 * @param pThis The array
 * @param nPktId The id of the Das packet which contains values that should be
 *               added to this array
 * @param uStartItem The location in the packet where this array's data starts
 *
 * @param uItems The number of items to add from each packet
 * @memberof DasAry
 */
void DasAry_setSrc (DasAry* pThis, int nPktId, size_t uStartItem, size_t uItems);

/* _das_array_h_ */
