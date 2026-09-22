# SPDX-License-Identifier: Apache-2.0
#
# Modified by Renzym Private limited in 2026.

# Makefile for the AMD-DV-Sprint project

# --- Phony targets (don't represent files) ---
.PHONY: all compile elaborate smoke clean gen sim regress compile_asm spike_sim cov formal bug uvm_compile uvm_smoke uvm_regress uvm_external_irq uvm_m_extension uvm_rv32im_features

# --- Environment Variables ---
# Load environment variables from .env file if it exists.
-include .env
export

# --- Variables ---
XVLOG = xvlog
XELAB = xelab
XSIM  = xsim

RTL_DIR ?= ../fpga/rtl

TEST      ?= riscv_arithmetic_basic_test
TARGET_ISA ?= rv32im
TEST_NAME ?= $(TEST)
export TEST_NAME
export TARGET_ISA

NUM_SEEDS ?= 1
LOG_DIR   ?= logs
SEED_FILE ?= $(LOG_DIR)/seeds.txt
RUN_LOG   ?= $(LOG_DIR)/run.log

# Coverage variables
COV_DIR   ?= coverage
COV_UCDB  ?= $(COV_DIR)/merged.ucdb
COV_JSON  ?= $(COV_DIR)/coverage.json

# --- Main Targets ---

# Default target
all: regress

# Run a full, clean regression. This is the main entry point.
regress: clean elaborate gen compile_asm spike_sim sim

	@echo "--- Regression Complete ---"

# Generate assembly tests and the golden spike log
gen:
	@echo "--- Generating tests and Spike reference log ---"
	@mkdir -p $(LOG_DIR)
	@if [ -z "$(PRESERVE_SEEDS)" ]; then python3 scripts/gen_seeds.py $(NUM_SEEDS) > $(SEED_FILE); fi
	@if [ -f "$(SEED_FILE)" ]; then \
		python3 scripts/run_regression.py $$(cat $(SEED_FILE)); \
	else \
		echo "Error: Seed file '$(SEED_FILE)' not found. Cannot preserve non-existent seeds."; \
		echo "Either run without PRESERVE_SEEDS=1 or create $(SEED_FILE) first."; \
		exit 1; \
	fi

# Manually compile the generated assembly files into ELFs
compile_asm:
	@echo "--- Compiling assembly tests to ELF files ---"
	@if [ ! -f $(SEED_FILE) ]; then \
		echo "Seed file '$(SEED_FILE)' not found. Please run 'make gen' first."; \
		exit 1; \
	fi
	@python3 scripts/compile_assembly.py

# Convert compiled ELF files to Verilog memory format
mem_convert:
	@echo "--- Converting ELF files to memory format ---"
	@python3 scripts/mem_convert.py

# Run the reference Spike simulation to generate the golden trace log
spike_sim: compile_asm
	@echo "--- Running Spike reference simulation ---"
	@if [ ! -f $(SEED_FILE) ]; then \
		echo "Seed file '$(SEED_FILE)' not found. Please run 'make gen' first."; \
		exit 1; \
	fi
	@python3 scripts/run_spike.py $$(cat $(SEED_FILE))

# Simulate previously generated tests and compare results
sim:
	@echo "--- Simulating generated tests and comparing results ---"
	@if [ ! -f $(SEED_FILE) ]; then \
		echo "Seed file '$(SEED_FILE)' not found. Please run 'make gen' first."; \
		exit 1; \
	fi
	@python3 scripts/run_simulation.py $$(cat $(SEED_FILE)) | tee $(RUN_LOG)

# --- Build Prerequisite Targets ---

