/** 
This module collects algoriths from various das2 programs that are more or
less generally useful instead of duplicating these in multiple projects.

The primary item defined is a `data range`.  This is the same as a regular
range, but the .front function always returns a tuple or structure with at
least the items:

  .data = The "payload" for the element.  If a regular InputRange has
          been wrapped in a DataRange, this is the .front value from
			 the original range.

  .cbeg = The minimum position of a data element in coordinate space,
          Think of this as the bin minimum in other respects

  .cend = The maximum position of a data element in coordinate space
          Think of this as the bin maximum.
			
It is okay for .cbeg = .cend

Building on DataRanges are PriorityRanges.  In addition to data and 
coordinates, the elements of this range will also have a:

  .priority
 
item in the output from a .front call.  The priority states how important
data from this range compared to similar ranges.  Priority ranges are used
in select-or-drop algorithms that merge multiple input streams into a single
output stream.
*/

module das2.range;

import std.algorithm;
import std.range;
import std.stdio;
import std.traits;

/**
Returns `true` if `R` is a data range.  Data ranges are just input ranges
that also supply a orderable coordinate value for each front value.  A
data range must define the primatives `empty`, `popFront`, `front` and
`coord`.  The following code should compile for any data range.

---
static assert(isInputRange!R)

auto d = r.front.data; // can get the data value of the element
auto b = r.front.cbeg;  // can get the beginning coordinate point
auto e = r.front.cend;  // can get the ending coordinate point

// Begin and end are same types
static assert(is( typeof(r.front.cbeg) == typeof(r.front.cend) ));

// Comparison operators can be used
static assert( isOrderingComparable!typeof(r.front.cbeg) );
static assert( isOrderingComparable!typeof(r.front.cend) );
---

In addition the following runtime check should not throw an error
---
enforce(r.front.cbeg <= r.front.cend);
---

The name "DataRange" may be a bit presumptuous as there are many types
data ranges that could not meet this definition, such as a stream of
population sizes by tagged by city name.  However, for the vast majority
of data streams encountered in das2 work, this definition applies.

This definition was selected instead of defining a basic element type
so that coordinates could be "glued on" for any standard range output.

Params:
	R = type to be tested
	
Returns:
	`true` if R is a data range, `false` if not.
*/
enum bool isDataRange(R) = isInputRange!R
	&& is(typeof((return ref R r) => r.front.cbeg))
	&& !is(ReturnType!((R r) => r.front.cbeg) == void)
	&& is(typeof((return ref R r) => r.front.cend))
	&& !is(ReturnType!((R r) => r.front.cend) == void);

/**
The coordinate of type `R`.  `R` does not have to be a range.  The coordinate
type is determined as the type yielded by `r.front.cbeg` for an object
`r` of type `R`. If `R` doesn't have `front`, `CoordType!R` is `void`.
*/
template CoordType(R)
{
	static if ( 
		is(typeof(R.init.front.cbeg.init) T)
		&& is(typeof(R.init.front.cend.init) T)
		&& is(typeof(R.init.front.cbeg.init) == typeof(R.init.front.cend.init))
	)
		alias CoordType = T;
	else
		alias CoordType = void;
}


/** Allows coordinate generating functions to be attached to an input range.
 * 
 * This is the structure created by [dataRange]
 */
 

struct DataElement(
	RT, CBegF, CEndF
){
	const ElementType!RT data;
	const ReturnType!CBegF cbeg;
	const ReturnType!CEndF cend;
}
 
