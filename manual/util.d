module das2.util;

import std.string;

/** Enumerated values for the das2_init error disposition (nErrDis) */
enum int DAS2_ERRDIS_EXIT = 0, DAS2_ERRDIS_RET = 1, DAS2_ERRDIS_ABORT = 43;

/** Typedef for log message handler callback functions */
extern(C) alias das_log_handler_t = void function(
	int nLevel, const char* sMsg, bool bPrnTime
);

extern(C) void das2_init(
	int nErrDis, int nErrBufSz, int nLevel, das_log_handler_t logfunc
);

extern(C) ErrorCode das2_error_func_fixed(
	const char* sFile, const char* sFunc, int nLine, ErrorCode nCode,
	const char* sMsg
);


enum ErrorCode : int {
	DAS2ERR_INIT = 11, DAS2ERR_BUF = 12, DAS2ERR_UTIL = 13, DAS2ERR_ENC = 14,
	DAS2ERR_UNITS = 15, DAS2ERR_DESC = 16, DAS2ERR_PLANE = 17, DAS2ERR_PKT = 18,
	DAS2ERR_STREAM = 19, DAS2ERR_OOB = 20, DAS2ERR_IO = 22, DAS2ERR_DSDF = 23,
	DAS2ERR_DFT = 24, DAS2ERR_LOG = 25, DAS2ERR_ARRAY = 26, DAS2ERR_CD = 27,
	DAS2ERR_BLDR = 28, DAS2ERR_HTTP  = 29, DAS2ERR_NOTIMP = 99
};

int das2_error(
	ErrorCode nErrCode, string sMsg, string file = __FILE__, string func = __FUNCTION__
){
	return das2_error_func_fixed(toStringz(file), toStringz(func), __LINE__, nErrCode, toStringz(sMsg) );
}
