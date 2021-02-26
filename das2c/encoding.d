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

/** @file encoding.h  Defines storage and access methods for values in a
 * Das2 Stream
 */

module das2c.encoding;

import das2c.buffer;
import das2c.defs;
import das2c.units;

extern (C):

/** An inconvenient way to get canonical fill value, -1e31 */
double getDas2Fill ();

/** An inconvenient way to check for the canonical fill value, -1e31 */
int isDas2Fill (double value);

/* Most Significant byte First (big-endian) IEEE-754 reals */
enum DAS2DT_BE_REAL = 0x0001;

/* Most Significant byte last (little-endian) IEEE-754 reals */
enum DAS2DT_LE_REAL = 0x0002;

enum DAS2DT_HOST_REAL = 0x0002;

/* A real number formatted in some number of characters.
 * Conventionally there are a whitespace characters to improve readability,
 * but this is not required.  The formatted number should be parsable by
 * scanf in C, readf in IDL, or Double.parseDouble in java.
 */
enum DAS2DT_ASCII = 0x0003;

/* A date-time formatted as an ASCII ISO-8601 string.
 * Actually any time that is parseable by the parsetime routine will work
 * Generally if a human can read it, it's parseable. For example,
 * YYYY-MM-DDThh:mm:ss.mmmZ.
 */
enum DAS2DT_TIME = 0x0004;

/* Most Significant byte First (big-endian) signed integers */
enum DAS2DT_BE_INT = 0x0005;

/* Most Significant byte last (little-endian) signed integers */
enum DAS2DT_LE_INT = 0x0006;

/* Most Significant byte First (big-endian) un-signed integers */
enum DAS2DT_BE_UINT = 0x0007;

/* Most Significant byte last (little-endian) un-signed integers */
enum DAS2DT_LE_UINT = 0x0008;

enum DASENC_FMT_LEN = 64;
enum DASENC_TYPE_LEN = 48;

/** @addtogroup streams
 * @{
 */

/** Reading and writing values on das2 streams.
 *
 * Values in a Das2 Stream have can be encoded in a variety of ways.  Values
 * can be big-endian reals, little-endian floats, ASCII strings, etc.  In
 * to it's basic category values can be represented on the stream using a
 * variable number of bytes.   It is the job of this class to handle
 * encoding and decoding values from a Das2 Stream.
 *
 * This class handles syntax not semantics.  The type of measurement represented
 * by a value depends on it's ::das_units  Any double value can be output as in
 * any given encoding.  The functions for this class are happy to output
 * amplitudes at time strings.  It's up to other classes to see that proper
 * encodings are used.
 *
 * This class contains no pointers to heap objects and thus may be handled as
 * pure stack variables.
 *
 * @see ::das_units
 * @see ::PlaneDesc
 * @class DasEncoding
 */
struct das_encoding
{
    /** The basic encoding category.
    	 * This may be one of:
    	 *  - @b DAS2DT_BE_REAL Most Significant byte First (big-endian) IEEE-754 reals
    	 *  - @b DAS2DT_LE_REAL Most Significant byte First (little-endian) IEEE-754 reals
    	 *  - @b DAS2DT_ASCII A real number formatted in some number of significant digits
    	 *  - @b DAS2DT_TIME A date-time formatted as an ASCII ISO-8601 string.
    	 * Additionally the following is defined for code that just wants to work
    	 * in the host byte order, which ever it happens to be:
    	 *  - @b DAS2DT_HOST_REAL
    	 */
    uint nCat;

    /** The width in bytes of the encoded values.
    	 * The largest width for an encoding in Das2 is 127 bytes. Not all encoding
    	 * categories support all widths the REAL types only allow for 4 or 8 bytes
    	 * widths.
    	 */
    uint nWidth;

    /** The sprintf format string.
    	 * This is the format converting doubles and times to ASCII strings.
    	 * Non-ASCII encodings do not make use of this string.  In that case
    	 * it is set by new_DasEncoding() and  DasEnc_fromString() to NULL
    	 */
    char[DASENC_FMT_LEN] sFmt;

    /** The type value for this encoding on a Das2 Stream.
    	 * For ASCII types the type value width is assumed to be one larger than
    	 * the actual number of bytes in the formatted output to allow for a field
    	 * separator of some type.
    	 *  */
    char[DASENC_TYPE_LEN] sType;
}

alias DasEncoding = das_encoding;

