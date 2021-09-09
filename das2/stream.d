module das2.stream;

import std.stdio: File, stdout, stderr, writeln;
import std.format;
import std.mmfile: MmFile;
import std.file: exists, isFile;
import std.experimental.logger;
import dxml.parser; //parseXML, simpleXML, EntityType, Entity;
import std.range;
import std.algorithm: filter;
import std.format : format;
import std.system; // Endian, OS
import std.conv : to;
import std.typecons: Tuple;
import std.algorithm: find;

import das2.time;
import das2.units;
import das2c.tt2000: das_tt2K_to_utc;

alias XmlStream = EntityRange!(simpleXML, const(char)[]);

/* ************************************************************************* */
class DasTypeException : Exception
{
package: // Only stuff in the das2 package can throw these
	this(	string msg, string file = __FILE__, size_t line = __LINE__) @safe pure {
		super(format("[%s,%s] %s", file, line, msg));
	}
}
class DasStreamException : Exception
{
package: // Only stuff in the das2 package can throw these
this(	string msg, string file = __FILE__, size_t line = __LINE__) @safe pure {
		super(format("[%s,%s] %s", file, line, msg));
	}
}

/* ************************************************************************* */

enum PropType {TIME, STR, DATUM, DATUM_RNG, ORD, REAL};

/++ Items have a intrinsic encoding, but also a semantic meaning.  For example
 + the string "2019-001T14:00" is a 14-byte array, but it is also a UTC time
 + and should be comparable to other times.   
 +/
struct PktProp{
	PropType type = PropType.STR;
	string value;
}

/* ************************************************************************* */

struct PktAry{
private:
	// The actual buffer can be of different types
	enum EncodingType {CHARS, DOUBLES, FLOATS, SHORTS, INTS, LONGS };

	// All types can be encoded as ascii, so we have to know what they mean
	enum SemanticType {STRINGS, TIMES, INTS, REALS /*asciiXX*/};
	
	EncodingType _buf_type;
	SemanticType _semantic;
	Endian _buf_endian;
	
	ubyte[] _rawdata;

	char cFieldSep;
	Units _units;
	
public:
	long vint(){
		switch(_buf_type){
		case EncodingType.CHARS:   return to!long( (cast(const(char)[]) _rawdata)[0] );
		case EncodingType.DOUBLES: return to!long( (cast(const(double)[]) _rawdata)[0]);
		case EncodingType.FLOATS:  return to!long( (cast(const(float)[]) _rawdata)[0]);
		case EncodingType.SHORTS:  return to!long( (cast(const(short)[]) _rawdata)[0]);
		case EncodingType.INTS:    return to!long( (cast(const(int)[]) _rawdata)[0]);
		default:   return (cast(const(int)[])_rawdata)[0];
		}
	}

	double vreal(){
		switch(_buf_type){
		case EncodingType.CHARS:   return to!double( (cast(const(char)[]) _rawdata)[0]);
		case EncodingType.FLOATS:  return to!double( (cast(const(float)[]) _rawdata)[0]);
		case EncodingType.SHORTS:  return to!double( (cast(const(short)[]) _rawdata)[0]);
		case EncodingType.INTS:    return to!double( (cast(const(int)[]) _rawdata)[0]);
		case EncodingType.LONGS:   return to!double( (cast(const(long)[]) _rawdata)[0]);
		default:
			return (cast(const(double)[])_rawdata)[0];
		}	
	}

	DasTime vtime(){
		if(_units == UNIT_UTC){
			if(_buf_type != EncodingType.CHARS)
				throw new DasTypeException("units=\"UTC\" but raw data are not characters");
			return DasTime(cast(const(char)[]) _rawdata);
		}

		if(_units == UNIT_TT2000){
			double[9] tt2k;
			
			// These are special, needed for TT2000 handling
			long l = vint();
			das_tt2K_to_utc(
				// year      month         day           hour
				l, tt2k.ptr, tt2k.ptr + 1, tt2k.ptr + 2, tt2k.ptr + 3, 
				// minute     second        millisec      microsec
				tt2k.ptr + 4, tt2k.ptr + 5, tt2k.ptr + 6, tt2k.ptr + 7, 
				// nanosec
				tt2k.ptr + 8 
			);
			return DasTime(
				to!int(tt2k[0]), to!int(tt2k[1]), to!int(tt2k[2]), 
				to!int(tt2k[3]), to!int(tt2k[4]), 
				tt2k[5] + tt2k[6]*1e-3 + tt2k[7]*1e-6 + tt2k[8]*1e-9
			);
		}

		if(_units.haveCalRep()){
			double d = vreal();
			return _units.toTime(d);
		}

		throw new DasTypeException(format(
			"Values in units=\"%s\" are not datetimes", _units ));
	}

	string vchar(){
		// If the underlying buffer type is character data, just give it to the
		if(_buf_type == EncodingType.CHARS)
			return (cast(string) _rawdata);

		// Okay, it's not so convert something to a string
		if(_semantic == SemanticType.TIMES)
			return vtime().toString();

		if(_semantic == SemanticType.INTS)
			return format("%d", vint());

		return format("%.8e", vreal());
	}

