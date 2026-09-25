# RV32IM 5-Stage Pipelined RISC-V Core
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)


A compact, in-order **RV32IM + Zicsr** processor written in SystemVerilog,
designed for FPGA integration with on-chip instruction and data memory. The
repository includes a reference Vivado integration for a Xilinx Zynq-7000
(`xc7z010clg400-1`) and the Digilent Zybo board. The core interfaces are
technology-agnostic; other FPGA families and memory/interconnect systems can
use the same RTL with an appropriate wrapper. Verification infrastructure
includes **Spike** reference comparisons, directed UVM tests, and standalone
regressions.

---

## Block Design and Resources

![RV32IM system block design](image/RV32I_block_design.png)

![RV32IM core block design](image/RV32I_riscv_core_block_design.png)

The system figure shows the native-BRAM and control paths, the `M_AXI_PERIPH`
master interface, and the `global_interrupts` vector. Solid arrows represent
signal or bus connections; the dashed purple arrow represents the shared
package dependency. The dashed memory-routing box groups logic written inside
`riscv_zynq_wrapper.sv`; it is not a separate instantiated RTL module. The core
figure is a simplified stage overview: names ending in `.sv` identify modules;
stage groupings and other functions describe logic inside `riscv_core.sv`.
Interface details are documented in sections 3, 4, and 7.

FPGA resource utilization report: [core_resources_utilization.txt](specs/core_resources_utilization.rpt)

Full core specification: [core_specs.md](specs/core_specs.md)

The RTL and interface descriptions below are authoritative for the current
implementation.

## Core Specifications

| Item | Specification |
|------|---------------|
| Core module | `riscv_core` |
| ISA | RISC-V RV32IM + Zicsr |
| XLEN | 32-bit |
| Implementation language | SystemVerilog |
| Target platform | Generic FPGA; reference Zynq-7000 BRAM integration included |
| Pipeline | 5-stage, in-order |
| Memory architecture | Separate instruction and data BRAM interfaces |
| Privilege support | Limited machine-mode CSR/trap subset (not a complete privileged implementation) |
| Interrupts | Parameterized 1-32 input external-interrupt vector; no timer/software interrupts |

| Feature | Support |
|---------|---------|
| Base integer ISA | RV32I supported |
| Register file | 32 integer registers, `x0`-`x31` |
| `x0` behavior | Hardwired to zero |
| Instruction width | 32-bit instructions only |
| Endianness | Little-endian load/store byte lanes |
| Compressed extension | Not supported |
| Multiply/divide extension | RV32M supported |
| Atomic extension | Not supported |
| Floating-point extension | Not supported |

---

## 1. Pipeline — 5 stages

```
IF  ->  ID  ->  EX  ->  MEM  ->  WB
```

| Stage | Does |
|-------|------|
| **IF** (fetch)   | drives the PC, fetches the instruction from IMEM |
| **ID** (decode)  | decodes the instruction, reads the register file, generates the immediate, reads a CSR |
| **EX** (execute) | ALU op / address calc, branch & jump resolution, CSR write & trap generation |
| **MEM** (memory) | data-memory load/store with byte strobes + load sign/zero extension |
| **WB** (write-back) | writes the result back to the register file |

**Hazard handling:**

- **Forwarding unit** — bypasses results from EX/MEM and MEM/WB back into EX, so most dependent instructions don't stall.
- **Load-use stall** — the hazard unit inserts a bubble, and registered hold logic keeps decode stalled for an additional cycle. Memory wait states can extend the stall.
- **Control hazards** — branches/jumps resolve in **EX**; the instructions already fetched behind them are squashed via the pipeline valid bits.

The core uses request/ready handshakes on both memory ports, so it works with
zero-wait-state simulation memory or delayed memory responses. Instruction
responses carry `imem_resp_pc`, and `imem_resp_accept` indicates that the core
has consumed or discarded a returned response. The FPGA wrapper adapts the
core interface to registered-output BRAM and completes a BRAM access after the
requested address has remained stable for a full clock cycle.

## 2. Instruction set

**RV32I computational, control-flow, and memory instructions (37):**

- R-type: `ADD SUB SLL SLT SLTU XOR SRL SRA OR AND`
- I-type: `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI`
- Upper:  `LUI AUIPC`
- Loads:  `LB LH LW LBU LHU`  Stores: `SB SH SW`
- Branch: `BEQ BNE BLT BGE BLTU BGEU`
- Jump:   `JAL JALR`

**RV32M multiply/divide extension:**

- Multiply: `MUL MULH MULHSU MULHU`
- Divide/remainder: `DIV DIVU REM REMU`

**Zicsr — `CSRRW CSRRS CSRRC CSRRWI CSRRSI CSRRCI`**
read/modify a CSR atomically and return its old value in `rd`.


