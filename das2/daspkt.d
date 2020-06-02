module das2.daspkt;

/** Traditional Das2 functionality we've grown used to having in any
 * Language
 */

import std.datetime;
import std.algorithm.searching;
import std.array;
import std.stdio;
import std.format;
import std.bitmanip;
import std.traits;
import std.string;

/** ************************************************************************
 * Handles buffering data and prepending proper header ID's for Das2 Headers
 * All output is in UTF-8.
 */
class HdrBuf{

	enum HeaderType {
		das2 = 1,   /** Output headers without the <?xml version info */
		qstream = 2 /** Include <?xml version declairation on each header packet */
	};

	HeaderType m_type;
	string[] m_lText;
	int m_nPktId;

	this(int nPktId, HeaderType ht = HeaderType.das2){
		assert(nPktId > -1 && nPktId < 100, format("Invalid Packet ID: %s", nPktId));

		m_nPktId = nPktId;
		m_type = ht;
		if(m_type == HeaderType.qstream)
			m_lText[0] = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	}

	void add(in string sText){ 	m_lText ~= sText;  }

	void addf(T...)(T args) { m_lText ~= format(args); }

	void send(File fOut){
		string sOut = join(m_lText);
		fOut.writef("[%02d]%06d%s", m_nPktId, sOut.length, sOut);
		fOut.flush();
		m_lText.length = 0;
		if(m_type == HeaderType.qstream)
			m_lText[0] = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	}
}
/****************************************************************************
 * Handles outputting data packets for das2 streams and qstreams
 */

class PktBuf{
	enum Endian { big = 1, little = 2};

	int m_nPktId;
	ubyte[][] m_aData;
	Endian m_endian = Endian.little;

private:
	final void startPkt(){
		string s = format(":%02d:", m_nPktId);
		m_aData.length = 1;
		m_aData[0] = new ubyte[s.length];
		for(int i = 0; i < s.length; i++) m_aData[0][i] = s[i];
	}

public:

	this(int nPktId){
		assert(nPktId > 0 && nPktId < 100, format("Invalid Packet ID: %s", nPktId));
		m_nPktId = nPktId;
		startPkt();
	}

	void encodeLittleEndian(){
		m_endian = Endian.little;
	}
	void encodeBigEndian(){
		m_endian = Endian.big;
	}

	void add(immutable(ubyte)[] uBytes){
		ulong u = m_aData.length;
		foreach(size_t v, ubyte b; uBytes) m_aData[u][v] = b;
	}

	void addf(T...)(T args) {
		string s = format(args);
		m_aData.length += 1;
		m_aData[$-1] = new ubyte[s.length];
		for(int i = 0; i < s.length; i++) m_aData[$-1][i] = s[i];
	}

	void addFloats(T)(in T[] lNums)
	     if (isAssignable!(T, float))
	{
		float val;
		ubyte[4] bytes;
		ubyte[] allBytes = new ubyte[ lNums.length * 4 ];

		foreach(int i, T t; lNums){
			val = t;
			if(m_endian == Endian.little) bytes = nativeToLittleEndian(val);
			else bytes = nativeToBigEndian(val);

			for(int j; j < 4; j++) allBytes[i*4 + j] = bytes[j];
		}

		m_aData.length += 1;
		m_aData[$-1] = allBytes;
	}

	void send(File fOut){
		ubyte[] uOut = join(m_aData);
		fOut.rawWrite(uOut);
		fOut.flush();
		m_aData.length = 0;
		startPkt();
	}
}


immutable char[] DAS2_EXCEPT_NODATA = "NoDataInInterval";
immutable char[] DAS2_EXCEPT_BADARG = "IllegalArgument";
immutable char[] DAS2_EXCEPT_SRVERR = "ServerError";

/**************************************************************************
 * Send a formatted Das2 exception
 * Params:
 *  fOut = The file object to receive the XML error packet
 *  sType = The exception type. Use one of the pre-defined strings
 *          DAS2_EXCEPT_NODATA
 *          DAS2_EXCEPT_BADARG
 *          DAS2_EXCEPT_SRVERR
 *  sMsg = The error message
 */
void sendException(File fOut, string sType, string sMsg){
	auto sFmt = "<exception type=\"%s\" message=\"%s\" />\n";
	sMsg = sMsg.replace("\n", "&#13;&#10;").replace("\"", "'");
	auto sOut = format(sFmt, sType.replace("\"", "'"), sMsg);
	fOut.writef("[xx]%06d%s", sOut.length, sOut);
}


/* ************************************************************************ */
/* Help text looks like trash, improve printing */

//void helpPrinter(string sHdr, GetoptResult res){
//	Output output = stdout.lockingTextWriter();
//
//}





















