/** Common utilities needed by many das readers, requires linking with -ldas2 */
module das2.reader;

import std.process;             // environment
import std.stdio;
import std.string;
import core.stdc.stdlib : exit;
import std.experimental.logger;
import std.getopt;
import std.array;



void stop(int nRet){ exit(nRet); }

//////////////////////////////////////////////////////////////////////////////

// Code from terminal.d by Adam Druppe via github,
// License is http://www.boost.org/LICENSE_1_0.txt
//
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

/** Get the current size of the terminal
 *
 * Falls back to 80x24 columns if nothing can be determined
 *
 * @return A two element integer array containing [columns, rows].
 */
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

/** Format getopt options for printing in the style of man page output
 *
 * @param opts A list of options returned from getopt
 * @param width The total print width in columns, used for text wrapping
 * @param indent The number of columns to leave blank before each line
 * @param subIndent The number of columns to leave blank before the help
 *        text of an item.  This is in addition to the overall indention
 * @return a string containing formatted option help text
 */
string formatOptions(Output)(
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

/** Default logger output is too detailed for common usage, provide a logger
 * with cleaner output.
 * Usage:
 *   import std.experimental.logger;
 *   sharedLog = new CleanLogger(stderr, opts.sLogLvl);
 *
 */
class CleanLogger : Logger
{
protected:
	File file_;
	string[ubyte] dLvl;
	
public:
	/** Set the logging level given one of the strings:
	 *
	 *   critical (c)
	 *   error (e)
	 *   warning (w)
	 *   info (i)
	 *   trace (t)
	 *
	 * Only the first letter of the string is significant
	 */
	this(File file, string sLogLvl){
		if(sLogLvl.startsWith('c')) globalLogLevel(LogLevel.critical);
		else if(sLogLvl.startsWith('e')) globalLogLevel(LogLevel.error);
		else if(sLogLvl.startsWith('w')) globalLogLevel(LogLevel.warning);
		else if(sLogLvl.startsWith('i')) globalLogLevel(LogLevel.info);
		else if(sLogLvl.startsWith('d')) globalLogLevel(LogLevel.trace);
		else if(sLogLvl.startsWith('t')) globalLogLevel(LogLevel.trace);
		else if(sLogLvl.startsWith('a')) globalLogLevel(LogLevel.all);
		else globalLogLevel(LogLevel.fatal);
		
		dLvl = [
			LogLevel.all:"ALL", LogLevel.trace:"DEBUG", LogLevel.info:"INFO", 
			LogLevel.warning:"WARNING", LogLevel.error:"ERROR",
			LogLevel.critical:"CRITICAL", LogLevel.fatal:"FATAL",
			LogLevel.off:"OFF"
		];

		super(globalLogLevel()); 
		this.file_ = file;
	}
	
	override void writeLogMsg(ref LogEntry entry){
		auto lt = file_.lockingTextWriter();
      lt.put(dLvl[globalLogLevel()]);
      lt.put(": ");
      lt.put(entry.msg);
      lt.put("\n");
	}	
}


/** Returns a top level working directory for the current project or the empty
 * string.
 */
string getPrefix(){
	string sPrefix = environment.get("PREFIX");
	if(sPrefix is null){
		sPrefix = environment.get("HOME");
		if(sPrefix is null){
			sPrefix = environment.get("USERPROFILE");
			if(sPrefix is null){
				warningf("Cannot determine top level project directory"~
				" tired environment vars PREFIX, HOME, USERPROFILE in that order.");
				return "";
			}
		}
	}
	return sPrefix;
}
