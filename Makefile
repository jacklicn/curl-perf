# Output binary to be built
TARGET=curl-loader
TAGFILE=.tagfile

BUILD=$(shell pwd)/build

#
# Building of DNS asynch resolving c-ares library.
#
CARES_BUILD=$(BUILD)/c-ares
CARES_VER:=1.11.0
CARES_MAKE_DIR=$(CARES_BUILD)/c-ares-$(CARES_VER)

CURL_BUILD=$(BUILD)/curl
CURL_VER:=7.41.0
CURL_MAKE_DIR=$(CURL_BUILD)/curl-$(CURL_VER)

LIBEVENT_BUILD=$(BUILD)/libevent
LIBEVENT_VER:=2.0.22
LIBEVENT_MAKE_DIR=$(LIBEVENT_BUILD)/libevent-$(LIBEVENT_VER)-stable

OPENSSL_BUILD=$(BUILD)/openssl
OPENSSL_VER:=1.0.2g
OPENSSL_MAKE_DIR=$(OPENSSL_BUILD)/openssl-$(OPENSSL_VER)

ZLIB_BUILD=$(BUILD)/zlib
ZLIB_VER:=1.2.8
ZLIB_MAKE_DIR=$(ZLIB_BUILD)/zlib-$(ZLIB_VER)

OBJ_DIR:=obj
SRC_SUFFIX:=c
OBJ:=$(patsubst %.$(SRC_SUFFIX), $(OBJ_DIR)/$(basename %).o, $(wildcard *.$(SRC_SUFFIX)))

OPENSSLDIR=$(shell $(CURDIR)/openssldir.sh)

# C compiler
CC=gcc

#C Compiler Flags
CFLAGS= -W -Wall -Wpointer-arith -pipe \
	-DCURL_LOADER_FD_SETSIZE=20000 \
	-D_FILE_OFFSET_BITS=64

#
# Making options: e.g. $make optimize=1 debug=0 profile=1 
#
debug ?= 1
optimize ?= 1
profile ?= 0

#Debug flags
ifeq ($(debug),1)
DEBUG_FLAGS+= -g
else
DEBUG_FLAGS=
ifeq ($(profile),0)
OPT_FLAGS+=-fomit-frame-pointer
endif
endif

#Optimization flags
ifeq ($(optimize),1)
OPT_FLAGS+= -O3 -ffast-math -finline-functions -funroll-all-loops \
	-finline-limit=1000 -mmmx -msse -foptimize-sibling-calls
else
OPT_FLAGS= -O0
endif

# CPU-tuning flags for Pentium-4 arch as an example.
#
#OPT_FLAGS+= -mtune=pentium4 -mcpu=pentium4

# CPU-tuning flags for Intel core-2 arch as an example. 
# Note, that it is supported only by gcc-4.3 and higher
#OPT_FLAGS+=  -mtune=core2 -march=core2

#Profiling flags
ifeq ($(profile),1)
PROF_FLAG=-pg
else
PROF_FLAG=
endif


#Linker mapping
LD=gcc

#Linker Flags
LDFLAGS=-L./lib

# Link Libraries. In some cases, plese add -lidn, or -lldap
LIBS= -lcurl -lcares -levent -lssl -lcrypto -lz -lpthread -lnsl -lresolv -ldl -lrt

# Include directories
INCDIR=-I. -I./include

# Targets
LIBCARES:=./lib/libcares.a
LIBCURL:=./lib/libcurl.a
LIBEVENT:=./lib/libevent.a
LIBOPENSSL:=./lib/libssl.a
LIBZ:=./lib/libz.a

# documentation directory
DOCDIR=/usr/share/doc/curl-loader/

# manual page directory
MANDIR=/usr/share/man

all: $(TARGET)

$(TARGET): $(LIBZ) $(LIBOPENSSL) $(LIBEVENT) $(LIBCARES) $(LIBCURL) $(CONF_OBJ) $(OBJ)
	$(LD) $(PROF_FLAG) $(DEBUG_FLAGS) $(OPT_FLAGS) -o $@ $(OBJ) $(LDFLAGS) $(LIBS)

nobuildcurl: $(OBJ)
	$(LD) $(PROF_FLAG) $(DEBUG_FLAGS) $(OPT_FLAGS) -o $(TARGET) $(OBJ) $(LIBS)

