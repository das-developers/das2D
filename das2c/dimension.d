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

module das2c.dimension;

import das2c.util;
import das2c.descriptor;
import das2c.variable;

extern (C):

enum DASDIM_MAXDEP = 16; // Arbitrary decision, can be changed
enum DASDIM_MAXVAR = 16; // Another arbitrary changable descision

/* OFFSET and REFERENCE variable roles were a tough call.  In the end you only
 * need center values to do DFT's.  The DFT code should look at the coordinate
 * series and see what if it has a constant change in index.  If so, you can do
 * a DFT, otherwise you can't.
 *
 * Currently in das 2.2 land we know that one "package" of values is a
 * continuous waveform set.  We can look at the yTags, see if they are
 * consistent and the if they are then we can transform.  It's very clear when
 * we can do this, but it's also it requires a very specific data structure.
 * So in a general data model, how do you get the yTags?  You *can* do it with a
 * morphology check but those tend to be a rabbit hole of exploding if
 * statements.
 *
 * The initial thought was to have offset dimensions, but that caused a massive
 * symmetry break in the data model.  Why have a rule that always combines two
 * dimensions with a + operator?  Why not other operators?  Also, if you set
 * say the the "STD_DEV" variable in the reference dimension and also in the
 * offset dimension, how do you combine those?  It seems offset dimensions
 * trigger more problems then they solve.
 *
 * The solution taken here is to introduce two variable roles, REFERENCE and
 * OFFSET.  Since this choice only requires adding two string constants it can
 * be ignored if turns out it's a bad choice.  Otherwise it simplifies the
 * concept of  breaking down values into a reference point that may change for
 * each packet and a set of fixed offsets.  These sorts of coordinates come up
 * a lot in our work, for example frequency values for down-mixed data, radar
 * return altitudes and waveform captures.
 *
 * DASVAR_CENTER should still be provided for client codes that don't understand
 * the offset and reference semantic.  And since this can be done with one
 * call to new_DasVarBinary() without exploding the network data volume
 * it doesn't seem like that much of a burden.
 *
 * Another approach would have been to expand properties to include an
 * index/value relationship section.  We could define things like constant
 * change of value for a change in a certain index and then define if rolling
 * the next index up is the same change as the lower index roll.  This seemed
 * like a much more complicated idea and didn't work so well with offsets that
 * are constant by record (i.e. the i value) but not constant by value index
 * (j,k,l ...).
 * -cwp
 */

extern __gshared const(char)* DASVAR_CENTER;
extern __gshared const(char)* DASVAR_MIN;
extern __gshared const(char)* DASVAR_MAX;
extern __gshared const(char)* DASVAR_WIDTH;
extern __gshared const(char)* DASVAR_MEAN; /* all these can substitute for the center    */
extern __gshared const(char)* DASVAR_MEDIAN; /* if the center is missing but they are      */
extern __gshared const(char)* DASVAR_MODE; /* distinct so it's good to include them here */
extern __gshared const(char)* DASVAR_REF;
extern __gshared const(char)* DASVAR_OFFSET;
extern __gshared const(char)* DASVAR_MAXERR;
extern __gshared const(char)* DASVAR_MINERR;
extern __gshared const(char)* DASVAR_UNCERT;
extern __gshared const(char)* DASVAR_STD_DEV;
extern __gshared const(char)* DASVAR_SPREAD;
extern __gshared const(char)* DASVAR_WEIGHT;

/** @addtogroup datasets
 * @{
 */

enum dim_type
{
    DASDIM_UNK = 0,
    DASDIM_COORD = 1,
    DASDIM_DATA = 2
}

/** Das2 Physical Dimensions
 *
 * Das2 dimensions are groups of variables within a single dataset that describe
 * the same physical thing.  For example the "Time" coordinate dimension would
 * groups all variables that locate data in time.  An "Ex" dimension would
 * provide a group of variables describing the electric field in a spacecraft X
 * direction.
 *
 * A dimension needs to have at least one variable, but it may have many.
 * For example, a dataset that only provides time values by single points
 * would only have a single variable in the time dimension.  Hovever a dataset
 * providing extended duration events would need two time variables.  One time
 * variable could provide the event start times and another the end times.
 *
 * There are two basic types of dimensions, coordinates and data.  Coordinate
 * dimensions provide variables to locate data in an independent parameter space,
 * these are typically the X-axis values (or X and Y for spectrograms).  Data
 * dimensions typically group together related measurements.
 *
 * @extends Descriptor
 */
struct das_dim
{
    DasDesc base; /* Attributes or properties for this variable */
    dim_type dtype; /* Coordinate or Data flag */
    char[DAS_MAX_ID_BUFSZ] sId; /* A name for this dimension */

