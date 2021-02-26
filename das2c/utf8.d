/*
  Basic UTF-8 manipulation routines
  by Jeff Bezanson
  placed in the public domain Fall 2005

  This code is designed to provide the utilities you need to manipulate
  UTF-8 as an internal string encoding. These functions do not perform the
  error checking normally needed when handling UTF-8 data, so if you happen
  to be from the Unicode Consortium you will want to flay me alive.
  I do this because error checking can be performed at the boundaries (I/O),
  with these routines reserved for higher performance on data known to be
  valid.
  A UTF-8 validation routine is included.
*/

module das2c.utf8;

import core.stdc.stdio;

extern (C):

extern __gshared int locale_is_utf8;

/* is c the start of a utf8 sequence? */
extern (D) auto isutf(T)(auto ref T c)
{
    return (c & 0xC0) != 0x80;
}

enum UEOF = cast(uint) -1;

/* convert UTF-8 data to wide character */
size_t u8_toucs (uint* dest, size_t sz, const(char)* src, size_t srcsz);

/* the opposite conversion */
size_t u8_toutf8 (char* dest, size_t sz, const(uint)* src, size_t srcsz);

/* single character to UTF-8, returns # bytes written */
size_t u8_wc_toutf8 (char* dest, uint ch);

/* character number to byte offset */
size_t u8_offset (const(char)* str, size_t charnum);

/* byte offset to character number */
size_t u8_charnum (const(char)* s, size_t offset);

/* return next character, updating an index variable */
uint u8_nextchar (const(char)* s, size_t* i);

/* next character without NUL character terminator */
uint u8_nextmemchar (const(char)* s, size_t* i);

/* move to next character */
void u8_inc (const(char)* s, size_t* i);

/* move to previous character */
void u8_dec (const(char)* s, size_t* i);

/* returns length of next utf-8 sequence */
size_t u8_seqlen (const(char)* s);

/* returns the # of bytes needed to encode a certain character */
size_t u8_charlen (uint ch);

/* computes the # of bytes needed to encode a WC string as UTF-8 */
size_t u8_codingsize (uint* wcstr, size_t n);

char read_escape_control_char (char c);

/* assuming src points to the character after a backslash, read an
   escape sequence, storing the result in dest and returning the number of
   input characters processed */
size_t u8_read_escape_sequence (const(char)* src, size_t ssz, uint* dest);

/* given a wide character, convert it to an ASCII escape sequence stored in
   buf, where buf is "sz" bytes. returns the number of characters output.
   sz must be at least 3. */
int u8_escape_wchar (char* buf, size_t sz, uint ch);

/* convert a string "src" containing escape sequences to UTF-8 */
size_t u8_unescape (char* buf, size_t sz, const(char)* src);

/* convert UTF-8 "src" to escape sequences.

   sz is buf size in bytes. must be at least 12.

   if escape_quotes is nonzero, quote characters will be escaped.

   if ascii is nonzero, the output is 7-bit ASCII, no UTF-8 survives.

   starts at src[*pi], updates *pi to point to the first unprocessed
   byte of the input.

   end is one more than the last allowable value of *pi.

   returns number of bytes placed in buf, including a NUL terminator.
*/
size_t u8_escape (
    char* buf,
    size_t sz,
    const(char)* src,
    size_t* pi,
    size_t end,
    int escape_quotes,
    int ascii);

/* utility predicates used by the above */
int octal_digit (char c);
int hex_digit (char c);

/* return a pointer to the first occurrence of ch in s, or NULL if not
   found. character index of found character returned in *charn. */
char* u8_strchr (const(char)* s, uint ch, size_t* charn);

/* same as the above, but searches a buffer of a given size instead of
   a NUL-terminated string. */
char* u8_memchr (const(char)* s, uint ch, size_t sz, size_t* charn);

char* u8_memrchr (const(char)* s, uint ch, size_t sz);

/* count the number of characters in a UTF-8 string */
size_t u8_strlen (const(char)* s);

/* number of columns occupied by a string */
size_t u8_strwidth (const(char)* s);

/* Only works on Linux.
 * TODO: Update this function to pickup Windows Code-page 65001, which is
 * a UTF-8 implementation
 */
int u8_is_locale_utf8 (const(char)* locale);

/* printf where the format string and arguments may be in UTF-8.
   you can avoid this function and just use ordinary printf() if the current
   locale is UTF-8. */
/* size_t u8_vprintf (const(char)* fmt, va_list ap); */
size_t u8_printf (const(char)* fmt, ...);

/* determine whether a sequence of bytes is valid UTF-8. length is in bytes */
int u8_isvalid (const(char)* str, size_t length);

/* reverse a UTF-8 string. len is length in bytes. dest and src must both
   be allocated to at least len+1 bytes. returns 1 for error, 0 otherwise */
int u8_reverse (char* dest, char* src, size_t len);

/** Copy a utf-8 string to a buffer taking care not to create broken sequences
 * @param dest The buffer to receive the string.  Will be NULL terminated unless
 *         len = 0
 * @param src The buffer to read for utf-8 characters
 * @returns a pointer to the destination buffer
 */
char* u8_strncpy (char* dest, const(char)* src, size_t len);

