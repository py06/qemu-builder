PREFIX ?= $(PWD)
BIN_DIR=$(PREFIX)/bin
LIB_DIR=$(PREFIX)/lib
INCLUDE_DIR=$(PREFIX)/include

SRC_DIR=$(PWD)/src
BUILD=$(PWD)/build
DL_DIR=$(PWD)/download

SOFTFLOAT_ZIP_NAME=SoftFloat-3e.zip
SOFTFLOAT_ZIP=$(DL_DIR)/$(SOFTFLOAT_ZIP_NAME)
SOFTFLOAT_URL=http://www.jhauser.us/arithmetic/$(SOFTFLOAT_ZIP_NAME)
SOFTFLOAT_SRC=$(SRC_DIR)/SoftFloat-3e
SOFTFLOAT_BUILD=$(SOFTFLOAT_SRC)/build/Linux-x86_64-GCC
SOFTFLOAT_LIB=softfloat.a
SOFTFLOAT_BUILD_LIB=$(SOFTFLOAT_BUILD)/$(SOFTFLOAT_LIB)
SOFTFLOAT_INSTALL_LIB=$(LIB_DIR)/$(SOFTFLOAT_LIB)
SOFTFLOAT_INCLUDE_DIR=$(SOFTFLOAT_SRC)/source/include
SOFTFLOAT_INCLUDES=softfloat.h softfloat_types.h
SOFTFLOAT_SRC_INCLUDES=$(addprefix $(SOFTFLOAT_INCLUDE_DIR)/,$(SOFTFLOAT_INCLUDES))
SOFTFLOAT_INSTALL_INCLUDES=$(addprefix $(INCLUDE_DIR)/,$(SOFTFLOAT_INCLUDES))

LAO_SRC=$(SRC_DIR)/lao
LAO_BUILD=$(BUILD)/lao

QEMU_SRC=$(SRC_DIR)/qemu
QEMU_BUILD=$(BUILD)/qemu
QEMU_BUILD_CMD:=$(shell which ninja >/dev/null 2>&1 && which ninja || echo $(MAKE))

find_cmd=$(shell which $1 >/dev/null 2>&1 && which $1)

WGET:=$(call find_cmd,wget)
CURL:=$(call find_cmd,curl)
CMAKE:=$(call find_cmd,cmake)

ifneq (,$(WGET))
    DOWNLOAD=$(WGET) -O-
else ifneq (,$(CURL))
    DOWNLOAD=$(CURL)
else
    $(error Please install wget or curl)
endif

ifeq (,$(CMAKE))
	$(error Please install cmake)
endif

all: qemu-link

$(LIB_DIR) $(INCLUDE_DIR) $(LAO_BUILD) $(QEMU_BUILD):
	mkdir -p $@

.PHONY: softfloat-get
softfloat-get: $(SOFTFLOAT_ZIP)

$(SOFTFLOAT_ZIP):
	mkdir -p $(dir $(SOFTFLOAT_ZIP))
	$(DOWNLOAD) $(SOFTFLOAT_URL) >"$@"


.PHONY: softfloat-unzip
softfloat-unzip: $(SOFTFLOAT_SRC) softfloat-get

$(SOFTFLOAT_SRC): $(SOFTFLOAT_ZIP)
	cd $(SRC_DIR); unzip -DD $(SOFTFLOAT_ZIP)


.PHONY: softfloat-build
softfloat-build: $(SOFTFLOAT_BUILD_LIB) softfloat-unzip

$(SOFTFLOAT_BUILD_LIB): $(SOFTFLOAT_SRC)
	$(MAKE) -C $(SOFTFLOAT_BUILD)


.PHONY: softfloat-install
softfloat-install: $(SOFTFLOAT_INSTALL_LIB) $(SOFTFLOAT_INSTALL_INCLUDES)

