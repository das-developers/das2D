module das2.array;

import std.string;

alias byte = uint8_t;

enum element_type {
	etUnknown = 0,	etIndex, etByte, etUShort, etShort,	etInt, etLong,
	etFloat, etDouble, etTime,	etText
};

const void* et_fill(element_type et);
size_t et_size(element_type et);
const char* et_name(element_type et);


struct child_info_t{
	ptrdiff_t uOffset;
	size_t uCount;
}

alias index_info = child_info_t;

struct dyna_buf{
	byte* pBuf;
	byte* pHead;
	/*byte* pWrite;*/
	size_t uSize;
	size_t uValid;
	size_t uElemSz;
	byte* pFill;
	byte [index_info.sizeof] fillBuf;

	size_t uChunkSz;
	size_t uShape;
	element_type etype;

	bool bRollParent;

	bool bKeepMem;
}

alias DynaBuf = dyna_buf;

struct das_array {
	char[64]      sId;
	int           nRank;
	index_info*   pIdx0;

	/* bool      bTopOwned;*/   /* Same as pIdx0 == &index0 */
	index_info   index0;   /* Storage for element 0 of buffer 0, if needed */

	DynaBuf*[16] pBufs;

	DynaBuf [16] bufs;    /* Storage for dynamic buffers, if needed */

	//int (*compare)(const void* vpFirst, const void* vpSecond);
	int function(const void* vpFirst, const void* vpSecond) compare;

	int nSrcPktId;
	size_t uStartItem;
	size_t uItems;

};

private extern (C) void del_DasAry(DasAry* pThis);

private extern (C) byte* DasAry_disownElements(DasAry* pThis, size_t* pLen);

private extern (C) const char* DasAry_id(const DasAry* pThis);

private extern (C) enum element_type DasAry_elementType(const DasAry* pThis);

private extern (C) const char* DasAry_type(const DasAry* pThis);

private extern (C) char* DasAry_info(const DasAry* pThis, char* sInfo, size_t uLen);

private extern (C) size_t DasAry_size(const DasAry* pThis);

private extern (C) size_t DasAry_elemSize(const DasAry* pThis);

private extern (C) size_t DasAry_lengthIn(const DasAry* pThis, int nDim, ptrdiff_t* pLoc);

private extern (C) int DasAry_shape(const DasAry* pThis, size_t* pShape);

private extern (C) bool DasAry_validAt(const DasAry* pThis, ptrdiff_t* pLoc);

private extern (C) const void* DasAry_getAt(const DasAry* pThis, element_type et, ptrdiff_t* pLoc);


private extern (C) bool DasAry_putAt(
	DasAry* pThis, ptrdiff_t* pStart, const void* pVals, size_t uVals
);

