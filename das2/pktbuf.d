// Small utilities to assist programs that are writing das2 packets from
// mission specific formats.  Very experimental and thus not included in
// the package import.

module das2.pktbuf;

enum DasStreamVer { V22=220, V23basic=230};
enum DasTagType  { Hs = 0, Hx = 1, Dx = 2};

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

	static if( SV == DasStreamVer.V22){	
		void tag(DasTagType tt, ushort id=0){
			_tt = tt; _pktId = id;
		}
	}
	else{
		static assert(false, "Das2/v2.3 basic streams are not yet supported");
	}

	/+ Write data to the buffer.  Binary items are written as little endian
	 + by default, but this can be set via template parameter.  For strings
	 + the encoding is ignored.
	 +/
	void write(Endian endian = LE, T...)(T args){
		
		//ubyte[] output = _buf[_iMsgWrite .. $];
		//size_t orig_len = output.length;
	   
		foreach(I, arg; args){
			
			static if(SV == DasStreamVer.V22){
				static assert( 
					is(T[I] == float) || is(T[I] == double) || is(T[I] : const(ubyte)[]) ||
					is(T[I] == float[]) || is(T[I] == double[]) , 
					"Type " ~ T[I].stringof ~ " is not supported for das2/v2.2 streams"
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
				if(_tt != DasTagType.Dx)
					tag = sformat!"[%02u]%06d"(buf[], _pktId, _iMsgWrite - _iMsgBeg);
				else
					tag = sformat!":%02u:"(buf[], _pktId);
			}
			else{
				static assert(SV == DasStreamVer.V22, "Das2/v2.3 packet tags not yet supported");
			}

			_nTagLen = tag.length;
			_buf[_iMsgBeg - _nTagLen .. _iMsgBeg] = cast(ubyte[])tag;

		}
		return _buf[_iMsgBeg - _nTagLen .. _iMsgWrite];
	}
}