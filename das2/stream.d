module das2.stream;

import std.stdio: File, stdout, stderr, writeln;
import std.format;
import std.mmfile: MmFile;
import std.file: exists, isFile;
import std.experimental.logger;
import dxml.parser; //parseXML, simpleXML, EntityType, Entity;
import dxml.dom;    //
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
alias DomObj = DOMEntity!(XmlStream.Input);

/* ************************************************************************* */
class TypeException : Exception
{
package: // Only stuff in the das2 package can throw these
	this(	string msg, string file = __FILE__, size_t line = __LINE__) @safe pure {
		super(format("[%s,%s] %s", file, line, msg));
	}
}
class StreamException : Exception
{
package: // Only stuff in the das2 package can throw these
this(	string msg, string file = __FILE__, size_t line = __LINE__) @safe pure {
		super(format("[%s,%s] %s", file, line, msg));
	}
}

/* ************************************************************************* */

enum DimAxis {X, Y, Z, W};

enum PropType {STR, DATUM, BOOL, INT, REAL, DATUM_RNG, REAL_RNG};

/++ Items have a intrinsic encoding, but also a semantic meaning.  For example
 + the string "2019-001T14:00" is a 14-byte array, but it is also a UTC time
 + and should be comparable to other times.   
 +/
struct PktProp{
	PropType type = PropType.STR;
	string value;
	string[string] alt;  //keys are language codes
}

size_t setProperties(PktProp[string] props, DomObj root)
{
	size_t uPropsSet = 0;

	foreach(elProp; root.children){
		if(elProp.type != EntityType.elementStart) continue;
		if(elProp.name != "p") continue;  // Ignore what you don't understand

		string name;
		PropType type = PropType.STR;
		foreach(attr; elProp.attributes){
			if(attr.name == "name"){ name = attr.name.dup; continue;}
			if(attr.name == "type"){
				switch(attr.value){
				case "Datum": type = PropType.DATUM; break;
				case "boolean": type = PropType.BOOL; break;
				case "int": type = PropType.INT; break;
				case "double": type = PropType.REAL; break;
				case "DatumRange": type = PropType.DATUM_RNG; break;
				case "doubleRange": type = PropType.REAL_RNG; break;
				default:
					throw new StreamException(format(
						"Unknown property type '%s' at line %d", attr.value, elProp.pos.line
					));
				}
			}
		}

		if(name.length == 0)
			throw new StreamException(format(
				"Attribute name missing from property at line %d", elProp.pos.line
			));

		// For string property parsing, we have the initial text, then alternate
		// languages.

		props[name] = PktProp.init;
		props[name].type = type;
		++uPropsSet;
		
		// See if any alternate language versions were set, if so save them
		foreach(subItem; elProp.children){
			if(subItem.type == EntityType.text)
				props[name].value = subItem.text.dup;

			if(subItem.type == EntityType.elementStart){
				if(subItem.name != "alt") continue;

				if(type != PropType.STR)
					throw new StreamException(format(
						"Property '%s' at line %d contains an alternate "~
						"langage setting, but is not a string property ",
						name, subItem.pos.line
					));

				auto attr = find!(a=> (a.name == "lang"))(subItem.attributes);
				if(attr.empty)
					throw new StreamException(format(
						"'lang' attribute missing from <alt> element of "~
						"property '%s' at line %d", name, subItem.pos.line
					));
				string lang = attr.front.value.dup;

				foreach(altchild; subItem.children){
					if(altchild.type == EntityType.text)
						props[name].alt[lang] = altchild.text.dup;
				}
			}
		}

	}

	return uPropsSet;
}

