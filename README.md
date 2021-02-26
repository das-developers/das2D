# das2D 
Initial [D language](https://dlang.org/) das2 module

This is a wrapper around the das2C library with adapters thot make much of
the interface more D-like.  This module is not ready for prime time, it is
however used in production code at U. Iowa in support of the Cassini and Juno 
missions as well as the Long Wave Array (LWA-1) radio astronomy station.

There are three sub-sections to this source library:

* **das2c** - A straight [dstep](https://github.com/jacob-carlborg/dstep)
  conversion of the das2C headers to D modules.
			 
* **das2** - struct & classes that wrap das2C to provide a more comfortable
  interface.
  
*  **test** - Small test programs which both verify that the package is
  operatin properly, and provide example code.
  



