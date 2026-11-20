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
SUITE ?= builtin
VECTORS ?=
SIM_ARGS ?=
DEFCONFIG ?= configs/default_defconfig

# Git tracer: snapshots of the working tree (and test results) on the tracer-ysyx branch.
# Set STUID/STUNAME in scripts/tracer.mk.
include scripts/tracer.mk

ifdef CONFIG
$(error Use the project .config and make menuconfig; CONFIG= is not supported)
endif
KCONFIG := $(CURDIR)/tools/kconfig
CONF := $(KCONFIG)/build/conf
MCONF := $(KCONFIG)/build/mconf

# NEMU-style native conf/mconf and generated Make configuration.
ifeq ($(filter menuconfig defconfig olddefconfig savedefconfig help clean distclean init,$(MAKECMDGOALS)),)
NEED_CONFIG := 1
include include/config/auto.conf
endif
WIDTH := $(CONFIG_WIDTH)
ALGO := $(patsubst "%",%,$(CONFIG_MUL))
HDL := $(if $(CONFIG_HDL_VERILOG),verilog,chisel)
SIGNED := $(if $(CONFIG_TEST_SIGNED),1,0)
EXHAUSTIVE := $(if $(CONFIG_TEST_EXHAUSTIVE),1,0)

# Interface/timing description of the selected implementation (impls/<id>.mk).
# csa_latency(n): CSA layers needed to compress n addends to two, plus one (final adder stage).
csa_latency = $(shell n=$(1); l=0; while [ $$n -gt 2 ]; do n=$$((n - n/3)); l=$$((l+1)); done; echo $$((l+1)))
IMPL_FILE := impls/$(ALGO).mk
ifeq ($(NEED_CONFIG),1)
ifeq ($(wildcard $(IMPL_FILE)),)
$(error unknown implementation '$(ALGO)'; see impls/*.mk)
endif
include $(IMPL_FILE)
ifneq ($(shell [ $(WIDTH) -le $(IMPL_MAX_WIDTH) ] && echo ok),ok)
$(error $(ALGO): operand width must be at most $(IMPL_MAX_WIDTH))
endif
endif
# Fixed-cycle implementations: LATENCY override (0 = default) only where the latency is a design choice.
LATENCY := $(or $(CONFIG_LATENCY),0)
LAT := $(if $(filter 1,$(IMPL_FIXED_CYCLE)),$(if $(and $(filter 1,$(IMPL_LATENCY_CONFIGURABLE)),$(filter-out 0,$(LATENCY))),$(LATENCY),$(IMPL_DEFAULT_LATENCY)),1)

BUILD_DIR := $(CURDIR)/build/$(HDL)-$(ALGO)-w$(WIDTH)-l$(LAT)-s$(SIGNED)-e$(EXHAUSTIVE)
# DUT parameter override: Verilog modules take WIDTH (and LATENCY when fixed-cycle); Chisel output has none.
PARAMS_WIDTH := \#(.WIDTH($(WIDTH)))
PARAMS_FIXED := \#(.WIDTH($(WIDTH)),.LATENCY($(LAT)))
MUL_PARAMS := $(if $(filter verilog,$(HDL)),$(if $(filter 1,$(IMPL_FIXED_CYCLE)),$(PARAMS_FIXED),$(PARAMS_WIDTH)))
# Interface family of the DUT: selects which instantiation the adapter compiles.
MUL_IF := $(if $(filter 1,$(IMPL_SIGNED)),MUL_IF_SIGNED,$(if $(filter 1,$(IMPL_HANDSHAKE)),MUL_IF_HANDSHAKE,$(if $(filter 1,$(IMPL_CLOCKED)),MUL_IF_TIMED,MUL_IF_COMB)))
CONFIG_SVH := $(BUILD_DIR)/mul_config.svh
SIM := $(BUILD_DIR)/sim
# Chisel students: Chisel sources are elaborated by the standalone chisel/ project (needs Mill + JDK).
# Verilog students never touch it.
CHISEL_DIR := $(BUILD_DIR)/chisel
CHISEL_SOURCES := $(shell find chisel -name '*.scala' -o -name 'build.mill' -o -name '.mill-*' 2>/dev/null | grep -v /out/)
ifeq ($(HDL),chisel)
RTL := $(CHISEL_DIR)/$(IMPL_MODULE).sv
else
# Helper modules go in student/rtl/common/ and are always compiled; other implementations' files are not.
RTL := $(CONFIG_SVH)
STUDENT_VERILOG := $(CURDIR)/student/rtl/$(IMPL_MODULE).v $(wildcard $(CURDIR)/student/rtl/common/*.v $(CURDIR)/student/rtl/common/*.sv)
VERILOG_DEPS := $(STUDENT_VERILOG) $(wildcard student/rtl/common/*.vh student/rtl/common/*.svh)
endif
SIM_SOURCES := $(wildcard sim/*.cpp student/tests/*.cpp)
SIM_DEPS := $(SIM_SOURCES) $(wildcard sim/*.h student/tests/*.h)
RUN_ARGS := --tests '$(TESTS)' --seed '$(SEED)' --timeout '$(TIMEOUT)' --suite '$(SUITE)'$(if $(VECTORS), --vectors '$(VECTORS)') $(SIM_ARGS)
RUN_INFO := hdl=$(HDL) impl=$(ALGO) width=$(WIDTH) latency=$(LAT) signed=$(SIGNED) exhaustive=$(EXHAUSTIVE) tests=$(TESTS) seed=$(SEED) timeout=$(TIMEOUT) suite=$(SUITE)$(if $(VECTORS), vectors=$(VECTORS))$(if $(SIM_ARGS), sim_args=$(SIM_ARGS))

# Run a simulator command, log its output and record the result as a tracer commit.
# prototype: traced_run(label, command)
define traced_run
	@+mkdir -p '$(BUILD_DIR)'; start=$$SECONDS; \
	$(2) 2>&1 | tee '$(BUILD_DIR)/$(1).log'; status=$${PIPESTATUS[0]}; \
	bash scripts/tracer-result.sh '$(1)' $$status $$((SECONDS - start)) '$(BUILD_DIR)/$(1).log' '$(RUN_INFO)' > '$(BUILD_DIR)/$(1).result'; \
	$(call git_commit_file_cmd,'$(BUILD_DIR)/$(1).result'); \
	exit $$status
endef

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
	cd chisel && $(MILL) $(MILL_FLAGS) multiplier.compile

# Generated parameters of the adapter (sim/rtl/Multiplier.sv) and the DUT instantiation.
$(CONFIG_SVH): $(IMPL_FILE) include/config/auto.conf Makefile
	@mkdir -p '$(dir $@)'
	@{ echo '`define MUL_MODULE $(IMPL_MODULE)'; \
	   echo '`define MUL_WIDTH $(WIDTH)'; \
	   echo '`define MUL_LATENCY $(LAT)'; \
	   echo '`define MUL_CLOCKED $(IMPL_CLOCKED)'; \
	   echo '`define MUL_FIXED_CYCLE $(IMPL_FIXED_CYCLE)'; \
	   echo '`define MUL_PIPELINED $(IMPL_PIPELINED)'; \
	   echo '`define MUL_HANDSHAKE $(IMPL_HANDSHAKE)'; \
	   echo '`define MUL_SIGNED $(IMPL_SIGNED)'; \
	   echo '`define $(MUL_IF)'; \
	   echo '`define MUL_PARAMS $(MUL_PARAMS)'; } > '$@'

ifeq ($(HDL),chisel)
$(RTL): $(CHISEL_SOURCES) include/config/auto.conf
	$(call git_commit,generate rtl)
	rm -rf -- '$(CHISEL_DIR)'
	@mkdir -p '$(CHISEL_DIR)'
	cd chisel && $(MILL) $(MILL_FLAGS) multiplier.run '$(WIDTH)' '$(ALGO)' '$(LAT)' '$(CHISEL_DIR)'
endif

rtl: $(RTL) $(CONFIG_SVH)
$(SIM): $(RTL) $(CONFIG_SVH) $(VERILOG_DEPS) $(SIM_DEPS) Makefile
	$(call git_commit,compile sim)
	$(VERILATOR) --cc --exe --build --trace-fst --assert $(VERILATOR_FLAGS) \
		--top-module Multiplier --prefix VMultiplier \
		-I'$(BUILD_DIR)' --Mdir '$(BUILD_DIR)/obj_dir' -o '$(SIM)' -j $(JOBS) \
		-CFLAGS '-std=c++17 -O2 -I$(CURDIR)/sim -Wall -Wextra -DOPERAND_WIDTH=$(WIDTH) -DTEST_SIGNED=$(SIGNED) -DTEST_EXHAUSTIVE=$(EXHAUSTIVE)' \
		-MAKEFLAGS 'CXX=$(CXX)' '$(CURDIR)/sim/rtl/Multiplier.sv' $(if $(filter chisel,$(HDL)),$(wildcard $(CHISEL_DIR)/*.sv),$(STUDENT_VERILOG)) $(addprefix $(CURDIR)/,$(SIM_SOURCES))

sim: $(SIM)
test: $(SIM)
	$(call git_commit,run test)
	$(call traced_run,test,'$(SIM)' $(RUN_ARGS))
wave: $(SIM)
	$(call git_commit,run wave)
	$(call traced_run,wave,'$(SIM)' $(RUN_ARGS) --trace '$(BUILD_DIR)/wave.fst')

regression: .config $(CONF)
	bash scripts/regression.sh

help:
	@echo 'make menuconfig | defconfig | savedefconfig | olddefconfig'
	@echo 'make test | wave | regression | rtl | sim | compile | clean | distclean'
	@echo 'Hardware settings: .config (default: width 8, direct A*B in Verilog)'
	@echo 'Runtime settings: TESTS=10000 SEED=1 TIMEOUT=10000 JOBS=2'
	@echo 'Custom tests: SUITE=builtin|custom|all VECTORS=file (student/tests/custom_tests.cpp)'

clean:
	rm -rf build

distclean: clean
	rm -rf chisel/out include/config include/generated .config .config.old
