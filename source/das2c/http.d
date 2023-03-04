/* Copyright (C) 2017 Chris Piker <chris-piker@uiowa.edu>
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

module das2c.http;

import das2c.array;
import das2c.credentials;

extern (C):

/** @file http.h functions for reading and writing http messages */

/** @defgroup network Network
 * HTTP and HTTPs network operations and authentication
 */

/** @addtogroup network
 * @{
 */

enum DASURL_SZ_SCHEME = 31;
enum DASURL_SZ_HOST = 63;
enum DASURL_SZ_PATH = 127;
enum DASURL_SZ_QUERY = 511;
enum DASURL_SZ_DATASET = 63;

/* Called from das_init(), no need to call directly */
bool das_http_init (const(char)* sProgName);
void das_http_finish ();

/** Get a new string allocated on the heap explaining an SSL error
 * or NULL in nRet == 0.
 *
 * To prevent memory leaks, caller must free string if return is NON null.
 */
char* das_ssl_getErr (const(void)* vpSsl, int nRet);

/* Recommended time out values for HTTP Connections, these settings result
 * in an initial expectation of 2 second response, 2 retries and a max
 * connection timeout of 18.0 seconds.  Probably too generous  */
enum DASHTTP_TO_MIN = 2.0;
enum DASHTTP_TO_MULTI = 3.0;
enum DASHTTP_TO_MAX = 18.0;

/** A parsed URL structure */
struct das_url
{
    /** The scheme string */
    char[32] sScheme;
    /** The host string */
    char[64] sHost;
    /** The path on the host */
    char[128] sPath;
    /** The query string */
    char[512] sQuery;
    /** The dataset identified in the query string (if any) */
    char[64] sDataset;

    /** The port number used to make the request, saved as a string */
    char[8] sPort;
}

/** Encapsulates the status of a HTTP resource request */
struct das_http_response_t
{
    /** The socket file descriptor that can be used to read the message body.
    	 * A value of -1 indicates that the connection could not be made if
    	 * pSsl is also NULL */
    int nSockFd;

    /** The SSL Connection if using HTTPS.  If both this value and nSockFd
    	 * are null it means the connection failed*/
    void* pSsl;

    /** The HTTP status code returned by the server (if any) */
    int nCode;

    /** An error message created by the library if a problem occurred */
    char* sError;

    /** The full HTTP header set from the final response */
    char* sHeaders;

    /** The parsed out mime-type string from the headers */
    char* pMime;

    /** The filename (if any) provided for the message body */
    char* sFilename;

    /** The parsed URL structure that was used to make the connection */
    das_url url;
}

alias DasHttpResp = das_http_response_t;

/** @} */

/** Convert a URL structure into a string
 * @memberof das_url
 */
bool das_url_toStr (const(das_url)* pUrl, char* sBuf, size_t uLen);

/** Initialize all fields in an http response to default values.
 *
 * All char fields are set to zero, the file descriptor (nSockFd) is set to
 * -1 and the response code is set to zero.  This function is called
 * automatically by http_getBodySocket() so there is usually no need to use it
 * directly.
 *
 * @param pRes The response to clear
 * @memberof DasHttpResp
 */
void DasHttpResp_clear (DasHttpResp* pRes);

/** Free any fields that contain allocated memory
 * This will not free the pRes structure itself, only sub-items such as
 * pMime etc.  To free the over all structure (if it was allocated on the
 * heap) call free(pRes).
 */
void DasHttpResp_freeFields (DasHttpResp* pRes);

/** Initialize the das_url component of an HTTP response
 *
 * The URL will be parsed into a das_url structure and stored internally.
 *
 * @param pRes The response to initialized
 * @param sUrl The fully qualified URL including the scheme, host, port (if any),
 *             path and query parameters.
 * @memberof DasHttpResp
 */
bool DasHttpResp_init (DasHttpResp* pRes, const(char)* sUrl);

/** Returns true if the response is an SSL (Secure Socket Layer) connection
 * @memberof DasHttpResp
 */
bool DasHttpResp_useSsl (DasHttpResp* pRes);

/** @addtogroup network
 * @{
 */

