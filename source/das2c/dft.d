/* Copyright (C) 2015-2017 Chris Piker <chris-piker@uiowa.edu>
 *
 * This file is part of libdas2, the Core Das2 C Library.
 *
 * Libdas2 is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License version 2.1 as published
 * by the Free Software Foundation.
 *
 * Libdas2 is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * version 2.1 along with libdas2; if not, see <http://www.gnu.org/licenses/>.
 */

/** @file dft.h Provides a wrapper around FFTW for memory management and
 * normalization.
 */

/** @defgroup DFT
 * Discrete Fourier transforms and power spectral density estimation
 *
 * This module provides an amplitude preserving 1-D Fourier transform and power
 * preserving Power Spectral Density estimator.  One key concept for this
 * module is FFT plans can not be created and destroyed while transforms are
 * running.  On Linux the FFTW3 library is used to provide fast transform
 * capability, the library to use for Windows is yet to be determined.
 *
 * On linux if the file /etc/fftw/wisdom exists it will be loaded during the
 * call to das_init().  Pre-planning FFT operations can significantly
 * increase the speed of new_DftPlan() calls
 *
 * The following example uses the pthread library to demonstrate running four
 * simultaneous transforms.
 *
 * @code
 *
 * #define SEC_IN_DAY 86400
 * #define FREQUENCIES (SEC_IN_DAY/2 + 1)
 *
 * // I/O structure for worker threads
 * struct thread_data {
 *   DftPlan* pPlan;
 *   double* pInput;
 *   double* pOutput;
 * };
 *
 * void* doTransform(void* vpThreadData){
 *   struct thread_data* pTd = (struct thread_data*)vpThreadData;
 *
 *   // DFT objects should be created on a per-thread basis
 *   Das2Dft* pDft = new_Dft(pTd->pPlan, "HANN");
 *
 *   // Run the transform saving the complex output to DFT obj memory
 *   Dft_calculate(pDft, pTd->pInput, NULL);
 *
 *   // Copy magnitude out to the location designated be the main thread
 *   size_t* uLen = 0;
 *   const double* pMag = Dft_getMagnitude(pDft, &uLen);
 *   assert(uLen == FREQUENCIES);
 *   memcpy(pTd->pOutput, pMag, uLen*sizeof(double));
 *
 *   del_Dft(pDft);
 *   return NULL;
 * }
 *
 * main(){
 *
 *   // Initialize libdas2
 *	  das_init(0, 0, DAS_LL_NOTICE, NULL);
 *
 *   double* timeseries = (double*) calloc(SEC_IN_DAY*4, sizeof(double));
 *
 *   // Do something to fill time array ...
 *
 *   double* spectra = (double*) calloc(FREQUENCIES*4, sizeof(double));
 *
 *   // Make a plan for calculating the DFTs
 *   DftPlan* pPlan = new_DftPlan(SEC_IN_DAY, DAS2DFT_FORWARD, "my_program");
 *
 *   // Now calculate 4 spectra at the same time
 *   struct thread_data[4] = {NULL};
 *   pthread_t threads[4];
 *   for(int i = 0; i < 4; ++i){
 *      thread_data[i].pPlan = pPlan;
 *      thread_data[i].pInput = timeseries + SEC_IN_DAY*i;
 *      thread_data[i].pOutput = spectra + FREQUENCIES*i;
 *      pthread_create(threads+i, NULL, doTransform, thread_data+i);
 *   }
 *
 *   for(int i = 0; i < 4; ++i) pthread_join(threads + i);
 *
 *   del_DftPlan(pPlan);
 *
 *   // Do something with all 4 spectra ...
 *
 * }
 *
 * @endcode
 *
 */

module das2c.dft;

import das2c.defs;

extern (C):

/** @addtogroup DFT
 * @{
 */

/* Called from das_init */
bool dft_init (const(char)* sProgName);

/** An structure containing a set of global planning data for DFTs
 * to be preformed. */
