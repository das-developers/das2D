#!/usr/bin/env bash

# Only argument is source directory for das2C header files.  Platform specific
# windows files "win_*h" are igonred because these are not ment to be exposed
# interfaces.

if [ "$1" = "" ] ; then
	echo "Usage: ./update.sh /path/to/das2C" 
	exit 3
fi

sInDir=$1/das2
sOutDir=./das2c

if [ ! -d "$sOUtDir" ] ; then
	if ! mkdir -p "$sOutDir/das2" ; then
		echo "Could not generate directory \"${sOutDir}\""
		exit 3
	fi
fi

if ! cd $sOutDir ; then
	echo "cd $sOutDir failed"
	exit 3
fi

# Re-write the include directives striping out the directory component since
# dstep doesn't seem to be able to handle these... fixed not needed
#echo "copy-patch include: ${file} -> ${sOutDir}/$(basename ${file})"
#sed 's/#include <das2\//#include </' ${file} > "$sOutDir/$(basename ${file})"

# Convert Zlib Byte to unsigned char 
# sed s/Byte*/ubyte*/' 

cp -v ${sInDir}/[a-v]*.h das2

echo "dstep --package das2c --collision-action=abort -I./ das2/*.h"

dstep --package das2c --collision-action=abort -I./ das2/*.h

if [ $? -ne 0 ] ; then
	echo "dstep error detected, update not complete"
	exit 3
fi

mv das2/*.d ./
if [ -f core.d] ; then
	rm core.d
fi

if [ $? -ne 0 ] ; then
	echo "D-module move error detected, update not complete"
	exit 3
fi

rm das2/[a-v]*.h 
if [ $? -ne 0 ] ; then
	echo "Old header removal error, update not complete"
	exit 3
fi

rmdir das2
if [ $? -ne 0 ] ; then
	echo "Temporary directory could not be removed, update not complete"
	exit 3
fi
