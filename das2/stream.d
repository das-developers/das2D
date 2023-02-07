module das2.stream;

import std.algorithm: filter, find, endsWith, skipOver;
import std.conv:      to;
import std.file:      exists, isFile;
import std.format:    format;
import std.mmfile:    MmFile;
import std.range;
import std.string:    toLower, indexOfAny, strip;
import std.system:    Endian, endian;
import std.typecons:  Tuple;


import dxml.parser; //parseXML, simpleXML, EntityType, Entity;
import dxml.dom;    //

import das2.util;  // force initilization of libdas2.so/.dll first

import das2.time;
import das2.units;
import das2.log;
import das2c.tt2000: das_tt2K_to_utc;

alias XmlStream = EntityRange!(simpleXML, const(char)[]);
alias DomObj = DOMEntity!(XmlStream.Input);

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
size_t mergeProperties(PktProp[string] props, DomObj dom)
{
	size_t uPropsSet = 0;

	foreach(elProp; dom.children){
		if(elProp.type != EntityType.elementStart) continue;
		if(elProp.name != "p") continue;  // Ignore what you don't understand

		string name;
		PropType type = PropType.STR;
		foreach(attr; elProp.attributes){
			if(attr.name == "name"){ name = attr.value.dup; continue;}
			if(attr.name == "type"){
				switch(attr.value){
				case "Datum":      type = PropType.DATUM;     break;
				case "boolean":    type = PropType.BOOL;      break;
				case "integer":    type = PropType.INTEGER;   break;
				case "real":       type = PropType.REAL;      break;
				case "DatumRange": type = PropType.DATUM_RNG; break;
				case "realRange":  type = PropType.REAL_RNG;  break;
				default:
					throw new DasException(format(
						"Unknown property type '%s' at line %d", attr.value, elProp.pos.line
					));
				}
			}
		}

		if(name.length == 0)
			throw new DasException(format(
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
					throw new DasException(format(
						"Property '%s' at line %d contains an alternate "~
						"langage setting, but is not a string property ",
						name, subItem.pos.line
					));

				auto attr = find!(a=> (a.name == "lang"))(subItem.attributes);
				if(attr.empty)
					throw new DasException(format(
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

// Expect to receive a stream stopped at the <properties> element
// return stream at start on next element (not our end tag )
size_t mergeProperties(PktProp[string] props, ref XmlStream rXml)
{
	// TODO: Handle screwed-up das2.2 'type:name="thing"' style properties.
	// Can't believe I didn't nip that travesty in the bud in 2012. -cwp

	rXml.popFront();
	if(rXml.front.type == EntityType.elementStart && rXml.front.name == "p"){
		auto dom = parseDOM(rXml);
		return mergeProperties(props, dom);
	}
	return 0;
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

version(BigEndian){
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
version(BigEndian){
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
				warnf("Unknown stream version '%s' this might not go well", attr.value);
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
						throw new DasException("Individual values larger than 64 kB are not supported");
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
				throw new DasException(format(
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
version(BigEndian){
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
					throw new DasException(format("Unknown value type '%s' in "~
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
			_rawdata.reserve = _decode.blks_per_item * _items;
		}
		else{
			// take a guess
			_rawdata.reserve = 32;  // Should get most isotime and text values
		}

		if(_decode.blks_per_item == VARIABLE_WIDTH && _decode.delim.length == 0){
			throw new DasException(format("Element <array> at %d has variable "~
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
			throw new DasException(format(
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
		size_t oldlen;

		if(uDlmSz > 0)
			while(data.skipOver(_decode.delim)){ } // shortens the range

		if(uItemBlks > 0){
			size_t uAll = uItemBlks * uBlkSz;

			oldlen = _rawdata.length;
			_rawdata.length += uAll;

			if(data.length < uAll) return false;

			if(!_decode.swap || uBlkSz == 1){
				_rawdata[oldlen..oldlen+uAll] = data[0..uAll]; // all in one go
				data = data[uAll..$]; // Shortens the range
			}
			else{
				// swap copy each block
				for(size_t u = 0; u < uItemBlks; ++u){
					size_t u0 = oldlen + u*uBlkSz;

					swapCopyN(_rawdata[u0 .. u0+uBlkSz], data, uBlkSz);
					data = data[uBlkSz .. $];
				}
			}

			return true;
		}
		else{  // Variable number of blocks per item, read till delim or no more data
			
			bool bItemRead = false;

			if(uDlmSz == 0)
				throw new DasException("No delimiter set for variable length items");


			while((data.length >= uBlkSz) && (data[0..uDlmSz] != _decode.delim)){

				// Okay to do this in a loop singe the same array is reused on
				// subsequent packets ?
				oldlen = _rawdata.length;
				_rawdata.length += uBlkSz;

				if(!_decode.swap || uBlkSz == 1) 
					_rawdata[oldlen .. oldlen+uBlkSz] = data[0 .. uBlkSz];
				else
					swapCopyN(_rawdata[oldlen .. oldlen+uBlkSz], data, uBlkSz);

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
				if(! readItem(data) ) throw new DasException(format(
					"Data packet too short for array '%s'", _name, ));	
		}
		else{
			// We don't have array row terminators yet, so just read until hit
			// end of data

			size_t uRead = 0;
			while(readItem(data)) ++uRead;
			
			// Assume that a variable number of items still needs at least one,
			// might be a dubious assumption
			if(uRead == 0)
				throw new DasException("Data packet too short for array"~_name);
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
				throw new DasException("units=\"UTC\" but raw data are not characters");
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

		throw new DasException(format(
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
				throw new DasException(format(
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
			throw new DasException(format(
				"Text strings are not comparible to %s", typeid(T))
			);
		}
	} 

	int opCmp(T)(auto ref const T other) if( is(T:DasTime) ){
		if(_decode.sem_type != SemanticType.TIME)
			throw new DasException("Non-time values can't be compared to a DasTime");
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

		_readOrder.reserve = 5;  // typical dims have about 2 arrays

		auto attr = find!(a=> (a.name == "pdim"))(root.attributes);
		if(attr.empty)
			throw new DasException(format(
				"Physical dimension name missing in element '%s' at line %d",
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
				_readOrder ~= usage;
			}

			if(el.name == "xcoord" || el.name == "ycoord" ||el.name == "zcoord"){
				throw new DasException(format(
					"Offset coordinate handling is yet implemented for '%s' at line %d",
					el.name, el.pos.line
				));
			}

			// Ignore anything else
		}
	}

	// Initialize PktDim objects using sections of the data
	const(ubyte)[] setData(const(ubyte)[] data)
	{
		for(int i = 0; i < _readOrder.length; ++i){
			data = _arrays[_readOrder[i]].setData(data);
		}

		return data;
	}

	ref PktAry opIndex(string sUsage){
		return _arrays[sUsage];
	}
}

/* ************************************************************************* */

struct DasPkt {
	int _id;  // The packet ID
	PktDim[string] _dims;
	string[] _readOrder;
	ubyte[] _delim;
	Decode _decode;

	this(int id, Decode decode, PktProp[string] props, ref XmlStream rXml)
	{
		_id = id;
		_readOrder.reserve = 10; // This is huge, typical packets have like 3 arrays

		_decode = cascadeDecode(decode, rXml.front.attributes, rXml.front.pos.line);

		if(rXml.front.type == EntityType.elementEmpty)
			throw new DasException(format(
				"Packet at line %d has no arrays", rXml.front.pos.line));

		rXml.popFront();  // now at first content
		auto dom = parseDOM(rXml);

		foreach(pdim; dom.children){
			if(pdim.name == "yset" || pdim.name == "zset" || pdim.name == "wset")
				throw new DasException("yset, zset & wset reading not yet implemented");

			
			if(pdim.name != "x" && pdim.name != "y" && pdim.name != "z")
				throw new DasException(format(
					"Skipping custom content, '%s' is not yet implemented", pdim.name
				));

			auto attr = find!(a=> (a.name == "pdim"))(pdim.attributes);
			if(attr.empty)
				throw new DasException(format("Required attribute 'pdim' missing from element '%s'", pdim.name));
			
			_readOrder ~= attr.front.value.dup;
			_dims[_readOrder[$-1]] = PktDim(_decode, props, pdim);
		}
	}

	@property int id() const { return _id;} 

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
class DasStream{
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
	int _iCurPkt = -1;
	string _source;     // Save the data source for error reports

	int getPktId(XmlStream rXml){
		auto attr = find!(a=> (a.name == "id"))(rXml.front.attributes);
		if(attr.empty)
			throw new DasException(format(
				"[%s:%d] 'id' attribute missing from <%s> element. ",
					_source, rXml.front.pos.line, rXml.front.name
			));
		return to!int(attr.front.value);
	}

public:
	this(string sSource){
		_source = sSource;
		infof("Reading %s", _source);
		isFile(_source);  // throw file exception if not readable
		_mmfile = new MmFile(_source);
		_data = cast(const(char)[]) _mmfile[];

		_decode.delim.length = 1;
		_decode.delim[0] = ' '; // have to set dynamic array val at runtime
		
		// Determine the container type (only 1 container type for today)
		//if(_data[0] == '[') _tagtype = binary_fixed;
		//else if(_data[0] == '|') _tagtype = binary_var;
		//else _tagtype = xml;

		_rXml = parseXML!(simpleXML)(_data);

		if(_rXml.front.name != "stream")
			throw new DasException(format("First element is named %s, "~
				"expected 'stream'", _rXml.front.name
			));
		
		_decode = cascadeDecode(
			_decode, _rXml.front.attributes, _rXml.front.pos.line
		);

		// Drop down to the first component in the stream, making sure we don't 
		// have an empty stream
		if(_rXml.front.type != EntityType.elementEmpty){
			_rXml.popFront();  // Should be at properties, x, y, z, comment etc.

			// If this is an end tag, we have an empty stream
			if(_rXml.front.type != EntityType.elementEnd)
				popFront();
		}
	}

	@property bool empty() { return (_iCurPkt < 0); }

	@property ref DasPkt front() {return _pkts[_iCurPkt];}

	void popFront() {
		int id = 0;
		_iCurPkt = -1;

		NEXTPKT: while(!_rXml.empty){

			// At this point I should have the start of the next element
			if(_rXml.empty) break NEXTPKT;

			// The only time the top of the loop should start with the end
			// of an element is when we close the stream.
			if(_rXml.front.type == EntityType.elementEnd){
				_rXml.popFront();  // and now we are done.
				break NEXTPKT;
			}

			switch(_rXml.front.name){
			case "comment":
				if(_rXml.front.type == EntityType.elementStart)
					_rXml.skipContents();
				else
					_rXml.popFront();
				continue NEXTPKT;

			case "properties":
				mergeProperties(_props, _rXml); // Bumps to next top
				continue NEXTPKT;

			case "packet":
				id = getPktId(_rXml);
				_pkts[id] = DasPkt(id, _decode, _props, _rXml);
				continue NEXTPKT;

			case "d":
				id = getPktId(_rXml);
				if(id !in _pkts)
					throw new DasException(format(
						"[%s:%d] Data packet id='%d' received before "~
						"header packet", _source, _rXml.front.pos.line, id
					));

				_rXml.popFront();
				if(_rXml.front.type != EntityType.text)
					throw new DasException(format(
						"[%s:%d] Data packet id='%d' is empty", _source, 
						_rXml.front.pos.line, id
					));

				_pkts[id].setData(cast( const(ubyte)[] ) _rXml.front.text);

				_rXml.popFront();
				assert(_rXml.front.type == EntityType.elementEnd);
				_rXml.popFront();

				_iCurPkt = id; 
				break NEXTPKT;    // we have data now

			default:
				throw new DasException(format(
					"[%s:%d] Unexpected header element '%s'", _source, 
					_rXml.front.pos.line, _rXml.front.name
				));
			}
		}	
	}
}

InputRange!DasPkt dasStream(string sFile){
	return inputRangeObject(new DasStream(sFile));
}


unittest{
	import std.stdio;

	string[] matching = [
		"../cdaweb/summary/v1/y79/48s/s48v17934600.dua",
		"../cdaweb/summary/v1/y79/48s/s48v17935100.dua",
		"../cdaweb/summary/v1/y79/48s/s48v17935600.dua",
		"../cdaweb/summary/v1/y79/48s/s48v17936100.dua",
		"../cdaweb/summary/v1/y80/s48v18000100.dua",
		"../cdaweb/summary/v1/y80/s48v18000600.dua"
	];

	auto beg = DasTime("1979-350");
	auto end = DasTime("1980-010");

	auto d2s_xml_file = "./test/vg1_mag_hg_48s_index.xml";

	auto stream = new DasStream(d2s_xml_file);

	auto filtered_stream = stream
		.filter!(pkt => pkt["time", "min"] < end && pkt["time", "max"] > beg);

	int i = 0;
	foreach(pkt; filtered_stream){
		assert(pkt["rel_path"].vchar == matching[i]);
		++i;
	}

	writefln("INFO: das2.stream unittest passed");
}


/* ************************************************************************ */
/* 2023 Iteration!!! 
 *
 * NOTE: This version came out after the version above.  They do NOT read
 *       the same XML schemas.  The code above is outdated.  Once the 
 *       Voyager time index readers are updated the ideas above and the 
 *       ideas below can be merged.  -cwp 2023-02-06
 */

/* Raw Reading of das3 tagged items from 1-N input file names */

import das2.producer:  TagType;

/++ Raw unparsed packets +/
struct RawPkt{
	TagType tag;
	ushort  id;
	const(ubyte)[] data;
}

/++ Basic das3 packet reading by shortening the input range.
 + 
 + Params:
 +   pSrc = Anything that has slice semantics, including a memory mapped file struct 
 +          The input range is shortened to the remaining un-read bytes
 + 
 + Returns:
 +   A tuple containing the packet tag, packet id and data pointer
 +
 + Raises:
 +   DasException if there is a problem parsing the next packet
 +/
RawPkt readTaggedPkts(PTR)(ref PTR pSrc)
{
	RawPkt tRet;	

	tRet.tag = TagType.INVALID;
	tRet.id  = 0;

	// The normal return
	// The correct return
	if(pSrc.length == 0)
		return tRet;

	// Get four pipes
	ulong[4] aPipes = 0;
	long nSet = 0;
	ulong uPos = 0;
	while((nSet < 4)&&(uPos < pSrc.length)){
		if(pSrc[uPos] == cast(byte)'|'){
			aPipes[nSet] = uPos;
		}
		uPos += 1;
		nSet += 1;
	}
	if(nSet < 4)  // Couldn't get 4 pipes before hitting the end of the file
		return tRet;
	// Type tag is not 2 bytes long, or data length is not more then 10 chars long 
	// or less then 1 char long
	if(((aPipes[1] - aPipes[0]) != 3)||((aPipes[3] - aPipes[1]) < 2)||
		((aPipes[3] - aPipes[2]) > 11)
	){
		throw new DasException("Maleformed packet tag");
	}
	// See if we recognize the tag
	string sTag = to!string( pSrc[ aPipes[0]+1 .. aPipes[1]] );
	switch(sTag){
	case "Sx": tRet.tag = TagType.Sx; break;
	case "Hx": tRet.tag = TagType.Hx; break;
	case "Pd": tRet.tag = TagType.Pd; break;
	case "Cx": tRet.tag = TagType.Cx; break;
	case "Ex": tRet.tag = TagType.Ex; break;
	case "XX": tRet.tag = TagType.XX; break;
	default:
		return tRet;
	}
	// Okay, now get the packet ID
	if((aPipes[2] - aPipes[1]) > 1){
		string _buf = to!string(pSrc[ aPipes[1]+1 .. aPipes[2] ]);
		string sId = _buf.strip();
		try{
			tRet.id = to!ushort(sId);
		}
		catch(ConvException ex){
			throw new DasException(ex.toString());
		}
	}
	// Get the length
	ulong uLen;
	try{
		string _buf = to!string(pSrc[ aPipes[2]+1 .. aPipes[3]]);
		uLen = to!ulong( to!int(_buf.strip() ));
	}
	catch(ConvException ex){
		throw new DasException("Invalid packet length");
	}
	if(uLen > (pSrc.length - (aPipes[3]+1))){
		throw new DasException(
			format!"Next packet is %d bytes long, but only %d reamian to read"(
			uLen, pSrc.length - (aPipes[3]+1)
		));
	}

	ulong uBeg = aPipes[3]+1;
	ulong uEnd = aPipes[3] + 1 + uLen;
	tRet.data = pSrc[uBeg .. uEnd];

	// Shorten the range...
	pSrc = pSrc[uEnd .. $];

	return tRet;
}

// Given a range of file names that should be das3 stream files, produce a range simple
// packet structures
struct RawPktRdr(R)
	if(isInputRange!R && is(ElementType!R == string))
{

public:
	R _names;
	MmFile _file;
	bool _empty;
	const(ubyte)[] _unread;
	RawPkt _rawPkt;


	this(R names){
		_names = names;
		if(_names.empty() ){
			_empty = true;
		}
		else{
			// Setup the conditions for the first call of nextPkt
			_empty = false;
			_file = new MmFile(_names.front);
			_unread = cast(const(ubyte)[]) _file[];
			_empty = ! nextPkt();     // <-- sets _rawPkt if it can
		}
	}

	@property RawPkt front(){ return _rawPkt;}
	@property bool empty(){ return _empty; }

	void popFront(){
		_empty = !nextPkt();
	}

private:
	// Return true if there is a next packet
	bool nextPkt(){
		if(_empty) return false;

		PKT_LOOP: while(true){

			// If this file is exhausted, try to get a next one
			FILE_LOOP: while((_unread.length == 0)&&(!_names.empty)){
				_file = null;
				_names.popFront();
				if(_names.empty)
					return false;  // no more packets

				_file = new MmFile(_names.front, MmFile.Mode.read, 0, null);
				_unread = cast(const(ubyte)[]) _file[];

				// This *could* be an empty length file, be read to try again
			}

			// Read the next packet see if we care about it
			_rawPkt = readTaggedPkts(_unread); // Shortens the range

			if(_rawPkt.tag == TagType.INVALID){
				_unread = [];          // Set the file done and...
				continue PKT_LOOP;     // try again
			}
			else
				break PKT_LOOP;        // We set a good rawPkt
		}

		return true;
	}
}

/++ Turn a range of das3 filenames into a range of das3 packets +/
RawPktRdr!R rawPktRdr(R)(R names){
	return RawPktRdr!R(names);
}