# Compile RTL and testbench
compile:
	@echo "--- Compiling all source files ---"
	@$(XVLOG) -sv $(RTL_DIR)/*.v $(RTL_DIR)/*.sv uvm_scripted_flow/*.v -i uvm_scripted_flow

# Elaborate the design for simulation
elaborate: clean compile
	@echo "--- Elaborating the design ---"
	@$(XELAB) -top tb_top -s smoke_top --timescale 1ns/1ps --override_timeunit --override_timeprecision

# --- Utility Targets ---

# Run a simple smoke test to ensure the base environment is set up
smoke: clean elaborate
	@echo "--- Running smoke test ---"
	@mkdir -p $(LOG_DIR)
	@$(XSIM) smoke_top -R

# Compile UVM implementation only
# riscv_pkg.sv must be compiled before the modules that import it, so the
# core RTL is listed explicitly instead of globbed. The Zynq/BRAM wrapper
# files are not needed for simulation. The instruction/data memory models
# are testbench-side (tb_mem/), not part of this core's RTL.
uvm_compile:
	@echo "--- Compiling UVM implementation ---"
	@$(XVLOG) -sv -L uvm \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/riscv_alu.sv \
		$(RTL_DIR)/riscv_regfile.sv \
		$(RTL_DIR)/riscv_csr.sv \
		$(RTL_DIR)/riscv_decode.sv \
		$(RTL_DIR)/riscv_hazard.sv \
		$(RTL_DIR)/riscv_lsu.sv \
		$(RTL_DIR)/riscv_core.sv \
		tb_mem/instruction_memory.v \
		tb_mem/data_memory.v \
		uvm_classic/interfaces/cpu_interface.sv \
		uvm_classic/riscv_uvm_pkg.sv \
		uvm_classic/cpu_top.sv \
		uvm_classic/uvm_top.sv \
		-i uvm_classic/interfaces \
		-i uvm_classic

# Run a smoke test on the UVM environment
uvm_smoke: clean uvm_compile
	@echo "--- Running UVM smoke test ---"
	@$(XELAB) -L uvm uvm_top -s uvm_smoke_top --timescale 1ns/1ps --override_timeunit --override_timeprecision
	@$(XSIM) uvm_smoke_top -R -testplusarg "UVM_TESTNAME=riscv_base_test"

uvm_external_irq: clean uvm_compile
	@echo "--- Running directed UVM external interrupt test ---"
	@$(XELAB) -L uvm uvm_top -s uvm_external_irq_top --timescale 1ns/1ps --override_timeunit --override_timeprecision
	@$(XSIM) uvm_external_irq_top -R \
		-testplusarg "UVM_TESTNAME=riscv_external_irq_test" \
		-testplusarg "MEM_FILE=tb_mem/external_irq_imem.mem" \
		-testplusarg "UVM_TIMEOUT=1000000,NO"

uvm_m_extension: clean uvm_compile
	@echo "--- Running directed UVM RV32M extension test ---"
	@$(XELAB) -L uvm uvm_top -s uvm_m_extension_top --timescale 1ns/1ps --override_timeunit --override_timeprecision
	@$(XSIM) uvm_m_extension_top -R \
		-testplusarg "UVM_TESTNAME=riscv_m_extension_test" \
		-testplusarg "MEM_FILE=tb_mem/m_extension_imem.mem" \
		-testplusarg "UVM_TIMEOUT=1000000,NO"

uvm_rv32im_features: uvm_m_extension uvm_external_irq
	@echo "--- Directed RV32IM feature tests passed ---"

# Elaborate the UVM design for simulation
uvm_elaborate: clean uvm_compile
	@echo "--- Elaborating the UVM design ---"
	@$(XELAB) -L uvm uvm_top -s uvm_regress_top --timescale 1ns/1ps --override_timeunit --override_timeprecision

# Run a UVM regression using a generated test program
uvm_regress: uvm_elaborate gen compile_asm mem_convert spike_sim
	@echo "--- Running UVM regression ---"; \
	if [ ! -f "$(SEED_FILE)" ]; then \
		echo "Seed file '$(SEED_FILE)' not found. Please run 'make gen' first."; \
		exit 1; \
	fi; \
	SEEDS=$$(cat $(SEED_FILE)); \
	for SEED in $$SEEDS; do \
		echo "--- Running test for SEED=$$SEED ---"; \
		MEM_FILE=$$(find out_*/asm_test -name "*_$$SEED.o.mem" -print -quit); \
		SPIKE_LOG=$$(find out_*/spike_sim -name "*_$$SEED.log" -print -quit); \
		if [ -z "$$MEM_FILE" ] || [ -z "$$SPIKE_LOG" ]; then \
			echo "Error: Could not find files for SEED=$$SEED. Please check previous steps."; \
			exit 1; \
		fi; \
		echo "Found memory file: $$MEM_FILE"; \
		echo "Found spike log: $$SPIKE_LOG"; \
		$(XSIM) uvm_regress_top -R -maxdeltaid 100000 \
			-testplusarg "UVM_TESTNAME=riscv_base_test" \
			-testplusarg "MEM_FILE=$$MEM_FILE" \
			-testplusarg "SPIKE_LOG=$$SPIKE_LOG" \
			-testplusarg "UVM_TIMEOUT=10000000,NO" \
			| tee -a $(LOG_DIR)/uvm_run.log; \
	done

