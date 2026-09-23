// SPDX-License-Identifier: MIT
//
// Copyright (c) 2026 Renzym Private limited

// ============================================================================
// riscv_alu.sv  -  combinational arithmetic/logic unit (EX stage)
// ============================================================================
`ifndef RISCV_ALU_SV
`define RISCV_ALU_SV

`timescale 1ns/1ps

module riscv_alu (
    input  logic [4:0]  alu_op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    import riscv_pkg::*;

    always_comb begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:  result = a ^ b;
            ALU_OR:   result = a | b;
            ALU_AND:  result = a & b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            // RV32M operations are completed by multicycle units in riscv_core.
            ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU,
            ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU: result = 32'd0;
            default:  result = b;                  // ALU_COPY_B (LUI)
        endcase
    end

endmodule

`endif