size_t setProperties(PktProp[string] props, XmlStream rXml)
{
	auto dom = parseDOM(rXml);
	auto root = dom.children[0];
	return setProperties(props, root);
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

	ubyte[] _delim;
	int _items;
	
public:

	this(DomObj root, const(ubyte)[] delim)
	{
		if(delim.length > 0) _delim = delim.dup;

		throw new StreamException("Array construction");
	}

	const(ubyte)[] setData(const(ubyte)[] _data)
	{
		// Cast the byte array to the appropriate buffer type, read data byte
		// swapping if necessary.  Keep track of the number of bytes read and 
		// return a shortened slice.


		return _data;
	}

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
				throw new TypeException("units=\"UTC\" but raw data are not characters");
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

		throw new TypeException(format(
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
				throw new TypeException(format(
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
			throw new TypeException(format(
				"Text strings are not comparible to %s", typeid(T))
			);
		}
	} 

	int opCmp(T)(auto ref const T other) if( is(T:DasTime) ){
		if(_semantic != SemanticType.TIMES)
			throw new TypeException("None time values can't be compared to a DasTime");
		DasTime dt = vtime();
		return dt.opCmp(other);
	}
}

/* ************************************************************************* */

struct PktDim {
	PktProp[string] _props;
	PktAry[string] _arrays;  //one array for each usage

	string[] _readOrder;

	this(DomObj root, PktProp[string] streamProps, ubyte[] delim){
		// Merge the stream props in with my props, then override later
		foreach(key, val; streamProps)
			_props[key] = val;
		
		foreach(el; root.children){
			if(el.name == "properties")
				setProperties(_props, el);

			if(el.name == "array"){
				string usage = "center";
				auto attr = find!(a=> (a.name == "usage"))(el.attributes);
				if(!attr.empty) usage = attr.front.value.dup;
				
				_arrays[usage] = PktAry(el, delim);
				_readOrder[$] = usage;
			}

			if(el.name == "xcoord" || el.name == "ycoord" ||el.name == "zcoord"){
				throw new StreamException(format(
					"Offset coordinate handling is yet implemented for '%s' at line %d",
					el.name, el.pos.line
				));
			}

			// Ignore anything else
		}
	}

	// Initialize PktDim objects using sections of the data
	const(ubyte)[] setData(const(ubyte)[] _data)
	{
		for(int i = 0; i < _readOrder.length; ++i){
			_data = _arrays[_readOrder[i]].setData(_data);
		}

		return _data;
	}

	ref PktAry opIndex(string sUsage){
		return _arrays[sUsage];
	}
}

/* ************************************************************************* */

struct DasPkt {
	PktDim[string] _dims;
	string[] _readOrder;
	ubyte[] _delim;

	this(XmlStream rXml, PktProp[string] streamProps)
	{
		auto dom = parseDOM(rXml);
		auto root = dom.children[0];
		foreach(attr; root.attributes){
			if( attr.name == "delim" && attr.value == "space"){
				_delim[0] = ' ';
				break;
			}
		}

		foreach(pdim; root.children){
			if(pdim.name == "yset" || pdim.name == "zset" || pdim.name == "wset")
				throw new StreamException("yset, zset & wset reading not yet implemented");

			
			if(pdim.name != "x" && pdim.name != "y" && pdim.name != "z")
				throw new StreamException(format(
					"Skipping custom content, '%s' is not yet implemented", pdim.name
				));

			auto attr = find!(a=> (a.name == "pdim"))(pdim.attributes);
			if(attr.empty)
				throw new StreamException(format("Required attribute 'pdim' missing from element '%s'", pdim.name));
			
			_readOrder[$] = attr.front.name.dup;
			_dims[_readOrder[$-1]] = PktDim(pdim, streamProps, _delim);
		}
	}

	// Initialize PktDim objects using sections of the data
	void setData(const(ubyte)[] _data)
	{
		for(int i = 0; i < _readOrder.length; ++i){
			// each dimension must eat all deliminators appearing before
			// and after it in the stream.
			_data = _dims[_readOrder[i]].setData(_data);
		}
	}

	ref PktAry opIndex(string sDim, string sUsage="center")
	{
		return _dims[sDim][sUsage];
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
				throw new StreamException(format(
					"[%s:%d] The 'id' attribute is missing from the XML header"~
					"packet container", _source, _rXml.front.pos.line
				));
			}
			return PktTag(to!int(attr.front.value), _rXml.front.name[0]);
		}
		
		// Wierd stuff 
		throw new StreamException(format(
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
					setProperties(_props, _rXml);
					continue NEXTPKT;
				case "packet":
					_pkts[tag.id] = DasPkt(_rXml, _props);
					break NEXTPKT;
				default:
					throw new StreamException(format(
						"[%s:%d] Unexpected header element '%s'", _source, 
						_rXml.front.pos.line, _rXml.front.name
					));
				}
			}

			// Data
			if(tag.type == 'd'){
				if(tag.id !in _pkts)
					throw new StreamException(format(
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
