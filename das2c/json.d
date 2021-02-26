/* The latest version of this library is available on GitHub;
    https://github.com/sheredom/json.h

   This is free and unencumbered software released into the public domain.

   Anyone is free to copy, modify, publish, use, compile, sell, or
   distribute this software, either in source code form or as a compiled
   binary, for any purpose, commercial or non-commercial, and by any
   means.

   In jurisdictions that recognize copyright laws, the author or authors
   of this software dedicate any and all copyright interest in the
   software to the public domain. We make this dedication for the benefit
   of the public at large and to the detriment of our heirs and
   successors. We intend this dedication to be an overt act of
   relinquishment in perpetuity of all present and future rights to this
   software under copyright law.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
   OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
   OTHER DEALINGS IN THE SOFTWARE.

   For more information, please refer to <http://unlicense.org/>
*/

/** @file json.h Sheredom's json.h parser with global symbol name changes.
 * The upstream version of this file can be found on GitHub at
 * https://github.com/sheredom/json.h
 */

/* das2 developer modification note:
 *
 * Neil Hennings's JSON library is quite good and I can imagine many others
 * would pick it up (I know I adopted it instead of json-c), so I've changed
 * the names of all the visible objects.  Structure names have been changed to
 * blend in with the rest of the libdas2 and functions have had their prefixes
 * changed from "json_" to "das_j".   If I could be sure that libdas2 users
 * would never need to access raw json objects, this change would not be
 * necessary.  However preventing access to the raw objects limits libdas2's
 * usefulness, hence this trivial token transformation.  Original "json.h"
 * logic has not been altered in any way, though some new functions have been
 * added at the end of the C file.
 *
 * Thanks to Neil, for helping out space physics research.
 *   -cwp 2018-10-14
 */

module das2c.json;

extern (C):

//disable 'bytes padding added after construct' warning

/** @addtogroup catalog
 * @{
 */

/** The various types JSON values can be. Used to identify what a value is */
enum das_json_type_e
{
    das_json_type_str = 0,
    das_json_type_num = 1,
    das_json_type_dict = 2,
    das_json_type_ary = 3,
    das_json_type_true = 4,
    das_json_type_false = 5,
    das_json_type_null = 6
}

/** A JSON string value */
struct das_json_str_s
{
    /** utf-8 string */
    const(char)* string;
    /** the size (in bytes) of the string */
    size_t string_size;
}

alias das_json_str = das_json_str_s;

/** A JSON string value (extended) */
struct das_json_str_ex_s
{
    /** the JSON string this extends. */
    das_json_str_s string;

    /** the character offset for the value in the JSON input */
    size_t offset;

    /** the line number for the value in the JSON input */
    size_t line_no;

    /** the row number for the value in the JSON input, in bytes */
    size_t row_no;
}

alias das_json_str_ex = das_json_str_ex_s;

/** A JSON number value */
struct das_json_num_s
{
    /** ASCII string containing representation of the number */
    const(char)* number;
    /** the size (in bytes) of the number */
    size_t number_size;
}

alias das_json_num = das_json_num_s;

/** An element of a JSON dictionary */
struct das_json_dict_el_s
{
    /** the name of this element */
    das_json_str_s* name;
    /** the value of this element */
    das_json_obj_s* value;
    /** the next object element (can be NULL if the last element in the object) */
    das_json_dict_el_s* next;
}

alias das_json_dict_el = das_json_dict_el_s;

/** a JSON dictionary payload */
struct das_json_dict_s
{
    /** a linked list of the elements in the object */
    das_json_dict_el_s* start;
    /** the number of elements in the object */
    size_t length;
}

alias das_json_dict = das_json_dict_s;

/** an element of a JSON array */
struct das_json_ary_el_s
{
    /** the value of this element */
    das_json_obj_s* value;
    /** the next array element (can be NULL if the last element in the array) */
    das_json_ary_el_s* next;
}

alias das_json_ary_el = das_json_ary_el_s;

/** a JSON array value */
struct das_json_ary_s
{
    /** a linked list of the elements in the array */
    das_json_ary_el_s* start;
    /** the number of elements in the array */
    size_t length;
}

alias das_json_ary = das_json_ary_s;

/** JSON Dom Element */
struct das_json_obj_s
{
    /** a pointer to either a das_json_str, das_json_num, das_json_dict, or
       * das_json_ary. Should be cast to the appropriate struct type based on what
       * the type parameter
    	*/
    void* value;

    /** must be one of das_json_type_e. If type is dasj_objtype_true,
    	* dasj_objtype_false, or dasj_objtype_null, payload will be NULL */
    size_t type;
}

alias DasJdo = das_json_obj_s;

/** a JSON value (extended)
 * @extends das_json_val_s
 */
struct das_json_val_ex_s
{
    /** the JSON value this extends. */
    DasJdo value;

    /** the character offset for the value in the JSON input */
    size_t offset;

