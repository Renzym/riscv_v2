// SPDX-License-Identifier: MIT
//
// Copyright (c) 2026 Renzym Private limited

// ============================================================================
// riscv_regfile.sv  -  32x32 integer register file
//   * x0 is hard-wired to 0
//   * synchronous write (WB stage)
//   * combinational read with write-first bypass, so an instruction in decode
//     sees a value being written back in the same cycle.
// ============================================================================
`ifndef RISCV_REGFILE_SV
`define RISCV_REGFILE_SV

`timescale 1ns/1ps

module riscv_regfile (
    input  logic        clk,
    input  logic        reset,

    // write port (from writeback)
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,

    // read ports (decode)
    input  logic [4:0]  raddr1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
);
    logic [31:0] regs [0:31];
    integer i;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            if (we && (waddr != 5'd0))
                regs[waddr] <= wdata;
            regs[0] <= 32'd0;
        end
    end

    // write-first bypass + x0 = 0
    always_comb begin
        if (raddr1 == 5'd0)
            rdata1 = 32'd0;
        else if (we && (waddr != 5'd0) && (waddr == raddr1))
            rdata1 = wdata;
        else
            rdata1 = regs[raddr1];

        if (raddr2 == 5'd0)
            rdata2 = 32'd0;
        else if (we && (waddr != 5'd0) && (waddr == raddr2))
            rdata2 = wdata;
        else
            rdata2 = regs[raddr2];
    end

endmodule

`endif