## 3. CSRs and ECALL / EBREAK (machine mode)

The core implements a small machine-mode CSR subset for basic trap handling:

| CSR | Addr | Role |
|-----|------|------|
| `mstatus`  | 0x300 | implements `MIE`, `MPIE`, and `MPP` |
| `mie`      | 0x304 | stores standard `MEIE` bit 11; see interrupt note below |
| `mtvec`    | 0x305 | direct-mode trap-handler address |
| `mscratch` | 0x340 | scratch register for the handler |
| `mepc`     | 0x341 | saved PC of the trapping instruction |
| `mcause`   | 0x342 | why the trap happened |
| `mtval`    | 0x343 | trap value, such as the faulting address or PC |
| `mip`      | 0x344 | read-only aggregate external-pending indication in `MEIP` |
| `meimask`  | 0x7c0 | custom per-input external-interrupt enable mask |
| `meipend`  | 0xfc0 | custom read-only external-interrupt pending vector |

**Trap mechanism (`ECALL` / `EBREAK` / `MRET`):**

| Instruction / event | Hardware action |
|-------------|-----------------|
| `ECALL`  | `mcause = 11`, `mepc = PC`, jump to `mtvec` |
| `EBREAK` | `mcause = 3`,  `mepc = PC`, jump to `mtvec` |
| Misaligned load | `mcause = 4`, `mtval = address`, jump to `mtvec` |
| Load access fault | `mcause = 5`, `mtval = address`, jump to `mtvec` when access-fault checking is enabled |
| Misaligned store | `mcause = 6`, `mtval = address`, jump to `mtvec` |
| Store access fault | `mcause = 7`, `mtval = address`, jump to `mtvec` when access-fault checking is enabled |
| External interrupt | `mcause = 0x8000000b`, `mtval = 0`, jump to `mtvec` |
| `MRET`   | jump to `mepc`, restore `MIE` from `MPIE`, clear `MPIE`, and clear `MPP` |

External interrupts are enabled by setting `mstatus.MIE` and the corresponding
bit in the custom `meimask` CSR. `global_interrupts[n]` is reflected in
`meipend[n]`; an enabled pending bit requests a machine external interrupt.
Although `mie.MEIE` is stored and readable, the current interrupt gate uses
`mstatus.MIE` plus `meimask`, not `mie.MEIE`.

Trap entry saves the PC in `mepc`, copies `MIE` into `MPIE`, clears `MIE`, and
sets `MPP` to machine mode. Redirects use `mtvec` with its low two bits cleared.
The custom interrupt mask and the clearing of `MPIE` on `MRET` are implementation
specific; they must not be assumed to match a complete standard privileged core.

This is a **minimal**, direct-`mtvec` trap implementation. Timer and software
interrupts, vectored trap mode, illegal-instruction traps, instruction access
faults, PMP, MMU, user/supervisor modes, and a debug module are not implemented.
Data access-fault checking is controlled by `TRAP_ACCESS_FAULTS` and is disabled
by the FPGA wrapper. Reads of unimplemented CSRs return zero and writes are
ignored.

## 4. Memory model (Harvard)

Separate instruction and data ports, both byte-addressed:

```
imem_req, imem_addr, imem_resp_accept -> IMEM
imem_ready, imem_instr, imem_resp_pc   <- IMEM

dmem_addr, dmem_write_data, dmem_wstrb,
dmem_read_en, dmem_write_en            -> DMEM
dmem_ready, dmem_read_data             <- DMEM
```

On the FPGA these connect to two **4 KB BRAMs** through
`riscv_zynq_wrapper.sv` or the plain-Verilog `riscv_zynq_bridge.v`. The wrapper
uses native BRAM ports for instruction/data memory, an `S_AXI_CTRL` AXI-Lite
slave for CPU reset/status, and an `M_AXI_PERIPH` AXI4-Lite master for CPU
data-side peripherals.

The core uses byte addresses internally. The BRAM wrapper drives word-aligned
byte addresses on `bram_imem_addr` and `bram_dmem_addr`, matching the native
BRAM address convention used by the Vivado AXI BRAM Controller. A core access
to byte address `0x100` drives BRAM address `0x100`, which selects BRAM word
`0x40` inside a 32-bit BRAM.

```
riscv_zynq_bridge
  S_AXI_CTRL        <-- PS control/status accesses
  bram_imem_*       --> instruction BRAM native port
  bram_dmem_*       --> data BRAM native port
  M_AXI_PERIPH      --> CPU data-side AXI4-Lite peripherals
  global_interrupts <-- external interrupt sources
```

