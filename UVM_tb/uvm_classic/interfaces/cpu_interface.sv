// uvm_classic/interfaces/cpu_interface.sv
//
// Refactored to eliminate redundant assignments and multiple-driver conflicts

`timescale 1ns / 1ps

interface cpu_interface(input logic clock, input logic rst);
    
    // Fetch signals (used by driver and to request instructions)
    logic [31:0] fetch_instruction;
    logic [31:0] fetch_pc;
    
    // Retirement signals (used by monitor/scoreboard)
    logic [31:0] retire_instruction;
    logic [31:0] retire_pc;
    logic        retire_valid;

    // Memory interface signals
    logic [3:0]  mem_wstrb;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] address;
    logic [31:0] mem_write_data;
    logic [31:0] mem_read_data;

    // Verification signals (retired register write)
    logic        reg_write_o;
    logic [4:0]  rd_o;
    logic [31:0] rf_rd_value_o;

    // Directed interrupt stimulus
    logic        external_irq;

    clocking monitor_cb @(posedge clock);
        default input #1step output #1ps;
        
        input retire_instruction;
        input retire_pc;
        input retire_valid;
        
        input mem_read;
        input mem_write;
        input address;
        input mem_write_data;
        input mem_read_data;
        input reg_write_o;
        input rd_o;
        input rf_rd_value_o;
    endclocking

    clocking driver_cb @(posedge clock);
        default input #1step output #1ps;
        
        output fetch_instruction;
        output external_irq;
        input  fetch_pc;
    endclocking

    modport monitor_mp (
        clocking monitor_cb,
        input rst
    );
    
    modport driver_mp (
        clocking driver_cb,
        input rst,
        input fetch_pc,
        output fetch_instruction,
        output external_irq
    );

endinterface
