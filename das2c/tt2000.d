module das2c.tt2000;

extern (C):

/* Basic TT2000 handling, functions in time.h and units.h make make use
   of these */
long das_utc_to_tt2000 (double year, double month, double day, ...);

void das_tt2000_to_utc (
    long nanoSecSinceJ2000,
    double* ly,
    double* lm,
    double* ld,
    ...);

/* _tt2000_h_ */
