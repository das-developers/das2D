module das2.builder;

import das2.cordata;

extern (C) CorDs** build_from_stdin(const char* sProgName, size_t* pSets);