    /** the line number for the value in the JSON input */
    size_t line_no;

    /** the row number for the value in the JSON input, in bytes */
    size_t row_no;
}

alias das_json_val_ex = das_json_val_ex_s;

/** Flag useed by dasj_parse() and dasj_parse_ex() to alter parsing behavior */
enum das_json_parse_flags_e
{
    das_jparse_flags_default = 0,

    /** allow trailing commas in objects and arrays. For example, both [true,] and
       * {"a" : null,} would be allowed with this option on.
    	*/
    das_jparse_flags_allow_trailing_comma = 0x1,

    /** allow unquoted keys for objects. For example, {a : null} would be allowed
       * with this option on.
    	*/
    das_jparse_flags_allow_unquoted_keys = 0x2,

    /** allow a global unbracketed object. For example, a : null, b : true, c : {}
       * would be allowed with this option on.
    	*/
    das_jparse_flags_allow_global_object = 0x4,

    /** allow objects to use '=' instead of ':' between key/value pairs. For
       * example, a = null, b : true would be allowed with this option on.
    	*/
    das_jparse_flags_allow_equals_in_object = 0x8,

    /** allow that objects don't have to have comma separators between key/value
       * pairs.
    	*/
    das_jparse_flags_allow_no_commas = 0x10,

    /** allow c-style comments (// or /\* *\/) to be ignored in the input JSON
     * file.
     */
    das_jparse_flags_allow_c_style_comments = 0x20,

    // deprecated flag, unused
    das_jparse_flags_deprecated = 0x40,

    /** record location information for each value. */
    das_jparse_flags_allow_location_information = 0x80,

    /** allow strings to be 'single quoted' */
    das_jparse_flags_allow_single_quoted_strings = 0x100,

    /** allow numbers to be hexadecimal */
    das_jparse_flags_allow_hexadecimal_numbers = 0x200,

    /** allow numbers like +123 to be parsed */
    das_jparse_flags_allow_leading_plus_sign = 0x400,

    /** allow numbers like .0123 or 123. to be parsed */
    das_jparse_flags_allow_leading_or_trailing_decimal_point = 0x800,

    /** allow Infinity, -Infinity, NaN, -NaN */
    das_jparse_flags_allow_inf_and_nan = 0x1000,

    /** allow multi line string values */
    das_jparse_flags_allow_multi_line_strings = 0x2000,

    /** allow simplified JSON to be parsed. Simplified JSON is an enabling of a set
       * of other parsing options.
    	*/
    das_jparse_flags_allow_simplified_json = das_jparse_flags_allow_trailing_comma | das_jparse_flags_allow_unquoted_keys | das_jparse_flags_allow_global_object | das_jparse_flags_allow_equals_in_object | das_jparse_flags_allow_no_commas,

    /** allow JSON5 to be parsed. JSON5 is an enabling of a set of other parsing
       * options.
    	*/
    das_jparse_flags_allow_json5 = das_jparse_flags_allow_trailing_comma | das_jparse_flags_allow_unquoted_keys | das_jparse_flags_allow_c_style_comments | das_jparse_flags_allow_single_quoted_strings | das_jparse_flags_allow_hexadecimal_numbers | das_jparse_flags_allow_leading_plus_sign | das_jparse_flags_allow_leading_or_trailing_decimal_point | das_jparse_flags_allow_inf_and_nan | das_jparse_flags_allow_multi_line_strings
}

/** JSON parsing error codes */
enum das_jparse_error_e
{
    /** no error occurred (huzzah!) */
    das_jparse_error_none = 0,

    /** expected either a comma or a closing '}' or ']' to close an object or
       * array!
    	*/
    das_jparse_error_expected_comma_or_closing_bracket = 1,

    /** colon separating name/value pair was missing! */
    das_jparse_error_expected_colon = 2,

    /** expected string to begin with '"'! */
    das_jparse_error_expected_opening_quote = 3,

    /** invalid escaped sequence in string! */
    das_jparse_error_invalid_string_escape_sequence = 4,

    /** invalid number format! */
    das_jparse_error_invalid_number_format = 5,

    /** invalid value! */
    das_jparse_error_invalid_value = 6,

    /** reached end of buffer before object/array was complete! */
    das_jparse_error_premature_end_of_buffer = 7,

    /** string was malformed! */
    das_jparse_error_invalid_string = 8,

    /** a call to malloc, or a user provider allocator, failed */
    das_jparse_error_allocator_failed = 9,

    /** the JSON input had unexpected trailing characters that weren't part of the
       * JSON value
    	*/
    das_jparse_error_unexpected_trailing_characters = 10,

    /** catch-all error for everything else that exploded (real bad chi!) */
    das_jparse_error_unknown = 11
}

/** error report from json_parse_ex() */
struct das_json_parse_result_s
{
    /** the error code (one of json_parse_error_e), use dasj_parse_error_info()
    	* To convert the value to an error string.
    	*/
    size_t error;

