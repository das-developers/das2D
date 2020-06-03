# Project definitions
BD=build.$(N_ARCH)

TARG=libdas2_d.a

TARG_SRCS=package.d daspkt.d dft.d log.d time.d util.d units.d reader.d
#builder.d dataset.d  
 

TARG_OBJS=$(patsubst %.d,$(BD)/%.o, $(TARG_SRCS))

UTIL_PROGS=

TEST_PROGS=



##############################################################################
# Build definitions

DC=dmd
#DC=gdc-5

DFLAGS=-g -od$(PWD)/$(BD) -w -m64 -debug
#DFLAGS=-ggdb -Wall -Idas2

DASLIBS=-L-L$(BD) -L-L../../$(BD) -L-ldas2_d -L-ldas2
#DASLIBS=-L$(BD) -L../../$(BD) -ldas2

DLIBS=$(DASLIBS) -L-lfftw3 -L-lexpat -L-lz -L-lm
#DLIBS=$(DASLIBS) -lfftw3 -lexpat -lz -lm

##############################################################################
# Derived definitions

TREE_SRCS=$(patsubst %.d,das2/%.d,$(TARG_SRCS))

INST_SRCS = $(patsubst %.d,$(INST_MOD_SRC)/das2/%.d,$(TARG_SRCS))

BUILD_UTIL_PROGS= $(patsubst %,$(BD)/%, $(UTIL_PROGS))
INST_UTIL_PROGS= $(patsubst %,$(INST_NAT_BIN)/%, $(UTIL_PROGS))

##############################################################################
# Pattern Rules

# Pattern rule for compiling D files
$(BD)/%.o:das2/%.d
	$(DC) $< $(DFLAGS) -o $@

# Pattern rule for building single source utility programs
$(BD)/%:utilities/%.d | $(BD)
	$(DC) $< $(DFLAGS) -of$@ $(DLIBS)

#$(DC) $< $(DFLAGS) -o $@ $(DLIBS)

# Pattern rule for installing static libraries
$(INST_NAT_LIB)/%.a:$(BD)/%.a
	install -D -m 664 $< $@

# Pattern rule for installing D module files
$(INST_MOD_SRC)/das2/%.d:das2/%.d
	install -D -m 664 $< $@

# Direct make not to nuke the intermediate .o files
.SECONDARY: $(BUILD_OBJS)
.PHONY: test


## Explicit Rules, Building ##################################################

build:$(BD) $(BD)/$(TARG)  $(BUILD_UTIL_PROGS)


$(BD):
	@if [ ! -e "$(BD)" ]; then echo mkdir $(BD); \
        mkdir $(BD); chmod g+w $(BD); fi

$(BD)/$(TARG):$(TREE_SRCS)
	$(DC) $^ -lib $(DFLAGS) -of$(notdir $@)


test:
	@echo "No D unit tests currently defined"


install:$(INST_NAT_LIB)/$(TARG) $(INST_SRCS)


## Explicit Rules, Documentation #############################################

distclean:
	if [ -d "$(BD)" ]; then rm -r $(BD); fi

clean:
	-rm -r $(BD)



