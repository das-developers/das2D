/++ Common utilities for das2 data producers 
 +
 + Programs that produce das2 streams from external data sources are typically
 + called readers.  Many das2 readers need to handle similar tasks including:
 +
 +   * Reading command line arguments
 +   * Writing error messages as stream exceptions
 +   * Serializing data packets
 +
 + which are supported by this module.  Other modules have a more focused
 + scope, for example time conversion and catalog node walking.
 +/

module das2.producer;

import core.stdc.stdlib: exit;

import std.algorithm: copy, map;
import std.array:     appender, join;
import std.bitmanip:  write;
import std.conv:      ConvException, to;
import std.format:    format, sformat;
import std.getopt:    getopt, config, GetoptResult, Option;
import std.range:     ElementType;
import std.regex:     regex, splitter;
import std.stdio:     File, stderr, stdout;
import std.string:    CaseSensitive, indexOf, representation, startsWith, strip, wrap;
import std.system:    Endian;
import std.traits:    isArray, isSomeString;
import std.typecons:  No;

import dxml.util:     encodeText;

import das2.log:      errorf;
import das2.time:     DasTime;
import das2.units:    Units, UNIT_DIMENSIONLESS;

/+ Set the output format for exceptions, properties, etc. +/
enum StreamFmt {INVALID=0, v22=220, v30=300 };

private alias r = representation;

/* Reader command line assistance ***************************************** */

version(Posix){
	// Code from terminal.d by Adam Druppe.
	struct winsize {
		ushort ws_row;
		ushort ws_col;
		ushort ws_xpixel;
		ushort ws_ypixel;
	}

	version(linux){
		extern(C) int ioctl(int, int, ...);
		enum int TIOCGWINSZ = 0x5413;
	}
	else version(OSX) {
		extern(C) int ioctl(int, ulong, ...);
		enum TIOCGWINSZ = 1074295912;
	} else static assert(0, "confirm the value of tiocgwinsz");
}

version(Windows){
	import core.sys.windows.windows;
}

/+ Get the current size of the terminal
 + Falls back to 80x24 columns if nothing can be determined
 + @return A two element integer array containing [columns, rows].
 +/
int[] termSize()
{
	version(Windows) {
		CONSOLE_SCREEN_BUFFER_INFO info;
		GetConsoleScreenBufferInfo( hConsole, &info );

		int cols, rows;

		cols = (info.srWindow.Right - info.srWindow.Left + 1);
		rows = (info.srWindow.Bottom - info.srWindow.Top + 1);

		return [cols, rows];
	}
	else {
		winsize w;
		ioctl(0, TIOCGWINSZ, &w);
		return [w.ws_col, w.ws_row];
	}
}

/+ Get reader command line options.
 + Error messages are sent to stardard error for logging and sent as 
 + a query error message to any remote clients.  All non-machine readable content is
 + always sent to stderr, even when using -h
 +/
bool getRdrOpts(StreamFmt SF, T...)(
	ref string[] aArgs, string name, string synopsis, string usage, string desc,
	string footer, T opts
){
	
	int[] aTermSz = termSize();
	int cols = aTermSz[0];

	string sind = "   ";    // Single indent
	string dind = "      "; // Double indent

	GetoptResult rslt;

	// For narrow terminals, back off the indent.
	if(cols < 60){ sind = "  "; dind = "    ";}
	if(cols < 40){ sind = " ";  dind = "  ";}

	// TODO: Add paragraph split on vertical tab '\v'
	string header = "NAME\n" ~
		wrap(name ~ " - " ~ synopsis, cols, sind, dind) ~ "\n" ~
		"USAGE\n" ~
		wrap(usage, cols, sind, sind) ~ "\n" ~
		"DESCRIPTION\n" ~
		_breakNrap(desc, cols, sind, sind) ~ "\n" ~
		"OPTIONS\n";  // Deal with commands without options later

	if(footer.length > 0) footer = "NOTES\n" ~ wrap(footer, cols, sind, dind);

	try{
		rslt = getopt(aArgs, config.passThrough, opts);
	}
	catch(ConvException ex){
		writeStreamHeader!SF();
		writeException!SF(StreamExc.Query, ex.msg);

		string sPkt = "<stream version=\"2.3/basic\"  />\n";
		stdout.writef("|Hs||%d|%s", sPkt.length, sPkt);

		string sExcept = "<exception type=\"QueryError\">\n"~"\n</exception>";
		//encodeText(ex.msg) ~ "\n</exception>";
		stdout.writef("|He||%d|%s", sPkt.length, sPkt);
		
		errorf("Error parsing command line, %s.\nUse -h for more help", ex.msg);
		return false;
	}

	if(rslt.helpWanted){
		stderr.write(header);
		auto output = appender!(string)();
		_formatOptions(output, rslt.options, cols, "   ", "            ");
		stderr.write(output.data);
		if(footer.length > 0) stderr.write(footer);
		exit(0);
	}

	return true;
}

