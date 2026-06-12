# Builds the standalone libinput reader binary.
#
# Two steps, mirroring how the spinel wrapper links, but with our C shim
# added to the final cc invocation:
#   1. spinel src/main.rb -c -o build/main.c   (Ruby -> C, codegen only)
#   2. cc build/main.c src/shim/shim.c ...      (+ shim, + libinput libs)
#
# spinel normally scrapes /* SPINEL_LINK */ markers from the generated C
# to find -linput etc.; because we drive cc ourselves we pass the
# libinput link flags explicitly via pkg-config instead.

SPINEL_DIR ?= $(HOME)/ghq/github.com/matz/spinel
SPINEL     := $(SPINEL_DIR)/spinel
# Optional spinel runtime (bigint + regexp). Empty if not built; our
# program does not need it, but link it when present to be safe.
SP_RT_LIB  := $(wildcard $(SPINEL_DIR)/lib/libspinel_rt.a)

CC ?= cc

LIBINPUT_CFLAGS := $(shell pkg-config --cflags libinput libudev)
LIBINPUT_LIBS   := $(shell pkg-config --libs libinput libudev)

SRCS  := $(wildcard src/*.rb)
SHIM  := src/shim/shim.c
GEN_C := build/main.c
BIN   := build/fusuma-libinput-events

all: $(BIN)

$(GEN_C): $(SRCS) | build
	$(SPINEL) src/main.rb -c -o $(GEN_C)

$(BIN): $(GEN_C) $(SHIM) | build
	$(CC) -O2 -Wno-all -ffunction-sections -fdata-sections \
	  -I$(SPINEL_DIR)/lib -I$(SPINEL_DIR)/lib/regexp $(LIBINPUT_CFLAGS) \
	  $(GEN_C) $(SHIM) $(SP_RT_LIB) -lm $(LIBINPUT_LIBS) \
	  -Wl,--gc-sections -o $(BIN)

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean
