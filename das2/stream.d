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
import std.algorithm: find, endsWith, skipOver;
import std.system: Endian, endian;
import std.string: toLower, indexOfAny;

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

enum PropType {STR, DATUM, BOOL, INTEGER, REAL, DATUM_RNG, REAL_RNG};

/++ Items have a intrinsic encoding, but also a semantic meaning.  For example
 + the string "2019-001T14:00" is a 14-byte array, but it is also a UTC time
 + and should be comparable to other times.   
 +/
struct PktProp{
	PropType type = PropType.STR;
	string value;
	string[string] alt;  //keys are language codes
}

// Read <properties><p> elements from a dom object
size_t mergeProperties(PktProp[string] props, DomObj root)
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
				case "Datum":      type = PropType.DATUM;     break;
				case "boolean":    type = PropType.BOOL;      break;
				case "integer":    type = PropType.INTEGER;   break;
				case "real":       type = PropType.REAL;      break;
				case "DatumRange": type = PropType.DATUM_RNG; break;
				case "realRange":  type = PropType.REAL_RNG;  break;
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

size_t mergeProperties(PktProp[string] props, XmlStream rXml)
{
	auto dom = parseDOM(rXml);
	auto root = dom.children[0];
	return mergeProperties(props, root);
}

/* ************************************************************************* */

// The actual buffer can be of different types
enum BufferType {TEXT, DOUBLE, FLOAT, BYTE, SHORT, INT, LONG };

// All types can be encoded as text, so we have to know what they mean
enum SemanticType {STRING, TIME, INTEGER, REAL};

enum INVALID_WIDTH = -1;
enum VARIABLE_WIDTH = 0;

// I bet this is why hectonano seconds exists: y m d h M S ms μs hns
// UTC Binary encoding? YYYY-MM-DDTHH:MM:SS -> 2 1 1 1 1 1  2  2   1 = 12 bytes
// Gives a range of 64K years at 10 nanosecond resolution and easy to parse.

// The default decoding for a value is: encode="text*", delim=" ", type="real"
//    with delimiter merging turned on
// The default byte order is little endian;

private struct Decode {
	BufferType buf_type = BufferType.TEXT;
	SemanticType sem_type = SemanticType.REAL;

	// Number of bytes for each buffer block.  (so double == 8)
	int bytes_per_blk = 1;

	// Number of buffer blocks per item (can be variable)
	int blks_per_item = VARIABLE_WIDTH;  // 0 = arbitrary length, -1 is invalid have to get len	

	ubyte[] delim;
	Endian order = Endian.littleEndian;
	bool mergedelim = true;  // multiple spaces treated as single space
	string lang = "en";      // default language to assume for properties

version(BegEndian){
	bool swap = true;       // true if byte swapping is needed for a value type
}
else{
	bool swap = false;
}	

	// And the obligatory postblit for the dynamic array member
	this(this){
		delim = delim.dup;
	}
}


/** Override values in a given decoding using attributes from a dom object */
private Decode cascadeDecode(AR)(Decode decode, AR rAttributes, int nLineNo)
	if(isAttrRange!AR)
{
	const(char)[] sBufType;

	// Cascade decoding rules
	Decode _decode = decode;

	// The default for das2.3/basic streams is little endian, if you're a big
	// endian machine, just assume you're going to need to swap values unless
	// told otherwise
version(BegEndian){
	_decode.swap = true;
}
else{
	_decode.swap = false;
}
	
	// Set the default decoding and parse default properties
	foreach(attr; rAttributes){
		switch(attr.name){
		case "version":
			if(attr.value != "2.3/basic-xml")
				errorf("Unknown stream version '%s' this might not go well", attr.value);
			break;

		case "encode":

			// Get the number of blocks per item, defaults to 1, may be variable
			decode.blks_per_item = 1;
			sBufType = attr.value;
			if(attr.value.endsWith("*")){
				decode.blks_per_item = VARIABLE_WIDTH;
				sBufType = attr.value[0..$-1];
			}
			else{
				long iPos = attr.value.indexOfAny("123456789");
				if(iPos > 1){
					decode.blks_per_item = to!int(attr.value[iPos..$]);
					if(decode.blks_per_item > 65536){ 
						// 64K / item sanity check
						throw new StreamException("Individual values larger than 64 kB are not supported");
					}
					sBufType = attr.value[0..iPos];
				}
			}
			
			switch(sBufType){
			case "text":   decode.bytes_per_blk = 1; decode.buf_type = BufferType.TEXT; break;
			case "float":  decode.bytes_per_blk = 4; decode.buf_type = BufferType.FLOAT; break;
			case "double": decode.bytes_per_blk = 8; decode.buf_type = BufferType.DOUBLE; break;
			case "byte":   decode.bytes_per_blk = 1; decode.buf_type = BufferType.BYTE; break;
			case "short":  decode.bytes_per_blk = 2; decode.buf_type = BufferType.SHORT; break;
			case "int":    decode.bytes_per_blk = 4; decode.buf_type = BufferType.INT; break;
			case "long":   decode.bytes_per_blk = 8; decode.buf_type = BufferType.LONG; break;
			default:
				throw new StreamException(format(
					"Unknown default value encoding in element at line %d",
					attr.value, nLineNo
				));
			}
			break;

		case "delim":
			if(attr.value == "space"){ decode.delim[0] = ' ';  break; }
			if(attr.value == "tab"){   decode.delim[0] = '\t';  break;}
			decode.delim = cast(ubyte[]) attr.value.dup;
			break;

		case "mergedelim":
			decode.mergedelim =  (attr.value.toLower() == "true");
			break;

		case "lang":
			decode.lang = attr.value.dup;
			break;

		case "byteorder":
version(BegEndian){
			if(attr.value == "BE") decode.swap = false;
}
else{
			if(attr.value == "BE") decode.swap = true;
}
			break;

		default:   //Just igonre other stuff
			break;
		}
	}
	return decode;
}