    /* Holds the max index to report out of this dimension.
    	 * The dimension may have internal indices beyond these
    	 * but they are not correlated with the overall dataset
    	 * indicies */
    int iFirstInternal;

    /* The variables which supply data for this dimension */
    DasVar*[DASDIM_MAXVAR] aVars;
    char[32][DASDIM_MAXVAR] aRoles;
    size_t uVars;

    /* For dependent variables (i.e. data) pointers to relavent independent
    	 * dimensions are here.  I don't think we need this here as the dataset
    	 * provides this information.  Going to punt it for now but will use
    	 * DasVar_orthoginalTo() when printing coordinate information */
    /* struct das_dim* aCoords[DASDIM_MAXDEP];
    	size_t uCoords;*/
}

alias DasDim = das_dim;

/** Create a new dimension (not as impressive as it sounds)
 *
 * @param sId The id of the dimension, which should be a common name such as
 *         time, energy, frequency, latitude, longitude, solar_zenith_angle,
 *         electric_spectral_density, netural_flux_density, etc.  It's much
 *         more important for coordinate dimensions to have common names than
 *         data dimensions.
 *
 * @param dtype One of DASDIM_COORD, DASDIM_DATA
 *
 * @param nRank
 * @memberof DasDim
 * @return
 */
DasDim* new_DasDim (const(char)* sId, dim_type dtype, int nRank);

/** Get the dimension's id
 *
 * @param pThis a pointer to a das dimension structure.
 * @return The id of the dimension, which should be a common name such as
 *         time, energy, frequency, electric_spectral_density,
 *         netural_flux_density, etc.
 * @memberof DasDim
 */
const(char)* DasDim_id (const(DasDim)* pThis);

/** Print an information string describing a dimension.
 *
 * @param pThis A pointer to a dimension structure
 * @param sBuf A buffer to hold the description
 * @param nLen Warning, these can be long so provide around 256 bytes or more
 *             of storage.
 * @return A pointer to the next write location within the buffer sBuf that
 *         can be used for appending more text.
 * @memberof DasDim
 */
char* DasDim_toStr (const(DasDim)* pThis, char* sBuf, int nLen);

/** Copy in dataset properties from some other descriptor
 *
 * This is a helper for das 2.2 streams as these use certian name patterns to
 * indicate which dimension a property is for
 *
 * Any properties that start with a specific dimension identifier i.e.
 * 'x','y','z','w' are copied into this dataset's properties dictionary.  Only
 * properties not present in the internal dictionary are copied in.
 *
 * @param pThis this dimension object
 * @param cAxis the connonical axis to copy in.
 * @param pOther The descriptor containing properites to copy in
 * @return The number of properties copied in
 * @memberof DasDim
 */
int DasDim_copyInProps (DasDim* pThis, char cAxis, const(DasDesc)* pOther);

/** Add a variable to a dimension
 *
 * @param pThis the dimesion in question
 * @param pVar the variable to add
 * @param role The type of information this variable supplies for the
 *             dimension.  Any string may be used, standard values are
 *             provided in the defines: DASVAR_CENTER, DASVAR_MIN, DASVAR_MAX,
 *             DASVAR_WIDTH, DASVAR_REF, DASVAR_OFFSET, DASVAR_MEAN, DASVAR_MEDIAN,
 *             DASVAR_MODE, DASVAR_MAX_ERR, DASVAR_MIN_ERR, DASVAR_UNCERT,
 *             DASVAR_STD_DEV, DASVAR_SPREAD, and DASVAR_WEIGHT.  Any string under 32
 *             characters is acceptable, using a single case is prefered.
 *
 * @returns true if the variable could be added, or false otherwise.  Trying
 *          to add a second variable for the same role will result in a return
 *          value of false.
 *
 * @memberof DasDim
 */
bool DasDim_addVar (DasDim* pThis, const(char)* sRole, DasVar* pVar);

/** Get a variable providing values for a particular role in the dimension
 *
 * @param pThis A pointer to a dimension
 *
 * @param sRole A string defining the role,  Any string may be used,
 *              standard values are provided in the defines: DASVAR_CENTER,
 *              DASVAR_MIN, DASVAR_MAX, DASVAR_WIDTH, DASVAR_REF, DASVAR_OFFSET,
 *              DASVAR_MEAN, DASVAR_MEDIAN, DASVAR_MODE, DASVAR_MAX_ERR, DASVAR_MIN_ERR,
 *              DASVAR_UNCERT, DASVAR_STD_DEV, DASVAR_SPREAD, and DASVAR_WEIGHT.
 *
 * @return A pointer to a DasVar or NULL if no variable exists within this
 *         dimension for the given role.
 * @memberof DasDim
 */