`aresetn` resets the whole wrapper. After `aresetn` is released, the
`S_AXI_CTRL` control register still holds the CPU in reset until software writes
`0` to control register `0x0`. The status register at `0x4` reports whether the
CPU is running.

The supplied Vivado block design gives the ARM processing system this view:

| PS address | Target |
|------------|--------|
| `0x40000000` | `S_AXI_CTRL` control/status block |
| `0x42000000` | instruction BRAM |
| `0x44000000` | data BRAM |

It also maps an AXI GPIO peripheral into the CPU address space at
`0x10000000`-`0x10000fff`.

## 5. RTL structure

The core is split into focused, single-purpose modules (a shared package plus
one module per function), instantiated by the top:

```
fpga/rtl/
  riscv_pkg.sv        constants (opcodes, ALU ops, CSR addresses)
  riscv_alu.sv        arithmetic/logic unit
  riscv_regfile.sv    32x32 register file (with write-back bypass)
  riscv_decode.sv     instruction decoder + immediate generation
  riscv_csr.sv        machine CSR subset + trap/interrupt state
  riscv_lsu.sv        load/store byte/half formatting
  riscv_hazard.sv     forwarding selects + load-use stalls
  riscv_core.sv       top: pipeline registers + EX control, wires the above
  ---- FPGA glue (AXI-Lite control + direct BRAM memory) ----
  axi_lite_control.sv    AXI-Lite CPU reset/status register block
  riscv_axi_lite_master.sv CPU data request to AXI4-Lite master bridge
  riscv_zynq_wrapper.sv  BRAM-based wrapper with control, peripherals, and interrupts
  riscv_zynq_bridge.v    plain-Verilog wrapper for Vivado block design import
  design_1_wrapper.v     generated block-design top (requires recreated design_1)
```

`riscv_core` parameters are `RESET_PC`, `TRAP_ACCESS_FAULTS`, `DMEM_BASE`,
`DMEM_LIMIT`, and `NUM_EXT_INTERRUPTS`. Wrapper parameters are `ADDR_WIDTH`,
`RESET_PC`, `AXI_PERIPH_BASE`, `AXI_PERIPH_MASK`, and `NUM_EXT_INTERRUPTS`.

## 6. Compile a C program (GCC)

Write your program in `GCC/main.c`, then build it:

```bash
cd GCC && make gcc        # -> rv32i_program_image.h (machine-code array)
```
Plain `make` also creates/builds the Vitis platform/application flow and opens
the resulting workspace and requires a hardware XSA. Image generation requires
GNU Make, Python, and a bare-metal RISC-V GCC toolchain; the default prefix is
`riscv64-unknown-elf`, with `-march=rv32im -mabi=ilp32`.
The C flow is freestanding: the current linker allows
2 KB for code/rodata, 768 bytes for data/BSS, and a 1 KB stack. The minimal
startup does not copy initialized global data or clear `.bss`, so applications
must initialize required data explicitly. File descriptions and additional flow
notes are in **[`GCC/README.md`](GCC/README.md)**; for image-only generation,
use the `make gcc` command shown above. The loader writes only the instruction
image and clears low DMEM; it does not initialize the linked data/BSS region.
Constants placed in IMEM `.rodata` are not automatically visible to loads from
the separate DMEM. Use the supplied example's explicit data initialization;
general C runtime and read-only-data support require additional work.

## 7. Build the FPGA project (Vivado)

The supplied project-recreation script targets Vivado 2024.2. It contains
machine-specific paths and a Zybo board preset; review those settings for your
installation and board before running it. From the repository root:

```bash
cd fpga/work
source ./rv32i.tcl
```

It creates the Zynq processing system, SmartConnect, two AXI BRAM controllers,
two dual-port BRAMs, the RISC-V bridge, an AXI GPIO peripheral, and the required
address map. The AXI BRAM controllers give the ARM processing system access to
BRAM port A; the RISC-V core itself uses native BRAM port B. Recreating the
project does not automatically run synthesis or implementation. Regenerate the
HDL wrapper from the block design so it includes the GPIO LED ports; the checked-in
`design_1_wrapper.v` predates those ports.

For manual block-design integration instead, add the RTL sources with
`riscv_pkg.sv` compiled before the modules, then:

1. Add module `riscv_zynq_bridge`.
2. Connect `clk` to the BRAM/core clock.
3. Connect `aresetn` to your active-low system reset.
4. Connect `S_AXI_CTRL` to a PS AXI master for software reset/status control.
5. Connect `global_interrupts` to your external interrupt lines, or tie it to zero.
6. Connect `bram_imem_*` directly to the instruction BRAM native port.
7. Connect `bram_dmem_*` directly to the data BRAM native port.
8. Connect `M_AXI_PERIPH` to an AXI4-Lite peripheral/interconnect. The supplied
   project connects it to AXI GPIO.
