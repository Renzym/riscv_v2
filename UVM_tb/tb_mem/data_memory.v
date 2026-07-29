// data_memory.v
// Behavioral memory model with byte-strobe support

`timescale 1ns / 1ps

module data_memory(
    input clk,
    input rst,
    input mem_read,
    input mem_write,
    input [3:0] wstrb,
    input [31:0] address,
    input [31:0] write_data,
    output [31:0] read_data
);

    reg [31:0] memory [0:16383]; // 64KB Memory
    integer i;

    // Word-aligned read
    assign read_data = memory[address[15:2]];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialization handled by UVM if needed, or leave as is
        end else if (mem_write) begin
            if (wstrb[0]) memory[address[15:2]][7:0]   <= write_data[7:0];
            if (wstrb[1]) memory[address[15:2]][15:8]  <= write_data[15:8];
            if (wstrb[2]) memory[address[15:2]][23:16] <= write_data[23:16];
            if (wstrb[3]) memory[address[15:2]][31:24] <= write_data[31:24];
        end
    end
    
endmodule
