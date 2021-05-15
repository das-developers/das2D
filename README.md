# das2D 
Initial [D language](https://dlang.org/) das2 module

This is a wrapper around the das2C library with adapters that make much of
the interface more D-like.  This module is *not ready for prime time*, it is
however used in production code at U. Iowa in support of the Cassini and Juno 
missions as well as the Long Wave Array (LWA-1) radio astronomy station.

There are two sub-sections to this source library:

* **das2c** - A straight [dstep](https://github.com/jacob-carlborg/dstep)
  conversion of the [das2C](https://github.com/das-developers/das2C) headers
  to D modules.
			 
* **das2** - struct & classes that wrap das2C to provide a more comfortable
  interface.
  
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

This is a source library, so technically there is nothing to build, though 
running the included unit tests is a good idea.  To do so you'll have to
provide the location to your libdas2.3.so file using the `LD_LIBRARY_PATH`
environment variable.  For example, assume you've built das2C in your home
directory with `N_ARCH` set to `ubuntu20`, then, to build this module's
unit tests run:

```bash
env LD_LIBRARY_PATH=$HOME/git/das2C/build.ubuntu20 dub test
```

To build the documentation run the excellent 
[adrdox](https://github.com/adamdruppe/adrdox) tool on the main project area:

```bash
cd das2D
doc2 ./
```
The program 'doc2' is supplied by `adrdox`.

## Using in D Scripts

Single file D programs may be run as scripts that are compiled automatically in
the backgroud.  The easiest way to use das2D in a script is to set the `dub`
program as the interpreter in a shebang line.  To do so, add the following to the
top of your D script file:
```d
#!/usr/bin/env dub
/+ dub.sdl:
    dependency "das2"  version="*"  path="/PATH/TO/das2D"
+/
```
and make sure das2D is on your dub search path (see below).  At present
[a bug in dub](https://github.com/dlang/dub/issues/2123) prevents using
an environment variable to set the path to das2D.

## Using in Projects

As is typical for D projects, there is no install script.  To install this
library so that it can be used by local dub projects you can issue a
`git clone` inside a local dub search path.  If you don't have one, the
following command example will do the trick:

```bash
dub add-local $HOME/dublocal    # For example, dublocal is not a special name
git clone git@github.com:das-developers/das2D.git
``` 

and add it as a dependency to your `dub.json` like so:

```json
"dependencies": {
	"das2D": "~master"
}
```

The version ID "~master" means the top level of the master branch.  (The main
branch of das2D will be switched to "main" at some point.)

To "install" the library for non-dub pojects, copy the das2 and das2c
directories to your favorite include path and tell dmd to autobuild any 
reference sources.  For example:

```bash
cp -r -p das2 das2c /usr/local/voyager/include/D  # For example

DINC=/usr/local/voyager/include/D
dmd -i -I$(DINC)  # In your project makefile
```

Since your D program will depend on das2C and it's libraries, here's the
rest of the command line arguments needed to link with das2C:

```bash
dmd -i -I$(DINC) -L-L$(DAS2C_BUILD_DIR) -L-ldas2.3 -L-lexpat -L-lssl \
    -L-lcrypto -L-lfftw3 -L-lz -L-lm -L-lpthread
```

This module uses the MIT license, but das2C is LGPL, you can avoid license
entanglements by linking against the shared object `libdas2.3.so` instead of
the static library `libdas2.3.a`.


## Differences with das2C

Other than being in a different language, the main usage difference between 
das2D and [das2C](https://github.com/das-developers/das2C) is that there is no
need to explicitly initialize the library in the primary thread.
```
das2_init(); // <-- not needed in D code due to module initilizers
```
A `shared static this()` block in the `das2/package.d` file handles runtime
initialization.

Other usage differences with das2C will be noted here as needed.




