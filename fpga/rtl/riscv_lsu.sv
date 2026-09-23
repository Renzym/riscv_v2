// SPDX-License-Identifier: MIT
//
// Copyright (c) 2026 Renzym Private limited

// ============================================================================
// riscv_lsu.sv  -  load/store data formatting (MEM stage), combinational
//   * builds dmem_write_data + byte strobes for SB/SH/SW
//   * sign/zero-extends loaded data for LB/LH/LW/LBU/LHU
// ============================================================================
`ifndef RISCV_LSU_SV
`define RISCV_LSU_SV

`timescale 1ns/1ps

module riscv_lsu (
    input  logic [1:0]  mem_size,      // 0=byte, 1=half, 2=word
    input  logic        mem_unsigned,
    input  logic [1:0]  addr_lo,       // byte offset within word (addr[1:0])
    input  logic        write_en,
    input  logic [31:0] store_data,    // raw rs2 value to store
    input  logic [31:0] read_data,     // raw word from data memory

    output logic [31:0] write_data,    // aligned store data to memory
    output logic [3:0]  wstrb,         // byte write strobes
    output logic [31:0] load_data      // extended load result
);
    // ---- store: align data + strobes ----
    always_comb begin
        write_data = 32'd0;
        wstrb      = 4'b0000;
        case (mem_size)
            2'd0: begin
                write_data = {4{store_data[7:0]}} << (8 * addr_lo);
                wstrb      = 4'b0001 << addr_lo;
            end
            2'd1: begin
                write_data = {2{store_data[15:0]}} << (16 * addr_lo[1]);
                wstrb      = addr_lo[1] ? 4'b1100 : 4'b0011;
            end
            default: begin
                write_data = store_data;
                wstrb      = 4'b1111;
            end
        endcase

        if (!write_en) begin
            write_data = 32'd0;
            wstrb      = 4'b0000;
        end
    end

    // ---- load: extract + extend ----
    always_comb begin
        load_data = read_data;
        case (mem_size)
            2'd0: begin
                case (addr_lo)
                    2'd0: load_data = mem_unsigned ? {24'd0, read_data[7:0]}   : {{24{read_data[7]}},  read_data[7:0]};
                    2'd1: load_data = mem_unsigned ? {24'd0, read_data[15:8]}  : {{24{read_data[15]}}, read_data[15:8]};
                    2'd2: load_data = mem_unsigned ? {24'd0, read_data[23:16]} : {{24{read_data[23]}}, read_data[23:16]};
                    default: load_data = mem_unsigned ? {24'd0, read_data[31:24]} : {{24{read_data[31]}}, read_data[31:24]};
                endcase
            end
            2'd1: begin
                if (addr_lo[1])
                    load_data = mem_unsigned ? {16'd0, read_data[31:16]} : {{16{read_data[31]}}, read_data[31:16]};
                else
                    load_data = mem_unsigned ? {16'd0, read_data[15:0]}  : {{16{read_data[15]}}, read_data[15:0]};
            end
            default: load_data = read_data;
        endcase
    end

endmodule

`endif