/* ************************************************************************ */

enum VARIABLE_ITEMS = 0;

struct PktAry{
private:
	string _name;

	Decode _decode;
	
	ubyte[] _rawdata;

	Units _units;

	int _items = 1; // 0 = variable number of items, need terminator
	
public:

	this(Decode decode, string sPdimName, DomObj elArray)
	{

		// Cascade down encoding attributes
		_decode = cascadeDecode(decode, elArray.attributes, elArray.pos.line);

		foreach(attr; elArray.attributes){
			switch(attr.name){
			case "usage":
				_name = format("%s.%s", sPdimName, attr.value);
				break;

			case "units": _units = Units(attr.value); break;

			case "type":
				switch(attr.value){
				case "string":  _decode.sem_type = SemanticType.STRING;  break;
				case "isotime": _decode.sem_type = SemanticType.TIME;    break;
				case "real":    _decode.sem_type = SemanticType.REAL;    break;
				case "integer": _decode.sem_type = SemanticType.INTEGER; break;
				default:
					throw new StreamException(format("Unknown value type '%s' in "~
						"element '%s' at line %d'", attr.value, elArray.name, 
						elArray.pos.line
					));
				}
				break;

			case "nitems":
				if(attr.value == "*") _items = VARIABLE_ITEMS; break;

			default:
				break; // ignore other stuff
			}
		}

		if(_name.length == 0)
			_name = _name = format("%s.center", sPdimName);
		
		// if we're not using variable length stuff, go ahead an initialize the
		// buffer for storing values
		if(_decode.blks_per_item != VARIABLE_WIDTH && _items != VARIABLE_ITEMS){
			_rawdata.length = _decode.blks_per_item * _items;
		}

		if(_decode.blks_per_item == VARIABLE_WIDTH && _decode.delim.length == 0){
			throw new StreamException(format("Element <array> at %d has variable "~
				"width items, but no 'delim'inator has been set.", elArray.pos.line
			));
		}
	}

	// Could just use reverse here (might change later)
	private void swapCopyN(ubyte[] dest, const(ubyte)[] src, size_t uLen){
		switch(uLen){
		case 8:
			dest[0] = src[7]; dest[1] = src[6];
			dest[2] = src[5]; dest[3] = src[4];
			dest[4] = src[3]; dest[5] = src[2];
			dest[6] = src[1]; dest[7] = src[0];
			break;
		case 4:
			dest[0] = src[3]; dest[1] = src[2];
			dest[2] = src[1]; dest[3] = src[0];
			break;
		case 2:
			dest[0] = src[1]; dest[1] = src[0];
			break;
		case 1:
			dest[0] = src[0];
			break;
		default:
			throw new StreamException(format(
				"Byte swapping size %s items not implemented", uLen
			));
		}
	}

