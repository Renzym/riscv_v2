// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2025 Igor Bogdanov
// All rights reserved.
//
// Modified by Renzym Private limited in 2026.

class cpu_flow_predictor extends uvm_component;
    `uvm_component_utils(cpu_flow_predictor)

    uvm_analysis_imp #(riscv_flow_transaction, cpu_flow_predictor) item_from_monitor_port;
    
    uvm_analysis_port #(riscv_flow_transaction) predicted_item_port;

    logic [31:0] instr_mem[bit[31:0]];
    string mem_init_file;
    string spike_log_path;
    integer spike_log_fh;
    
    bit [31:0] expected_pc_q[$];
    int trace_ptr = 0;

    function new(string name = "cpu_flow_predictor", uvm_component parent = null);
        super.new(name, parent);
        item_from_monitor_port = new("item_from_monitor_port", this);
        predicted_item_port = new("predicted_item_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(string)::get(this, "", "MEM_FILE", mem_init_file)) begin
            `uvm_fatal(get_type_name(), "Memory init file not provided via config_db")
        end
        if(!uvm_config_db#(string)::get(this, "", "SPIKE_LOG", spike_log_path))
           `uvm_fatal(get_type_name(), "Could not get SPIKE_LOG path");
    endfunction
    
    task automatic run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Loading instruction memory for predictor from file: %s", mem_init_file), UVM_MEDIUM)
        $readmemb(mem_init_file, instr_mem);
        
        spike_log_fh = $fopen(spike_log_path, "r");
        if (spike_log_fh == 0) begin
            `uvm_fatal(get_type_name(), $sformatf("Could not open Spike log: %s", spike_log_path))
        end
        
        // Pre-fill the expected PC queue from Spike log
        begin
            string line;
            bit [31:0] pc;
            while (!$feof(spike_log_fh)) begin
                void'($fgets(line, spike_log_fh));
                // Match standard execution lines: core   0: 0x80000108
                // We ignore retirement lines (starting with '3') to avoid duplicates,
                // as every retired instruction first has an execution line.
                // Traps also have execution lines but no retirement lines.
                if ($sscanf(line, "core   0: 0x%h", pc) == 1) begin
                    expected_pc_q.push_back(pc);
                end
            end
        end
        $fclose(spike_log_fh);
        
        `uvm_info(get_type_name(), $sformatf("Loaded %0d expected PCs from Spike log", expected_pc_q.size()), UVM_MEDIUM)
    endtask

    virtual function automatic void write(riscv_flow_transaction tx);
        riscv_flow_transaction predicted_tx;
        bit [31:0] word_addr;

        // If current instruction is ECALL, stop predicting flow
        word_addr = (tx.current_pc - 32'h80000000) >> 2;
        if (instr_mem.exists(word_addr) && instr_mem[word_addr] == 32'h00000073) begin
            return;
        end
        
        // Find matching PC in trace, starting from current pointer
        while (trace_ptr < expected_pc_q.size() && expected_pc_q[trace_ptr] != tx.current_pc) begin
            trace_ptr++;
        end

        if (trace_ptr >= expected_pc_q.size() - 1) begin
             return;
        end
        
        predicted_tx = riscv_flow_transaction::type_id::create("predicted_tx");
        predicted_tx.current_pc = tx.current_pc;
        predicted_tx.next_pc = expected_pc_q[trace_ptr + 1];
        
        trace_ptr++;

        `uvm_info(get_type_name(), $sformatf("Predicted FLOW tx: %s", predicted_tx.sprint()), UVM_HIGH)
        predicted_item_port.write(predicted_tx);
    endfunction

endclass
