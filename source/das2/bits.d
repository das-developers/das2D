module das2.bits;

import std.algorithm: canFind;
import std.exception: enforce;
import std.format:    format;

import das2.producer: StreamFmt, ValueType;

// Flags corresponding to the output types given in:
//     das-basic-stream-v3.0.xsd  
//  which is the authoritative upstream source.


// Should use the C structure instead!
enum EncodingType {
	NONE=0, BYTE, UBYTE, UTF8, BE_INT, BE_UINT, BE_REAL, LE_INT, LE_UINT, LE_REAL
};


/+ Handle extracting bit fields to a buffer.
 +
 + BitReaders are useful for translating bit-fields into das stream values.
 + The various valuetypes and encoding types are taken from:
 +
 +   das-basic-stream-v3.0.xsd
 +   das-basic-stream-v2.2.xsd
 +
 + in the das2docs repoistory, which are the authoritative source of encodings
 + for das3 and das2 streams streams repectively
 +
 + Examples:
 + --------------
 + ubyte[] pDat;  // The upstream data buffer
 + 
 + BitReader seqNo = BitReader(
 +   "SeqNo", 11, 3, "LEuint", 2, "bool", "Packet Sequence Number"
 + );
 + BitReader rawTemp = BitReader(
 +   "TMON", 12, 200, "LEuint", 2, "int", "LF preamp 1 temperature"
 + );
 +
 + // Write L0 (non calibrated data)
 + PktBuf(800, StreamFmt.v30) packet;
 + packet.write(seqNo(pDat), rawTemp(pDat));
 +
 + // Write L1 (calibrated data using polynomial set)
 + CalReader celsius = CalReader(rawTemp, [26.4, 20.0], "°C");
 + packet.write(celcius(pDat));
 + --------------
 +
 +/
struct BitReader(StreamFmt SF = StreamFmt.v30){
	string name;
   ubyte  inBits;
	size_t inOffset;
	EncodingType encType;
	ushort  encLen;
	ValueType valType;
	string title;
	bool   ignore = true;
	private ubyte[8] _buf = 0;

	/++ Create a bit parser, minimal verision 
	 +
	 + Params:
	 +   name = A short name for this field, should follow rules for a
	 +      legal variable name in most languages
	 +   inBits = The number of input bits in the field
	 +   inOffset = The offset *in bits* at which the field starts in a blob
	 +   dasEncode = A Das Encoding for the output, one of:
	 +      "ubyte","","","",""
	 +/
	this(
		string name, ubyte inBits, size_t inOffset, string encodeType, 
		ubyte encodeLen, string valueType = "", string title = ""
	){
		this.name = name;
		this.inBits = inBits;
		this.inOffset = inOffset;

		// These are taken from das-basic-stream-v3.0.xsd
		switch(encodeType){
			case "ubyte":  encType = EncodingType.UBYTE;   break;
			case "utf8" :  encType = EncodingType.UTF8;    break;
			case "BEint":  encType = EncodingType.BE_INT;  break;
			case "BEuint": encType = EncodingType.BE_UINT; break;
			case "BEreal": encType = EncodingType.BE_REAL; break;
			case "LEint":  encType = EncodingType.LE_INT;  break;
			case "LEuint": encType = EncodingType.LE_UINT; break;
			case "LEreal": encType = EncodingType.LE_REAL; break;
			default:
				enforce(false, format!"Unknown encoding %s"(encodeType));
		}

		encLen = encodeLen;
		if(encType != EncodingType.UBYTE && encType != EncodingType.UTF8)
			enforce([1u, 2u, 4u, 8u].canFind(encLen), 
				format!"Invalid encoding length of %d for %s"(encLen, encodeType)
			);
		
		// These are taken from das-basic-stream-v3.0.xsd
		switch(valueType){
			case "bool":     valType = ValueType.BOOL; break;
			case "datetime": valType = ValueType.DATETIME; break;
			case "int":      valType = ValueType.INT; break;
			case "real":     valType = ValueType.REAL; break;
			case "string":   valType = ValueType.STRING; break;
			default:         valType = ValueType.UNKNOWN; break;
		}

		this.title = title;
	}

	/++ Since das3 stream values are never smaller than 1-byte, return the 
	 + bit field as a byte array, with the proper endianness +/
   ubyte[] opCall(ubyte[] pIn){

   	// Example Input: offset=19  length=11
   	//             1          2          3       
   	//  01234567 89012345 67890123 45678901 23456789
   	// +--------+--------+--------+--------+--------+
   	// |        |        |   XXXXX|XXXXXX  |        |
   	// +--------+--------+--------+--------+--------+
   	//
   	// Example Output (endian retained):
   	//
   	//  01234567 89012345
   	// +--------+--------+
   	// |00000XXX|XXXXXXXX|
   	// +--------+--------+
   	//
   	// Example Output (endian swapped):
   	//
   	//  01234567 89012345
   	// +--------+--------+
   	// |XXXXXXXX|00000XXX|
   	// +--------+--------+

   	// Algorithm:
   	// * Take last two bytes of source as a ushort,
   	//   ushort last2 = to!ushort(pIn[iEnd - 1 .. iEnd + 1]);
   	//
   	// * Downshift by uShift, truncate if bytes left 
   	//   last2 = last 2 >> uShift


   	// Just 0 everything for now to make code compile.
   	return _buf[0 .. encLen];

   	/*
   	size_t iBeg = inOffset / 8;  // truncate down
   	size_t iEnd = (inOffset + etLen)/8; // truncate down
   	ushort uShift = 0;
   	ubyte  uMask0 = 0xFF;
   	if( iEnd*8 < inOffset + enLen){ 
   		iEnd += 1;
   		uShift = iEnd*8 - (inOffset + enLen);

   	}




   	else{
   		// Positions to remove from top of byte0
   		ushort uRm = 8 - ((inOffset - iBeg*8) + uShift);

   	}

   	pOut[0] = (pIn[iEnd] >> uShift) & uMask0;


   	ubyte[] pRead = pIn[iBeg .. iEnd + 1];

   	// Shift & patch starting from highest address
   	if(uShift > 0){
   		for(int i = pRead.length - 1; i > -1; --i){
	   		pRead[i] = ;
   		}
   	}
   	*/
   }

   /++ Return the bit field as a given value +/
   //T as(T)(ubyte[] pIn){
//
//
   //}
}

unittest{
	ubyte[] aSrc = [0x30, 0x00];

	immutable(StreamFmt) SF = StreamFmt.v30;

	// Just test construction and function call (without error checking)
	BitReader!SF flag = BitReader!SF("flag", 1, 3, "ubyte", 1, "bool" );

	auto aRet = flag(aSrc[]);
}