clean:
	@echo "--- Cleaning up ---"
	rm -rf xsim.dir/ xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.pb xsim.jou
	rm -rf work/ transcript vsim.wlf smoke_top* out_* 
	rm -rf coverage/*
	rm -rf logs/*

# --- Tier A Verification Targets ---

# Generate and merge functional coverage reports
cov:
	@echo "--- Generating coverage reports ---"
	@mkdir -p $(COV_DIR)
	@# Find all UCDB files and merge them
	@UCDB_FILES=$$(find $(COV_DIR) -name "sim_*.ucdb" 2>/dev/null || true); \
	if [ -z "$$UCDB_FILES" ]; then \
		echo "No coverage databases found. Run regression with coverage first:"; \
		echo "  COV_ENABLE=1 make regress"; \
		exit 1; \
	fi; \
	echo "Merging coverage databases: $$UCDB_FILES"; \
	rm -f $(COV_UCDB); \
	vcover merge -64 -suppress 6854 $(COV_UCDB) $$UCDB_FILES
	@# Generate HTML report
	@vcover report -html -details -output $(COV_DIR)/html $(COV_UCDB)
	@# Generate JSON summary
	@python3 scripts/merge_cov.py $(COV_UCDB) -o $(COV_JSON)
	@echo "Coverage reports generated:"
	@echo "  JSON: $(COV_JSON)"
	@echo "  HTML: $(COV_DIR)/html/index.html"

# Run formal verification using SymbiYosys
formal:
	@echo "--- Running formal verification ---"
	@mkdir -p $(FORMAL_DIR)
	@if [ ! -f $(FORMAL_SBY) ]; then \
		echo "Formal script not found: $(FORMAL_SBY)"; \
		echo "Please create the SymbiYosys script first."; \
		exit 1; \
	fi
	@cd $(FORMAL_DIR) && sby -f pc_x0.sby | tee pc_x0.log
	@echo "Formal verification complete. Check $(FORMAL_LOG) for results."

# Automated demonstration of RISC-V ADDI bug discovery and fix
bug:
	@echo "--- Automated RISC-V ADDI Bug Demonstration ---"
	@echo "Demonstrating real bug discovered in ALU_controller.v"
	@echo ""
	
	@# Start with completely clean state
	@echo "Cleaning workspace for demonstration..."
	@make clean
	
	@# Save current state
	@echo "Saving current git state..."
	@git stash push -m "Temporary stash for automated bug demo" || true
	@CURRENT_BRANCH=$$(git branch --show-current); \
	\
	echo ""; \
	echo "1. Running BUGGY version (branch: bug_demo_addi_controller)..."; \
	git checkout bug_demo_addi_controller; \
	mkdir -p logs; \
	echo "695998" > logs/seeds.txt; \
	echo "   Testing ADDI with large immediate - expecting FAILURE..."; \
	echo ""; \
	PRESERVE_SEEDS=1 make regress || echo "   ✓ Bug reproduced - ADDI fails as expected"; \
	\
	echo ""; \
	echo "2. Running FIXED version (branch: $$CURRENT_BRANCH)..."; \
	git checkout $$CURRENT_BRANCH; \
	git stash pop || true; \
	make clean; \
	mkdir -p logs; \
	echo "695998" > logs/seeds.txt; \
	echo "   Testing same instruction with fix - expecting PASS..."; \
	echo ""; \
	PRESERVE_SEEDS=1 make regress && echo "   ✓ Fix verified - ADDI now works correctly" || echo "   ✗ Unexpected failure"; \
	\
	echo ""; \
	echo "Bug demonstration complete!"; \
	echo "See $(BUG_DIR)/BUG.md for detailed technical analysis." 