/** Make a new data encoder/decoder
 *
 * There is no corresponding destructor for DasEncoding structures, since these
 * are self-contained and have no sub-pointers to heap objects.  Use free() to
 * delete structures returned by this function.
 *
 * @param nCat The basic encoding category one of:
 *        - DAS2DT_BE_REAL
 *        - DAS2DT_LE_REAL
 *        - DAS2DT_HOST_REAL
 *        - DAS2DT_BE_INT
 *        - DAS2DT_LE_INT
 *        - DAS2DT_HOST_INT
 *        - DAS2DT_BE_UINT
 *        - DAS2DT_LE_UINT
 *        - DAS2DT_HOST_UINT
 *        - DAS2DT_ASCII
 *        - DAS2DT_TIME
 *
 * @param nWidth The width in bytes of each encoded value, ASCII and TIME
 *        types can have arbitrary widths, REAL can be 4 or 8, and INT and
 *        UINT can be 1, 2, 4, or 8 bytes wide.  Half-floats, although useful
 *        in some applications are not supported
 *
 * @param sFmt If not NULL then this sprintf style string will be use to
 *        format the values for output.  If the encoding is just used for
 *        input then a format string is not required.  If the encoding is
 *        used for output and no format string has been set the library
 *        will assign a reasonable default.
 *
 * @returns A new DasEncoding structure allocated on the heap.
 * @memberof DasEncoding
 */
DasEncoding* new_DasEncoding (int nCat, int nWidth, const(char)* sFmt);

/** @} */

/** Create a new encoding based on the encoding type string.
 *
 * @param sType the @e type string from a Das2 Stream plane definition.
 *        This should be one of, <b>sun_real8</b>, <b>little_endian_real8</b>,
 *        <b>sun_real4</b>, <b>little_endian_real4</b>, <b>ascii</b>XX, or
 *        <b>time</b>XX.  Here <b>XX</b> is a field width.
 *
 * @returns a new DasEncoding allocated on the heap.
 *
 * @memberof DasEncoding
 */
DasEncoding* new_DasEncoding_str (const(char)* sType);

/** Deepcopy a DasEncoding pointer */
DasEncoding* DasEnc_copy (DasEncoding* pThis);

/** Check for equality between two encodings
 *
 * @param pOne The first encoding
 * @param pTwo The second encoding
 * @return true if the encodings have the same category, width, and format
 *         string.
 */
bool DasEnc_equals (const(DasEncoding)* pOne, const(DasEncoding)* pTwo);

/** Set the output format to be used when converting interal binary
 * values to ASCII strings.
 *
 * ASCII values are written to Das2 streams with a single space character
 * between each formatted value.  The last value of the the last plane is
 * followed by a new-line character instead of a space character.  Using this
 * function will change the value format, but will not alter the separater
 * character or the end-of-line characters.  (Sorry, no CSV output formats.)
 *
 * Use of this function is not required.  ASCII values will receive a
 * default format.
 *
 * @param pThis The output plane in question
 *
 * @param sValFmt a printf style format string.  Typical strings for general
 *        data values would be: '%9.2e', '%+13.6e'.  In general strings
 *        such as '%13.3f' should @b not be used as these aren't guarunteed
 *        to have a fix output width and your value strings may be truncated.
 *
 * @param nFmtWidth the number of output characters indicated by this format.
 *        This is just the width of the formatted value, not including any
 *        field separators.
 *
 * @memberof DasEncoding
 */
void DasEnc_setAsciiFormat (
    DasEncoding* pThis,
    const(char)* sValFmt,
    int nFmtWidth);

/** Set the output format to be used when converting binary time values to
 * to ASCII strings.
 *
 * ASCII Time values are always encoded for output using the following C-call:
 *
 * @code
 * sprintf(buf, sValFmt, year, month, dayofmonth, hour, min, sec);
 * @endcode
 *
 * The seconds field is double precision.  Note that you do <b>not</b> have to
 * convert all the fields in your output.  In this case the output time will
 * be a truncated time.
 *
 * ASCII values are written to Das2 streams with a single space character
 * between each formatted value.  The last value of the the last plane is
 * followed by a new-line character instead of a space character.  Using this
 * function will change the value format, but will not alter the separater
 * character or the end-of-line characters.  Sorry, no CSV output formats.
 *
 * Use of this function is not required.  ASCII Time values will receive a
 * default format.
 *
 * @param pThis The output plane in question
 *
 * @param sTimeFmt a printf style format string.  An example strings would be:
 *        '%04d-%02d-%02dT%02d:%02d%02.0fZ' for seconds resolution with the
 *        Zulu time character 'Z' appended.
 *
 * @param nFmtWidth the number of output characters indicated by this format.
 *        This is just the width of the formatted value, not including any
 *        field separators.
 * @memberof DasEncoding
 */
void DasEnc_setTimeFormat (
    DasEncoding* pThis,
    const(char)* sTimeFmt,
    int nFmtWidth);

/* More explicit indication of a big-endian 8-byte number */
enum DAS2DT_BE_REAL_8 = 0x0801;

/* little-endian (least significant byte first) 8-byte real */
enum DAS2DT_LE_REAL_8 = 0x0802;

/* 8-byte real number, in host byte order */
enum DAS2DT_DOUBLE = 0x0802;

/* More explicit indication of a big-endian 4-byte number */
enum DAS2DT_BE_REAL_4 = 0x0401;

/* little-endian (least significant byte first) 4-byte real */
enum DAS2DT_LE_REAL_4 = 0x0402;