/* Format getopt options for printing in the style of man page output
 *
 * Params: 
 *   opts = A list of options returned from getopt
 *   width = The total print width in columns, used for text wrapping
 *   indent = The number of columns to leave blank before each line
 *   subIndent = The number of columns to leave blank before the help
 *        text of an item.  This is in addition to the overall indention
 * Returns: a string containing formatted option help text
 */
private string _formatOptions(Output)(
	Output output, Option[] aOpt, size_t ccTotal, string sIndent, string sSubInd
){
	// cc* - Indicates column count
	string sReq = " (Required)";
	string sPre;
	string sHelp;

	size_t ccOptHdr;
	foreach(opt; aOpt){

		// Assume that the short, long and required strings fit on a line.
		auto prefix = appender!(string)();
		prefix.put(sIndent);
		if(opt.optShort.length > 0){
			prefix.put(opt.optShort);
			if(opt.optLong.length > 0) prefix.put(",");
		}
		prefix.put(opt.optLong);
		if(opt.required) prefix.put(sReq);
		sPre = prefix.data;

		// maybe start option help text on the same line, at least one word of
		// the help text must fit
		if(sPre.length < (sIndent.length + sSubInd.length - 1)){
			sPre = format("%*-s ", (sIndent.length + sSubInd.length - 1), sPre);
			sHelp = wrap(strip(opt.help), ccTotal, sPre, sIndent ~ sSubInd);
		}
		else{
			string sTmp = sIndent~sSubInd;
			sHelp = sPre~"\n"~ wrap(strip(opt.help), ccTotal, sTmp, sTmp);
		}
		output.put(sHelp);
		output.put("\n");
	}

	return output.data;
}

// Applies the wrap function to each substring indicated by a vertical tab '\v'
private S _breakNrap(S)(
	S sText, size_t cols = 80, S firstindent = null, S indent = null, size_t tabsize = 2
){

	auto reg = regex(`\v`);

	string s = sText.splitter(reg).
		map!(s => s.wrap(cols, firstindent, indent, tabsize)).
		join();

	return s;
}

/* Packet Buffering and Tagging ******************************************* */

alias BE = Endian.bigEndian;
alias LE = Endian.littleEndian;

enum TagType   {INVALID=0, Sx = 1, Hx = 2, Pd = 3 };

// Das stream exception types (move this somewhere else)
enum StreamExc{ Query, Server, NoData };

string toString(StreamFmt SV)(StreamExc et){
	static if(SV == StreamFmt.v30){
		switch(et){
		case StreamExc.Query: return "QueryError";
		case StreamExc.Server: return "ServerError";
		case StreamExc.NoData: return "NoMatchingData";
		default: break;
		}
	}
	else{
	switch(et){
		case StreamExc.Query: return "IllegalArgument";
		case StreamExc.Server: return "ServerError";
		case StreamExc.NoData: return "NoDataInInterval";
		default: break;
		}
	}
	return "INVALID";
}


/+ Structure to hold a stack buffer and and track write points
 +
 + This is a stack memory optimized writer.  A single buffer is used
 + for each instance of this structure. +/
struct DasPktBuf(size_t buf_sz = 65536, StreamFmt SV = StreamFmt.V30 )
{
	ubyte[buf_sz] _buf;        
	/* Leave room for a tag with 2 tag bytes, 4 pipe bytes, 10 len bytes
	   and 32 tag bytes, for a total of 48 bytes. */
	immutable(size_t) _iMsgBeg = 48;
	