clean:
	rm -f $(OBJ_DIR)/*.o $(TARGET) core*

cleanall: clean
	rm -rf ./build ./packages/curl-$(CURL_VER) \
	./packages/curl ./include ./lib ./bin $(TAGFILE) \
	./packages/c-ares-$(CARES_VER) \
	*.log *.txt *.ctx *~ ./conf-examples/*~

tags:
	etags --members -o $(TAGFILE) *.h *.c

install:
	mkdir -p $(DESTDIR)/usr/bin 
	mkdir -p $(DESTDIR)$(MANDIR)/man1
	mkdir -p $(DESTDIR)$(MANDIR)/man5
	mkdir -p $(DESTDIR)$(DOCDIR)
	cp -f curl-loader $(DESTDIR)/usr/bin
	cp -f doc/curl-loader.1 $(DESTDIR)$(MANDIR)/man1/  
	cp -f doc/curl-loader-config.5 $(DESTDIR)$(MANDIR)/man5/
	cp -f doc/* $(DESTDIR)$(DOCDIR) 
	cp -rf conf-examples $(DESTDIR)$(DOCDIR)

$(LIBEVENT):
	mkdir -p $(LIBEVENT_BUILD)
	mkdir -p ./include; mkdir -p ./lib
	cd $(LIBEVENT_BUILD); tar zxvf ../../packages/libevent-$(LIBEVENT_VER)-stable.tar.gz;
	cd $(LIBEVENT_MAKE_DIR); patch -p1 < ../../../patches/libevent-nevent.patch; \
	./configure --prefix=$(LIBEVENT_BUILD) --disable-shared CFLAGS="$(PROF_FLAG) $(DEBUG_FLAGS) $(OPT_FLAGS)"
	make -C $(LIBEVENT_MAKE_DIR); make -C $(LIBEVENT_MAKE_DIR) install
	cp -prf $(LIBEVENT_BUILD)/include/* ./include
	cp -pf $(LIBEVENT_BUILD)/lib/libevent.a ./lib

$(LIBCARES):
	mkdir -p $(CARES_BUILD)
	mkdir -p ./include; mkdir -p ./lib
	cd $(CARES_BUILD); tar zxvf ../../packages/c-ares-$(CARES_VER).tar.gz;
	cd $(CARES_MAKE_DIR); ./configure --prefix=$(CARES_BUILD) --disable-shared CFLAGS="$(PROF_FLAG) $(DEBUG_FLAGS) $(OPT_FLAGS)"
	make -C $(CARES_MAKE_DIR); make -C $(CARES_MAKE_DIR) install
	cp -prf $(CARES_BUILD)/include/* ./include
	cp -pf $(CARES_BUILD)/lib/libcares.a ./lib

$(LIBOPENSSL):
	mkdir -p $(OPENSSL_BUILD)
	mkdir -p ./include; mkdir -p ./lib
	cd $(OPENSSL_BUILD); tar zxvf ../../packages/openssl-$(OPENSSL_VER).tar.gz;
	cd $(OPENSSL_MAKE_DIR); ./config no-shared --prefix=$(OPENSSL_BUILD)
	make -C $(OPENSSL_MAKE_DIR); make -C $(OPENSSL_MAKE_DIR) install
	cp -prf $(OPENSSL_BUILD)/include/* ./include
	cp -pf $(OPENSSL_BUILD)/lib/libcrypto.a ./lib
	cp -pf $(OPENSSL_BUILD)/lib/libssl.a ./lib
	
$(LIBZ):
	mkdir -p $(ZLIB_BUILD)
	mkdir -p ./include; mkdir -p ./lib
	cd $(ZLIB_BUILD); tar zxvf ../../packages/zlib-$(ZLIB_VER).tar.gz;
	cd $(ZLIB_MAKE_DIR); ./configure --static --prefix=$(ZLIB_BUILD)
	make -C $(ZLIB_MAKE_DIR); make -C $(ZLIB_MAKE_DIR) install
	cp -prf $(ZLIB_BUILD)/include/* ./include
	cp -pf $(ZLIB_BUILD)/lib/libz.a ./lib

# To enable IPv6 change --disable-ipv6 to --enable-ipv6

$(LIBCURL):
	mkdir -p $(CURL_BUILD)
	mkdir -p ./include; mkdir -p ./lib
	cd $(CURL_BUILD); tar zxvf ../../packages/curl-$(CURL_VER).tar.gz;
	cd $(CURL_MAKE_DIR); patch -p1 < ../../../patches/curl-trace-info-error.patch; \
	patch -p1 < ../../../patches/curl-configure.patch; \
	./configure --prefix=$(CURL_BUILD) \
	--without-libidn \
	--without-libssh2 \
	--disable-ldap \
	--disable-ipv6 \
    --enable-thread \
	--with-random=/dev/urandom \
	--with-ssl=$(OPENSSL_BUILD) \
	--disable-shared \
	--enable-ares=$(CARES_BUILD) \
	CFLAGS="$(PROF_FLAG) $(DEBUG_FLAGS) $(OPT_FLAGS) -DCURL_MAX_WRITE_SIZE=4096" \
	LIBS="-ldl"
	make -C $(CURL_MAKE_DIR); make -C $(CURL_MAKE_DIR) install
	cp -prf $(CURL_BUILD)/include/* ./include
	cp -pf $(CURL_BUILD)/lib/libcurl.a ./lib


# Files types rules
.SUFFIXES: .o .c .h

*.o: *.h

$(OBJ_DIR)/%.o: %.c
	$(CC) $(CFLAGS) $(PROF_FLAG) $(OPT_FLAGS) $(DEBUG_FLAGS) $(INCDIR) -c -o $(OBJ_DIR)/$*.o $<