9. Initialize instruction BRAM contents with your program image, or expose the
   other BRAM ports to the PS loader.

Then run **Synthesis → Implementation → Generate Bitstream** in Vivado.

No AXI bridge is present in the CPU-to-BRAM instruction/data path. The supplied
PS loader design nevertheless uses AXI BRAM controllers and SmartConnect on the
other BRAM ports so the ARM processor can load IMEM and inspect DMEM.

## 8. Run on the core

For a preinitialized-BRAM build, initialize instruction BRAM with the program
image produced by the GCC flow. After `aresetn` is released, write `0` to the
control register at offset `0x0` to release the CPU. The core starts at
`RESET_PC` and accesses instruction/data BRAM through the native BRAM ports.

To load a program from the ARM processing system, build the GCC image and run
the supplied Vitis loader:

1. Copy **`GCC/rv32i_program_image.h`** and **[`FW/run_gcc_program.c`](FW/run_gcc_program.c)**
   into your Vitis application.
2. Build and run it. The loader holds the CPU in reset, clears the low data-BRAM
   mailbox, loads and verifies instruction BRAM, releases the CPU, and reads the
   result from data BRAM.

For a self-contained hardware instruction test that does not require a RISC-V
GCC image, use [`FW/simple_test.c`](FW/simple_test.c). It hand-assembles a test
program, loads it through PS address `0x42000000`, and reads results through
`0x44000000`. In the CPU's DMEM view, status is at `0x10`, results start at
`0x40`, and load/store scratch space starts at `0x200`. It tests the RV32I
integer operations, all eight RV32M operations and selected divide/remainder
corner cases, plus `FENCE`/`FENCE.I` no-operation behavior. It does not test CSR
instructions, ECALL, EBREAK, or MRET. If Vivado assigns different PS addresses,
update `IMEM_BASE`, `DMEM_BASE`, and `CTRL_BASE` at the top of the file.

## 9. Verification

The current verification flow is documented in
**[`UVM_tb/README.md`](UVM_tb/README.md)**. It is a Linux-only flow using Vivado
xsim, riscv-dv, Spike, and the UVM testbench in `UVM_tb/uvm_classic/`.

- **`UVM_tb/uvm_classic/`** - UVM testbench, monitors, predictors, and scoreboards.
- **`UVM_tb/RISC-V/custom_target/rv32i/`** - RV32IM riscv-dv target and test list (legacy directory name).
- **`UVM_tb/scripts/`** - generation, compile, Spike, xsim, and compare helpers.

The standalone regression below passed during the documentation review. The
Linux UVM/Spike flow and Vivado implementation were not rerun as part of that
review. Directed interrupt tests use RTL-side stimulus; they are separate from
Spike comparisons. Passing these regressions is not a claim of exhaustive ISA
or privileged-architecture compliance.

## 10. Standalone simulation (tb / Icarus Verilog)

A quick, non-UVM regression in [`tb/`](tb/) runs focused **RV32M core checks**,
external-interrupt checks, native-BRAM wrapper checks, AXI4-Lite peripheral
routing checks, and an **RV32I + Zicsr + trap** program. It checks results
against known-good register, memory, CSR, and bus values. It uses **Icarus
Verilog** and dumps a waveform.

```bash
sudo apt install -y iverilog gtkwave     # one-time
cd tb
bash run_sim.sh                          # compile + run  -> PASS / FAIL
gtkwave riscv_core.vcd                   # open the waveform
```
On Windows, install Icarus Verilog, ensure `iverilog` and `vvp` are on `PATH`,
change to `tb/`, and run `./run_sim.ps1`. A successful run prints:
```
PASS: RV32M multicycle regression completed without mismatches.
PASS: External interrupt regression completed without mismatches.
PASS: direct BRAM wrapper regression completed.
PASS: native BRAM plus AXI-Lite peripheral access completed.
PASS: RV32I regression completed without mismatches.
```
The expected final state (registers / memory / CSRs) is encoded in the checks in
[`tb/riscv_tb.sv`](tb/riscv_tb.sv) — handy for matching values in the waveform.

## 11. Repository layout

```
fpga/rtl/     RTL (core modules + FPGA glue)
fpga/work/    Vivado 2024.2 project-recreation script and constraints
GCC/          bare-metal C toolchain flow (C -> program image)
FW/           Vitis (ARM) loaders / tests
tb/           standalone Icarus regression (riscv_tb.sv + hex + run_sim.*)
UVM_tb/       verification: uvm_classic, riscv-dv target, scripts, and docs
image/        block design image
specs/        supplementary processor specification (requires synchronization)
```