	size_t _nTagLen   = 0;   // if zero, the tag hasn't been created
	size_t _iMsgWrite = _iMsgBeg;
	TagType _tt       = TagType.INVALID;
	ushort _pktId     = 0;
	
	void clear(){
		_pktId = 0;
		_nTagLen = 0;
		_iMsgWrite = _iMsgBeg;
	}
	
	/*
	this(){
		clear();
	}
	*/

	void tag(TagType tt, ushort id=0){
		_tt = tt; _pktId = id;
	}
	
	/+ Write data to the buffer.  Binary items are written as little endian
	 + by default, but this can be set via template parameter.  For strings
	 + the encoding is ignored.
	 +/
	void write(Endian endian = LE, T...)(T args){
		
		//ubyte[] output = _buf[_iMsgWrite .. $];
		//size_t orig_len = output.length;
	   
		foreach(I, arg; args){
			
			static if(SV == StreamFmt.v22){
				static assert( 
					is(T[I] == float) || is(T[I] == double) || is(T[I] : const(ubyte)[]) ||
					is(T[I] == float[]) || is(T[I] == double[]) , 
					"Type " ~ T[I].stringof ~ " is not supported for das v2.2 streams"
				);
			}
			
			// Each arg can be a single item, or an array of items.
			static if( isArray!(T[I])){

				// Skip bit manipulation for single byte types
				static if( (ElementType!(T[I])).sizeof == 1){
					for(int i = 0; i < arg.length; ++i){
						_buf[_iMsgWrite] = cast(ubyte) arg[i];
						++_iMsgWrite;
					}
				}

				// For multi-byte types do the byte shuffle dance
				else{
					foreach(i, item; arg){ 
						_buf[].write!(ElementType!(T[I]), endian)(arg[i], &_iMsgWrite);
					}
				}
			}
			else{
				//output.write!(T[I], endian)(arg,0);
				_buf[].write!(T[I], endian)(arg, &_iMsgWrite);
			}
		}
		//_iMsgWrite += orig_len - output.length;
	}

	/+ Write formatted string data to the buffer.  Encoding should be utf-8 +/
	void writef(alias fmt, Args...)(Args args)
	if (isSomeString!(typeof(fmt))){
		char[] space = cast(char[]) _buf[_iMsgWrite..$];
		char[] used  = sformat!fmt(space, args);

		_iMsgWrite += used.length;
	}
	
	/+ Return a slice covering the valid formatted bytes, which is a subset of
	 + the full buffer.
	 +/
	ubyte[] bytes(){

		// Prepend the tag into the buffer if it's not present
		if(_nTagLen == 0){
			char[48] buf;
			char[] tag;
			//char[] slice = tag_buf[];
			static if(SV == StreamFmt.v22){
				if(_tt != TagType.Pd)
					tag = sformat!"[%02u]%06d"(buf[], _pktId, _iMsgWrite - _iMsgBeg);
				else
					tag = sformat!":%02u:"(buf[], _pktId);
			}
			else{
				// All das v3 tags use the same format
				tag = sformat!"|%s|%d|%d|"(buf[], _tt, _pktId, _iMsgWrite - _iMsgBeg);
			}

			_nTagLen = tag.length;
			_buf[_iMsgBeg - _nTagLen .. _iMsgBeg] = cast(ubyte[])tag;

		}
		return _buf[_iMsgBeg - _nTagLen .. _iMsgWrite];
	}
}

/* Common packet emits **************************************************** */

/* Emitt a query error as a das packet
 *
 * Params: 
 *   opts = A list of options returned from getopt
 *   width = The total print width in columns, used for text wrapping
 *   indent = The number of columns to leave blank before each line
 *   subIndent = The number of columns to leave blank before the help
 *        text of an item.  This is in addition to the overall indention
 * Returns: The value 13, always.
 */

enum PropType {
 	STRING, BOOL, DATETIME, DATETIME_RNG, INT, INT_RNG, REAL, REAL_RNG
};

/+ A simple das properties class, holds a property with it's name 
   type and units +/

struct Property{
	string name;
	PropType type;
	string value;
	Units units;

