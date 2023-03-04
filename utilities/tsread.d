import core.stdc.stdlib: exit;

import std.format:    format;

import das2.log:      loglevel, infof;
import das2.producer: LE, PktBuf, StreamFmt, StreamExc, TagType, getRdrOpts, 
	writeStreamHeader, writeException; 
import das2.time:     DasTime;


version(das2){
	immutable(StreamFmt) DASVER = StreamFmt.v22;
	const string PROG = "das2_tsread";
	const string STREAM_VER = "v2.2";
}
version(das3){
	immutable(StreamFmt) DASVER = StreamFmt.v30;
	const string PROG = "das3_tsread";
	const string STREAM_VER = "v3.0";
}

/* ************************************************************************ */

int main(string[] argv){
	string sLogLevel = "info";
	string sTimeCols = "0";
	string sTimeGroup;
	string sColDelim;

	if(! getRdrOpts!(StreamFmt.v22)(argv,
		PROG, //name

		// Summary
		"Read time series data from a set of files and output a das "~STREAM_VER~" stream",

		// Usage
		PROG~" [options] PATTERN BEGIN END [OUT_FIELDS]",

		// Description
		PROG~" uses a path name pattern to find files corresponding to a given
		given time range and outputs a das "~STREAM_VER~" stream.  By default
		all fields are output, which you typically don't want.  Thus an optional
		list of field names (or numbers) can be supplied.",

		// Footer
		"Maintainer: Chris Piker <chris-piker@uiowa.edu>",
		
		// Optional Args
		"level|l",
		"The console logging level, one of debug, info, warning, error.  Defaults
		to warning.", &sLogLevel,

		"time|t", "Provide a column number set for the time field", &sTimeCols,

		"group|g", "Provide extra data for time groups via an ancillary file.
		Group times can be included in path name patterns.  Often this is
		used to collect files by orbit.", &sTimeGroup,
		
		"delim|d", "The field delimiter, useful for CSV files.  By default
		text files are assumed to be TABular data and columns are separated 
		by whitespace.", &sColDelim
	)) exit(13);

	loglevel(sLogLevel);

	if(argv.length < 4){
		writeStreamHeader!DASVER();
		return writeException!DASVER(StreamExc.Query,
			format!"Usage: %s [options] PATTERN BEGIN END [COLUMNS].  Use -h for more help."(PROG)
		);
	}

	string sBeg   = argv[1];
	string sEnd   = argv[2];
	DasTime dtBeg, dtEnd;
	try{
		dtBeg = DasTime(sBeg);
		dtEnd = DasTime(sEnd);
	}
	catch(Exception ex){
		writeStreamHeader!DASVER();
		return writeException!DASVER(StreamExc.Query, ex.msg);
	}

	size_t uPktsOut = 0;
/*	try{
		timeCoverageFiles(toPath, 86400, dtBeg, dtEnd)
			.tee!(s => infof("Reading %s", s))
			.rowFilter(dtBeg, dtEnd)
			.tee!(_ => uPktsOut++)
			.pktWriter(pCols)
			.flushBinWriter();
	}
	catch(Exception ex){
		writeStreamHeader!DASVER();
		return writeException!DASVER(StreamExc.Server, ex.msg);
	}
*/
	if(uPktsOut == 0)
		writeException!DASVER(StreamExc.NoData, format!"No data in range %s to %s"(sBeg, sEnd));
	else
		infof("%u packets processed for range %s to %s", uPktsOut, sBeg, sEnd);

	return 0;
}

/* ************************************************************************ */
/* Helpers */

/* 
Orbit[] loadOrbits(string sRoot){
	Orbit[] pOrbs;
	foreach(sLine; File(sRoot).byLine()){
		if(sLine[0] == '#') continue;
		auto lLine = sLine.split(',');
		pOrbs ~= Orbit(DasTime(lLine[0]),DasTime(lLine[1]),to!int(lLine[2])));
	}
	return pOrbs;
}

/++ Given a time, return the path associated.  There need not be a file at 
 + this path.
 +/
string toPath(DasTime dt){
	int nOrb = -1;
	Orbit orb;
	foreach(testOrb; g_pOrbits){
		if((testOrb.beg <= dt)&&(dt < testOrb.end )){
			orb = testOrb;
			break;
		}
	}
	if(orb.num == -1) return [];

	// Special item: If this day is the same day as the start of an orbit
	// we have to give the start hour, min & second
	int nHr = 0, nMin = 0, nSec = 0;
	if((dt.year == orb.beg.year)&&(dt.yday == orb.beg.yday)){
		nHr = orb.beg.hour; nMin = orb.beg.minute;
		nSec = cast(int) orb.beg.sec;  // truncates
	}

	string sPath = format!(
		"%s/%04d%03d_orbit_%02d/wav_%04d-%03dT%02d-%02d-%02d_e-dens-%s_v1.0.csv"
	)(
		g_sRoot, orb.beg.year, orb.beg.yday, nOrb, // dir name
		dt.year, dt.yday, nHr, nMin, nSec          // file name
	);

	return sPath;
}

*/

/* ************************************************************************ */

/* What this should look like... */
/+
   das2_ts_reader -g "/project/juno/etc/pds/orbits.conf" 
   -d ";" -t col0 
   "/project/juno/data/flight/juno-waves-electron-density/data"~
   "/{group.min.year}{group.min.yday}_orbit_{group.data0}"~"
   "/wav_{min.year}-{min.yday}T*_e-dens-j_{version}.csv" 

   2021-01-01 2022-02-03 "Marked BMag Fce Fci Fpe Fpe/Fce"

	das3_ts_reader -p 
+/