struct DataRange(
	RT, CBegF, CEndF, DT=const ElementType!RT, CT=const ReturnType!CBegF
){
private:
	RT range;
	CT function(DT) getCBeg;  // Member function
	CT function(DT) getCEnd;  // Member function
public:
	this(RT range, CT function(DT) getCBeg, CT function(DT) getCEnd)
	{
		this.range = range;
		this.getCBeg = getCBeg;
		this.getCEnd = getCEnd;
	}
	@property bool empty() const {return range.empty; }
	@property DataElement!(RT, CBegF, CEndF) front() const {
		return DataElement!(RT, CBegF, CEndF)(
			range.front,
			getCBeg(range.front),
			getCEnd(range.front)
		);
	}
	
	void popFront(){ range.popFront(); }
	
	// Add save function for forward range
	static if(isForwardRange!RT){
		@property DataRange!(RT, CBegF, CEndF) save() {
			return DataRange!(RT, CBegF, CEndF)(
				range.save, getCBeg, getCEnd
			);
		}
	}
	
	// Add back, popBack for bidirectional range
	static if(isBidirectionalRange!RT){
		@property DataElement!(RT, CBegF, CEndF) back() const {
			return DataElement!(RT, CBegF, CEndF)(
				range.back,
				getCBeg(range.back),
				getCEnd(range.back)
			);
		}
		
		void popBack(){ range.popBack(); }
	}
	
	
	// Add index for random access range
	static if(isRandomAccessRange!RT){
		DataElement!(RT, CBegF, CEndF) opIndex(size_t index) const {
			return DataElement!(RT, CBegF, CEndF)(
				range[index],
				getCBeg(range[index]),
				getCEnd(range[index])
			);
		}
	}
	
	static if(hasLength!RT){
		@property size_t length() const { return range.length; }
	}
	
}

/******************************************************************************
 * Adaptor for converting input ranges into data ranges
 *
 * Template:
 *  * RT = The type of range to wrap
 *  * CBegF = Function for producing coordinate minimum from each element of RT
 *  * CEndF = Function for producing coordinate maximum from each element of RT 
 *
 * Params:
 *    range = The InputRange to wrap as a DataRange
 *    fBeg  = Function that extracts the beginning coordinate for
 *            each data element from range.front
 *    fEnd  = Function that extracts the ending 
 */
DataRange!(RT, CBegF, CEndF) dataRange(RT, CBegF, CEndF)(
	RT range, CBegF fBeg, CEndF fEnd
){
	return DataRange!(RT, CBegF, CEndF)(range, fBeg, fEnd);
}

///
unittest
{
	double[][] packets = [ 
		[10.0, 13.0 ], [20, 14.0], [30, 17.0], [40, 15.0]
	];
	
	// Provide rules for digging coordinates out of the packets 
	auto dr = packets.dataRange(
		(const double[] el) => el[0] - 2.0, (const double[] el) => el[0] + 2.0
	);

	static assert( isInputRange!(typeof(dr)));
	static assert( isDataRange!(typeof(dr)));
	static assert( isForwardRange!(typeof(dr)));
	static assert( isBidirectionalRange!(typeof(dr)));
	static assert( isRandomAccessRange!(typeof(dr)));
	
	auto aDr = dr.save;
	
	foreach(el; dr){
		writeln("Coord: [", el.cbeg, ", ", el.cend, ")  Data: ", el.data);
	}
	
	assert(aDr[3].cbeg == 38.0);
	assert(aDr[3].cend == 42.0);
	assert(aDr[3].data == [40.0, 15.0]);
}


// NOTE: "///" is an obtuse was to say add this unittest as an example to the
// previous item. 

/**
Returns `true` if `R` is a priority range.  Priority ranges are just data
ranges that also supply the priority of the current data item, *and* produce
Monotonic data.

In addition to the operations for data ranges, the following code should
compile for all priority ranges.

---
static assert( isDataRange!R);

auto p = r.priority; // can get the priority value of the front object.
---

A priority range must be monotonic increasing, so the following run-time
check should always succeed.
---
auto last = r.cbeg;
r.popFront();
for(auto cur = r.cbeg; !r.empty; r.popFront()){
	enforce(cur >= last);
	last = cur;
}
---

Params:
	R = type to be tested
	
Returns:
	`true` if R is a priority range, `false` if not.
*/
enum bool isPriorityRange(R) = isDataRange!R
	&& is(typeof((return ref R r) => r.priority))
	&& !is(ReturnType!((R r) => r.cbeg) == void);