struct dft_plan;
alias DftPlan = dft_plan;

/** Create a new shareable DFT plan on the heap
 *
 * DFT plan creation is thread safe in that this function will block until it
 * can obtain a global plan lock while the new plan is created.  This function
 * will block if any DFTs are currently being calculated or if another thread is
 * in the process of creating or deleting a new plan.
 *
 * @param uLen The length of the 1-D complex signal to analyze
 * @param bForward Wether to do a forward DFT or revers DFT
 * @returns A new dft_plan allocated on the heap suitable for use in multiple
 *          simutaneous calls to Dft_calculate().
 * @memberof DftPlan
 */
DftPlan* new_DftPlan (size_t uLen, bool bForward);

/** Delete a shareable DFT plan from the heap
 *
 * DFT plan destruction is thread safe in that this function will block until it
 * can obtain a global plan lock while the plan is being deleted.  This function
 * will block if any DFTs are currently being calculated or if another thread is
 * in the process of creating or deleting a plan.
 *
 * @warning For the love of all that's holy don't run this function if any of
 * your exec threads are still executing.  I don't mean the actual
 * dft_execute function but the whole damn thread!
 *
 * @param pThis
 * @memberof DftPlan
 */
bool del_DftPlan (DftPlan* pThis);

/** An amplitude preserving Discrete Fourier Transform converter
 *
 * On POSIX systems this code uses pthreads and fftw to handle simutaneous
 * FFTs.  The windows implemetation doesn't exist yet, but will not alter the
 * call interface.  An example of using this class follows:
 *
 */
struct das_dft_t
{
    /* The plan, the only varible changed in the plan is the usage count */
    DftPlan* pPlan;

    /* FFTW variables */
    void* vpIn;
    void* vpOut;

    /* Input vector length */
    size_t uLen;

    /* Input vector is real only*/
    bool bRealOnly;

    /* DFT Direction */
    bool bForward;

    /* Holder for the window function and name*/
    char* sWindow;
    double* pWnd;

    /* Holder for the magnitude result */
    bool bNewMag;
    double* pMag;
    size_t uMagLen;

    /* Holder for continuous real and imaginary results */
    bool[2] bNewCmp; /* fftw convention: 0 = reals, 1 = img */
    double*[2] pCmpOut;
    size_t[2] uCmpLen;
}

alias Das2Dft = das_dft_t;

/** Create a new DFT calculator
 *
 * This function allocates re-usable storage for Fourier transform output,
 * but in order to preform calculations a re-usable plan object must be
 * provided
 *
 * @param pPlan - A Transform plan object.  The reference count of DFTs
 *                using this plan will be incremented.
 *
 * @param sWindow - A named window to apply to the data.  If NULL then
 *               no window will be used.
 *
 * @return A new Das2Dft object allocated on the heap.
 * @memberof Das2Dft
 */
Das2Dft* new_Dft (DftPlan* pPlan, const(char)* sWindow);

/** Free a DFT (Discrete Fourier Transform) calculator
 *
 * @param pThis the DFT calculator to free, the caller should set the object
 *        pointer to NULL after this call.  Calling this also deletes the
 *        reference count for the associated DftPlan object
 *
 * @memberof Das2Dft
 */
void del_Dft (Das2Dft* pThis);

/** Calculate a discrete Fourier transform
 *
 * Using the calculation plan setup in the constructor, calculate a discrete
 * Fourier transform.  When this function is called internal storage of any
 * previous DFT calculations (if any) are over written.
 *
 * @param pThis The DFT object which will hold the result memory
 *
 * @param pReal An input vector of with the same length as the plan object
 *        provided to the constructor
 *
 * @param pImg The imaginary (or quadrature phase) input vector with the
 *        same length as pRead.  For a purely real signal this vector is
 *        NULL.
 *
 * @memberof Das2Dft
 * @return 0 (DAS_OKAY) if the calculation was successful, a non-zero error code
 *           otherwise
 */