    /** the character offset for the error in the JSON input */
    size_t error_offset;

    /** the line number for the error in the JSON input */
    size_t error_line_no;

    /** the row number for the error, in bytes */
    size_t error_row_no;
}

/** Provide error string describing a parsing error result */
const(char)* json_parse_error_info (
    const(das_json_parse_result_s)* pRes,
    char* sTmp,
    size_t uLen);

/** Parse a JSON text file, returning a pointer to the root of the JSON
 * structure.
 *
 * @param src a pointer to a utf-8 encoded JSON document, type is void* to
 *        emphasize that the data may contain byte values > 127.
 *
 * @param src_size The size in bytes of the document string to parse

 * @param flags_bitset values from enum das_jparse_flags_e OR'ed together
 *           to configure parsing preferences.
 *
 * @param alloc_func_ptr May be use to allocate memory via some method other
 *           than malloc.
 *
 * @param user_data A user data pointer pto be passed as the first argument
 *           to alloc_func_ptr, if alloc_func_ptr is not NULL.
 *
 * @param result (if not NULL) will explain the type of error, and the
 *           location in the input it occurred.

 * @return  A pointer to the entire malloc'ed memory.  Use free() on the
 *          return value when it's no longer needed.  Returns NULL if an
 *          error occured (malformed JSON input, or malloc failed)
 */
DasJdo* das_json_parse_ex (
    const(void)* src,
    size_t src_size,
    size_t flags_bitset,
    void* function (void*, size_t) alloc_func_ptr,
    void* user_data,
    das_json_parse_result_s* result);

/** Parse a JSON text file with default options and without detailed error
 * reporting.
 *
 * This is just shorthand for das_json_parse_ex(src, size, 0, NULL, NULL, NULL);
 */
DasJdo* das_json_parse (const(void)* src, size_t src_size);

/** Given a DOM path retrieve a JSON element
 *
 * @param pThis
 *
 * @param sRelPath Pointer to a utf-8 string providing a relative path
 *              to the sub object.  This has the form:
 *              [STRING | INTEGER] [ / [STRING | INTEGER] [ / [STRING | INTEGER]]]
 *              For example: "cassini/ephemeris/CONTACTS/0/EMAIL".  For Arrays
 *              sub items are denoted by ascii integers 0 - size, for
 *              dictionaries sub items can be denoted by either keys strings
 *              or by ascii integers.  Objects of type string, number, true,
 *              false and null have no sub items
 *
 * @return NULL if no object exists at the specified relative path or if the
 *              object is atomic and has no sub items.
 *
 * @memberof DasJdo
 */
const(DasJdo)* DasJdo_get (const(DasJdo)* pThis, const(char)* sRelPath);

/** Get the first dictionary element from a JSON dictionary */
const(das_json_dict_el)* DasJdo_dictFirst (const(DasJdo)* pThis);

/** Get the first array element from a JSON array */
const(das_json_ary_el)* DasJdo_aryFirst (const(DasJdo)* pThis);

/** Get a string value from a JSON DOM element
 *
 * @param pThis The element in question
 * @return NULL if the object type is not a string or if pThis is NULL, a null
 *         terminated utf-8 string otherwise
 */
const(char)* DasJdo_string (const(DasJdo)* pThis);

const(das_json_dict)* DasJdo_dict (const(DasJdo)* pThis);

/** Write out a minified JSON utf-8 string.
 *
 * This string is an encoding of the minimal string characters required to still
 * encode the same data.  DasJdo_writeMinified performs 1 call to malloc for the
 * entire encoding.
 *
 * @param pThis The top level document object to write, all sub-objects will
 *       be written as well.
 *
 * @return A new buffer containing utf-8 string data, or NULL if an error
 *         occurred (malformed JSON input, or malloc failed),
 *
 * The out_size parameter is optional as the utf-8 string is null terminated.
 * @memberof DasJdo
 */
void* DasJdo_writeMinified (const(DasJdo)* pThis, size_t* out_size);

/** Write out a pretty JSON utf-8 string.
 *
 * This string is encoded such that the resultant JSON is pretty in that it is
 * easily human readable. The indent and newline parameters allow a user to
 * specify what kind of indentation and newline they want (two spaces / three
 * spaces / tabs? \r, \n, \r\n ?). Both indent and newline can be NULL, indent
 * defaults to two spaces ("  "), and newline defaults to linux newlines ('\n'
 * as the newline character).
 *
 * DasJdo_writePretty performs 1 call to malloc for the entire encoding.
 *
 * @return NULL if an error occurred (malformed JSON input, or malloc failed).
 * The out_size parameter is optional as the utf-8 string is null terminated.
 */
void* DasJdo_writePretty (
    const(DasJdo)* pThis,
    const(char)* indent,
    const(char)* newline,
    size_t* out_size);

/** @} */

// extern "C"

// _das_json_h_
