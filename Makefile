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
STUDENT_MODULES := CombMultiplier MulticycleMultiplier PipelineMultiplier HandshakeMultiplier SignedMultiplier
STUDENT_ENTRIES := $(addprefix $(CURDIR)/student/rtl/,$(addsuffix .v,$(STUDENT_MODULES)))
ifeq ($(IMPL),verilog)
VERILOG_ENTRY := $(word $(or $(STAGE),1),$(STUDENT_ENTRIES))
# Compile the selected stage plus any additional student helper modules.
VERILOG_SOURCES := $(VERILOG_ENTRY) $(filter-out $(STUDENT_ENTRIES),$(wildcard $(CURDIR)/student/rtl/*.v $(CURDIR)/student/rtl/*.sv))
VERILOG_DEPS := $(VERILOG_SOURCES) $(wildcard student/rtl/*.vh student/rtl/*.svh) student/rtl
endif
RUN_INFO := impl=$(IMPL) stage=$(STAGE) width=$(WIDTH) latency=$(LATENCY) signed=$(SIGNED) exhaustive=$(EXHAUSTIVE) tests=$(TESTS) seed=$(SEED) timeout=$(TIMEOUT)$(if $(SIM_ARGS), sim_args=$(SIM_ARGS))

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
	$(MILL) $(MILL_FLAGS) multiplier.compile

$(RTL): $(SCALA_SOURCES) multiplier/src/multiplier include/config/auto.conf build.mill .mill-version .mill-jvm-version
	$(call git_commit,generate rtl)
	rm -rf -- '$(dir $(RTL))'
	@mkdir -p '$(dir $(RTL))'
	$(MILL) $(MILL_FLAGS) multiplier.run '$(WIDTH)' '$(STAGE)' '$(LATENCY)' '$(IMPL)' '$(dir $(RTL))'

rtl: $(RTL)
$(SIM): $(RTL) $(VERILOG_DEPS) sim/main.cpp Makefile
	$(call git_commit,compile sim)
	$(VERILATOR) --cc --exe --build --trace-fst --assert $(VERILATOR_FLAGS) \
		--top-module Multiplier --prefix VMultiplier \
		-I'$(dir $(RTL))' -I'$(CURDIR)/student/rtl' --Mdir '$(BUILD_DIR)/obj_dir' -o '$(SIM)' -j $(JOBS) \
		-CFLAGS '-std=c++17 -O2 -Wall -Wextra -DOPERAND_WIDTH=$(WIDTH) -DTEST_SIGNED=$(SIGNED) -DTEST_EXHAUSTIVE=$(EXHAUSTIVE)' \
		-MAKEFLAGS 'CXX=$(CXX)' $(wildcard $(dir $(RTL))*.sv) $(VERILOG_SOURCES) '$(CURDIR)/sim/main.cpp'

sim: $(SIM)
test: $(SIM)
	$(call git_commit,run test)
	$(call traced_run,test,'$(SIM)' --tests '$(TESTS)' --seed '$(SEED)' --timeout '$(TIMEOUT)' $(SIM_ARGS))
wave: $(SIM)
	$(call git_commit,run wave)
	$(call traced_run,wave,'$(SIM)' --tests '$(TESTS)' --seed '$(SEED)' --timeout '$(TIMEOUT)' --trace '$(BUILD_DIR)/wave.fst' $(SIM_ARGS))

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
