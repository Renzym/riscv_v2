`timescale 1ns/1ps
`include "uvm_macros.svh"

module uvm_top;
    import uvm_pkg::*;
    import riscv_uvm_pkg::*;

    logic clock;
    logic rst;
    
    cpu_interface cpu_if_inst(clock, rst);

    // Hardware Model for Instruction Memory
    instruction_memory imem (
        .address(cpu_if_inst.fetch_pc),
        .instruction(cpu_if_inst.fetch_instruction)
    );

    data_memory data_mem (
        .mem_read(cpu_if_inst.mem_read),
        .mem_write(cpu_if_inst.mem_write),
        .wstrb(cpu_if_inst.mem_wstrb),
        .address(cpu_if_inst.address),
        .write_data(cpu_if_inst.mem_write_data),
        .read_data(cpu_if_inst.mem_read_data),
        .clk(clock),
        .rst(rst)
    );

    string mem_file;
    initial begin
        $display("[UVM_TOP] Hardware Instruction Memory model is ACTIVE");
        if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
            imem.load_memory(mem_file);
        end else begin
            $display("[UVM_TOP] WARNING: No MEM_FILE plusarg provided. IMEM will contain NOPs.");
        end
    end

    cpu_top dut (
        .clock(clock),
        .rst(rst),
        .external_irq(cpu_if_inst.external_irq),
        // Connect to fetch signals in interface
        .instruction(cpu_if_inst.fetch_instruction),
        .current_PC(cpu_if_inst.fetch_pc),
        
        .mem_read(cpu_if_inst.mem_read),
        .mem_write(cpu_if_inst.mem_write),
        .mem_wstrb(cpu_if_inst.mem_wstrb),
        .address(cpu_if_inst.address),
        .mem_write_data(cpu_if_inst.mem_write_data),
        .mem_read_data(cpu_if_inst.mem_read_data),
        .reg_write_o(cpu_if_inst.reg_write_o),
        .rd_o(cpu_if_inst.rd_o),
        .rf_rd_value_o(cpu_if_inst.rf_rd_value_o),
        
        // Connect to retirement signals in interface
        .retired_pc(cpu_if_inst.retire_pc),
        .retired_instr(cpu_if_inst.retire_instruction),
        .retired_valid(cpu_if_inst.retire_valid)
    );

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    initial begin
        rst = 1;
        cpu_if_inst.external_irq = 1'b0;
        #22;
        rst = 0;
    end

    initial begin
        uvm_config_db#(virtual cpu_interface)::set(null, "uvm_test_top.*", "monitor_vif", cpu_if_inst);
        uvm_config_db#(virtual cpu_interface)::set(null, "uvm_test_top.*", "driver_vif", cpu_if_inst);
        
        run_test(); 
    end

    always @(posedge clock) begin
        if (!rst && cpu_if_inst.retire_valid && cpu_if_inst.retire_instruction == 32'h00000073) begin
            $display("ECALL instruction detected at PC=0x%h. Test will complete via UVM.", cpu_if_inst.retire_pc);
        end
    end

endmodule
