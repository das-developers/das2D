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
import std.typecons;

/** Test for das2 ranges

This is a templated variable evaluates to `true` if type `R` is a das2
range.  Das2 ranges are just standard phobos ranges with:

 * Tuples for range elements
 * A sub-element 'data' is present in the tuple elements.
 * The sub-elements `cbeg` and `cend` are present in the range element.
 * The sub-elements `cbed` and `cend` are orderable via `<`.

The follow code should compile for any data range.
---
static assert(isInputRange!R);

auto b = r.front.data;  // can get the data "payload"
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

Params:
	R = type to be tested
	
Returns:
	`true` if R is a data range, `false` if not.

*/
enum bool isDasRange(R) = isInputRange!R
	&& isTuple!(ReturnType!((R r) => r.front))
	&& is(typeof((return ref R r) => r.front.data))
	&& !is(ReturnType!((R r) => r.front.data) == void)
	&& is(typeof((return ref R r) => r.front.cbeg))
	&& !is(ReturnType!((R r) => r.front.cbeg) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.cbeg))
	&& is(typeof((return ref R r) => r.front.cend))
	&& !is(ReturnType!((R r) => r.front.cend) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.cend));

/******************************************************************************
 * One possible DasRange template.
 *
 * This is the range structure emitted by [dasRange] see that function
 * for more details.
 * 
 * Params:
 *   RT = The input range type should be some Phobos input range.
 *   BF = The type of function that produces coordinate begin values
 *        the upstream elements.
 *   EF = The type of function that produces coordinate ending values
 *        from the upstream elements.
 */ 
struct DasRange(
	RT, BF, EF, IN_T=ElementType!RT, CT=ReturnType!BF
){
private:
	RT range;
	CT function(IN_T) getBeg;  // Member function pointer
	CT function(IN_T) getEnd;  // Member function pointer
public:
	
	// Define the output type tuple
	alias OUT_T = Tuple!(IN_T, "data", CT, "cbeg", CT, "cend");

	this(RT range, CT function(IN_T) getCBeg, CT function(IN_T) getCEnd)
	{
		this.range = range;
		this.getBeg = getCBeg;
		this.getEnd = getCEnd;
	}
	
	void popFront(){ range.popFront(); }

	@property bool empty() {return range.empty; }
	
	@property OUT_T front() {
		return OUT_T(range.front, getBeg(range.front), getEnd(range.front));
	}
		
	// Add save function for forward range
	static if(isForwardRange!RT){
		@property DasRange!(RT, BF, EF) save() {
			return DasRange!(RT, BF, EF)(range.save, getBeg, getEnd);
		}
	}
	
	// Add back, popBack for bidirectional range
	static if(isBidirectionalRange!RT){
		@property OUT_T back() {
			return OUT_T(range.back, getBeg(range.back), getEnd(range.back));
		}
		void popBack(){ range.popBack(); }
	}
	
	
	// Add index for random access range
	static if(isRandomAccessRange!RT){
		OUT_T opIndex(size_t index) {
			return OUT_T(
				range[index], getBeg(range[index]), getEnd(range[index])
			);
		}
	}
	
	static if(hasLength!RT){
		@property size_t length() { return range.length; }
	}
}

/******************************************************************************
 * Adaptor for converting input ranges into coordinate + data ranges
 *
 * Params:
 *    range = The InputRange to wrap as a DataRange. Range properties are 
 *            preservend.  So, if the input range type is also a FrontRange, 
 *            BidirectionRange, or RandomAccessRange then the returned structure
 *            will also be one too.
 * 
 *    fBeg  = Function that extracts the beginning coordinate for each data
 *            element from range.front
 *
 *    fEnd  = Function that extracts the ending coordinate for each data 
 *            element form range.front
 * 
 * Returns:
 *    A [DasRange] structure.  The returned range object will also be a
 *    FrontRange, BidirectionalRange, or RandomAccessRange depending on
 *    the input range.
 *    
 */
DasRange!(RT, CBegF, EF) dasRange(RT, CBegF, EF)(
	RT range, CBegF fBeg, EF fEnd
){
	return DasRange!(RT, CBegF, EF)(range, fBeg, fEnd);
}

///
unittest
{
	double[][] packets = [ 
		[10.0, 13.0 ], [20, 14.0], [30, 17.0], [40, 15.0]
	];
	
	// Provide rules for digging coordinates out of the packets 
	auto dr = packets.dasRange(
		(double[] el) => el[0] - 2.0, (double[] el) => el[0] + 2.0
	);

	static assert( isInputRange!(typeof(dr)));
	static assert( isDasRange!(typeof(dr)));
	static assert( isForwardRange!(typeof(dr)));
	static assert( isBidirectionalRange!(typeof(dr)));
	static assert( isRandomAccessRange!(typeof(dr)));
	
	auto dr_backup = dr.save;
	
	foreach(el; dr){
		writeln("Coord: [", el.cbeg, ", ", el.cend, ")  Data: ", el.data);
	}
	
	assert(dr_backup[3].cbeg == 38.0);
	assert(dr_backup[3].cend == 42.0);
	assert(dr_backup[3].data == [40.0, 15.0]);
}


