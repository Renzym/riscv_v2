# Core1 RV32IM Processor Specification

## Summary

| Item | Specification |
| --- | --- |
| Core name | Core1 |
| ISA | RISC-V RV32IM |
| XLEN | 32-bit |
| Implementation language | SystemVerilog |
| Target platform | FPGA / Zynq BRAM-based system |
| Pipeline | 5-stage, in-order |
| Memory architecture | Separate instruction and data BRAM interfaces |
| Privilege support | Machine-mode CSR/trap subset |
| Interrupts | Machine external interrupt only |

## ISA Support

| Feature | Support |
| --- | --- |
| Base integer ISA | RV32I supported |
| Register file | 32 integer registers, `x0`-`x31` |
| `x0` behavior | Hardwired to zero |
| Instruction width | 32-bit instructions only |
| Endianness | Little-endian load/store byte lanes |
| Compressed extension | Not supported |
| Multiply/divide extension | RV32M supported |
| Atomic extension | Not supported |
| Floating-point extension | Not supported |

## Supported Instructions

| Group | Instructions |
| --- | --- |
| Upper immediate | `LUI`, `AUIPC` |
| Jumps | `JAL`, `JALR` |
| Branches | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| Loads | `LB`, `LH`, `LW`, `LBU`, `LHU` |
| Stores | `SB`, `SH`, `SW` |
| Register-immediate ALU | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` |
| Register-register ALU | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` |
| Multiply/divide | `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU` |
| System / CSR | `ECALL`, `EBREAK`, `MRET`, `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` |

## Pipeline

| Stage | Main function |
| --- | --- |
| IF | Fetch instruction from instruction BRAM |
| ID | Decode instruction, read register file, read CSR |
| EX | ALU operation, branch/jump decision, trap generation, CSR write-data generation |
| MEM | Data BRAM access, load/store alignment and formatting |
| WB | Register writeback |

| Pipeline feature | Specification |
| --- | --- |
| Execution order | In-order |
| Forwarding | MEM/WB to EX operand forwarding |
| Load-use hazard | Front end stalls and bubble is inserted |
| Data memory wait | Pipeline stalls until `dmem_ready` |
| Redirect point | Branches, jumps, traps, and `MRET` resolve in EX |
| Branch prediction | Not implemented |

## Core Parameters

| Parameter | Default | Description |
| --- | ---: | --- |
| `RESET_PC` | `32'h00000000` | Program counter after reset |
| `TRAP_ACCESS_FAULTS` | `1'b0` | Enables data access-fault traps |
| `DMEM_BASE` | `32'h80000000` | Start of valid data memory range |
| `DMEM_LIMIT` | `32'h80020000` | End of valid data memory range, exclusive |

## Core Interface

| Signal | Direction | Width | Description |
| --- | --- | ---: | --- |
| `clk` | Input | 1 | Core clock |
| `reset` | Input | 1 | Core reset |
| `external_irq` | Input | 1 | Level-sensitive machine external interrupt request |
| `imem_req` | Output | 1 | Instruction fetch request |
| `imem_addr` | Output | 32 | Instruction byte address |
| `imem_ready` | Input | 1 | Instruction data valid / fetch accepted |
| `imem_instr` | Input | 32 | Fetched instruction |
| `dmem_addr` | Output | 32 | Data byte address |
| `dmem_write_data` | Output | 32 | Store write data |
| `dmem_wstrb` | Output | 4 | Store byte enables |
| `dmem_read_en` | Output | 1 | Load request |
| `dmem_write_en` | Output | 1 | Store request |
| `dmem_ready` | Input | 1 | Data access complete |
| `dmem_read_data` | Input | 32 | Load read data |

## Machine CSRs

| CSR | Address | Implemented behavior |
| --- | ---: | --- |
| `mstatus` | `0x300` | Implements `MIE`, `MPIE`, and `MPP` |
| `mie` | `0x304` | Implements writable `MEIE` bit 11 only |
| `mtvec` | `0x305` | Trap vector base; redirects use `{mtvec[31:2], 2'b00}` |
| `mscratch` | `0x340` | Machine scratch register |
| `mepc` | `0x341` | Trap return PC; bits `[1:0]` forced to zero on writes |
| `mcause` | `0x342` | Trap cause |
| `mtval` | `0x343` | Trap value |
| `mip` | `0x344` | Read-only `MEIP` bit 11 mirrors `external_irq` |

| CSR rule | Behavior |
| --- | --- |
| Reset value | Implemented CSRs reset to zero |
| Unimplemented CSR read | Returns zero |
| Unimplemented CSR write | Ignored |
| CSR read result | Old CSR value is written to `rd` |
| `CSRRS` / `CSRRC` zero source | CSR write suppressed |
| `CSRRSI` / `CSRRCI` zero immediate | CSR write suppressed |

## Trap and Exception Support

| Trap condition | `mcause` | `mtval` |
| --- | ---: | --- |
| `EBREAK` | 3 | Faulting PC |
| Load address misaligned | 4 | Effective address |
| Load access fault | 5 | Effective address |
| Store address misaligned | 6 | Effective address |
| Store access fault | 7 | Effective address |
| Machine `ECALL` | 11 | Zero |
| Machine external interrupt | `0x8000000b` | Zero |

| Trap action | Behavior |
| --- | --- |
| Trap entry | Save `mepc`, `mcause`, and `mtval` |
| Interrupt enable save | `mstatus.MPIE <= mstatus.MIE` |
| Interrupt enable clear | `mstatus.MIE <= 0` |
| Previous privilege | `mstatus.MPP <= 2'b11` |
| Trap target | Aligned `mtvec` base |
| `MRET` target | `mepc` |
| `MRET` status restore | `MIE <= MPIE`, `MPIE <= 1`, `MPP <= 2'b00` |

## Zynq Wrapper

| Wrapper feature | Specification |
| --- | --- |
| Wrapper module | `riscv_zynq_wrapper` |
| Instruction BRAM | CPU read-only |
| Data BRAM | CPU read/write |
| BRAM latency handling | `imem_ready` and `dmem_ready` assert after address is stable for one clock |
| AXI-Lite control module | `axi_lite_control` |

## AXI-Lite Control Registers

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x0` | Control | RW | Bit 0 holds CPU in reset when set |
| `0x4` | Status | RO | Bit 0 indicates CPU running |

## Known Limits

| Area | Limit |
| --- | --- |
| Interrupts | External interrupt only; no timer or software interrupts |
| Memory system | No caches, MMU, or PMP |
| Debug | No debug module |
| Illegal instructions | Illegal-instruction trap not implemented |
| Instruction alignment | Instruction address misalignment trap not implemented |
| Trap vector mode | Direct `mtvec` base only; vectored mode not implemented |
| Access faults | Optional for data memory; disabled by default |
