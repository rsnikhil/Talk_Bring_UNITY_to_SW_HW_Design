# WARNING: This Makefile is 'include'd from other Makefiles. It should not be used by itself.

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  b_compile b_link         bsc-compile and link for Bluesim"
	@echo "  v_compile v_link         bsc-compile and link for Verilator"
	@echo ""
	@echo "Vector-Add tests (b_run_* are Bluesim, v_run_* are Verilog sim (in Verilator)"
	@echo "  b_run_vadd_accel     v_run_vadd_accel     VAdd On the accelerator"
	@echo "  b_run_vadd_sw_2      v_run_vadd_sw_2      VAdd in sw, vector size 2"
	@echo "  b_run_vadd_sw_100    v_run_vadd_sw_100    VAdd in sw, vector size 100"
	@echo "  b_run_vadd_sw_200    v_run_vadd_sw_200    VAdd in sw, vector size 200"
	@echo ""
	@echo "  b_run         /v_run             run exe on test_memhex64, generating log.txt"
	@echo "  b_run_hello   /v_run_hello       ... on 'Hello World!' test"
	@echo "  b_run_add     /v_run_add         ... on 'add' ISA test"
	@echo "  b_run_FreeRTOS/v_run_FreeRTOS    ... on 'FreeRTOS' test"
	@echo ""
	@echo "  b_all = b_compile b_link b_run_vadd_accel"
	@echo "  v_all = v_compile v_link v_run_vadd_accel"
	@echo ""
	@echo "  clean                    Remove temporary intermediate files"
	@echo "  full_clean               Restore to pristine state"

.PHONY: all
b_all: b_compile b_link b_run_vadd_accel
v_all: v_compile v_link v_run_vadd_accel

# ****************************************************************
# Config

EXEFILE ?= exe_$(CPU)_$(RV)

# ****************************************************************
# Common bsc args

ROOT = ../..
DRUM_FIFE = $(ROOT)/vendor/Drum_Fife

SRC_TOP    = $(DRUM_FIFE)/src_Top
SRC_CPU    = $(DRUM_FIFE)/src_$(CPU)
SRC_COMMON = $(DRUM_FIFE)/src_Common
TOOLS      = $(DRUM_FIFE)/Tools

TOPFILE   ?= $(ROOT)/src_BSV/Top.bsv
TOPMODULE ?= mkTop

MISC_LIBS     = $(ROOT)/vendor/bsc-contrib_Misc
RVFI_DII_LIBS = $(ROOT)/vendor/RVFI_DII_Types

BSCFLAGS = -D $(RV) \
	-use-dpi \
	-keep-fires \
	-aggressive-conditions \
	-no-warn-action-shadowing \
	-show-range-conflict \
        -opt-undetermined-vals \
	-unspecified-to X \
	-show-schedule

C_FILES  = $(DRUM_FIFE)/src_Top/C_Mems_Devices.c
C_FILES += $(DRUM_FIFE)/src_Top/UART_model.c

# For imported C code
BSC_C_FLAGS += -Xl -v  -Xc -O3  -Xc++ -O3

ifdef DRUM_RULES
BSCFLAGS += -D DRUM_RULES
endif

# ----------------
# bsc's directory search path

BSCPATH = $(ROOT)/src_BSV:$(SRC_TOP):$(SRC_CPU):$(SRC_COMMON):$(MISC_LIBS):$(RVFI_DII_LIBS):+

# ****************************************************************
# FOR VERILATOR

VSIM      = verilator

BSCDIRS_V = -bdir build_v  -info-dir build_v  -vdir verilog

BSCPATH_V = $(BSCPATH)

build_v:
	mkdir -p $@

verilog:
	mkdir -p $@

.PHONY: v_compile
v_compile: build_v verilog
	@echo "Compiling for Verilog (Verilog generation) ..."
	bsc -u -elab -verilog  $(BSCDIRS_V)  $(BSCFLAGS)  -p $(BSCPATH_V)  $(TOPFILE)
	@echo "Verilog generation finished"

.PHONY: v_link
v_link: build_v verilog
	@echo "Linking for Verilog simulation (simulator: $(VSIM)) ..."
	bsc -verilog  -vsim $(VSIM)  -use-dpi  -keep-fires  -v  $(BSCDIRS_V) \
		-e $(TOPMODULE) -o ./$(EXEFILE)_$(VSIM) \
		$(BSC_C_FLAGS) \
		$(C_FILES)
	@echo "Linking for Verilog simulation finished"

# ----------------
# Verilator runs

.PHONY: v_run
v_run:
	@echo "INFO: Simulation ..."
	./$(EXEFILE)_verilator
	@echo "INFO: Finished Simulation"

.PHONY: v_run_hello
v_run_hello:
	@echo "INFO: Simulation of Hello World! ..."
	ln -s -f $(TOOLS)/Hello_World_Example_Code/hello.RV32.bare.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator
	@echo "INFO: Finished Simulation of Hello World! ..."

.PHONY: v_run_add
v_run_add:
	@echo "INFO: Simulation of add ISA test ..."
	ln -s -f $(TOOLS)/rv32ui-p-add_Example_Code/rv32ui-p-add.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator
	@echo "INFO: Finished Simulation of add ISA test ..."

