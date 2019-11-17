module das2;

/** D Language wrappers for libdas2.
 *
 *  Note: This is not a systematic definition of all usable items in liddas2.a.
 *        Instead definitions are added as needed.  If you are working on a
 *        D-language program that uses something in libdas2 that is not here,
 *        go ahead and add it.  Ask chris-piker@uiowa.edu if you need help.
 *
 * To use libdas2 when compiling D programs, simply include this module file
 * (libdas2_d.a) on the compiler command line as well as the libdas2.a
 *  object itself.  For example:
 *
 * dmd your_file1.d your_file2.d /lib/dir/libdas2_d.a /lib/dir/libdas2.a
 *
 * To cut down on the length of the module, most comments are not repeated here,
 * see the C-language doxygen comments for details.
 */

public import das2.util;
public import das2.daspkt;
public import das2.dft;
public import das2.time;
public import das2.units;
public import das2.cordata;
public import das2.builder;
public import das2.log;