DasErrCode Dft_calculate (
    Das2Dft* pThis,
    const(double)* pReal,
    const(double)* pImg);

/** Return the real component after a calculation
 *
 * @param pThis
 * @param pLen
 * @return
 */
const(double)* Dft_getReal (Das2Dft* pThis, size_t* pLen);

/** Return the imaginary component after a calculation
 *
 * @param pThis
 * @param pLen
 * @return
 * @memberof Das2Dft
 */
const(double)* Dft_getImg (Das2Dft* pThis, size_t* pLen);

/** Get the amplitude magnitude vector from a calculation
 *
 * Scale the stored DFT so that it preserves amplitude, and get the magnitude.
 * For real-valued inputs (complex pointer = 0) the 'positive' and 'negative'
 * frequencies are combined.  For complex input vectors this is not the case
 * since all DFT output amplitudes are unique.  Stated another way, for complex
 * input signals components above the Nyquist frequency have meaningful
 * information.
 *
 * @param pThis The DFT calculator object which has previously been called to
 *        calculate a result.
 *
 * @param pLen The vector length.  In general this is *NOT* the same as the
 *        input time series length.  For real-value input signals (complex
 *        input is NULL), this is N/2 + 1.  For complex input signals this is N.
 *
 * @return A pointer to an internal holding bin for the real signal magnitude
 *         values.
 *
 * @warning If Dft_calculate() is called again, the return pointer can be
 *          invalidated.  If a permanent result is needed after subsequent
 *          Dft_calculate() calls, copy these data to another buffer.
 * @memberof Das2Dft
 */
const(double)* Dft_getMagnitude (Das2Dft* pThis, size_t* pLen);

/** A power spectral density estimator (periodogram)
 *
 * This is a wrapper around the FFTW (Fastest Fourier Transform in the West)
 * library to handle memory management, normalization and windowing.
 */
struct das_psd_t
{
    /* The plan, the only varible changed in the plan is the usage count */
    DftPlan* pPlan;

    /* FFTW variables */
    void* vpIn;
    void* vpOut;

    /* Input vector information */
    size_t uLen;
    bool bRealOnly;

    /* Center data about average first */
    bool bCenter;

    /* Holder for up conversion arrays, helps Psd_calculate_f*/
    size_t uUpConvLen;
    double* pUpConvReal;
    double* pUpConvImg;

    /* Holder for the window function and name */
    char* sWindow;
    double* pWnd;
    double rWndSqSum;

    /* Holder for the PSD result */
    double* pMag;
    size_t uMagLen;

    /* Total Energy calculations */
    double rPwrIn;
    double rPwrOut;
}

alias Das2Psd = das_psd_t;

/** Create a new Power Spectral Density Calculator
 *
 * This estimator uses the equations given in Numerical Recipes in C, section
 * 13.4, but not any of the actual Numerical Recipes source code.
 *
 * @param pPlan - A Transform plan object.  The reference count of DFTs
 *                using this plan will be incremented.
 *
 * @param bCenter If true, input values will be centered on the Mean value.
 *        This shifts-out the DC component from the input.
 *
 * @param sWindow A named window to use for the data.  Possible values are:
 *        "hann" - Use a hann window as defined at
 *                 http://en.wikipedia.org/wiki/Hann_function
 *        NULL  - Use a square window. (i.e. 'multiply' all data by 1.0)
 *
 * @return A new Power Spectral Density estimator allocated on the heap
 * @memberof Das2Psd
 */
Das2Psd* new_Psd (DftPlan* pPlan, bool bCenter, const(char)* sWindow);

/** Free a Power Spectral Density calculator
 *
 * @param pThis the PSD calculator to free, the caller should set the object
 *        pointer to NULL after this call.  Calling this also deletes the
 *        reference count for the associated DftPlan object
 *
 * @memberof Das2Psd
 */
void del_Das2Psd (Das2Psd* pThis);

