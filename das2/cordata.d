module das2.cordata;

import std.stdio, std.string, std.conv;
import das2.util, das2.log, das2.builder;

enum element_type {
	etUnknown = 0,  etIndex, etByte, etUShort, etShort, etInt, etLong,
	etFloat, etDouble, etTime,  etText
};

/** Object for holding a correlated set of datum generators and any backing
 * array storage */
struct cordata;
alias Cds = cordata;

private extern (C) int Cds_rank(Cds* pThis);

private extern (C) void del_Cds(Cds* pThis);

private extern (C) size_t Cds_shape(Cds* pThis, int* outAry);

private extern (C) size_t Cds_shapeOf(
	Cds* pThis, const char* sSetName, size_t* outAry
);

/** Get the dataset ids */
private extern (C) size_t Cds_datasetIds(Cds* pThis, const char** pOutAry);

private extern (C) size_t Cds_coordIds(Cds* pThis, const char** pOutAry);

private extern (C) size_t Cds_coordsOf(Cds* pThis, const char* dataset, const char** pOutAry);

private extern (C) bool Cds_orthogonal(Cds* pThis, const char* datasetA, const char* datasetB);

private extern (C) void* Cds_slice1D( 
	const Cds* pThis, const char* sDs, const char* sCoord, int iCoordIdx, int*pCoeff
);
  
private extern (C) void Cds_releaseArrays(Cds* pThis);

private extern (C) void Cds_write(Cds* pThis);

/** A CdsRange is a Random Access Range returned by Cds.slice().
 * 		It can be treated just like a traditional D slice.
 *
 *  CdsRanges are slices of a Cds that may not be a contiguous 
 *  block of memory. The variable sliceCoef holds the length,
 *  stride and offset that are used in the necessary Random 
 *  Access Range functions. 
*/
struct CdsRange(T){
	
	this(int[3] inSliceCoef, void* inDataBegin){
		sliceCoef = inSliceCoef;	
		dataBegin = cast(T*)inDataBegin;
		data[] = dataBegin[inSliceCoef[2] .. 
					(inSliceCoef[0] - 1) * inSliceCoef[1] + inSliceCoef[2] + 1];
	}

	private T* dataBegin;

	private T[] data;
	
	private int[3] sliceCoef; // ( length, stride, offset)

	@property bool empty() const {
		return sliceCoef[0] == 0;
	}

	@property size_t length() const {
		return sliceCoef[0];		
	}

	@property ref T front() {
	   return data[sliceCoef[2]];	
	}

	@property ref T back(){
		return data[ (sliceCoef[0] - 1) * sliceCoef[1] + sliceCoef[2]];
	}

	@property CdsRange save() {
		return this;	
	}

	void popFront(){
		data[] = data[sliceCoef[1] + sliceCoef[2] .. 
						(sliceCoef[0] - 1) * sliceCoef[1] + sliceCoef[2] + 1];
		--sliceCoef[0];
	}

	void popBack(){
		data[] = data[sliceCoef[2] ..
					(sliceCoef[0] -	2) * sliceCoef[1] + sliceCoef[2] + 1];
		--sliceCoef[0];
	}

	T opIndex(size_t index) const{
		immutable intVal = cast(int)index;
		assert(intVal >= 0 && intVal < sliceCoef[0]);
		return data[intVal*sliceCoef[1] + sliceCoef[2]];
	}
}


class Cds{

private:

	Cds* m_pCds;
	int m_nRank;

	string[] m_datasets;

	string[] m_coordinates; // All coordinates of all datasets in the Cds
	string[][string] m_coordsOfDict; // Associative array to get coordinates of a 
									 // specific dataset
	
	int[] m_shape; 
	int[][string] m_shapeOfDict; // Defined similar to m_coordsOfDict


	this(Cds* pCds){
		m_pCds = pCds;  //check is non-null
		m_nRank = Cds_rank(m_pCds);
	}

public:	
	~this(){ 
		del_Cds(m_pCds); 
	}

	/** Provides a list of dataset IDs.
	 * @return array of strings
	 */
	string[] datasets() @property {
		if(m_datasets.length ==  0){
			char*[] aDs = new char*[m_nRank];
			size_t uSets = Cds_datasets(m_pCds, aDs.ptr);
			m_datasets = new string[uSets];
			foreach(int i; 0 .. m_nRank){
				m_datasets[i] = to!string(aDs[i]);
			}
		}
		return m_datasets;
	}

