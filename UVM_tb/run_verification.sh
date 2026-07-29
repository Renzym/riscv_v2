#!/bin/bash
# run_verification.sh
# Execute the full RISC-V verification flow using Vivado and Spike

# 1. Setup environment (Update paths if necessary)
echo "--- Setting up environment ---"
source /tools/Xilinx/Vivado/2022.1/settings64.sh
export PATH=$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin:$PATH
export PATH=$HOME/tools/spike/bin:$PATH

# 2. Clean previous runs
echo "--- Cleaning project ---"
make clean

# 3. Run full UVM regression
TEST_NAME=${1:-riscv_arithmetic_basic_test}
echo "--- Starting UVM Regression (1 Seed) for test: $TEST_NAME ---"
make uvm_regress NUM_SEEDS=1 TEST=$TEST_NAME

# 4. Check result
if [ $? -eq 0 ]; then
    echo "--- VERIFICATION PASSED ---"
else
    echo "--- VERIFICATION FAILED ---"
    exit 1
fi
