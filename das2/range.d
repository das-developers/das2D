/++ Range types, templates and algorithms.
 
 Most of these algorithms work on `data ranges`.  This is the same as a regular
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
 +/
module das2.range;

import std.algorithm;  // gets: filter, map
import std.range;      // gets: uniform
import std.traits;     // gets: isOrderingComparible, isInputRange, etc.

/** Test for data ranges

This is a templated variable evaluates to `true` if type `R` is a data
range.  Data ranges are just standard phobos ranges where the return 
value from front() always contains the sub items:

 * .data - The main content of each element
 * .cbeg - The intial "X" coordinate of the element.  My be any type, including
 *        coordinate pairs or triplets.
 * .cend - The final "X" coordinate of the element. 
 
The sub-elements `cbed` and `cend` must be orderable via `<`.

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
enum bool isDataRange(R) = isInputRange!R
	&& isTuple!(ReturnType!((R r) => r.front))
	&& is(typeof((return ref R r) => r.front.data))
	&& !is(ReturnType!((R r) => r.front.data) == void)
	&& is(typeof((return ref R r) => r.front.cbeg))
	&& !is(ReturnType!((R r) => r.front.cbeg) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.cbeg))
	&& is(typeof((return ref R r) => r.front.cend))
	&& !is(ReturnType!((R r) => r.front.cend) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.cend));

/** Test for priority ranges

This is a templated variable that evaluates to `true` if type `R` is a 
priority range.  Priority ranges are data ranges with a priority attribute 
n each element.  Thus the return value from front():

 * Has all the same properties as data range elements
 * .priority - This must be present in each range element
 * .priority items  should be compariable via `<` and `==`.
 
The priority elements of a range can be a constant value for the whole
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
enum bool isPriorityRange(R) = isDataRange!R
	&& is(typeof((return ref R r) => r.front.priority))
	&& !is(ReturnType!((R r) => r.front.priority) == void)
	&& isOrderingComparable!(typeof((return ref R r) => r.front.priority));

/******************************************************************************
 * The object type returned by the prioritySelect() function
 */

struct PrioritySelect(REC_T)
{
private:
	InputRange!REC_T[] _ranges;  // slice of priority range objects
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

	this(InputRange!REC_T[] ranges){
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
	
	@property REC_T front(){ return _ranges[_iReady].front; }
}

///
unittest {
	import std.random;
	import std.typecons;   // gets: Tuple
	import std.stdio;      // gets: write

	
	struct data_t {
		double x;
		int y;
	}

	struct record_t {
		data_t data;
		double cbeg;
		double cend; 
		int priority;
	}

	// High resolution data spaced 2 appart
	auto fine_recs = zip(iota(120.0f, 140.0f, 2.0f).array, generate!(() => uniform(0, 128)))
		.map!(
			el => record_t(data_t(el[0], el[1]), el[0] - 1.0, el[0] + 1.0, 10)
		);
	
   // Generate an array of low-resolution records (spaced 10 apart)
   auto coarse_recs = zip(iota(100.0f, 200.0f, 10.0f).array, generate!(() => uniform(0, 128)))
		.map!(
			el => record_t(data_t(el[0], el[1]), el[0] - 5.0, el[0] + 5.0, 5)
		);

	// Generate an array of ultra low-resolution records (spaced 25 apart)
   auto summary_recs = zip(iota(0, 400, 25).array, generate!(() => uniform(0, 128)))
		.map!(
			el => record_t(data_t(el[0], el[1]), el[0] - 12.5, el[0] + 12.5, 1)
		);

	InputRange!record_t oF = inputRangeObject(fine_recs);
	InputRange!record_t oC = inputRangeObject(coarse_recs);
	InputRange!record_t oS = inputRangeObject(summary_recs);
	
	
	foreach(el; prioritySelect([oF, oC, oS])){  // print merged stream
	   writefln(
	      "Priority: %2d  Width: %2.0f  Coord: [%3.1f, %3.1f)  Data [%s, %s]",
	      el.priority, el.cend - el.cbeg, el.cbeg, el.cend, el.data.x , el.data.y
	   );
	}


	/*
	auto r = prioritySelect([oF, oC]);
	assert(r.front.priority == 5 && r.front.cbeg == -5 && r.front.cend == 5);
	r.popFront();
	r.popFront();
	assert(r.front.priority == 10 && r.front.cbeg == 18 && r.front.cend == 22);

	foreach(i; 0..10) r.popFront();
	assert(r.front.priority == 5 && r.front.cbeg == 45 && r.front.cend == 55);
*/

	writefln("INFO: das2.range unittest passed");
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
 * Types:
 *   REC_T = the record type which must have the properties:
 *     .cbeg - The begin time of the owned area of a record.
 *     .cend - The end time of the owned area of a record
 *
 *
 * Params:
 *   ranges = A slice of PriorityRange class objects.  Since this is a slice
 *      all of the range objects must be of the same type.
 *      Hint: To get a little but of type erasure for the input ranges array,
 *            use std.range.inputRangeObject()
 *
 * See Also:
 *   [isPriorityRange] for a macro that determines if a range is a das2 priority
 *   range.
 */
 
InputRange!(REC_T) prioritySelect(REC_T)(InputRange!REC_T[] ranges){
	return inputRangeObject(PrioritySelect!(REC_T)(ranges));
}
