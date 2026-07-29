// ============================================================================
// riscv_pkg.sv
// Shared constants for the RV32IM core: opcodes, ALU ops, writeback selects,
// branch kinds, and CSR addresses. Imported by every core module.
// ============================================================================
`ifndef RISCV_PKG_SV
`define RISCV_PKG_SV

`timescale 1ns/1ps

package riscv_pkg;

    // ---- opcodes (instr[6:0]) ----
    localparam logic [6:0] OPCODE_LUI      = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPCODE_JAL      = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR     = 7'b1100111;
    localparam logic [6:0] OPCODE_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPCODE_LOAD     = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE    = 7'b0100011;
    localparam logic [6:0] OPCODE_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPCODE_OP       = 7'b0110011;
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OPCODE_SYSTEM   = 7'b1110011;

    // ---- ALU operations ----
    localparam logic [4:0] ALU_ADD    = 5'd0;
    localparam logic [4:0] ALU_SUB    = 5'd1;
    localparam logic [4:0] ALU_SLT    = 5'd2;
    localparam logic [4:0] ALU_SLTU   = 5'd3;
    localparam logic [4:0] ALU_XOR    = 5'd4;
    localparam logic [4:0] ALU_OR     = 5'd5;
    localparam logic [4:0] ALU_AND    = 5'd6;
    localparam logic [4:0] ALU_SLL    = 5'd7;
    localparam logic [4:0] ALU_SRL    = 5'd8;
    localparam logic [4:0] ALU_SRA    = 5'd9;
    localparam logic [4:0] ALU_COPY_B = 5'd10;
    localparam logic [4:0] ALU_MUL    = 5'd11;
    localparam logic [4:0] ALU_MULH   = 5'd12;
    localparam logic [4:0] ALU_MULHSU = 5'd13;
    localparam logic [4:0] ALU_MULHU  = 5'd14;
    localparam logic [4:0] ALU_DIV    = 5'd15;
    localparam logic [4:0] ALU_DIVU   = 5'd16;
    localparam logic [4:0] ALU_REM    = 5'd17;
    localparam logic [4:0] ALU_REMU   = 5'd18;

    // ---- writeback source select ----
    localparam logic [1:0] WB_ALU  = 2'd0;
    localparam logic [1:0] WB_LOAD = 2'd1;
    localparam logic [1:0] WB_PC4  = 2'd2;
    localparam logic [1:0] WB_CSR  = 2'd3;

    // ---- branch kinds ----
    localparam logic [2:0] BR_NONE = 3'd0;
    localparam logic [2:0] BR_EQ   = 3'd1;
    localparam logic [2:0] BR_NE   = 3'd2;
    localparam logic [2:0] BR_LT   = 3'd3;
    localparam logic [2:0] BR_GE   = 3'd4;
    localparam logic [2:0] BR_LTU  = 3'd5;
    localparam logic [2:0] BR_GEU  = 3'd6;

    // ---- implemented CSR addresses (machine mode) ----
    localparam logic [11:0] CSR_MSTATUS  = 12'h300;
    localparam logic [11:0] CSR_MIE      = 12'h304;
    localparam logic [11:0] CSR_MTVEC    = 12'h305;
    localparam logic [11:0] CSR_MSCRATCH = 12'h340;
    localparam logic [11:0] CSR_MEPC     = 12'h341;
    localparam logic [11:0] CSR_MCAUSE   = 12'h342;
    localparam logic [11:0] CSR_MTVAL    = 12'h343;
    localparam logic [11:0] CSR_MIP      = 12'h344;
    localparam logic [11:0] CSR_MEIMASK  = 12'h7c0; // ORCA external interrupt mask
    localparam logic [11:0] CSR_MEIPEND  = 12'hfc0; // ORCA external interrupt pending

    // ---- trap causes ----
    localparam logic [31:0] CAUSE_BREAKPOINT      = 32'd3;
    localparam logic [31:0] CAUSE_LOAD_MISALIGNED = 32'd4;
    localparam logic [31:0] CAUSE_LOAD_ACCESS     = 32'd5;
    localparam logic [31:0] CAUSE_STORE_MISALIGNED= 32'd6;
    localparam logic [31:0] CAUSE_STORE_ACCESS    = 32'd7;
    localparam logic [31:0] CAUSE_ECALL_M         = 32'd11;
    localparam logic [31:0] CAUSE_MACHINE_EXTERNAL_INTERRUPT = 32'h8000_000b;

    // ---- machine interrupt CSR bits ----
    localparam int unsigned MSTATUS_MIE_BIT = 3;
    localparam int unsigned MSTATUS_MPIE_BIT = 7;
    localparam int unsigned MIE_MEIE_BIT = 11;
    localparam int unsigned MIP_MEIP_BIT = 11;

endpackage

`endif