.PHONY: v_run_FreeRTOS
v_run_FreeRTOS:
	@echo "INFO: Simulation of FreeRTOS ..."
	ln -s -f $(TOOLS)/FreeRTOS/RTOSDemo.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator
	@echo "INFO: Finished Simulation of FreeRTOS ..."

.PHONY: v_run_vadd_sw_2
v_run_vadd_sw_2:
	@echo "INFO: Verilog simulation of vadd, sw, vector size 2 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_2.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator +log
	@echo "INFO: Finished Verilog simulation of vadd, sw, vector size 2 ..."

.PHONY: v_run_vadd_sw_100
v_run_vadd_sw_100:
	@echo "INFO: Verilog simulation of vadd, sw, vector size 100 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_100.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator +log
	@echo "INFO: Finished Verilog simulation of vadd, sw, vector size 100 ..."

.PHONY: v_run_vadd_sw_200
v_run_vadd_sw_200:
	@echo "INFO: Verilog simulation of vadd, sw, vector size 200 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_200.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator +log
	@echo "INFO: Finished Verilog simulation of vadd, sw, vector size 200 ..."

.PHONY: v_run_vadd_accel
v_run_vadd_accel:
	@echo "INFO: Verilog simulation of vadd, in accel ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_accel.memhex32 \
		test.memhex32
	./$(EXEFILE)_verilator +log
	@echo "INFO: Finished Verilog simulation of vadd, in accel ..."

# ****************************************************************
# FOR BLUESIM

BSCDIRS_BSIM_c = -bdir build_b -info-dir build_b
BSCDIRS_BSIM_l = -simdir C_for_bsim

BSCPATH_BSIM = $(BSCPATH)

build_b:
	mkdir -p $@

C_for_bsim:
	mkdir -p $@

.PHONY: b_compile
b_compile: build_b
	@echo Compiling for Bluesim ...
	bsc -u -sim $(BSCDIRS_BSIM_c)  $(BSCFLAGS)  -p $(BSCPATH_BSIM)  $(TOPFILE)
	@echo Compilation for Bluesim finished

.PHONY: b_link
b_link: build_b C_for_bsim
	@echo Linking for Bluesim ...
	bsc  -sim  -parallel-sim-link 8\
		$(BSCDIRS_BSIM_c)  $(BSCDIRS_BSIM_l)  -p $(BSCPATH_BSIM) \
		-e $(TOPMODULE) -o ./$(EXEFILE)_bsim \
		-keep-fires \
		$(BSC_C_FLAGS)  $(C_FILES)
	@echo Linking for Bluesim finished

# ----------------

.PHONY: b_run
b_run:
	@echo "INFO: Simulation ..."
	./$(EXEFILE)_bsim
	@echo "INFO: Finished Simulation"

.PHONY: b_run_hello
b_run_hello:
	@echo "INFO: Simulation of Hello World! ..."
	ln -s -f $(TOOLS)/Hello_World_Example_Code/hello.RV32.bare.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim
	@echo "INFO: Finished Simulation of Hello World! ..."

.PHONY: b_run_add
b_run_add:
	@echo "INFO: Simulation of add ISA test ..."
	ln -s -f $(TOOLS)/rv32ui-p-add_Example_Code/rv32ui-p-add.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim
	@echo "INFO: Finished Simulation of add ISA test ..."

.PHONY: b_run_FreeRTOS
b_run_FreeRTOS:
	@echo "INFO: Simulation of FreeRTOS ..."
	ln -s -f $(TOOLS)/FreeRTOS/RTOSDemo.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim
	@echo "INFO: Finished Simulation of FreeRTOS ..."

.PHONY: b_run_vadd_sw_2
b_run_vadd_sw_2:
	@echo "INFO: Bluesim simulation of vadd, sw, vector size 2 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_2.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim +log
	@echo "INFO: Finished Bluesim simulation of vadd, sw, vector size 2 ..."

.PHONY: b_run_vadd_sw_100
b_run_vadd_sw_100:
	@echo "INFO: Bluesim simulation of vadd, sw, vector size 100 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_100.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim +log
	@echo "INFO: Finished Bluesim simulation of vadd, sw, vector size 100 ..."

.PHONY: b_run_vadd_sw_200
b_run_vadd_sw_200:
	@echo "INFO: Bluesim simulation of vadd, sw, vector size 200 ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_sw_200.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim +log
	@echo "INFO: Finished Bluesim simulation of vadd, sw, vector size 200 ..."

.PHONY: b_run_vadd_accel
b_run_vadd_accel:
	@echo "INFO: Bluesim simulation of vadd, in accel ..."
	ln -s -f $(ROOT)/RISCV_binaries/vadd_accel.memhex32 \
		test.memhex32
	./$(EXEFILE)_bsim +log
	@echo "INFO: Finished Bluesim simulation of vadd, in accel ..."

# ****************************************************************

.PHONY: clean
clean:
	rm -r -f  *~  .*~  src_*/*~  build*  C_for_bsim  $(VERILATOR_MAKE_DIR)

.PHONY: full_clean
full_clean: clean
	rm -r -f  exe_*  verilog  log*  test.memhex32  obj_dir_*

# ****************************************************************