$(SOFTFLOAT_INSTALL_LIB): $(SOFTFLOAT_BUILD_LIB) | $(LIB_DIR)
	cp $(SOFTFLOAT_BUILD_LIB) $(SOFTFLOAT_INSTALL_LIB)

$(SOFTFLOAT_INSTALL_INCLUDES): $(INCLUDE_DIR)/%.h: $(SOFTFLOAT_SRC) | $(INCLUDE_DIR)
	cp $(SOFTFLOAT_INCLUDE_DIR)/$*.h $(INCLUDE_DIR)/$*.h

.PHONY: lao-cmake
lao-cmake: $(LAO_BUILD)/Makefile

$(LAO_BUILD)/Makefile: $(SOFTFLOAT_INSTALL_LIB) $(SOFTFLOAT_INSTALL_INCLUDES) | $(LAO_BUILD)
	cd $(LAO_BUILD); \
	cmake $(LAO_SRC)/LAO \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DFAMILY=$(LAO_SRC)/LAO/kvx \
		-DTARGET=kv3 \
		-DYAML_ENABLED=off \
		-DGLPK_ENABLED=off \
		-DSOFTFLOAT_PREFIX=$(PREFIX) \
		-DKALRAY_INTERNAL=$(PREFIX)/kalray_internal

.PHONY: lao-build
lao-build: $(LAO_BUILD)/PRO/lao.so

$(LAO_BUILD)/PRO/lao.so: $(LAO_BUILD)/Makefile
	$(MAKE) -C $(LAO_BUILD)

.PHONY: lao-install
lao-install: $(PREFIX)/lib/lao/lao.so

$(PREFIX)/lib/lao/lao.so: $(LAO_BUILD)/PRO/lao.so
	$(MAKE) -C $(LAO_BUILD) install
	touch $@

.PHONY: qemu-configure
qemu-configure: $(QEMU_BUILD)/config.status

$(QEMU_BUILD)/config.status: $(PREFIX)/lib/lao/lao.so | $(QEMU_BUILD)
	cd $(QEMU_BUILD); \
	$(QEMU_SRC)/configure \
		--prefix=$(PREFIX) \
		--target-list=kvx-softmmu \
		--with-lao=$(PREFIX) \
		--disable-werror

.PHONY: qemu-build
qemu-build: $(QEMU_BUILD)/qemu-system-kvx

$(QEMU_BUILD)/qemu-system-kvx: $(QEMU_BUILD)/config.status
	cd $(QEMU_BUILD); \
	$(QEMU_BUILD_CMD)

.PHONY: qemu-install
qemu-install: $(BIN_DIR)/qemu-system-kvx

$(BIN_DIR)/qemu-system-kvx: $(QEMU_BUILD)/qemu-system-kvx
	cd $(QEMU_BUILD); \
	$(QEMU_BUILD_CMD) install

.PHONY: qemu-link
qemu-link: qemu-system-kvx

qemu-system-kvx: $(BIN_DIR)/qemu-system-kvx
	ln -s $(BIN_DIR)/qemu-system-kvx $@

.PHONY: clean
clean:
	test -d $(SOFTFLOAT_BUILD) && $(MAKE) -C $(SOFTFLOAT_BUILD) clean || true
	rm -rf $(LAO_BUILD) $(QEMU_BUILD)
	rm -rf $(BUILD)
	rm -rf $(DL_DIR)

.PHONY: distclean
distclean: clean
ifneq ($(PREFIX), $(PWD))
	rm -rf $(PREFIX)
else
	rm -rf $(PREFIX)/lib
	rm -rf $(PREFIX)/bin
	rm -rf $(PREFIX)/include
	rm -rf $(PREFIX)/include
	rm -rf $(PREFIX)/libexec
	rm -rf $(PREFIX)/share
	rm -rf $(PREFIX)/var
	rm -rf $(PREFIX)/kalray_internal
endif
	rm -f qemu-system-kvx
	rm -rf $(SOFTFLOAT_SRC)
	rm -f $(SOFTFLOAT_ZIP)
