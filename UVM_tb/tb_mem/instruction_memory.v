// SPDX-License-Identifier: Apache-2.0
//
// Author: Igor Bogdanov
//
// Modified by Renzym Private limited in 2026.

// instruction_memory.v
// Read-only memory for instructions, initialized via $readmemb

`timescale 1ns / 1ps

module instruction_memory(
    input [31:0] address,
    output [31:0] instruction
);

    reg [31:0] memory [0:16383]; // 64KB Instruction Memory
    
    // Asynchronous read (Instruction memory is typically combinational or latched in simple cores)
    // Adjust address for word alignment (starting at 0x8000_0000)
    assign instruction = memory[(address - 32'h8000_0000) >> 2];

    initial begin
        // The memory will be loaded from uvm_top or via a plusarg task
        // We initialize with NOPs
        for (integer i = 0; i < 16384; i = i + 1) begin
            memory[i] = 32'h00000013;
        end
    end

    // Task to load memory from outside (e.g., from uvm_top)
    task load_memory(input string filename);
        begin
            $display("[IMEM] Loading memory from file: %s", filename);
            $readmemb(filename, memory);
        end
    endtask
    
endmodule
