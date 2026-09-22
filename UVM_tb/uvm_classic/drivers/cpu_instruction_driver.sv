// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2025 Igor Bogdanov
// All rights reserved.
//
// Modified by Renzym Private limited in 2026.

// uvm_classic/drivers/cpu_instruction_driver.sv
//
// Robust driver with precise timing to ensure correct instruction sampling

class cpu_instruction_driver extends uvm_driver#(riscv_instruction_transaction);
    `uvm_component_utils(cpu_instruction_driver)

    riscv_dut_config cfg;
    logic [31:0] instruction_memory[bit[31:0]];
    bit memory_loaded = 0;

    function new(string name = "cpu_instruction_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(riscv_dut_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("DRIVER", "Failed to get configuration object")
    endfunction

    task run_phase(uvm_phase phase);
        // Instruction driving is now handled by the Hardware Instruction Memory model in uvm_top.sv
        // This driver now acts in a passive/monitoring mode for instruction bits if needed,
        // but it will no longer drive the fetch_instruction signal to avoid conflicts.
        
        `uvm_info("DRIVER", "Instruction driving is DISABLED (Handled by Hardware Model)", UVM_LOW)

        fork
            // Transaction Receiver - Keep this to avoid sequence hanging
            forever begin
                riscv_instruction_transaction txn;
                seq_item_port.get_next_item(txn);
                // We still update the local memory just in case other components use it,
                // but we don't drive the interface.
                instruction_memory[txn.pc_address] = txn.instruction;
                seq_item_port.item_done();
                memory_loaded = 1;
            end
        join_none
    endtask

endclass