	string _formatReal(double rValue){
		string temp = format!"%.15e"(rValue);

		// Remove unnessary zeros starting in the second place after the
		// decimal.  Note, this has locale problems!
		long iDot = indexOf(temp, '.');
		long iExp = indexOf(temp, 'e', No.caseSensitive);
		long iEnd = iExp - 1;
		while(iEnd > iDot + 1){
			if(temp[iEnd] == '0') --iEnd;
			else break;
		}
		value = temp[0..iDot] ~ temp[iDot..iEnd+1] ~ temp[iExp..$];
		return value;
	}

	// a universal constructor, probably unneeded
	this(string n, PropType t, string v, Units u = UNIT_DIMENSIONLESS){ 
		name = n; type = t; units = u; value = v; 
	}

	/++ Shortcut for string properties +/
	this(string n, string v, Units u = UNIT_DIMENSIONLESS){
		type = PropType.STRING; name = n; units = u;
		value = v;
	}

	this(string n, long v, Units u = UNIT_DIMENSIONLESS){
		type = PropType.INT; name = n; units = u;
		value = to!string(v);
	}

	/++ Shortcut for boolean properties +/
	this(string n, bool v , Units u = UNIT_DIMENSIONLESS){
		type = PropType.BOOL; name = n; units = u;
		value = v ? "true" : "false";
	}
	
	this(string n, double a, Units u = UNIT_DIMENSIONLESS){
		type = PropType.REAL; name = n; units = u;
		value = _formatReal(a);
	}

	this(string n, DasTime dt, Units u = UNIT_DIMENSIONLESS){
		type = PropType.DATETIME; name = n; units = u;
		value = dt.isoShort();
	}

	this(string n, long a, long b, Units u = UNIT_DIMENSIONLESS){
		type = PropType.INT_RNG; name = n; units = u;
		value = format!("%s to %s")(to!string(a), to!string(b));
	}
	
	this(string n, double a, double b, Units u = UNIT_DIMENSIONLESS){
		type = PropType.REAL_RNG; name = n; units = u;
		value = format!"%s to %s"(_formatReal(a), _formatReal(b));
	}
	
	this(string n, DasTime a, DasTime b, Units u = UNIT_DIMENSIONLESS){
		type = PropType.DATETIME; name = n; units = u;
		value = format!("%s to %s")(a.isoShort(), b.isoShort());
	}

	/++ 
	Return the property as as string that is suitable for writing into
	either a das 2.2 or 3.0 stream.  The output is one of:

	Type:Name="value"                     // v2.2 (bad) attribute style
	<p type="Type" name="Name">Value</p>  // v3.0 element style

	In either case, if the type is String, then the type is dropped
	since that's the default in both systems.
   +/
	string toString(StreamFmt SF)(){
		string sType;
		static if(SF == StreamFmt.v30){
 			switch(type){
	 		case PropType.BOOL:         sType = "bool";          break;
 			case PropType.DATETIME:     sType = "datetime";      break;
 			case PropType.DATETIME_RNG: sType = "datetimeRange"; break;
 			case PropType.INT:          sType = "int";           break;
 			case PropType.INT_RNG:      sType = "intRange";      break;
 			case PropType.REAL:         sType = "real";          break;
 			case PropType.REAL_RNG:     sType = "realRange";     break;
 			default: break;
 			}

 			if(sType.length > 0){
 				if(units != UNIT_DIMENSIONLESS)
 					return format!"<p type=\"%s\" name=\"%s\" units=\"%s\">%s</p>"(
 						sType, name, units.toString(), value
 					);
 				else
 					return format!"<p type=\"%s\" name=\"%s\">%s</p>"(
 						sType, name, value
 					);
 			}
 			else{
 				if(units != UNIT_DIMENSIONLESS)
 					return format!"<p name=\"%s\" units=\"%s\">%s</p>"(
 						name, units.toString(), value
 					);
 				else
 					return format!"<p name=\"%s\">%s</p>"(name, value);
 			}
 		}
 		else{
 			switch(type){
	 		case PropType.BOOL:         sType = "bool";          break;
 			case PropType.DATETIME:     sType = "datetime";      break;
 			case PropType.DATETIME_RNG: sType = "datetimeRange"; break;
 			case PropType.INT:          sType = "int";           break;
 			case PropType.INT_RNG:      sType = "intRange";      break;
 			case PropType.REAL:         sType = "real";          break;
 			case PropType.REAL_RNG:     sType = "realRange";     break;
 			default: break;
 			}

 			if(sType.length > 0){
 				if(units != UNIT_DIMENSIONLESS)
 					return format!"%s:%s=\"%s %s\""(sType, name, value, units.toString());
 				else
 					return format!"%s:%s=\"%s\""(sType, name, value);
 			}
 			else{
 				if(units != UNIT_DIMENSIONLESS)
 					return format!"%s=\"%s %s\""(name, value, units.toString());
 				else
 					return format!"%s=\"%s\""(name, value);
 			}
 		}
	}
}

