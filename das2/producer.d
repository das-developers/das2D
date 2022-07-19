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

import std.algorithm: map;
import std.array:     appender, join;
import std.conv:      ConvException;
import std.format:    format;
import std.getopt:    getopt, config, GetoptResult, Option;
import std.stdio:     File, stderr, stdout;
import std.string:    startsWith, strip, wrap;
import std.regex:     regex, splitter;

import dxml.util:     encodeText;

import das2.log:      errorf;

// Code from terminal.d by Adam Druppe.
version(Posix){
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
bool getRdrOpts(T...)(
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
		string sPkt = "<stream version=\"2.3/basic\" lang=\"en\" />\n";
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

/* Packet Buffering and Tagging ******************************************* */

enum DasStreamVer { V22=220, V30=300};
enum DasTagType  { Sx = 0, Hx = 1, Pd = 2};

/+ Structure to hold a stack buffer and and track write points
 +
 + This is a stack memory optimized writer.  A single buffer is used
 + for each instance of this structure. +/
struct DasPktBuf(size_t buf_sz = 65536, DasStreamVer SV = DasStreamVer.V22 )
{
	ubyte[buf_sz] _buf;        
	/* Leave room for a tag with 2 tag bytes, 4 pipe bytes, 10 len bytes
	   and 32 tag bytes, for a total of 48 bytes. */
	immutable(size_t) _iMsgBeg = 48;
	
	size_t _nTagLen   = 0;   // if zero, the tag hasn't been created
	size_t _iMsgWrite = _iMsgBeg;
	DasTagType _tt    = DasTagType.Hs;
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

	void tag(DasTagType tt, ushort id=0){
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
			
			static assert( 
				is(T[I] == float) || is(T[I] == double) || is(T[I] : const(ubyte)[]) ||
				is(T[I] == float[]) || is(T[I] == double[]) , 
				"Type " ~ T[I].stringof ~ " is not supported for das v2.2 streams"
			);
			
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
	
	/+ Return a slice covering the valid formatted bytes, which is a subset of
	 + the full buffer.
	 +/
	ubyte[] bytes(){

		// Prepend the tag into the buffer if it's not present
		if(_nTagLen == 0){
			char[48] buf;
			char[] tag;
			//char[] slice = tag_buf[];
			static if(SV == DasStreamVer.V22){
				if(_tt != DasTagType.Pd)
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

/* Helpers Follow ********************************************************* */

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