/** 4-byte real number, in host byte order */
enum DAS2DT_FLOAT = 0x0402;

/* Legacy specific width encoding */
enum DAS2DT_ASCII_10 = 0x0A03;
enum DAS2DT_ASCII_24 = 0x1804;
enum DAS2DT_ASCII_14 = 0x0E04;

enum DAS2DT_TIME_25 = 0x1904;
enum DAS2DT_TIME_28 = 0x1c04;

/** Get a hash value suitable for use in switch statements.
 *
 * Combines the DasEncoding::nWidth and DasEncoding::nCategory into a single
 * integer that represents the encoding.
 *
 * Since there are only 4 binary value output encodings the following
 * constants are defined for the binary encoding hash values.
 *
 *  - @b DAS2DT_BE_REAL_4 - Big-Endian 4-byte IEEE-754 reals
 *  - @b DAS2DT_LE_REAL_4 - Little-Endian 4-byte IEEE-754 reals
 *  - @b DAS2DT_BE_REAL_8 - Big-Endian 4-byte IEEE-754 reals
 *  - @b DAS2DT_LE_REAL_8 - Little-Endian 4-byte IEEE-754 reals
 *
 * To help with byte-swapping logic the following are also defined
 *
 *  - @b DAS2DT_DOUBLE - The 8-byte real hash above that corresponds to
 *       either DAS2DT_BE_REAL_8 or DAS2DT_LE_REAL_8 depending on the
 *       host endian orber.
 *
 *  - @b DAS2DT_FLOAT - The 4-byte real hash above that corresponds to
 *       either DAS2DT_BE_REAL_4 or DAS2DT_LE_REAL_4 depending on the the
 *       host endian order.
 *
 * @param pThis the encoding to hash
 *
 * @returns The encoding category in the lower byte and the width in
 *          the next to lowest byte.
 *
 * @memberof DasEncoding
 */
uint DasEnc_hash (const(DasEncoding)* pThis);

/** Get a string representation of the data type.
 *
 * This provides a string representation of the data type that is suitable for
 * use as the type parameter of a plane in a Das2 stream packet header.  All
 * Das2 Tools use the same string representations for encodings.
 *
 * @param[in] pThis the Das2 encoding to represent as a string.
 *
 * @param[out] sType a buffer to receive this encoding's type string, should
               be at least 20 bytes long.
 * @param[in] nLen the actual length of the string buffer.
 *
 * @returns 0 on success a positive error code if there is a problem
 *
 * @memberof DasEncoding
 */
DasErrCode DasEnc_toStr (DasEncoding* pThis, char* sType, size_t nLen);

/** Encode and write a value onto a string.
 *
 * Writes a value onto a stream without any separators.  Note that the ASCII
 * types write one fewer bytes than their DasEncoding::nWidth parameter would
 * indicate.  The last byte is left for the caller to use as a separator of
 * thier choosing.
 *
 * @param pThis the DasEncoding object to handle the translation
 * @param pBuf a write buffer to receive the encoded bytes
 * @param value The value to write
 * @param units All values are held internally by the library as doubles.  In
 *        the instance that the output type for this encoding is a time string
 *        this parameter will be used to determine the epoch and scale for
 *        @a value.  Otherwise it is ignored.
 *
 * @returns 0 on success, a positive error value on an error.
 * @memberof DasEncoding
 */
DasErrCode DasEnc_write (
    DasEncoding* pThis,
    DasBuf* pBuf,
    double value,
    das_units units);

/*  (Not Implemented)
 * Encode and write a value to a buffer.
 *
 * Similar to DasEnc_write except this version outputs to a DasBuf object.
 *
 * @param pThis the DasEncoding object to handle the translation
 * @param pBuf the buffer to receive the encoded bytes
 * @param value the numeric value to write
 * @param units Handles scaling and offset of values if needed.
 *
 * @returns 0 on success, a positive error code on failure.
 * @memberof DasEncoding
 */
/* ErrorCode DasEnc_encode(
	DasEncoding* pThis, DasBuf* pBuf, double value, UnitType units
); */

/** Read and Decode a value from a string.
 *
 * Reads a value from a stream consuming and ignoring separators.
 *
 * @param[in] pThis the DasEncoding object to handle the translation
 *
 * @param[in] pBuf The buffer to read from.  This buffer should have at
 *        least DasEncoding::nWidth more valid bytes in the buffer from the
 *        current read location.
 *
 * @param[in] units All values are held internally by the library as doubles.
 *        this means that times must be converted to some number of steps
 *        from a 0 time.  The units value provides this information.  It is
 *        not consulted for non-time fields.
 *
 * @param[out] pOut The decoded value.
 * @returns 0 on success or a positive error code if there is a problem.
 * @memberof DasEncoding
 */
DasErrCode DasEnc_read (
    const(DasEncoding)* pThis,
    DasBuf* pBuf,
    das_units units,
    double* pOut);

/* _das_encoding_h_ */