	// Read one item off the range and reduce it.  Returns true if an item was
	// read, false otherwise
	private bool readItem(ref const(ubyte)[] data)
	{
		size_t uBlkSz = _decode.bytes_per_blk;
		size_t uDlmSz = _decode.delim.length;
		size_t uItemBlks = _decode.blks_per_item;

		if(uDlmSz > 0)
			while(skipOver(_decode.delim, data)){ } // shortens the range

		if(uItemBlks > 0){
			size_t uAll = uItemBlks * uBlkSz;

			if(data.length < uAll) return false;

			if(!_decode.swap || uBlkSz == 1){
				_rawdata[$..$+uAll] = data[0..uAll];  // no swap, copy in all blocks
				data = data[uAll..$];                 // Shortens the range
			}
			else{
				// swap copy each block
				for(size_t u = 0; u < uItemBlks; ++u){
					swapCopyN(_rawdata[$ .. $+uBlkSz], data, uBlkSz);
					data = data[uBlkSz .. $];
				}
			}

			return true;
		}
		else{  // Variable number of blocks per item, read till delim or no more data
			
			bool bItemRead = false;

			if(uDlmSz == 0)
				throw new StreamException("No delimiter set for variable length items");

			while((data.length > uBlkSz) && (data[0..uDlmSz] != _decode.delim)){

				if(!_decode.swap || uBlkSz == 1) 
					_rawdata[$ .. $+uBlkSz] = data[0 .. uBlkSz];
				else
					swapCopyN(_rawdata[$ .. $+uBlkSz], data, uBlkSz);

				data = data[uBlkSz .. $];  // Shortens the range
				bItemRead = true;
			}

			return bItemRead;
		}
	}

	// Copy (and swap if needed) N number of items at M_n bytes each 
	const(ubyte)[] setData(const(ubyte)[] data)
	{
		_rawdata.length = 0;

		if(_items != VARIABLE_ITEMS){

			for(size_t u = 0; u < _items; ++u)
				if(! readItem(data) )
					throw new StreamException("Data packet too short for array"~_name);	
		}
		else{
			// We don't have array row terminators yet, so just read until hit
			// end of data

			size_t uRead = 0;
			while(readItem(data)) ++uRead;
			
			// Assume that a variable number of items still needs at least one,
			// might be a dubious assumption
			if(uRead == 0)
				throw new StreamException("Data packet too short for array"~_name);
		}
		
		return data;
	}

	long vint(){
		switch(_decode.buf_type){
		case BufferType.TEXT:   return to!long( (cast(const(char)[]) _rawdata)[0] );
		case BufferType.DOUBLE: return to!long( (cast(const(double)[]) _rawdata)[0]);
		case BufferType.FLOAT:  return to!long( (cast(const(float)[]) _rawdata)[0]);
		case BufferType.SHORT:  return to!long( (cast(const(short)[]) _rawdata)[0]);
		case BufferType.INT:    return to!long( (cast(const(int)[]) _rawdata)[0]);
		default:   return (cast(const(int)[])_rawdata)[0];
		}
	}

	double vreal(){
		switch(_decode.buf_type){
		case BufferType.TEXT:   return to!double( (cast(const(char)[]) _rawdata)[0]);
		case BufferType.FLOAT:  return to!double( (cast(const(float)[]) _rawdata)[0]);
		case BufferType.SHORT:  return to!double( (cast(const(short)[]) _rawdata)[0]);
		case BufferType.INT:    return to!double( (cast(const(int)[]) _rawdata)[0]);
		case BufferType.LONG:   return to!double( (cast(const(long)[]) _rawdata)[0]);
		default:
			return (cast(const(double)[])_rawdata)[0];
		}	
	}