const(DasVar)* DasDim_getVar (const(DasDim)* pThis, const(char)* sRole);

/** Get a variable poviding single point values in a dimension
 *
 * The most common variable role, DASVAR_CENTER, is typically present in a
 * dimension but not always.  Sometimes other roles take this variable's
 * place, such as the mean, median or mode or an average of the minimum and
 * maximum values.  Use this function to autoselct a variable to use as the
 * center point when plotting data.
 *
 * @param pThis A pointer to a dimension
 *
 * @return A pointer to a variable that can be used to provide single points
 *         in this dimension, or NULL in the rare instance that nothing in
 *         this dimesion can be used for single point values.  A return of
 *         false from this call probably means you have an invalid or highly
 *         customized dataset.
 *
 * @memberof DasDim
 */
const(DasVar)* DasDim_getPointVar (const(DasDim)* pThis);

/** Remove a variable by role from a dimensions
 *
 * The caller is considered to own the variable and must delete it if no longer
 * in use.
 *
 * @param pThis The dimension in question
 *
 * @param role A role string.  Can be anything less that 32 characters but
 *        library uses are recommened to choose from the predefined strings:
 *        D2VP_CENTER, D2VP_MIN, D2VP_MAX, D2VP_WIDTH, D2VP_MEAN, D2VP_MEDIAN,
 *        D2VP_MODE, D2VP_REF, D2VP_OFFSET, D2VP_MAXERR, D2VP_MINERR,
 *        D2VP_UNCERT, D2VP_STD_DEV
 *
 * @return A pointer to the variable occuping the given role, or NULL if no
 *         variable occupied the specified role
 *
 * @memberof DasDim
 */
DasVar* DasDim_popVar (DasDim* pThis, const(char)* role);

/** Delete a dimension and drop the reference count on all contained variables
 *
 * @param pThis A pointer to a dimension structure.  This pointer should be
 *        set to NULL after calling this function
 * @memberof DasDim
 */
void del_DasDim (DasDim* pThis);

/** Get the maximum extent of this dimension in index space
 *
 * This function can be used to determine if there is a set of indices that
 * when changed, only affect the values of the variables in one dimension
 * without affecting the other.  If such an index set exists then the dimensions
 * are orthogonal in index space.
 *
 * @code
 * // Given two dimension structure pointer, pLat and pLong
 * int lat_shape[D2ARY_MAXIDX];
 * int long_shape[D2ARY_MAXIDX];
 *
 * DasDim_shape(pLat, lat_shape);
 * DasDim_shape(pLong, long_shape);
 *
 * if(Shape_IsOrthoginal(lat_shape, long_shape)){
 *		// Yes, we can slice in latitude and longitude simply by changing the
 *		// indices lat_shape but not long_shape and vice versa
 * }
 * else{
 *		// No, we can't simply slice in index space to hold latitude or
 *    // longitude constant.  Will need to define an index of a latitude or
 *		// longitude range.  I.e. will need to make a thin slab in
 * }
 * @endcode
 *
 * This is a convenience wrapper around Variable_shape that takes the maximum
 * extent in all contained variables.
 *
 * @param pThis the Coordinate Dimension or Data Dimension in question
 *
 * @param pShape a pointer to an array up to D2ARY_MAXDIM in size to receive the
 *        shape values.  A -1 in any position means that the index in question
 *        does not affect any of variables within this dimension.
 *
 * @return The rank of the variable
 *
 * @see Variable_shape()
 *
 * @memberof DasDim
 */
int DasDim_shape (const(DasDim)* pThis, ptrdiff_t* pShape);

/** Return the current max value index value + 1 for any partial index
 *
 * This is a more general version of DasDim_shape that works for both cubic
 * arrays and with ragged dimensions, or sequence values.
 *
 * @param pThis A pointer to a DasDim strutcture
 * @param nIdx The number of location indices which may be less than the
 *             number needed to specify an exact value.
 * @param pLoc A list of values for the previous indexes, must be a value
 *             greater than or equal to 0
 * @return The number of sub-elements at this index location or D2IDX_UNUSED
 *         if this variable doesn't depend on a given location, or D2IDx_FUNC
 *         if this variable returns computed results for this location
 *
 * @see DasAry_lengthIn
 */
ptrdiff_t DasDim_lengthIn (const(DasDim)* pThis, int nIdx, ptrdiff_t* pLoc);

/** @} */

/* _das_dimension_h_ */