/** Calculate a Power Spectral Density (periodogram)
 *
 * Using the calculation plan setup in the constructor, calculate a discrete
 * Fourier transform.  When this function is called internal storage of any
 * previous DFT calculations (if any) are over written.
 *
 * @param pThis The PSD calculator object
 *
 * @param pReal An input vector of with the same length as the plan object
 *        provided to the constructor
 *
 * @param pImg The imaginary (or quadrature phase) input vector with the
 *        same length as pRead.  For a purely real signal this vector is
 *        NULL.
 *
 * @return 0 (DAS_OKAY) if the calculation was successful, a non-zero error code
 *           otherwise
 * @memberof Das2Psd
 */
DasErrCode Psd_calculate (
    Das2Psd* pThis,
    const(double)* pReal,
    const(double)* pImg);

/** The floating point array input analog of Psd_calaculate()
 *
 * Internal calculations are still handled in double precision.
 * @memberof Das2Psd
 */
DasErrCode Psd_calculate_f (
    Das2Psd* pThis,
    const(float)* pReal,
    const(float)* pImg);

/** Provide a comparison of the input power and the output power.
 *
 * During the Psd_calculate() call the average magnitude of the input vector
 * is saved along with the average magnitude of the output vector (divided by
 * the Window summed and squared).  These two measures of power should always
 * be close to each other when using a hann window.  When using a NULL window
 * they should be almost identical, to within rounding error.  The two measures
 * are:
 *
 * <pre>
 *              N-1
 *          1  ----   2      2
 *  Pin =  --- \    r    +  i
 *          N  /     n       n
 *             ----
 *              n=0
 *
 *                N-1
 *           1   ----   2      2
 *  Pout =  ---  \    R    +  I
 *          Wss  /     k       k
 *               ----
 *                k=0
 * </pre>
 *
 * where Wss collapses to N**2 when a NULL (square) window is used.  The reason
 * that the Pout has an extra factor of N in the denominator is due to the
 * following identity for the discrete Fourier transform (Parseval's theorem):
 * <pre>
 *
 *     N-1                   N-1
 *    ----   2    2      1  ----  2    2
 *    \     r  + i   =  --- \    R  + I
 *    /      n    n      N  /     n    n
 *    ----                  ----
 *     n=0                   k=0
 *
 * </pre>
 * Where r and i are the real and imaginary input amplitudes, and R and I are
 * the DFT real and imaginary output values.
 *
 * @param pThis A PSD calculator for which Psd_calculate has been called
 *
 * @param pInput A pointer to store the input power.  If NULL, the input power
 *               will no be saved separately.
 *
 * @param pOutput A pointer to store the output power.  If NULL, the output power
 *               will no be saved separately.
 *
 * @return The ratio of Power Out divided by Power In. (Gain).
 * @memberof Das2Psd
 */
double Psd_powerRatio (const(Das2Psd)* pThis, double* pInput, double* pOutput);

/** Get the amplitude magnitude vector from a calculation
 *
 * Scale the stored DFT so that it preserves amplitude, and get the magnitude.
 * For real-valued inputs (complex pointer = 0) the 'positive' and 'negative'
 * frequencies are combined.  For complex input vectors this is not the case
 * since all DFT output amplitudes are unique.  Stated another way, for complex
 * input signals components above the Nyquist frequency have meaningful
 * information.
 *
 * @param pThis The DFT calculator object which has previously been called to
 *        calculate a result.
 *
 * @param pLen The vector length.  In general this is *NOT* the same as the
 *        input time series length.  For real-value input signals (complex
 *        input is NULL), this is N/2 + 1.  For complex input signals this is N.
 *
 * @return A pointer to an internal holding bin for the real signal magnitude
 *         values.
 *
 * @warning If Psd_calculate() is called again, the return pointer can be
 *          invalidated.  If a permanent result is needed after subsequent
 *          Psd_calculate() calls, copy these data to another buffer.
 *
 * @memberof Das2Psd
 */
const(double)* Psd_get (const(Das2Psd)* pThis, size_t* pLen);

/** @} */