private extern (C) const void* DasAry_getIn(
	const DasAry* pThis, element_type et, int nDim, ptrdiff_t* pLoc, size_t* pCount
);

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getFloatsIn(T, ...) (const float*) DasAry_getIn(T, etFloat, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getDoublesIn(T, ...) (const double*) DasAry_getIn(T, etDouble, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getBytesIn(T, ...) (const byte*) DasAry_getIn(T, etByte, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getUShortsIn(T, ...) (const uint16_t*) DasAry_getIn(T, etUShort, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getShortsIn(T, ...) (const int16_t*) DasAry_getIn(T, etShort, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getIntsIn(T, ...) (const int32_t*) DasAry_getIn(T, etInt, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getLongsIn(T, ...) (const int64_t*) DasAry_getIn(T, etLong, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getTimesIn(T, ...) (const das_time_t*) DasAry_getIn(T, etTime, __VA_ARGS__)

/** A wrapper around DasAry_getIn that casts the output and preforms type checking
 * @memberof DasAry */
//#define DasAry_getTextIn(T, ...) (const char**) DasAry_getIn(T, etText, __VA_ARGS__)

private extern (C) DasAry* DasAry_subSetIn(
	const DasAry* pThis, const char* id, int nIndices, ptrdiff_t* pLoc
);

private extern (C) size_t DasAry_qubeIn(DasAry* pThis, int iRecDim);

private extern (C) bool DasAry_append(DasAry* pThis, const void* pVals, size_t uCount);

private extern (C) void DasAry_markEnd(DasAry* pThis, int iDim);

private extern (C) size_t DasAry_clear(DasAry* pThis);

private extern (C) int DasAry_cmp(DasAry* pThis, const void* vpFirst, const void* vpSecond );

private extern (C) void DasAry_setSrc(DasAry* pThis, int nPktId, size_t uStartItem, size_t uItems);


/** Wrapper Class for DasAry structures and functions */
class DasAry
{
	private:
		das_array* m_pDa;

	public:
		this(das_array* pDa){ 
			m_pDa = pDa;
		}

		~this(){
			DasAry_del(m_pDa); 
		}

		string id() const {
			return to!string( DasAry_id(m_pDa) );
		}

		int rank() const {
			return DasAry_rank(m_pDa);
		}

		enum element_type elementType() {
			return DasAry_elementType(m_pDa);
		}

		string type()const {
			return to!string(DasAry_type(m_pDa));
		}

		override string toString() const {
			char[64] sInfo;
			return to!string(DasAry_info(m_pDa, sInfo.ptr, sInfo.length - 1));
		}

		size_t size(){ return DasAry_size(m_pDa); }

		size_t elemSize(){ return DasAry_elemSize(m_pDa); };

		size_t lengthIn(ptrdiff_t[] aLoc)
		{
			return DasAry_lengthIn(m_pDa, loc.length, aLoc.ptr);
		}

		size_t[] shape(){
			size_t[] aShape;
			aShape.length = m_pDa.nRank;
			DasAry_shape(m_pDa, aShape.ptr);
			return aShape;
		}

		bool validAt(ptrdiff_t[] aLoc){
			if(aLoc.length == m_pDa.nRank){
				das2_error(DAS2ERR_ARRAY, "Length of array aLoc is not equal to "~
							  "the array's rank.");
				return false;
			}
			return DasAry_validAt(m_pDa, aLoc.ptr);
		}
		/** Wrapper around DasAry_get for IEEE-754 binary32 (float)
 * @memberof DasAry */
//#define DasAry_getFloatAt(pThis, pLoc)  *((float*)(DasAry_getAt(pThis, etFloat, pLoc)))
/** Wrapper around DasAry_get for IEEE-754 binary64 (double)
 * @memberof DasAry */
//#define DasAry_getDoubleAt(pThis, pLoc)  *((double*)(DasAry_getAt(pThis, etDouble, pLoc)))
/** Wrapper around DasAry_get for unsigned bytes
 * @memberof DasAry */
//#define DasAry_getByteAt(pThis, pLoc)  *((byte*)(DasAry_getAt(pThis, etByte, pLoc)))
/** Wrapper around DasAry_get for unsigned 16-bit integers
 * @memberof DasAry */
//#define DasAry_getUShortAt(pThis, pLoc)  *((uint16_t*)(DasAry_getAt(pThis, etUint16, pLoc)))
/** Wrapper around DasAry_get for signed 16-bit integers
 * @memberof DasAry */
//#define DasAry_getShortAt(pThis, pLoc)  *((int16_t*)(DasAry_getAt(pThis, etInt16, pLoc)))
/** Wrapper around DasAry_get for 32-bit integers
 * @memberof DasAry */
//#define DasAry_getIntAt(pThis, pLoc)  *((int32_t*)(DasAry_getAt(pThis, etInt32, pLoc)))
/** Wrapper around DasAry_get for signed 64-bit integers
 * @memberof DasAry */
//#define DasAry_getLongAt(pThis, pLoc)  *((int64_t*)(DasAry_getAt(pThis, etInt64, pLoc)))
/** Wrapper around DasAry_get for das_time_t structures
 * @memberof DasAry */
//#define DasAry_getTimeAt(pThis, pLoc)  *((das_time_t*)(DasAry_getAt(pThis, etTime, pLoc)))
/** Wrapper around DasAry_get for  pointers to null-terminated strings
 * @memberof DasAry */
//#define DasAry_getTextAt(pThis, pLoc)  *((char**)(DasAry_getAt(pThis, etText, pLoc)))

		/* D note, the slice operator turns a pointer into a slice ! */

		private extern (C) const void* DasAry_getAt(const DasAry* pThis, element_type et, ptrdiff_t* pLoc);

//		getAt(element_type et, ptrdiff_t* pLoc)


		size_t clear();
};