unittest{
	import core.stdc.locale: LC_ALL, setlocale;
	
	// Pick a locale that happens to use ',' for the decimal separator
	// and see if it messes with real value formatting for properties
	setlocale(LC_ALL, "uk_UA.utf8".ptr);  

	Property p = Property("length", 1.34);

	assert((p.value == "1.34e+00")||(p.value == "1.34E+00"), 
		format!"Unexpected p.value: %s"(p.value)
	);
}

/+ Write a stream header and an arbitary number of properties to stdout +/
void writeStreamHeader(StreamFmt SF)(auto ref Property[] aProp)
{

	if(aProp.length == 0){
		writeStreamHeader!SF();
		return;
	}
   
   char[48] aTag;  // Tags are small, use static buffer
   char[]   pTag;  
	ubyte[]  pPkt;  // Slower dynamic buffer for data since length is unk
	pPkt.reserve(1024);

	static if(SF == StreamFmt.v30){
		pPkt ~= "\n<stream version=\"3.0\" type=\"das-basic-stream\">\n  <properties>\n    ".r;
		pPkt ~= aProp.map!( prop => prop.toString!SF()).join("\n    ").r;
		pPkt ~= "\n  </properties>\n</stream>\n";

		pTag = sformat!"|Sx||%d|"(aTag[], pPkt.length);
	}
	else {
		pPkt ~= "<stream version=\"2.2\" >\n  <properties\n".r;
		pPkt ~= aProp.map!( prop => prop.toString!SF()).join("\n    ").r;
		pPkt ~= "\n  >\n</stream>\n";

		pTag = sformat!"[00]%06d"(aTag[], pPkt.length);
	}

	pTag.copy(stdout.lockingBinaryWriter);
	pPkt.copy(stdout.lockingBinaryWriter);
}

void writeStreamHeader(StreamFmt SF)()
{
	DasPktBuf!(128, SF) pktBuf;
	pktBuf.tag(TagType.Sx);
	static if(SF == StreamFmt.v30){
		pktBuf.write("\n<stream version=\"3.0\" type=\"das-basic-stream\" />\n".r);
	}
	else{
		pktBuf.write("<stream version=\"2.2\" />\n".r);
	}
	pktBuf.bytes.copy(stdout.lockingBinaryWriter);
}

int writeException(StreamFmt SF)(StreamExc et, string sMsg)
{

	char[48] aTag;  // Tags are small, use static buffer
   char[]   pTag;  
	ubyte[]  pPkt;  // Slower dynamic buffer for data since length is unk
	pPkt.reserve(256);

	string sType=et.toString!SF();

	auto sSafeMsg = encodeText( sMsg );
	
	if(SF == StreamFmt.v30){
		pPkt ~= format!"\n<exception type=\"%s\">\n%s\n</exception>\n"(et.toString!SF(), sSafeMsg);
		pTag = sformat!"|Ex||%d|"(aTag[], pPkt.length);
	}
	else{
		pPkt ~= format!"<exception type=\"%s\" message=\"%s\" />\n"(et.toString!SF(), sSafeMsg);
		pTag = sformat!"[XX]%06d"(aTag[], pPkt.length);
	}

	pTag.copy(stdout.lockingBinaryWriter);
	pPkt.copy(stdout.lockingBinaryWriter);
		
	errorf("%s", sMsg.strip());
	return 13;
}
