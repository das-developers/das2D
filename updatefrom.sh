#!/usr/bin/env bash

# Only argument is source directory for das2C header files.  Platform specific
# windows files "win_*h" are igonred because these are not ment to be exposed
# interfaces.

if [ "$1" = "" ] ; then
	echo "Usage: ./update.sh /path/to/das2C" 
	exit 3
fi

sInDir=$1/das2
sOutDir=./tmp

if [ ! "$sOUtDir" ] ; then
	if ! mkdir -p "$sOutDir" ; then
		echo "Could not generate directory \"${sOutDir}\""
		exit 3
	fi
fi


# Re-write the include directives striping out the directory component since
# dstep doesn't seem to be able to handle these.
# Example:   #include <das2/array.h>  -> 
for file in $(ls ${sInDir}/[a-v]*.h); do
	echo "copy-patch include: ${file} -> ${sOutDir}/$(basename ${file})"
	sed 's/#include <das2\//#include </' ${file} > "$sOutDir/$(basename ${file})"
done

exit 1