	int opCmp(T)(auto ref const T other) if( is(T == int) || is(T == double) ){
		switch(_semantic){

		// read as integer, also works for times encoded as integers
		case SemanticType.INTS:
			long i = Int();
			if( i < other) return -1;
			else if (i > other) return 1;
			return 0;

		case SemanticType.REALS:
			double r = Real();
			if(r < other) return -1;
			else if (r > other) return 1;
			return 0;

		case SemanticType.TIMES:
			if(_units == UNIT_UTC)
				throw new DasTypeException(format(
					"ISO time strings not comparible to %s", typeid(T)
				));
					
			if(_units == UNIT_TT2000){
				long i = vint();
				if( i < other) return -1;
				else if (i > other) return 1;
				return 0;
			}
			else{
				double r = vreal();
				if(r < other) return -1;
				else if (r > other) return 1;
				return 0;				
			}
		default:	
			throw new DasTypeException(format(
				"Text strings are not comparible to %s", typeid(T))
			);
		}
	} 

	int opCmp(T)(auto ref const T other) if( is(T:DasTime) ){
		if(_semantic != SemanticType.TIMES)
			throw new DasTypeException("None time values can't be compared to a DasTime");
		DasTime dt = vtime();
		return dt.opCmp(other);
	}
}

/* ************************************************************************* */

struct PktDim {
	PktProp[string] props;
	PktAry[string] arrays;
	ref PktAry opIndex(string sUsage){
		return arrays[sUsage];
	}
}

/* ************************************************************************* */

struct DasPkt {
	PktDim[string] dims;

package:
	this(XmlStream)
	{

	}

	// Initialize PktDim objects using sections of the data
	void setData(const(ubyte)[] _data)
	{

	}

	ref PktAry opIndex(string sDim, string sUsage="center")
	{
		return dims[sDim][sUsage];
	}
}

/* ************************************************************************* */
class InputPktRange{
package:

	alias PktTag = Tuple!(int, "id", char, "type");

	const char[] _data;
	MmFile _mmfile;

	// Only support XML tag types for now, others can be added as needed
	//enum TagType {binary_fixed, binary_var, xml};
	//TagType _tagtype;
	
	XmlStream _rXml;
	
	PktProp[string] _props;
	DasPkt[int] _pkts;  // Not an array, a map
	int _curPktId = -1;
	string _source;     // Save the data source for error reports

	PktTag getPktId(XmlStream rXml){

		if(_rXml.front.name == "h" || _rXml.front.name == "d"){
			auto attr = find!(a=> (a.name == "id"))(_rXml.front.attributes);
			if(attr.empty){
				throw new DasStreamException(format(
					"[%s:%d] The 'id' attribute is missing from the XML header"~
					"packet container", _source, _rXml.front.pos.line
				));
			}
			return PktTag(to!int(attr.front.value), _rXml.front.name[0]);
		}
		
		// Wierd stuff 
		throw new DasStreamException(format(
			"[%s:%d] Unknown packet tag element '%s'",
			_source, _rXml.front.pos.line, _rXml.front.name
		));
	}

public:
	this(string sSource){
		_source = _source;
		_mmfile = new MmFile(_source);
		_data = cast(const(char)[]) _mmfile[];

		// Determine the container type (only 1 container type for today)
		//if(_data[0] == '[') _tagtype = binary_fixed;
		//else if(_data[0] == '|') _tagtype = binary_var;
		//else _tagtype = xml;

		// Read the stream header
		_rXml = parseXML!(simpleXML)(_data);

		if(_rXml.front.name != "container"){
			stderr.writeln("Not a das2 xml container");
		}
		_rXml.popFront();

		// Iterate to next data packet
		popFront();
	}

	void setProps(XmlStream rXml)
	{

	}

	@property bool empty() { return (_curPktId > 0); }

	@property ref DasPkt front() {return _pkts[_curPktId];}

	void popFront() {

		_curPktId = -1;

		NEXTPKT: while(!_rXml.empty){
			// Open packet envelope
			PktTag tag = getPktId(_rXml);
			_rXml.popFront();

			// At this point I can have a content entity, or a sub-packet but I
			// should have something 
			if(_rXml.empty) break NEXTPKT;

			// Headers
			if(tag.type == 'h'){
				// Content switch
				switch(_rXml.front.name){
				case "comment":
					_rXml.skipToParentEndTag();
					_rXml.skipToEntityType(EntityType.elementStart);
					continue NEXTPKT;
				case "stream":
					// Subsequent stream headers are okay, so long as they don't
					// change the format
					setProps(_rXml);
					continue NEXTPKT;
				case "packet":
					_pkts[tag.id] = DasPkt(_rXml);
					break NEXTPKT;
				default:
					throw new DasStreamException(format(
						"[%s:%d] Unexpected header element '%s'", _source, 
						_rXml.front.pos.line, _rXml.front.name
					));
				}
			}

			// Data
			if(tag.type == 'd'){
				if(tag.id !in _pkts)
					throw new DasStreamException(format(
						"[%s:%d] Data packet id='%d' received before "~
						"header packet %s", _source, _rXml.front.pos.line, tag.id
					));
				if(_rXml.front.type == EntityType.text)

				_pkts[tag.id].setData(cast( const(ubyte)[] ) _rXml.front.text);
				_curPktId = tag.id;
				break NEXTPKT;
			}
		}	
	}

}

InputRange!DasPkt inputPktRange(string sFile){
	return inputRangeObject(new InputPktRange(sFile));
}
