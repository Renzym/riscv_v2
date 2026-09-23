# RV32IM Core Verification

This directory contains the Linux verification flow for the RV32IM core. It
uses:

- AMD/Xilinx Vivado xsim for RTL and UVM simulation
- riscv-dv for assembly-program generation
- a bare-metal RISC-V GCC toolchain for compilation
- Spike as the reference instruction-set simulator

The flow is intended for Linux. Native Windows PowerShell and CMD
are not supported by this UVM flow.

## Directory Layout

```text
UVM_tb/
  Makefile                         Verification targets
  run_verification.sh              One-command regression wrapper
  .env                             Local tool and test configuration
  uvm_classic/                     UVM environment and tests
  tb_mem/                          Simulation memory models and directed images
  scripts/                         Generation, build, simulation, and comparison tools
  RISC-V/riscv-dv/                 Vendored riscv-dv generator
  RISC-V/custom_target/rv32i/      Core-specific riscv-dv configuration
```

The custom-target directory keeps the legacy name `rv32i`, but its settings
enable both RV32I and RV32M instructions.

## Verification Flow

The main regression performs these steps:

1. riscv-dv generates an RV32IM assembly program for each seed.
2. RISC-V GCC compiles the generated program into an ELF file.
3. Spike runs the ELF and produces a reference commit log.
4. Vivado xsim runs the same program on the RTL/UVM testbench.
5. The UVM scoreboards compare RTL program flow and architectural commits with
   the Spike results.

The main UVM test is `riscv_base_test`. It receives the generated memory image
and Spike log through simulation plusargs.

## Required Tools

Install these tools before running verification:

- Vivado with `xvlog`, `xelab`, and `xsim`
- Python 3 and pip
- a bare-metal RISC-V GCC toolchain containing `gcc` and `objcopy`
- Spike built with commit-log support
- GNU Make and common Linux utilities such as Bash, `find`, and `tee`

Install the Linux packages needed to build Spike and run the helper scripts:

```bash
sudo apt update
sudo apt install -y git make gcc g++ autoconf automake autotools-dev curl \
  python3 python3-pip python3-venv libmpc-dev libmpfr-dev libgmp-dev gawk \
  build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev \
  libexpat-dev
```

Install the Python dependencies from the repository root:

```bash
python3 -m pip install -r UVM_tb/RISC-V/riscv-dv/requirements.txt
```

Install Vivado and a bare-metal RISC-V GCC toolchain using their respective
vendor instructions. Their installation directories may be anywhere on the
machine; the next section explains how to configure them.

To build Spike with commit-log support, replace `[SPIKE_INSTALL_DIR]` with the
directory where Spike should be installed:

```bash
git clone https://github.com/riscv-software-src/riscv-isa-sim.git spike-src
cd spike-src
mkdir build
cd build
../configure --prefix="[SPIKE_INSTALL_DIR]" --enable-commitlog
make -j"$(nproc)"
make install
```

## Configure Tool Paths

Before running any verification test, configure both `run_verification.sh` and
`.env`. Replace every bracketed placeholder, including the square brackets,
with the path or tool prefix for your machine.

The placeholders mean:

- `[VIVADO_INSTALL_DIR]`: directory containing Vivado's `settings64.sh`
- `[RISCV_TOOLCHAIN_BIN]`: directory containing the RISC-V `gcc` and `objcopy`
- `[SPIKE_INSTALL_DIR]`: directory containing `bin/spike`
- `[RISCV_TOOLCHAIN_PREFIX]`: executable prefix without `-gcc`

For example, if the compiler executable is `riscv-none-elf-gcc`, use
`RISCV_PREFIX=riscv-none-elf`. If it is `riscv64-unknown-elf-gcc`, use
`RISCV_PREFIX=riscv64-unknown-elf`.

### 1. Configure `run_verification.sh`

Replace its environment setup lines with your paths:

```bash
echo "--- Setting up environment ---"
source "[VIVADO_INSTALL_DIR]/settings64.sh"
export PATH="[RISCV_TOOLCHAIN_BIN]:$PATH"
export PATH="[SPIKE_INSTALL_DIR]/bin:$PATH"
```

### 2. Configure `.env`

Update these values and keep the test configuration below them:

```bash
VIVADO_HOME=[VIVADO_INSTALL_DIR]
XILINX_VIVADO=[VIVADO_INSTALL_DIR]
SPIKE_HOME=[SPIKE_INSTALL_DIR]
SPIKE_CMD=[SPIKE_INSTALL_DIR]/bin/spike
RISCV_PREFIX=[RISCV_TOOLCHAIN_PREFIX]

DEFAULT_TEST_NAME=riscv_arithmetic_basic_test
TARGET_ISA=rv32im
TARGET_ARCH=rv32im_zicsr
TARGET_ABI=ilp32
```

Keep the paths in `.env` and `run_verification.sh` consistent. The Makefile
loads `.env`, while the wrapper script loads Vivado and extends `PATH` itself.