	/** Provides a list of coordinates.
	 * @return array of strings
	*/
	string[] coordinates() @property {
		if(m_coordinates.length == 0){ 
			char*[] aCoord;
			size_t uCoords = Cds_coords(m_pCds, aCoord.ptr);		
			m_coordinates = new string[uCoords];
			foreach(ulong i; 0 .. uCoords){
				m_coordinates[i] = to!string(aCoord[i]);
			}
		}
		return m_coordinates;	
	}

	/**	Provides a list of coordinates for a given dataset ID. 
	 * @param dataset the string ID of a dataset.
	 * @return array of strings
	*/
	string[] coordinatesOf(string dataset){
		if(m_coordsOfDict[dataset].length == 0){
			char*[] aCoord;
			size_t uCoords = Cds_coordsOf(m_pCds, toStringz(dataset), aCoord.ptr);	
			m_coordsOfDict[dataset] = new string[uCoords];
			foreach(ulong i; 0 .. uCoords){
				m_coordsOfDict[dataset][i] = to!string(aCoord[i]);
			}
		}
		return m_coordsOfDict[dataset];
	}

	/**	Provides valid ranges for whole dataset iteration 
	*/
	int[] shape() @property {
		if(m_shape.length == 0){ 
			int[] aShape;
			size_t uShape = Cds_shape(m_pCds, aShape.ptr);		
			m_shape = new int[uShape];
			foreach(ulong i; 0 .. uShape){
				m_shape[i] = to!int(aShape[i]);
			}
		}
		return m_shape;	
	}

	/** Provides valid ranges for iteration over a specific dataset
	 * @param dataset the dataset of interest
	 * @return The array ranges for iteration over dataset.
	 */
	int[] shapeOf(string dataset){
		if(m_shapeOfDict[dataset].length == 0){
			int[] aShape;
			size_t uSets = Cds_shapeOf(m_pCds, toStringz(dataset), aShape.ptr);
			foreach(ulong i; 0 .. uSets){
				m_shapeOfDict[dataset][i] =	aShape[i]; 	
			}
		}
		return m_shapeOfDict[dataset];
	}


	/** Determine if a set of coordinates are orthogonal.
	 *
	 * Two coordinates are orthogonal if a change in the value of 
	 * 		one coordinate is in no way related to a change in the
	 *		other coordinate.
	 * 
	 * @param coordinates an array of coordinates
	 * @return True if each combination of two coordinates in
				the input array are orthogonal. 
 	*/	
	bool isOrthogonal(string[] coordinates){
		foreach(ulong i; 0  .. coordinates.length - 1){
			foreach(ulong j; i .. coordinates.length - 1){
				if( i == j || Cds_orthogonal(m_pCds, toStringz(coordinates[i]), toStringz(coordinates[j]))) continue;
				else return false;
			}
		}		
		return true; 
	}

	/** Returns a CdsRange (RandomAccessRange) of values.
	 * @param dataset The string ID of the dataset to be sliced.
	 * @param coordinate The string ID of the coordinate to be sliced.
	 * @param index The index to slice at.
	 * @return CdsRange The range of values.
	*/
	CdsRange!T slice(T)(string dataset, string coordinate, int index) {
			
		int[3] coefficients = new int[3];
		void* dataBegin = Cds_slice1D(
			m_pCds, toStringz(dataset), toStringz(coordinate), index, coefficients.ptr
		);	
		return *(new CdsRange!T(coefficients, cast(T*)dataBegin));
	}
}


/** Get an array of correlated datasets from a Das2 stream on standard input
 * @param sProgName the name of the program calling this function, suded for 
 *        error reporting.
 * @return An array of correlated dataset objects.  The array may have no
 *         members if there was an error reading standard input or if the
 *         standard input was not a Das2 stream
 */
Cds[] buildFromDas2Stdin(string sProgName)
{
	Cds[] lCds;
	// Just use the libdas2 function to get everything.  For now we will just
	// assume that the supplied data are all that were available for a three
	// day period
	size_t uSets;
	cordata** lRawCds = build_from_stdin(toStringz(sProgName), &uSets);
	if(uSets == 0) dasInfo("No datasets present in the input");

	lCds.length = uSets;
	foreach(ulong i; 0 .. uSets)
		lCds[i] = new Cds(lRawCds[i]);	

	return lCds;
}
