# das2D 
Initial [D language](https://dlang.org/) das2 module

This is a wrapper around the das2C library with adapters that make much of
the interface more D-like.  This module is *not ready for prime time*, it is
however used in production code at U. Iowa in support of the Cassini and Juno 
missions as well as the Long Wave Array (LWA-1) radio astronomy station.

There are three sub-sections to this source library:

* **das2c** - A straight [dstep](https://github.com/jacob-carlborg/dstep)
  conversion of the das2C headers to D modules.
			 
* **das2** - struct & classes that wrap das2C to provide a more comfortable
  interface.
  
*  **test** - Small test programs which both verify that the package is
  operatin properly, and provide example code.
  
To use the library add:
```d
import das2;
```
To your modules.  Since the higher level functions are being created as needed
it may also be necessary to add:
```d
import das2c;
```
as well.


## Building

You'll have to provide the location to your libdas2.3.so file using the
`LIBDAS2_PATH` environment variable.  For example, assume you've built das2C
in your home directory with `N_ARCH` set to `ubuntu20`, then, to build this
modules executable you might run:

```bash
env LIBDAS2_PATH=$HOME/git/das2C/build.ubuntu20 dub build
```

## Using in Projects
Das2D is mostly a source library, though small test programs can be (and should
be) built that demonstrate functionality and test the library.  The DMD command
line that I typically use with external das2D based projects is:
```bash
dmd -i -I$(DAS2D_TOP_DIR) -L-L$(DAS2C_BUILD_DIR) -L-ldas2.3 -L-lexpat -L-lssl \
    -L-lcrypto -L-lfftw3 -L-lz -L-lm -L-lpthread
```
Most of the switches are used to pickup libdas2.3.so and it's dependencies.  The
`-i` switch is important as that directs DMD to compile any imported modules. 
Since this module uses the MIT license, but das2C is LGPL it's best to link against
the shared object libdas2.3.so instead of libdas2.3.a to avoid license entanglements.