Do not commit personal installation paths when preparing a contribution.

## Verify the Configuration

Open a Linux/WSL Bash terminal and run the following commands from `UVM_tb/`.
Replace `[RISCV_TOOLCHAIN_BIN]` with the same value used above.

```bash
cd UVM_tb

set -a
source ./.env
set +a

source "$VIVADO_HOME/settings64.sh"
export PATH="[RISCV_TOOLCHAIN_BIN]:$SPIKE_HOME/bin:$PATH"

command -v xvlog
command -v xelab
command -v xsim
command -v "${RISCV_PREFIX}-gcc"
command -v "${RISCV_PREFIX}-objcopy"
test -x "$SPIKE_CMD"
"$SPIKE_CMD" --help >/dev/null
```

Every command must succeed before running a regression. The `command -v`
checks must print executable paths, and the Spike help check must return without
an error. Repeat this environment setup when starting a new terminal.

## Run Verification

Run the default arithmetic regression from `UVM_tb/`:

```bash
bash run_verification.sh
```

Pass a test name to run a specific generated test:

```bash
bash run_verification.sh riscv_rand_instr_test
```

The enabled generated tests can be run as follows:

```bash
bash run_verification.sh riscv_arithmetic_basic_test
bash run_verification.sh riscv_rand_instr_test
bash run_verification.sh riscv_jump_stress_test
bash run_verification.sh riscv_loop_test
bash run_verification.sh riscv_rand_jump_test
bash run_verification.sh riscv_mmu_stress_test
bash run_verification.sh riscv_no_fence_test
bash run_verification.sh riscv_illegal_instr_test
bash run_verification.sh riscv_ebreak_test
bash run_verification.sh riscv_ebreak_debug_mode_test
bash run_verification.sh riscv_full_interrupt_test
```

The wrapper uses one random seed. To run the Makefile target directly with more
seeds:

```bash
make uvm_regress TEST=riscv_rand_instr_test NUM_SEEDS=10
```

## Available Generated Tests

The authoritative list is
`RISC-V/custom_target/rv32i/testlist.yaml`.

| Test | Purpose | Status |
| --- | --- | --- |
| `riscv_arithmetic_basic_test` | RV32I arithmetic without load/store/branch instructions | Enabled |
| `riscv_rand_instr_test` | Random instruction, load/store, and jump stress | Enabled |
| `riscv_jump_stress_test` | Back-to-back jump stress | Enabled |
| `riscv_loop_test` | Loop instruction generation | Enabled |
| `riscv_rand_jump_test` | Random jump generation | Enabled |
| `riscv_mmu_stress_test` | Load/store memory stress | Enabled |
| `riscv_no_fence_test` | Random program with fence disabled | Enabled |
| `riscv_illegal_instr_test` | Illegal-instruction exception generation | Enabled |
| `riscv_ebreak_test` | EBREAK handling | Enabled |
| `riscv_ebreak_debug_mode_test` | EBREAK with the debug sequence enabled | Enabled |
| `riscv_full_interrupt_test` | Generated interrupt-sequence test | Enabled |
| `riscv_csr_test` | CSR test-list entry | Disabled (`iterations: 0`) |
| `riscv_unaligned_load_store_test` | Unaligned load/store test | Disabled (`iterations: 0`) |

The CSR test is not part of the normal regression while its iteration count is
zero. The unaligned-access test is disabled because this core traps misaligned
loads and stores, while the generated bare-metal program does not install the
required trap handler.

## Directed UVM Tests

The directed tests use RTL-side stimulus and do not use the normal Spike
lockstep comparison.

Run the external-interrupt test:

```bash
make uvm_external_irq
```

It loads `tb_mem/external_irq_imem.mem`, asserts external interrupt bit 0, and
checks:

- `mcause = 0x8000000b`
- `mepc` contains an aligned interrupted-loop PC
- ORCA `meipend[0]` is set while the interrupt input is high
- the handler executes once and returns with `MRET`

Run the RV32M directed test:

```bash
make uvm_m_extension
```

It checks all eight RV32M multiply/divide operations, divide-by-zero behavior,
and signed division overflow.

Run both directed feature tests:

```bash
make uvm_rv32im_features
```

## Results and Troubleshooting

A successful wrapper run ends with:

```text
--- VERIFICATION PASSED ---
```

If a run fails:

1. Confirm that all commands in **Verify the Configuration** succeed.
2. Inspect `logs/uvm_run.log` for compilation, elaboration, simulation, or
   scoreboard failures.
3. Inspect the generated `out_*/` directory for the assembly, ELF, memory image,
   RTL trace, and Spike log associated with the failing seed.
4. Rerun with the same `logs/seeds.txt` file and `PRESERVE_SEEDS=1` when a
   reproducible seed is needed.

The wrapper returns a nonzero exit status when verification fails.