/** Test for das priority ranges

This is a templated variable that evaluates to `true` if type `R` is a 
das priority range.  Das priority ranges are das ranges with a priority 
attribute in each element.

 * Tuples for range elements
 * The sub-element `priority` must be present in each range element.
 * The sub-elemens `.priority` should be compariable via `<` and `==`.
 
The priority elemens of a range can be a constant value for the whole
range.

The follow code should compile for any priority range.
---
static assert(isDasRange!R)

auto b = r.front.priority;  // can get the priority value
---

Params:
	R = type to be tested
	
Returns:
	`true` if R is a priority range, `false` if not.
*/
enum bool isPriorityRange(R) = isDasRange!R
	&& is(typeof((return ref R r) => r.front.priority))
	&& !is(ReturnType!((R r) => r.front.priority) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.priority));


/**
The coordinate of type `R`.  `R` does not have to be a range.  The coordinate
type is determined as the type yielded by `r.front.cbeg` for an object
`r` of type `R`. If `R` doesn't have `front`, `CoordType!R` is `void`.
*/
//template CoordType(R)
//{
//	static if ( 
//		is(typeof(R.init.front.cbeg.init) T)
//		&& is(typeof(R.init.front.cend.init) T)
//		&& is(typeof(R.init.front.cbeg.init) == typeof(R.init.front.cend.init))
//	)
//		alias CoordType = T;
//	else
//		alias CoordType = void;
//}


/***************************************************************************
 * Adaptor for adding priorities to das ranges
 *
 * Params:
 *   RT = The type of das range to wrap
 *   PF = The type of function providing priority measures
 */
 

struct PriorityRange(RT, PF)

if( isDasRange!RT){ // Expects a type of dasRange for the input

public:
	alias IN_T = ElementType!RT; // The input range type
	
	alias DT   = typeof(IN_T.data); // The input data
	
	alias CT   = typeof(IN_T.cbeg); // The input coordinates
	
	alias PT   = ReturnType!PF;  // The type of priority to store
	
	// The output range type
	alias OUT_T = Tuple!(DT, "data", CT, "cbeg", CT, "cend", PT, "priority");

private:
	RT range;
static if(arity!PF == 1){
	PT function( DT ) priority; // member function pointer
}else{
	PT function() priority; // member function pointer
}
	
public:

static if(arity!PF == 1){
	this(RT range, PT function(DT) priority){
		this.range    = range;
		this.priority = priority;
	}
}else{
	this(RT range, PT function() priority){
		this.range    = range;
		this.priority = priority;
	}
}
	

	@property bool empty() { return range.empty(); }
	
	@property OUT_T front() { 
static if(arity!PF == 1){
		return OUT_T(
			range.front.data, range.front.cbeg, range.front.cend,
			priority(range.front.data)
		);
}else{
		return OUT_T(
			range.front.data, range.front.cbeg, range.front.cend,
			priority()
		);
}
	}
	
	void popFront(){ range.popFront(); }
	
	// Add save function for forward range
	static if(isForwardRange!RT){
		@property PriorityRange!(RT, PF) save() {
			return PriorityRange!(RT, PF)(range.save, priority);
		}
	}
	
	// Add back, popBack for bidirectional range
	static if(isBidirectionalRange!RT){
		@property OUT_T back() {
			static if(arity!PF == 1){	
				return OUT_T(
					range.back.data, range.back.cbeg, range.back.cend,
					priority(range.back.data)
				);
			}
			else{
				return OUT_T(
					range.back.data, range.back.cbeg, range.back.cend,
					priority()
				);
			}
		}
		void popBack(){ range.popBack(); }
	}
	
	// Add index for random access range
	static if(isRandomAccessRange!RT){
		static if(arity!PF == 1){	
			OUT_T opIndex(size_t index) {
				return OUT_T(
					range[index].data, range[index].cbeg, range[index].cend,
					priority(range[index].data)
				);
			}
		}
		else{
			OUT_T opIndex(size_t index) {
				return OUT_T(
					range[index].data, range[index].cbeg, range[index].cend,
					priority()
				);
			}
		}

	}
	
	static if(hasLength!RT){
		@property size_t length() { return range.length; }
	}
}

//enum Tuple!(RT, BF, EF)

/** Wrap a das range as a das priority range
 *
 * Params:
 *   range = A das range 
 * 
 *   priority = A function which produces priority values for each das
 *     range element.
 *
 */
PriorityRange!(RT, PF) priorityRange(RT, PF)(RT range, PF priority)
{
	return PriorityRange!(RT, PF)(range, priority);
}