	DasTime vtime(){
		if(_units == UNIT_UTC){
			if(_decode.buf_type != BufferType.TEXT)
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
		// If the underlying buffer type is character data, just give it to them
		if(_decode.buf_type == BufferType.TEXT)
			return (cast(string) _rawdata);

		// Okay, it's not so convert something to a string
		if(_decode.sem_type == SemanticType.TIME)
			return vtime().toString();

		if(_decode.sem_type == SemanticType.INTEGER)
			return format("%d", vint());

		return format("%.8e", vreal());
	}

	int opCmp(T)(auto ref const T other) if( is(T == int) || is(T == double) ){
		switch(_decode.sem_type){

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
		if(_decode.sem_type != SemanticType.TIME)
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
	string _name;

	this(Decode decode, PktProp[string] streamProps, DomObj root){

		auto attr = find!(a=> (a.name == "name"))(root.attributes);
		if(attr.empty)
			throw new StreamException(format(
				"Physical dimension name missing in element '%s' at %d",
				root.name, root.pos.line
			));
		_name = attr.front.value.dup;

		// Merge the stream props in with my props, then override later
		foreach(key, val; streamProps)
			_props[key] = val;
		
		foreach(el; root.children){
			if(el.name == "properties")
				mergeProperties(_props, el);

			if(el.name == "array"){
				string usage = "center";
				attr = find!(a=> (a.name == "usage"))(el.attributes);
				if(!attr.empty) usage = attr.front.value.dup;
				
				_arrays[usage] = PktAry(decode, _name, el);
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
	Decode _decode;

	this(Decode decode, PktProp[string] props, XmlStream rXml)
	{
		auto dom = parseDOM(rXml);
		auto root = dom.children[0];

		_decode = cascadeDecode(decode, root.attributes, root.pos.line);

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
			_dims[_readOrder[$-1]] = PktDim( _decode, props, pdim);
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

	Decode _decode; // The default decoding for a stream, unless overridden

	const char[] _data;
	MmFile _mmfile;
	XmlStream _rXml;

	// Only support XML tag types for now, others can be added as needed
	//enum TagType {binary_fixed, binary_var, xml};
	//TagType _tagtype;
	
	PktProp[string] _props;
	DasPkt[int] _pkts;  // Not an array, a map
	int _curPktId = -1;
	string _source;     // Save the data source for error reports

	int getPktId(XmlStream rXml){
		auto attr = find!(a=> (a.name == "id"))(rXml.front.attributes);
		if(attr.empty)
			throw new StreamException(format(
				"[%s:%d] 'id' attribute missing from <%s> element. ",
					_source, rXml.front.pos.line, rXml.front.name
			));
		return to!int(attr.front.value);
	}

public:
	this(string sSource){
		_source = sSource;
		infof("Reading %s", _source);
		_mmfile = new MmFile(_source);
		_data = cast(const(char)[]) _mmfile[];

		_decode.delim.length = 1;
		_decode.delim[0] = ' '; // have to set dynamic array val at runtime
		
		// Determine the container type (only 1 container type for today)
		//if(_data[0] == '[') _tagtype = binary_fixed;
		//else if(_data[0] == '|') _tagtype = binary_var;
		//else _tagtype = xml;

		// Read the stream header
		_rXml = parseXML!(simpleXML)(_data);

		if(_rXml.front.name != "stream")
			throw new StreamException(format("First element is named %s, "~
				"expected 'stream'", _rXml.front.name
			));
		
		_decode = cascadeDecode(
			_decode, _rXml.front.attributes, _rXml.front.pos.line
		);

		// Iterate to next data packet
		popFront();
	}

	@property bool empty() { return (_curPktId > 0); }

	@property ref DasPkt front() {return _pkts[_curPktId];}

	void popFront() {
		int id = 0;

		NEXTPKT: while(!_rXml.empty){
			
			_rXml.popFront();

			// At this point I should have the start of the next element
			if(_rXml.empty) break NEXTPKT;

			switch(_rXml.front.name){
			case "comment":
				_rXml.skipContents();
				continue NEXTPKT;

			case "properties":
				mergeProperties(_props, _rXml);
				continue NEXTPKT;

			case "packet":
				id = getPktId(_rXml);
				_pkts[id] = DasPkt(_decode, _props, _rXml);
				continue NEXTPKT;

			case "d":
				id = getPktId(_rXml);
				if(id !in _pkts)
					throw new StreamException(format(
						"[%s:%d] Data packet id='%d' received before "~
						"header packet %s", _source, _rXml.front.pos.line, id
					));

				_rXml.popFront();
				if(_rXml.front.type != EntityType.text)
					throw new StreamException(format(
						"[%s:%d] Data packet id='%d' is empty", _source, 
						_rXml.front.pos.line, id
					));

				_pkts[id].setData(cast( const(ubyte)[] ) _rXml.front.text);

				break NEXTPKT;  // we have data now

			default:
				throw new StreamException(format(
					"[%s:%d] Unexpected header element '%s'", _source, 
					_rXml.front.pos.line, _rXml.front.name
				));
			}
		}	
	}
}

InputRange!DasPkt inputPktRange(string sFile){
	return inputRangeObject(new InputPktRange(sFile));
}


unittest{

struct DataFiles{

	DasTime _beg, _end;
	InputRange!DasPkt _ds;
	string _indexName;
	const char[] _index;
	bool _empty;
	string _file;

	this(string sIndex, DasTime dtBeg, DasTime dtEnd)
	{
		_indexName = sIndex; _beg = dtBeg; _end = dtEnd;

		auto ipr = new InputPktRange(sIndex); // Public radio is useful

		// Get a das packet stream filtered on our time range, for files 
		// that actually exist on disk
		_ds = ipr
			.filter!(p => p["time", "min"] < _end && p["time", "max"] > _beg)
			.inputRangeObject;

		if(!_ds.empty){
			_file = _ds.front["rel_path"].vchar;
		}
	}

	@property bool empty()  { return _ds.empty; }
	@property string front() return { return _file; }

	void popFront(){
		_ds.popFront();
		if(!_ds.empty){
			_file = _ds.front["rel_path"].vchar;
		}
	}
}

DasTime beg = DasTime("1979-063");
DasTime end = DasTime("1979-079");

string sIndex = "./test/vg1_mag_hg_48s_index.xml";

foreach(el; DataFiles(sIndex, beg, end)){
	writeln("File: ", el, " is in range");
		
}


}