/***************************************************************************
 * Adaptor for converting data ranges into priority ranges
 *
 * Params:
 *   RT = The type of range to wrap
 *   CT = The coordinate type produced by the range
 *   DT = The data type produced by the range (same as ElementType)
 */
//struct PriorityRange(RT, CT, DT) {
//	RT range;
//	CT spread;
//	int priority; // automatically a property
//	
//	/** Construct a priority range from a standard input range.
//	 * Params:
//	 *   range = An InputRange object whose elements are comparable via
//	 *       the "<" operator.
//	 * 
//	 *   spread = Increase the "owned" coordinate area by this amount. In the
//	 *       PriorityFilter algorithm, lower priority points that overlap 
//	 *       higher priority points are dropped from the output stream.  In
//	 *       order to determin overlap, each point must be spread out in
//	 *       coordinate space.  The min and max values for each front record
//	 *       will be dermined by:
//	 *       '''
//	 *       min = front - spread;
//	 *       max = front + spread;
//	 *       ''' 
//	 *
//	 *   priority = An integer rating of the priority, higer values take
//	 *       precidence over lower values.
//	 */
//	this(RT range, int priority, CT spread){
//		this.range    = range;
//		this.spread   = spread;
//		this.priority = priority;
//	}
//
//	/** Determine if calling popFront will provide any new elements.
//	 * Standard InputRange property. */	
//	@property bool empty() const { return range.empty(); }
//	
//	/** Get the front element of the range
//	 * Standard InputRange property
//	 */
//	@property DT front() const   { return range.front; }
//	
//	/** The lower bound of the owned coordinate space for the front record.
//	 * This is a standard ProrityRange property which is equal to:
//	 * ```
//	 * front - spread
//	 * ```
//	 */
//	@property CT min() const     { return range.front - spread; }
//	
//	/** The upper bound of the owned coordinate space for the front record.
//	 * This is a standard ProrityRange property which is equal to:
//	 * ```
//	 * front + spread
//	 * ```
//	 */	
//	@property CT max() const     { return range.front + spread; }
//	
//	/** Mave the next element of the range into the .front property
//	 * Standard InputRange function */
//	void popFront(){ range.popFront(); }
//}
//
///** Convenience for adapting InputRanges to PriorityRanges  
// *
// * See the documentation for the PriorityRange constructor.
// * '''
// * auto stream1 = iota(100.0, 400.0, 10.0).priorityRange(1, 5.0);
// * auto stream2 = iota(100.0, 400.0, 20.0).priorityRange(2, 10.0);
// * '''
// */
//PriorityRange!(RT, ET) priority(RT, ET = ElementType!RT)(
//	RT range, int priority, ET spread
//){
//	return PriorityRange!(RT, ET)(range, priority, spread);
//}
//
//unittest
//{
//	double[][] packets = [ 
//		[10.0, 13.0 ], [20, 14.0], [30, 17.0], [40, 15.0]
//	];
//	
//	
//	file.byline.dataRange().priorityRange(5);
//	
//	// Create a priority range by wrapping the array in data range
//	// and then wrapping the data range as a priority range, with a fixed
//	// priority value of 5.
//		
//	auto pr = packets
//		.coordinates!(el => el[0] - 2.0, el => el[0] + 2.0)
//		.priority(5);
//
//	pr.popFront();
//	
//	auto tEl = pr.front;
//	
//	assert((tEl.cbeg == 108.0)&&(tEl.cend == 112.0), "Algorithm test 1 failed");
//	assert(tEl.priority == 5, "Algorithm test 2 failed"); 
//	assert(tEl.data = [20, 14.0]);
//}

