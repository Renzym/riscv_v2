# RV32IM Core Verification

This directory contains the Linux verification flow for the RV32IM core. The
current flow uses Vivado xsim for RTL/UVM simulation, riscv-dv for program
generation, Spike as the golden ISA model, and a RISC-V GCC toolchain for
building generated assembly.

This flow is Linux-only. Do not expect the UVM/riscv-dv flow to build or run on
native Windows PowerShell or CMD. Windows can be used for editing, but the
verification commands below should be run on Linux, WSL with the required tools,
or the project machine configured for CI.

## Directory Map

```text
UVM_tb/
  Makefile                         Main verification entry points
  run_verification.sh              One-command local regression wrapper
  .env                             Local tool/path defaults
  uvm_classic/                     UVM testbench, agents, monitors, predictors, scoreboards
  tb_mem/                          Instruction/data memory models for simulation
  scripts/                         Generation, compile, Spike, xsim, and compare helpers
  RISC-V/riscv-dv/                 Vendored riscv-dv generator and compare scripts
  RISC-V/custom_target/rv32i/      Core-specific riscv-dv target and test list
```

## What Is Checked

The important regression path is Spike lockstep comparison:

1. `riscv-dv` generates an RV32IM assembly program for one or more seeds.
2. The generated assembly is compiled with the RISC-V GCC toolchain.
3. Spike runs the exact compiled ELF and writes a commit log.
4. Vivado xsim runs the same program on the RTL/UVM testbench.
5. The UVM scoreboards compare program flow and architectural commits against
   the Spike reference log.

The UVM environment is in `uvm_classic/`. The active test is `riscv_base_test`,
which loads a generated memory image and Spike log through plusargs.

## Required Tools

Install these on Linux before running the flow:

- AMD/Xilinx Vivado with `xvlog`, `xelab`, and `xsim` available.
- Python 3.
- RISC-V GCC toolchain with `riscv-none-elf-gcc` and `riscv-none-elf-objcopy`.
- Spike built with commit-log support.
- Standard Linux build tools: `make`, `bash`, `find`, `tee`.

The checked-in `.env` uses these defaults:

```bash
VIVADO_HOME=/tools/Xilinx/Vivado/2022.1
XILINX_VIVADO=/tools/Xilinx/Vivado/2022.1
SPIKE_HOME=/home/rafi/tools/spike
SPIKE_CMD=/home/rafi/tools/spike/bin/spike
RISCV_PREFIX=riscv-none-elf
TARGET_ISA=rv32im
TARGET_ARCH=rv32im_zicsr
TARGET_ABI=ilp32
```

The riscv-dv custom target package is still named `rv32i` for compatibility
with `RISC-V/custom_target/rv32i/`; that target's settings enable both `RV32I`
and `RV32M`.

Edit `UVM_tb/.env` for your machine, or export the same variables in your shell.
For example:

```bash
cd UVM_tb
source /tools/Xilinx/Vivado/2022.1/settings64.sh
export PATH=$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin:$PATH
export PATH=$HOME/tools/spike/bin:$PATH
export SPIKE_CMD=$HOME/tools/spike/bin/spike
export RISCV_PREFIX=riscv-none-elf
```

Check the tools before starting:

```bash
which xvlog xelab xsim
which riscv-none-elf-gcc riscv-none-elf-objcopy
which spike
```

## Install And Run

Run these commands on Linux. Adjust the Vivado version/path if your installation
is different.

```bash
sudo apt update
sudo apt install -y git make gcc g++ autoconf automake autotools-dev curl \
  python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential \
  bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
```

Install the xPack RISC-V GCC toolchain under `~/tools` so the path matches this
project:

```bash
mkdir -p $HOME/tools
cd $HOME/tools
# Download and extract xpack-riscv-none-elf-gcc-15.2.0-1 for Linux x64.
# The extracted folder should be:
#   $HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1
export PATH=$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin:$PATH
```

Build and install Spike with commit-log support:

```bash
cd $HOME/tools
git clone https://github.com/riscv-software-src/riscv-isa-sim.git spike-src
cd spike-src
mkdir -p build
cd build
../configure --prefix=$HOME/tools/spike --enable-commitlog
make -j$(nproc)
make install
export PATH=$HOME/tools/spike/bin:$PATH
```

Set the project paths before running verification:

```bash
source /tools/Xilinx/Vivado/2022.1/settings64.sh
export PATH=$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin:$PATH
export PATH=$HOME/tools/spike/bin:$PATH
```

You can put the same exports in `UVM_tb/.env` or in your shell startup file if
you do not want to type them every time.

Check that the tools are visible:

```bash
which xvlog xelab xsim
which riscv-none-elf-gcc riscv-none-elf-objcopy
which spike
```

Run the verification wrapper from `UVM_tb/`:

```bash
cd UVM_tb
bash run_verification.sh
```

To run a specific test, pass the test name as the first argument:

```bash
bash run_verification.sh riscv_arithmetic_basic_test
```
Run each verification test like this:

```bash
./run_verification.sh riscv_arithmetic_basic_test
./run_verification.sh riscv_rand_instr_test
./run_verification.sh riscv_jump_stress_test
./run_verification.sh riscv_loop_test
./run_verification.sh riscv_rand_jump_test
./run_verification.sh riscv_mmu_stress_test
./run_verification.sh riscv_no_fence_test
./run_verification.sh riscv_illegal_instr_test
./run_verification.sh riscv_ebreak_test
./run_verification.sh riscv_ebreak_debug_mode_test
./run_verification.sh riscv_full_interrupt_test
```

`riscv_csr_test` is listed in the riscv-dv test list but is currently disabled
with `iterations: 0`, so do not use it as a normal regression test until that
entry is enabled.

`riscv_unaligned_load_store_test` is also disabled. This core traps misaligned
loads/stores instead of completing them in hardware, and the generated bare-metal
test does not install a trap handler.

## Available Verification Tests

The active test list is `RISC-V/custom_target/rv32i/testlist.yaml`.

| Test | Purpose |
|------|---------|
| `riscv_arithmetic_basic_test` | Arithmetic-focused RV32I test, no load/store/branch instructions. |
| `riscv_rand_instr_test` | Random instruction stress with load/store and jump streams. |
| `riscv_jump_stress_test` | Back-to-back jump stress. |
| `riscv_loop_test` | Simple loop instruction test. |
| `riscv_rand_jump_test` | Random jump test. |
| `riscv_mmu_stress_test` | Load/store memory stress for the simple memory model. |
| `riscv_no_fence_test` | Random program with fence disabled. |
| `riscv_illegal_instr_test` | Illegal instruction exception sequence. |
| `riscv_ebreak_test` | EBREAK instruction handling. |
| `riscv_ebreak_debug_mode_test` | EBREAK with debug-mode sequence option. |
| `riscv_full_interrupt_test` | Interrupt sequence entry in the generator list. |
| `riscv_csr_test` | CSR test entry. Currently disabled with `iterations: 0`. |
| `riscv_unaligned_load_store_test` | Disabled; this core does not support unaligned load/store completion. |

Run any enabled test by passing its name to `run_verification.sh`.

## Directed External Interrupt UVM Test

The external interrupt path is checked with a directed UVM test instead of the
Spike lockstep scoreboard, because the interrupt assertion is an RTL-side event.

Run it from `UVM_tb/`:

```bash
make uvm_external_irq
```

This loads `tb_mem/external_irq_imem.mem`, asserts bit 0 of the ORCA-style
external interrupt vector through the UVM interface, and checks:

- `mcause = 0x8000000b`
- `mepc` is an aligned interrupted loop PC
- ORCA `meipend[0]` reads as set while the interrupt input is high
- the handler executes once and returns with `MRET`

## Directed RV32M UVM Test

The M extension is checked with a directed UVM test that runs
`tb_mem/m_extension_imem.mem` and observes writeback results for all RV32M
multiply/divide operations and corner cases:

- `MUL`, `MULH`, `MULHSU`, `MULHU`
- `DIV`, `DIVU`, `REM`, `REMU`
- divide-by-zero behavior
- signed divide overflow behavior

Run it from `UVM_tb/`:

```bash
make uvm_m_extension
```

To run both newly added feature checks:

```bash
make uvm_rv32im_features
```

## Pass/Fail

A passing run ends with the Makefile command returning exit code 0. For the
script wrapper, the final line is:

```text
--- VERIFICATION PASSED ---
```

For failed UVM regressions, inspect `logs/uvm_run.log` first, then check the
generated `out_*/` directory for the program, memory image, and Spike log used
by that run.

## If You Do Not Have Linux Locally

If you cannot run the Linux verification flow on your own machine, push your
work to the GitHub repository `renzym/rv32i_core1` on the `PR_review` branch.
Do not push directly to `main`.

One safe sequence is:

```bash
git remote add origin https://github.com/renzym/rv32i_core1.git
git checkout -B PR_review
git add .
git commit -m "Update RV32I verification changes"
git push -u origin PR_review
```

The repository is expected to run the configured action automatically on pushes
to `PR_review`. Check the action result in GitHub; it will report whether the
verification passed or failed on the configured Linux machine.
