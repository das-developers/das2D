module das2.dft;

// DFT
struct dft_plan;
alias DftPlan = dft_plan;

extern(C) DftPlan* new_DftPlan(size_t uLen, bool bForward);
bool del_DftPlan(DftPlan* pThis);

struct das2_dft_t{
	void* vpIn;
	void* vpOut;
	size_t uLen;
	bool bRealOnly;
	char* sWindow;
	double* pWnd;
	bool bNewMag;
	double* pMag;
	size_t uMagLen;
	bool[2] bNewCmp;   /* fftw convention: 0 = reals, 1 = img */
	double*[2] pCmpOut;
	size_t[2] uCmpLen;
};

alias Das2Dft = das2_dft_t;

extern (C) Das2Dft* new_Dft(DftPlan* pPlan, const char* sWindow);
extern (C) void del_Dft(Das2Dft* pThis);
extern (C) int Dft_calculate(
	Das2Dft* pThis, const double* pReal, const double* pImg
);
extern (C) const (double)* Dft_getReal(Das2Dft* pThis, size_t* pLen);
extern (C) const (double)* Dft_getImg(Das2Dft* pThis, size_t* pLen);
extern (C) const (double)* Dft_getMagnitude(Das2Dft* pThis, size_t* pLen);
