SHELL := /bin/bash
.DEFAULT_GOAL := test
.DELETE_ON_ERROR:

MILL ?= mill
MILL_FLAGS ?= --no-server
VERILATOR ?= verilator
VERILATOR_FLAGS ?= -Wall -Wno-UNUSEDSIGNAL
CXX ?= g++
JOBS ?= 2
TESTS ?= 10000
SEED ?= 1
TIMEOUT ?= 10000
SIM_ARGS ?=
DEFCONFIG ?= configs/default_defconfig

ifdef CONFIG
$(error Use the project .config and make menuconfig; CONFIG= is not supported)
endif
KCONFIG := $(CURDIR)/tools/kconfig
CONF := $(KCONFIG)/build/conf
MCONF := $(KCONFIG)/build/mconf

# NEMU-style native conf/mconf and generated Make configuration.
ifeq ($(filter menuconfig defconfig olddefconfig savedefconfig help clean distclean init,$(MAKECMDGOALS)),)
include include/config/auto.conf
endif
WIDTH := $(CONFIG_WIDTH)
STAGE := $(CONFIG_STAGE)
LATENCY := $(or $(CONFIG_LATENCY),3)
IMPL := $(if $(CONFIG_IMPL_VERILOG),verilog,chisel)
SIGNED := $(if $(CONFIG_TEST_SIGNED),1,0)
EXHAUSTIVE := $(if $(CONFIG_TEST_EXHAUSTIVE),1,0)
BUILD_DIR := $(CURDIR)/build/$(IMPL)-stage$(STAGE)-w$(WIDTH)-l$(LATENCY)-s$(SIGNED)-e$(EXHAUSTIVE)
RTL := $(BUILD_DIR)/rtl/Multiplier.sv
SIM := $(BUILD_DIR)/sim
SCALA_SOURCES := $(wildcard multiplier/src/multiplier/*.scala)
VERILOG_SOURCES := $(wildcard student/rtl/*.v)

.PHONY: init all menuconfig defconfig olddefconfig savedefconfig compile rtl sim test wave regression help clean distclean
init: tools/kconfig/parser.y

tools/kconfig/parser.y: init.sh
	bash init.sh

$(CONF) $(MCONF): tools/kconfig/parser.y scripts/kconfig-build.mk
	$(MAKE) -C tools/kconfig -f ../../scripts/kconfig-build.mk

.config:
	$(MAKE) defconfig

include/config/auto.conf: .config Kconfig $(CONF)
	$(CONF) --olddefconfig Kconfig
	$(CONF) --syncconfig Kconfig

menuconfig: $(MCONF)
	$(MCONF) Kconfig
	$(CONF) --syncconfig Kconfig

defconfig: $(CONF)
	$(CONF) --defconfig=$(DEFCONFIG) Kconfig
	$(CONF) --syncconfig Kconfig

olddefconfig: $(CONF)
	$(CONF) --olddefconfig Kconfig
	$(CONF) --syncconfig Kconfig

savedefconfig: $(CONF)
	$(CONF) --savedefconfig=$(DEFCONFIG) Kconfig

all: test
compile:
	$(MILL) $(MILL_FLAGS) multiplier.compile

$(RTL): $(SCALA_SOURCES) multiplier/src/multiplier $(VERILOG_SOURCES) student/rtl include/config/auto.conf build.mill .mill-version .mill-jvm-version
	rm -rf -- '$(dir $(RTL))'
	@mkdir -p '$(dir $(RTL))'
	$(MILL) $(MILL_FLAGS) multiplier.run '$(WIDTH)' '$(STAGE)' '$(LATENCY)' '$(IMPL)' '$(dir $(RTL))'

rtl: $(RTL)
$(SIM): $(RTL) sim/main.cpp Makefile
	$(VERILATOR) --cc --exe --build --trace-fst --assert $(VERILATOR_FLAGS) \
		--top-module Multiplier --prefix VMultiplier \
		-I'$(dir $(RTL))' -I'$(CURDIR)/student/rtl' --Mdir '$(BUILD_DIR)/obj_dir' -o '$(SIM)' -j $(JOBS) \
		-CFLAGS '-std=c++17 -O2 -Wall -Wextra -DOPERAND_WIDTH=$(WIDTH) -DTEST_SIGNED=$(SIGNED) -DTEST_EXHAUSTIVE=$(EXHAUSTIVE)' \
		-MAKEFLAGS 'CXX=$(CXX)' $(wildcard $(dir $(RTL))*.sv) $(wildcard $(dir $(RTL))*.v) '$(CURDIR)/sim/main.cpp'

sim: $(SIM)
test: $(SIM)
	'$(SIM)' --tests '$(TESTS)' --seed '$(SEED)' --timeout '$(TIMEOUT)' $(SIM_ARGS)
wave: $(SIM)
	'$(SIM)' --tests '$(TESTS)' --seed '$(SEED)' --timeout '$(TIMEOUT)' --trace '$(BUILD_DIR)/wave.fst' $(SIM_ARGS)

regression: .config $(CONF)
	bash scripts/regression.sh

help:
	@echo 'make menuconfig | defconfig | savedefconfig | olddefconfig'
	@echo 'make test | wave | regression | rtl | sim | compile | clean | distclean'
	@echo 'Hardware settings: .config (default: width 8, combinational Chisel)'
	@echo 'Runtime settings: TESTS=10000 SEED=1 TIMEOUT=10000 JOBS=2'

clean:
	rm -rf build

distclean: clean
	rm -rf out include/config include/generated .config .config.old
