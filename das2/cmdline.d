// Command line program assistance, mostly for das2 readers 
module das2.cmdline;

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
