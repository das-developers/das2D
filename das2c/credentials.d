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

module das2c.credentials;

import das2c.array;

extern (C):

/** @file credentials.h Handle storing credentials during a Das2 session and
 * optionally save them to a file */

/** @addtogroup network
 * @{
 */

/** Function signature for swapping out the user-prompt for credentials
 * acquisition.
 *
 * @param sServer The server name
 * @param sRealm The authorization realm on this server, can be same as the dataset
 * @param sDataset The name of the dataset on this server
 * @param sMessage An additional message that may be supplied, such as
 *        "The user name cannot contain a colon, ':', character"
 * @param sUser a pointer to 128 bytes of storage to hold the username
 * @param sPassword a pointer to 128 bytes of storage to hold the password
 * @returns true if the user entered a user name and password (even empty ones)
 *          and false if the prompt was canceled.
 */
alias das_prompt = bool function (
    const(char)* sServer,
    const(char)* sRealm,
    const(char)* sDataset,
    const(char)* sMessage,
    char* sUser,
    char* sPassword);

/** A single credential*/
struct das_credential_t
{
    bool bValid;
    char[128] sServer;
    char[128] sRealm;
    char[128] sDataset;
    char[256] sHash;
}

alias das_credential = das_credential_t;

/** Initialize a credential to be cached in the credentials manager
 *
 * @param pCred A pointer to a das_credentials structure
 *
 * @param sServer The name of the server, ex: 'jupiter.physics.uiowa.edu'
 *
 * @param sRealm The authentication realm.  This is provided in the dsdf
 *                files under the securityRealm keyword.
 *
 * @param sDataset The dataset, ex: 'Juno/WAV/Survey'  The dataset is typically
 *                 determined by the http module by URL inspection.  If this
 *                 credentials manager is used for a general URL then the
 *                 http module will not specify the the dataset.  To match those
 *                 sites, use NULL here.
 *
 * @param sHash The hash value.  Currently the library only supports
 *              HTTP Basic Authentication hashes. i.e. a USERNAME:PASSWORD
 *              string that has been base64 encoded.
 *
 * @memberof das_credential
 */
bool das_cred_init (
    das_credential* pCred,
    const(char)* sServer,
    const(char)* sRealm,
    const(char)* sDataset,
    const(char)* sHash);

/** Credentials manager
 * Handles a list of login credentials and supplies these as needed for network
 * operations
 */
struct das_credmngr
{
    DasAry* pCreds;
    das_prompt prompt;
    const(char)* sKeyFile;
    char[1024] sLastAuthMsg;
}

alias DasCredMngr = das_credmngr;

/** @} */

/** Initialize a new credentials manager, optionally from a saved list
 *
 * @param sKeyStore If not NULL, the credentials manager will initialize itself
 *        from the given file.
 * @return A new credentials manager allocated on the heap
 * @memberof DasCredMngr
 */
DasCredMngr* new_CredMngr (const(char)* sKeyStore);

/** Delete a credentials manager free'ing it's internal credential store
 *
 * @param pThis A pointer to the credentials manager structure to free.  The
 *        pointer is no-longer valid after this call and should be set to NULL.
 * @memberof DasCredMngr
 */
void del_CredMngr (DasCredMngr* pThis);

/** Manually add a credential to a credentials manager instead of prompting the
 * user.
 *
 * Typically when the credentials manager does not have a password it needs it
 * calls the prompt function that was set using CredMngr_setPrompt() or the
 * built in command line prompter if no prompt function has been set.
 *
 * @param pThis The credentials manager structure that will hold the new
 *        credential in RAM
 * @param pCred The credential to add.  If an existing credential matches this
 *        one except for the hash value, the new hash will overwrite the old
 *        one.
 * @return The new number of cached credentials
 */
int CredMngr_addCred (DasCredMngr* pThis, const(das_credential)* pCred);

/** Retrieve an HTTP basic authentication token for a given dataset on a given
 * server.
 *
 * @param pThis A pointer to a credentials manager structure
 * @param sServer The name of the server for which these credentials apply
 * @param sRealm A string identifing the system the user will be authenticating too.
 * @param sDataset The name of the dataset for which these credentials apply
 * @return The auth token, NULL if no auth token could be supplied
 * @memberof DasCredMngr
 */
const(char)* CredMngr_getHttpAuth (
    DasCredMngr* pThis,
    const(char)* sServer,
    const(char)* sRealm,
    const(char)* sDataset);

/** Let the credentials manager know that a particular authorization method
 * failed.
 *
 * The credentials manager can use this information to re-prompt the user if
 * desired
 *
 * @param pThis A pointer to a credentials manager structure
 * @param sServer The name of the server for which these credentials apply
 * @param sRealm A string identifing the system the user will be authenticating too.
 * @param sDataset The name of the dataset for which these credentials apply
 * @param sMsg an optional message providing more details on why authentication
 *        failed
 * @memberof DasCredMngr
 */
void CredMngr_authFailed (
    DasCredMngr* pThis,
    const(char)* sServer,
    const(char)* sRealm,
    const(char)* sDataset,
    const(char)* sMsg);

/** Change the function used to prompt users for das2 server credentials
 *
 * The built-in password prompt function assumes a console application, it
 * asks for a username then tries to set the controlling terminal to non-echoing
 * I/O and asks for a password.
 *
 * @param pThis a pointer to a credentials manager structure
 * @param new_prompt The new function, or NULL if no password prompt should
 *        ever be issued
 * @return The old password prompt function
 * @memberof DasCredMngr
 */
das_prompt CredMngr_setPrompt (DasCredMngr* pThis, das_prompt new_prompt);

/** Save the current credentials to the given filename
 *
 * @param pThis a pointer to a CredMngr structure
 * @param sFile the file to hold the loosly encypted credentials
 * @memberof DasCredMngr
 */
bool CredMngr_save (const(DasCredMngr)* pThis, const(char)* sFile);

/* _das_credmngr_h_ */
