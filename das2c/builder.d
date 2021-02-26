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

module das2c.builder;

import das2c.stream;
import das2c.dataset;
import das2c.descriptor;
import das2c.packet;
import das2c.processor;

extern (C):

struct ds_pd_set
{
    PktDesc* pPd;
    DasDs* pDs;
}

/** Builds datasets from a das2 stream
 *
 * General usage for this object type would be:
 *
 * @code
 * DasIO* pIn = new_DasIO_file("myprogram", stdin, "r");
 * Builder pBldr = new_Builder();
 * DasIO_addProcessor(pIn, (StreamHandler*)pBldr);
 * DasIO_readAll(pIn);
 * size_t nSets = 0;
 * DataSet** lDataSets = Builder_datasets(pBldr, &nSets);
 * @endcode
 *
 * @extends StreamHandler
 * @class Builder
 * @ingroup datasets
 */
struct das_builder
{
    StreamHandler base;

    DasDesc* pProps; /* Hold on to the global set of properties in a separate
    	                       location */

    bool _released; /* true if datasets taken over by some other object */

    /* Das2 allows packet descriptors to be re-defined.  This is annoying but
    	 * we have to deal with it.  Here's the tracking mechanism
    	 *
    	 * lDsMap - The index in this array is a packet ID
    	 *          The value is the index in lPairs that holds a copy of the packet
    	 *          descriptor and it's dataset.
    	 *
    	 * lPairs -    The dataset and corresponding packet descriptors.
    	 *
    	 * If a packet ID is re-defined, first look to see if the new definition is
    	 * actually something that's been seen before and change the value in lDsMap
    	 * to the old definition. */
    int[MAX_PKTIDS] lDsMap;

    size_t uValidPairs;
    ds_pd_set* lPairs;
    size_t uSzPairs;
}

alias DasDsBldr = das_builder;

/** Generate a new dataset builder.
 *
 * @return A new dataset builder allocated on the heap suitable for use in
 *         DasIO::addProcessor()
 *
 * @member of DasDsBldr
 */
DasDsBldr* new_DasDsBldr ();

/** Delete a builder object, freeing it's memory and the array memory if
 * it has not been released
 *
 * @param pThis
 * @member of DasDsBldr
 */
void del_DasDsBldr (DasDsBldr* pThis);

/** Detach data ownership from builder.
 *
 * Call this function to indicate that deleting the builder should not delete
 * any DataSets or properties that have been constructed.  If this call is no
 * made, then del_Builder() will also deallocate any dataset objects and
 * descriptor objects that have been generated.
 *
 * @member of DasDsBldr
 */
void DasDsBldr_release (DasDsBldr* pThis);

/** Gather all correlated data sets after stream processing has finished.
 *
 * @param[in] pThis a pointer to this builder object.
 * @param[out] uLen pointer to a size_t variable to receive the number of
 *         correlated dataset objects.
 * @return A pointer to an array of correlated dataset objects allocated on the
 *         heap.  Each data correlation may contain 1-N datasets
 *
 * @member of DasDsBldr
 */
DasDs** DasDsBldr_getDataSets (DasDsBldr* pThis, size_t* pLen);

/** Get a pointer to the global properties read from the stream.
 * The caller does not own the descriptor unless Builder_release() is called.
 *
 * @param pThis a pointer to the builder object
 * @return A pointer the builder's copy of the top-level stream descriptor,
 *         or NULL if no stream was read, or it had no properties
 *
 * @member of DasDsBldr
 */
DasDesc* DasDsBldr_getProps (DasDsBldr* pThis);

/** Convenience function to read all data from standard input and store it
 *  in memory.
 *
 * @param sProgName the name of the program for log writing.
 *
 * @param pSets pointer to a value to hold the number of datasets read from
 *              standard input
 *
 * @return NULL if there was an error building the dataset, an array of
 *         correlated dataset pointers otherwise
 */
DasDs** build_from_stdin (
    const(char)* sProgName,
    size_t* pSets,
    DasDesc** ppGlobal);

/* _das_builder_h_ */
