/* Copyright (C) 2018 Chris Piker <chris-piker@uiowa.edu>
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

module das2c.node;

import das2c.credentials;
import das2c.json;

extern (C):

/** @defgroup catalog Catalogs
 * Provides utilities for reading remote data source catalogs and caching their
 * contents in RAM.
 *
 * There are two basic methods of catalog object acquisition, finding a node by
 * it's path from the global root of the federated das2 catalog system:
 * (ex: tag:das2.org,2012:site:/swri/mars_express/aspera3/sciels)
 * or by an loading an explicit URL
 * (ex: http://das2.org/catalog/das/site/uiowa/cassini/rpws/survey.json).
 *
 * When describing the das2 catalog C-API there are two meanings for the word
 * Root.
 *
 * 1) Memory Roots - A node can be the in-memory root of a linked list of nodes.
 *
 * 2) Global Root - Root can also refer to the global das2 top-level un-named
 *    node which resides at http://das2.org/catalog/index.json and it's mirrors.
 *
 * Any node loaded using new_RootNode() or new_RootNode_url() is an *in memory*
 * root node.  It might not be the root of a federated catalog system, but it
 * is still a top level memory item that manages a memory cache for it's
 * subnodes.  If new_RootNode() happens to be called with a URI of 'NULL' then
 * the in-memory root corresponds to the federated catalog root.  The reason for
 * splitting the concept of the in-memory root from the global catalog root
 * is to provide for isolated catalogs that are not part of the global system.
 *
 * When you instantiate a node from a random URL you have to give it a name.
 * Just like files on a disk, catalog nodes do not know their name, it is
 * derived from the name provided by the higher level catalog entries (up to
 * root, which has no name).
 *
 * An Example of getting a data source interface definition follows:
 * @code{.cpp}

 // Get the site root and safely cast the output.  Any particular point in
 // the catalog can be a root node for the purposes of sub-item queries and
 // memory management.  By calling new_RootNode() the returned item is a local
 // root object for memory management purposes.  The higher level nodes that
 // were traversed to get to the requested item are deleted from memory.

 DasNode* pRoot = new_RootNode("tag:das2.org,2012:site:/uiowa", NULL, NULL);
 if(!DasNode_isCatalog(pNode)) handle_error();

 // Use the site catalog to get the Cassini Saturn SLS2 data source description

 const char* sRelPath = "uiowa/cassini/ephemeris/saturn_sls2";
 DasNode* pNode = DasNode_subNode(pRoot, sRelPath, NULL, NULL);

 if(!(DasNode_isStreamSource(pNode)) handle_error();

 // Get the HTTP get Query interface definition

 const DasJdo* pDef = DasNode_getJdo(pNode, "SOURCE/QUERY_PARAMS");
 if(pDef == NULL) handle_error();

 // Freeing the root node will delete all lower nodes

 del_DasNode(pRoot);

 @endcode
 *
 * You now have a JSON object providing the query definition see
 * http://das2.org/datasource.html for more information on the content of das2
 * data source definitions.
 *
 * For isolated sites, or for testing purposes catalog nodes can be loaded
 * directly.  The following example acquires a local test root and then a
 * specific test node.
 *
 @code

 // Assume this site uses a password since it is a testing area.  Create a
 // credentials manager and pass a basic auth hash so we aren't bothered during
 // testing.

 DasCredMngr* pMngr = new_CredMngr(NULL);
 das_credential cred;
 das_cred_init(&cred, "my.domain.com", "Regression Test Catalog", NULL,
              "VVNFUk5BTUU6UEFTU1dPUkQ=");
 CredMngr_addCred(pMngr, &cred);

 const char* sTestUrl = "http://my.domain.com/das2/regtest.json";
 DasNode* pRoot = new_RootNode_url(sTestUrl, pMngr, NULL);
 if(!DasNode_isCatalog(pNode)) handle_error();

 // At this point sub-items can be loaded from the local root as above.

 DasNode* pNode = DasNode_subNode("MarsExpress/aspera/els", pMngr, NULL);

 @endcode
 *
 *
 */

/* Defines for common path_uri's */
enum D2URI_ROOT = "tag:das2.org,2012:";

/* Defines for common document fragments */
enum D2FRAG_TYPE = "type";
enum D2FRAG_NAME = "name";
enum D2FRAG_TITLE = "title";
enum D2FRAG_DESC = "description";
enum D2FRAG_SUB_PATHS = "catalog";
enum D2FRAG_PATH_SEP = "separator";
enum D2FRAG_SOURCES = "sources";
enum D2FRAG_URLS = "urls";