unittest
{
	double[][] packets = [ 
		[10.0, 13.0, 3.0], [20, 14.0, 2.0], [30, 17.0, 1.0], [40, 15.0, 5.0]
	];
	
	// Functions for pulling values from the data packets
	alias coord0   = (double[] el) => el[0] - 2.0;
	alias coord1   = (double[] el) => el[0] + 2.0;
	alias priority = (double[] el) => el[2]      ;
	
	auto pr = packets
		.dasRange(coord0, coord1)  // Converts elements to .data .cbeg .cend
		.priorityRange(priority);  // adds .priority element

	static assert( isRandomAccessRange!(typeof(pr)) );
	static assert( isDasRange!(typeof(pr)) );
	static assert( isPriorityRange!(typeof(pr)) );

	auto sorted = pr.array.sort!"a.priority < b.priority";
				
	foreach(el; sorted)
		writeln(
			"Coord: [", el.cbeg, ", ", el.cend, ")   Priority: ", el.priority,
			" Data: ", el.data
		);	
}

/******************************************************************************
 * The range structure returned by [prioritySelect].
 */
struct PrioritySelect(RT)
{
private:
	RT[] _ranges;  // slice of priority range objects
	long _iReady;	// If > 0, range that will provide the next value
	
	// Pick an internal range object to go next, pop items to be skipped.
	void getReady(){
		_ranges = _ranges.filter!(rng => !rng.empty).array();
		if(_ranges.length == 0) return;

		_ranges = _ranges.sort!(
			(rngA, rngB) => rngA.front.priority < rngB.front.priority
		).array();
								
		_iReady = _ranges.minIndex!((a, b) => a.front.cbeg < b.front.cbeg);
		
		// Assume ranges are sorted from lowest priority to highest
		for(long i = _iReady+1; i < _ranges.length; ++i){
		
			// don't overlap with higher priority items
			if(_ranges[i].front.cbeg < _ranges[_iReady].front.cend){
			
				_ranges[_iReady].popFront(); // Okay if empty afterwords
				++_iReady;
			}
		}
	}
	
public:

	alias OUT_T = ElementType!RT;
	static assert(!is(OUT_T == void), "Common type not found for input ranges");

	this(RT[] ranges){
		this._ranges = ranges;
		getReady();
	}
	
	@property bool empty(){
		// When the input ranges can no longer supply data, they are 
		// rm'ed from the slice.
		return (_ranges.length == 0);
	}
		
   /** Ready the next element at the front. */
	 
	void popFront(){
		_ranges[_iReady].popFront();
		getReady();
	}
	
	@property OUT_T front(){ return _ranges[_iReady].front; }
}


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
 * Since this function climbs the priority ladder dropping all lower priority
 * values that overlay, it is possible to drop more data than you might expect.
 * 
 * For the three elements below, only the highest one is emitted, even though
 * the lowest priority item and the highest do not overlap.  Nonetheless the
 * middle priority point acts as a bridge that get's both lower points dropped.
 * 
 * ```
 *               
 *               ^
 *               |                   +----+----+
 * Priority N    |                min|    |pt  |max
 *               |                   +----+----+
 *               |
 *               |           +----+-----+
 * Priority N-1  |        min|    |pt   |max
 *               |           +----+-----+
 *               |
 *               |    +------+-----+
 * Priority N-2: | min|      |pt   |max
 *               |    +------+-----+
 *               |
 *               +------------------------------------->
 *                     Increasing Coordinates
 * ```
 *
 * Params:
 *   ranges = A slice of PriorityRange objects.  Since this is a slice all of
 *      the range objects must be of the same type.
 *
 * See Also:
 *   [isPriorityRange] for a macro that determins if a range is a das2 priority
 *   range.
 */
PrioritySelect!(RT) prioritySelect(RT)(RT[] ranges){
	return PrioritySelect!RT(ranges);
}

///
unittest{
   import std.random;

   // Generate an array of high-resolution records (spaced 2 apart)
   // In a real program, records would be gathered from a file or from
   // some other source.
   auto fine_recs = zip(iota(20, 40, 2), generate!(() => uniform(0, 128))).array;

   // Generate an array of low-resolution records (spaced 10 apart)
   auto coarse_recs = zip(iota(0, 100, 10), generate!(() => uniform(0, 128))).array;

   // Common element type for both datasets
   alias ET = ElementType!(typeof(fine_recs));

   // Wrap the records as a DasRange, and then a PriorityRange
   // Lambda function arguments to dasRange get coordiantes from the records.
   // Lambda functions arguments to priorityRange provide priority values.
   auto dr_fine = fine_recs
      .dasRange((ET el) => el[0] - 2, (ET el) => el[0] + 2) // get coords
      .priorityRange( () => 2 );     // higher priority

   auto dr_coarse = coarse_recs
      .dasRange((ET el) => el[0] - 5, (ET el) => el[0] + 5) // get coords
      .priorityRange( () => 1 );     // lower priority

   // Wrap both ranges as a proritySelect range, lower priority items
   // from the input ranges will be dropped if thier coordinates overlap
   // higher priority records
   auto pr = prioritySelect([dr_fine, dr_coarse]);

   // Print the resulting stream
   foreach(el; pr){
      write(
         "Priority: ", el.priority, "  Coord: [", el.cbeg, ", ", el.cend, ")",
         "  Data: "
      );
      foreach(i, member; el.data)
         if(i > 0) write(", ", member);
         else write(member);
      write("\n");
   }
}
