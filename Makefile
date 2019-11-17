# This is a sub-make: It needs the C library output area
#ifeq ($(C_BUILD_DIR),)
#$(error Set environment C_BUILD_DIR or exec "make dlib" from the top-level project directory)
#endif

#ifeq ($(C_HDR_DIR),)
#$(error Set environment C_HDR_DIR or exec "make dlib" from the top-level project directory)
#endif


##############################################################################
# Generic definitions for: Native Programs

ifeq ($(PREFIX),)
ifeq ($(HOME),)
PREFIX:=$(USERPROFILE)
else
PREFIX=$(HOME)
endif
endif

ifeq ($(INST_ETC),)
INST_ETC=$(PREFIX)/etc
endif

ifeq ($(INST_SHARE),)
INST_SHARE=$(PREFIX)/share
endif

ifeq ($(INST_DOC),)
INST_DOC=$(PREFIX)/doc
endif

ifeq ($(INST_INC),)
INST_INC=$(PREFIX)/include
endif

ifeq ($(N_ARCH),)
N_ARCH=$(shell uname -s).$(shell uname -p)
endif

ifeq ($(INST_NAT_BIN),)
INST_NAT_BIN=$(PREFIX)/bin/$(N_ARCH)
endif

ifeq ($(INST_NAT_LIB),)
INST_NAT_LIB=$(PREFIX)/lib/$(N_ARCH)
endif

BUILD_DIR:=build.$(N_ARCH)

##############################################################################
# Native Platform specific include

UNAME = $(shell uname)

include $(UNAME).mak
