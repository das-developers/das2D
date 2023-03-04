/* Copyright (C) 2022 Chris Piker <chris-piker@uiowa.edu>
 *
 * This file is part of das2C, the Core Das2 C Library.
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
 * version 2.1 along with das2C; if not, see <http://www.gnu.org/licenses/>.
 */

module das2c.spice;

extern(C):

version(spice){

/** Setup spice so that errors are not automatically output to the standard 
 *  output channel.
 * 
 * Das2 readers (and unix programs in general) are only supposed to output
 * data to standard out, not error messages.
 */
void das_spice_err_setup();


enum DAS2_EXCEPT_NO_DATA_IN_INTERVAL = "NoDataInInterval";
enum DAS2_EXCEPT_ILLEGAL_ARGUMENT    = "IllegalArgument";
enum DAS2_EXCEPT_SERVER_ERROR        = "ServerError";


/** Reads a spice error and outputs it as a das exception, the program
 * should only call this if failed_ returns non-zero, and it should exit
 * after callling this function.
 *
 * @param nDasVer - Set to 1 to get das1 compatable output, 2 to get
 *        das2 output
 *
 * @param sErrType - Use one of the predefined strings from the core das2
 *       library:
 *
 *      - DAS2_EXCEPT_NO_DATA_IN_INTERVAL
 *      - DAS2_EXCEPT_ILLEGAL_ARGUMENT
 *      - DAS2_EXCEPT_SERVER_ERROR
 * 
 * @return The function always returns a non-zero value so that the das
 *      server knows the request did not complete.
 */
int das_send_spice_err(int nDasVer, const char* sErrType);


}