/******************************************************************************
 * Prority 1-D Coordinate range multiplexer
 *
 * Produces a Montonically increasing output stream of records from 1-N 
 * montonically increasing input ranges. 
 *
 * The output type of the range is the same as the output type of the given
 * input ranges, which must all be the same.  The basic concept is that each
 * input record occupies an "owned width" in some coordinate (typically time)
 * and has some priority rating.  When records overlap in coordinate space 
 * the highest priority one is emitted, and the others are dropped.
 *
 * This is useful for measurement data that are provided at various
 * resolutions, or from various similar sensors, and the highest resolution
 * or most accurate sensor should be output.  Typically only one input stream
 * has data at any given coordinate point... but not alwoys, so a priority
 * scheme is used to handle the edge cases.
 *
 * Other ways to handle multiple overlapping data sources would be to average
 * measurements together in some space.
 *
 * Params:
 *   RT = The type of the input priority range array
 *   CT = The coordinate type producted by the PriorityRanges
 *   DT = The data type (ElementType) produced by the PriorityRanges
 */
//struct PriorityFilter(RT, CT, DT)
//{
//private:
//	RT[] _ranges;  // slice of priority range objects
//	long _iReady;	// If > 0, range that will provide the next value
//	
//	// Pick an internal range object to go next, pop items to be skipped.
//	void getReady(){
//		_ranges = _ranges.filter!(rng => !rng.empty).array();
//		
//		_ranges = _ranges.sort!((rngA, rngB) => rngA.priority < rngB.priority).array();
//				
//		if(_ranges.length == 0) return;
//				
//		_iReady = _ranges.minIndex!((a, b) => a.min < b.min);
//		
//		// Assume ranges are sorted from lowest priority to highest
//		for(long i = _iReady+1; i < _ranges.length; ++i){
//		
//			// don't overlap with higher priority items
//			if(_ranges[i].min < _ranges[_iReady].max){
//			
//				_ranges[_iReady].popFront(); // Okay if empty afterwords
//				++_iReady;
//			}
//		}
//	}
//	
//public:
//	this(RT[] ranges){
//		this._ranges = ranges;
//		getReady();
//	}
//	
//	@property bool empty(){
//		// When the input ranges can no longer supply data, they are 
//		// rm'ed from the slice.
//		return (_ranges.length == 0);
//	}
//		
//   /** Ready the next element at the front.
//	 *
//	 * If the min value of a higher priority point overlaps with this
//    * point, pop it out and switch over to the higher priority item.
//    * This can create a stair step chain like so:
//	 * ```
//    *               
//    *               ^
//    *               |                   +----+----+
//    * Priority N    |                min|    |pt  |max
//    *               |                   +----+----+
//    *               |
//    *               |           +----+-----+
//    * Priority N-1  |        min|    |pt   |max
//    *               |           +----+-----+
//    *               |
//    *               |    +-------+------+
//    * Priority N-2: | min|       |pt    |max
//    *               |    +-------+------+
//    *               |
//    *               +------------------------------------->
//    *                     Increasing Coordinates
//	 * ```
//    */	 
//	void popFront(){
//		_ranges[_iReady].popFront();
//		getReady();
//	}
//	
//	@property DT front(){ return _ranges[_iReady].front; }
//	@property CT min()  { return _ranges[_iReady].min; }
//	@property CT max()  { return _ranges[_iReady].max; }
//	@property int priority() { return _ranges[_iReady].priority;}
//}
//
//PriorityFilter!(RT, CT, DT) priorityFilter(
//	RT, CT=CoordType!RT, DT=ElementType!RT
//)(
//	RT[] ranges
//){
//	return PriorityFilter!(RT, CT, DT)(ranges);
//}
//
//unittest{
//	auto pr1 = iota(20, 40, 2).priorityRange(5, 1);  // Fine data
//	auto pr2 = iota(0, 100, 10).priorityRange(2, 5); // Coarse data
//	
//	auto fltr = [pr1, pr2].priorityFilter();
//	
//	foreach(el; fltr){
//		auto val = fltr.priority;
//		writefln("priority: %s, value: %s", val, el);
//	}
//}