/** Get a socket positioned at the start of a remote resource
 *
 * This function makes a connection to a remote HTTP or HTTPS server, reads
 * through the HTTP headers and then passes the socket descriptor and possibly
 * an SSL connection object back to the caller.
 *
 * If a redirect response is detected, the initial connection is dropped and a
 * new one is made to the indicated location.
 *
 * If the GET request fails due to needing authentication, the given credential
 * manager is consulted for a username and password.  If one is present that
 * matches the URL path (and optionally the dataset, see below) then it is used,
 * otherwise the manager's getPassword function is called and another attempt is
 * made.  The cycle continues until the connection succeeds or getPassword
 * fails.
 *
 * Meta details about the connection including the body mime-type and any
 * error messages are stored in the sHeaders element of the DasHttpResp
 * structure.
 *
 * It is the caller's responsibility to call shutdown for the provided
 * socket descriptor or the SSL connection when it is finished reading the
 * message body.
 *
 * <b>Das2 Note:</b>  Since das2 servers can request different authentication for
 * each dataset, the get string is inpected for the 'server=dataset' pair.  If
 * found the URL saved in the credentials manager will be
 * http://SERVER/path?dataset=DATASET instead of just http://SERVER/path.
 * This a bit of a hack and a better solution should be found in the future.
 *
 * @param sUrl The location to connect to, will be URL encoded before
 *              transmission
 *
 * @param sAgent The user agent string you wish to send to the server.  If NULL
 *        then the string "libdas2/2.3" is sent.
 *
 * @param pMgr A credentials manager object to consult if a password is
 *             requested.  May be set to NULL to indicate that only public
 *             items may be requested.
 *
 * @param pRes A pointer to a response object that will be filled in with the
 *             result of the connection attempt.  This contains the headers
 *             error messages etc.
 *
 * @param rConSec If > 0.0 this is the floating point number of seconds to
 *             wait on a connection before giving up.  If 0.0 or less then
 *             operating system defaults are used.  Typical OS default is about
 *             five minutes.  This value only affects the initial connection
 *             timeout and not the wait time for data to appear.
 *
 * @return true if pRes->nSockFd, or pRes->pSsl is ready for reading, false
 *         otherwise.
 */
bool das_http_getBody (
    const(char)* sUrl,
    const(char)* sAgent,
    DasCredMngr* pMgr,
    DasHttpResp* pRes,
    float rConSec);

/** Read all the bytes for a URL into a byte array
 *
 * Since network operations are presumed to fail often, all errors are
 * logged using the functions in log.h, das_error is not called unless a memory
 * allocation error occurs.
 *
 * @param sUrl - The URL to read, may be http or https contain alternate port
 *               numbers etc.
 *
 * @param sAgent The user agent string you wish to send to the server.  If
 *               NULL then the string "libdas2/2.3" is sent.
 *
 * @param pMgr   A credentials manager object to consult if a password is
 *               requested.  May be set to NULL to indicate that only public
 *               items may be requested.
 *
 * @param pRes   A pointer to a http response object that will hold the headers
 *               from the final destination.  Due to redirects the URL in
 *               the response may not be the same as the initial one provided
 *               in sUrl
 *
 * @param nLimit An upper limit on the number of bytes to download, if less than
 *               1 then limit checks are disabled and download will continue
 *               until complete, a socket error occurs, or no additional
 *               memory can be allocated.  The actual amount of data read maybe
 *               upto 32K - 1 bytes more than the given limit.
 *
 * * @param rConSec If > 0.0 this is the floating point number of seconds to
 *             wait on a connection before giving up.  If 0.0 or less then
 *             operating system defaults are used.  Typical OS default is about
 *             five minutes.  This value only affects the initial connection
 *             timeout and not the wait time for data to appear.
 *
 * @return       A 1-dimensional DasAry with element type vtByte allocated on
 *               the heap, or NULL if the download failed.
 *
 *               The ID member of the allocated array will correspond to the
 *               last component of the URL path, not including any fragments,
 *               or if accessing the root of a server, then the host name will
 *               be used.
 */
DasAry* das_http_readUrl (
    const(char)* sUrl,
    const(char)* sAgent,
    DasCredMngr* pMgr,
    DasHttpResp* pRes,
    long nLimit,
    float rConSec);

/** @} */

/* _das_http_h_ */