/* Defines for common document string values */
enum D2CV_TYPE_CATALOG = "Catalog";
enum D2CV_TYPE_COLLECTION = "Collection";
enum D2CV_TYPE_STREAM = "HttpStreamSrc";
enum D2CV_TYPE_TIMEAGG = "FileTimeAgg";
enum D2CV_TYPE_SPASE = "SpaseRecord";
enum D2Cv_TYPE_SPDF_MASTER = "SpdfMasterCat";

/** Catalog node type */
enum das_node_type_enum
{
    d2node_inv = 0,
    d2node_catalog = 1,
    d2node_collection = 2,
    d2node_stream_src = 3,
    d2node_file_agg = 4,
    d2node_spdf_cat = 5,
    d2node_spase_cat = 6
}

alias das_node_type_e = das_node_type_enum;

/** @addtogroup catalog
 * @{
 */

/** Base type for das2 catalog nodes. */
struct das_node
{
    das_node_type_e nType; /* Holds the node type */
    char[512] sURL; /* Holds source URL for this node */
    char[512] sPath; /* Holds the Path URI for this node */
    bool bIsRoot; /* True if a local root node (i.e. is a memory manager) */
    void* pDom; /* A pointer to the document tokens. */
}

alias DasNode = das_node;

/** @} */

/** Create a new root catalog node via a path URI
 *
 * Get a catalog node that is not attached to any parent nodes.  If the
 * node acquired is a container type such as Root, Scheme, or Catalog then
 * it can be used to aquire further nodes.
 *
 * This function consults the distributed das2 catalog to find and load nodes.
 * See new_RootNode_url() for a version that only loads a specified URL.
 *
 * @code{.cpp}

  DasNode* pRoot = NULL;

  // Get the das2 site root catalog node
  pRoot = new_RootNode(D2URI_DAS_SITE_ROOT, NULL, NULL, NULL);

  // Get the U. Iowa site catalog top node
  pRoot = new_RootNode(D2URI_DAS_SITE_ROOT "/uiowa", NULL, NULL);

 @endcode
 *
 * @param sPathUri Retrieve a catalog node given a global path URI.  This a
 *               location from the top of the federated catalog system, not
 *               a file system or web path.
 *
 * @param sAgent The user agent string you wish to send to the server.  If
 *               NULL then the string "libdas2/2.3" is sent.
 *
 * @param pMgr   A credentials manager object to consult if a password is
 *               requested.  May be set to NULL to indicate that only public
 *               items may be requested.  Usually this is not needed as most
 *               catalog entries are public though the data sources they
 *               describe may not be.
 *
 * @return A new DasNode object allocated on the heap, or NULL if object
 *               resolution failed.  Calling del_RootNode() for the returned
 *               pointer will delete all sub-nodes from memory as well.
 *
 * @memberof DasNode
 */
DasNode* new_RootNode (
    const(char)* sPathUri,
    DasCredMngr* pMgr,
    const(char)* sAgent);

/** Create a new root catalog node via direct URL
 *
 * Get a catalog node that is not attached to any parent nodes.  If the
 * node acquired is a container type such as Root, Scheme, or Catalog then
 * it can be used to aquire further nodes.
 *
 * There are two basic methods of node acquisition, set a path URI and let the
 * library find the node using the built-in global catalog location, or
 * provide an explicit URL.
 *
 * @code{.cpp}

  DasNode* pRoot = NULL;

  // Get a standalone local Voyager catalog root
  pRoot = new_RootNode(NULL, "http://my.site.gov/test/local_vgr.json", NULL, NULL);

  // Get a standalone data source description for Voyager PLS data
  pRoot = new_RootNode(NULL, "http://my.site.gov/test/local_vgr/pls.json", NULL, NULL);

 @endcode
 *
 * @param sUrl   Retrieve a catalog node from an explicit Url.  No searches
 *               will be preformed.
 *
 * @param sPathUri Since the node was not loaded by following the federated
 *               catalog system to an end point, you will have to tell the node
 *               it's name.  Any name will worked and it's saved internally.
 *
 * @param sAgent The user agent string you wish to send to the server.  If
 *               NULL then the string "libdas2/2.3" is sent.
 *
 * @param pMgr   A credentials manager object to consult if a password is
 *               requested.  May be set to NULL to indicate that only public
 *               items may be requested.  Usually this is not needed as most
 *               catalog entries are public though the data sources they
 *               describe may not be.
 *
 * @return A new DasNode object allocated on the heap, or NULL if object
 *               resolution failed.  Use DasNode_type() to determine the which
 *               type of Catalog item was acquired.
 *
 * @memberof DasNode
 */
