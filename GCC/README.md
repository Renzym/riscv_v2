# GCC - Bare-Metal C Flow For The RV32IM Core

This folder builds one bare-metal C program into a RISC-V instruction image.
The Vitis ARM loader in `../FW/run_gcc_program.c` writes that image into direct
instruction BRAM, releases the core, and reads the result from direct data BRAM.

Current hardware map:
- `0x40000000`: RISC-V core control register, bit0 holds reset
- `0x42000000`: instruction BRAM, ARM view
- `0x44000000`: data BRAM, ARM view

Core memory map:
- IMEM `0x0000..0x07ff`: code and rodata
- DMEM `0x0000..0x00ff`: mailbox/result/status
- DMEM `0x0900..0x0bff`: data and bss
- DMEM `0x0c00..0x0fff`: stack

## Files

- `main.c`: RV32IM self-test executed by the RISC-V core
- `crt0.s`: startup code, sets stack pointer and jumps to `main`
- `linker.ld`: fixed 4 KB core memory layout
- `shared_mem.h`: mailbox addresses shared by RISC-V C and ARM loader
- `Makefile`: builds `program.elf`, `program.imem.bin`, and `rv32i_program_image.h`
- `emit_riscv_header.py`: converts the binary image into a C header for Vitis

## Build

Requires a bare-metal RISC-V GCC toolchain:

```sh
cd GCC
make
```

The Makefile defaults to:

```sh
RISCV_PREFIX=riscv64-unknown-elf
ARCH=rv32im
ABI=ilp32
```

If your compiler prefix is different:

```sh
make RISCV_PREFIX=riscv32-unknown-elf
```

## Run On Hardware

After `make` regenerates `GCC/rv32i_program_image.h`, build and run the Vitis
app. The active Vitis source wrapper is:

```c
#include "../../../../FW/run_gcc_program.c"
```

The current `main.c` forces all eight RV32M instruction encodings with inline
assembly:
- `MUL`, `MULH`, `MULHSU`, `MULHU`
- `DIV`, `DIVU`, `REM`, `REMU`
- divide-by-zero and signed overflow architectural corner cases

Expected result:
- `MAILBOX_RESULT_ADDR`: `0x00000fff`
- `MAILBOX_EXPECTED_ADDR`: `0x00000fff`
- `MAILBOX_FAIL_COUNT_ADDR`: `0x00000000`
- `MAILBOX_STATUS_ADDR`: `0xcafecafe`