DasNode* new_RootNode_url (
    const(char)* sUrl,
    const(char)* sPathUri,
    DasCredMngr* pMgr,
    const(char)* sAgent);

/** Get a das2 catalog node contained item.
 *
 * This function will search down the catalog hierarchy and find the requested
 * node, downloading any intermediate nodes as needed.  If the descendant node
 * has already been downloaded no new network activity is generated.
 *
 * @param pThis A pointer to a node of type D2C_CATALOG
 *
 * @param sRelPath  the ID of the descendant node.  This id is the portion
 *              that would be appended to this node's PathUri to make the
 *              complete URI of the final node.  sRelPath does not need to start
 *              with the sub-item separator (if one is defined for this catalog)
 *              but may at the callers option.  For example, both:
 *              ":/uiowa" and "uiowa" work for getting the uiowa subnode from
 *              the site catalog, but "/uiowa" would not since the separator
 *              defined for site is ":/".
 *
 * @param sAgent The user agent string you wish to send to the server.  If
 *               NULL then the string "libdas2/2.3" is sent.
 *
 * @param pMgr   A credentials manager object to consult if a password is
 *               requested.  May be set to NULL to indicate that only public
 *               items may be requested.
 *
 * @return       A pointer to the child node, or NULL if no such child existed
 *               in the node cache nor could not be downloaded.
 * @memberof DasNode
 */
DasNode* DasNode_subNode (
    DasNode* pThis,
    const(char)* sRelPath,
    DasCredMngr* pMgr,
    const(char)* sAgent);

/** Returns true this node can contain sub nodes.
 * @memberof DasNode
 */
bool DasNode_isCatalog (const(DasNode)* pNode);

/** Determine if this node defines a das2 stream source
 * @memberof DasNode
 */
bool DasNode_isStreamSrc (const(DasNode)* pNode);

/** Determine if this node is a SPASE record
 * @memberof DasNode
 */
bool DasNode_isSpaseRec (const(DasNode)* pNode);

/** Determine if this node is an SPDF catalog
 * @memberof DasNode
 */
bool DasNode_isSpdfCat (const(DasNode)* pNode);

/** Get the path URI for this catalog node
 * @param pThis the catalog node
 * @return A pointer to the path URI string.  All catalog nodes have a path URI
 * @memberof DasNode
 */
const(char)* DasNode_pathUri (const(DasNode)* pThis);

/** Get the location from which this catalog node was read.
 * @param pThis the catalog node
 * @return A pointer to the source URL string.  All catalog nodes are loaded
 *         from somewhere,  libdas2 does not provide functions to generate
 *         node objects programmatically.
 * @memberof DasNode
 */
const(char)* DasNode_srcUrl (const(DasNode)* pThis);

/** Get the type of node
 * This is a more specific question than the 'is' functions below, which should
 * probably be used instead so that application code can work in a "duck-typing"
 * manner.
 * @param pThis the catalog node
 * @return The node type from the
 * @memberof DasNode
 */
das_node_type_e DasNode_type (const(DasNode)* pThis);

/** Get the node title
 *
 * @param pThis the catalog node
 * @return A string suitable for labeling this node in a GUI.
 *
 * @memberof DasNode
 */
const(char)* DasNode_name (const(DasNode)* pThis);

/** Get the node short description, if provided
 * @memberof DasNode
 */
const(char)* DasNode_title (const(DasNode)* pThis);

/** If true the internal data for this node are in JSON format
 *
 * @param pThis The catalog node
 * @return True if DasNode_getJdo() usable
 */
bool DasNode_isJson (const(DasNode)* pThis);

/**  Get a JSON document object at a fragment location in a node.
 * @param pThis The catalog node
 * @param sFragment The fragment path, for example "CONTACTS/TECH/0/EMAIL"
 * @return The json object at that location, or NULL if the node does not
 *         contain the given element.
 * @memberof DasNode
 */
const(DasJdo)* DasNode_getJdo (const(DasNode)* pThis, const(char)* sFragment);

/**  Get a JSON document object of a particular type at a fragment location
 * @param pThis The catalog node
 * @param type The type of object expected
 * @param sFragment The fragment path, for example "CONTACTS/TECH/0/EMAIL"
 * @return The json object at that location, or NULL if the node does not
 *         contain the given element, or if the given element is of the
 *         wrong type
 * @memberof DasNode
 */
const(DasJdo)* DasNode_getJdoType (
    const(DasNode)* pThis,
    das_json_type_e,
    const(char)* sFragment);

/** Delete a root node freeing it's memory.
 * All sub-nodes will be deleted as well.
 * @memberof DasNode
 */
void del_RootNode (DasNode* pNode);

/* _das_catalog_h_ */
