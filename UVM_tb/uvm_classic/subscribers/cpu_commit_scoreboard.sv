class cpu_commit_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_commit_scoreboard)

    uvm_tlm_analysis_fifo#(riscv_commit_transaction) checker_fifo;
    
    string spike_log_path;
    integer spike_log_fh;
    uvm_event test_done_event;
    bit ecall_detected = 0;

    riscv_commit_transaction actual_buffer[$];
    riscv_commit_transaction expected_q[$];

    function new(string name = "cpu_commit_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(string)::get(this, "", "SPIKE_LOG", spike_log_path))
           `uvm_fatal(get_type_name(), "Could not get SPIKE_LOG path");
        if(!uvm_config_db#(uvm_event)::get(this, "", "test_done_event", test_done_event))
           `uvm_fatal(get_type_name(), "Could not get test_done_event");
        
        if(!uvm_config_db#(uvm_tlm_analysis_fifo#(riscv_commit_transaction))::get(this, 
            "", "checker_fifo", checker_fifo)) begin
            checker_fifo = new("checker_fifo", this);
        end
    endfunction

    task run_phase(uvm_phase phase);
        riscv_commit_transaction actual_tx;
        
        forever begin
            checker_fifo.get(actual_tx);
            if (ecall_detected) begin
                continue;
            end
            
            if (actual_tx.instr == 32'h00000073) begin
                `uvm_info(get_type_name(), $sformatf("ECALL detected at PC 0x%h", actual_tx.pc), UVM_MEDIUM);
                ecall_detected = 1;
                actual_buffer.delete();
                test_done_event.trigger();
            end else begin
                actual_buffer.push_back(actual_tx);
                if (actual_buffer.size() > 20) begin
                    riscv_commit_transaction tx = actual_buffer.pop_front();
                    check_transaction(tx);
                end
            end
        end
    endtask

    task get_next_expected();
        string spike_line;
        
        if (expected_q.size() > 50) return;

        while(expected_q.size() < 500) begin
            if ($feof(spike_log_fh)) return;
            void'($fgets(spike_line, spike_log_fh));
            process_spike_line_refactored(spike_line);
        end
    endtask

    function void process_spike_line_refactored(string spike_line);
        int match_count;
        riscv_commit_transaction expected_tx;
        bit [31:0] pc_exp, instr_exp, rd_data_exp;
        bit [4:0]  rd_addr_exp;
        bit gpr_write_enable_exp;

        // Try matching execution line (for traps/ebreak)
        match_count = $sscanf(spike_line, "core   0: 0x%h (0x%h)", pc_exp, instr_exp);
        if (match_count == 2) begin
            expected_tx = riscv_commit_transaction::type_id::create("expected_tx");
            expected_tx.pc = pc_exp;
            expected_tx.instr = instr_exp;
            expected_tx.gpr_write_enable = 0;
            expected_q.push_back(expected_tx);
            return;
        end
        
        // Try matching retirement line (to UPDATE the last added transaction if PCs match)
        match_count = $sscanf(spike_line, "core   0: 3 0x%h (0x%h) x%d 0x%h", 
                              pc_exp, instr_exp, rd_addr_exp, rd_data_exp);
        if (match_count == 4) begin
            if (expected_q.size() > 0 && expected_q[expected_q.size()-1].pc == pc_exp) begin
                expected_q[expected_q.size()-1].gpr_write_enable = 1;
                expected_q[expected_q.size()-1].rd_addr = rd_addr_exp;
                expected_q[expected_q.size()-1].rd_data = rd_data_exp;
            end
            return;
        end

        match_count = $sscanf(spike_line, "core   0: 3 0x%h (0x%h)", pc_exp, instr_exp);
        if (match_count == 2) begin
             // Same as above but no GPR write. 
             // We don't really need to do anything since the execution line already added it.
             return;
        end
    endfunction

    task check_transaction(riscv_commit_transaction actual_tx);
        riscv_commit_transaction expected_tx;

        get_next_expected();
        
        if (expected_q.size() == 0) return;
        
        begin
            int found_idx = -1;
            for (int i = 0; i < expected_q.size(); i++) begin
                if (expected_q[i].pc == actual_tx.pc) begin
                    found_idx = i;
                    break;
                end
            end

            if (found_idx != -1) begin
                expected_tx = expected_q[found_idx];
                if (actual_tx.compare(expected_tx)) begin
                    `uvm_info(get_type_name(), $sformatf("PC 0x%h MATCH", actual_tx.pc), UVM_HIGH);
                    for (int i = 0; i <= found_idx; i++) void'(expected_q.pop_front());
                end else begin
                    `uvm_error(get_type_name(), $sformatf("Architectural Mismatch at PC 0x%h!\\nExpected: %s\\nActual:   %s", 
                               actual_tx.pc, expected_tx.sprint(), actual_tx.sprint()));
                    void'(expected_q.pop_front());
                end
            end
        end
    endtask

    function void start_of_simulation_phase(uvm_phase phase);
        spike_log_fh = $fopen(spike_log_path, "r");
        if (spike_log_fh == 0) begin
            `uvm_fatal(get_type_name(), $sformatf("Could not open Spike log: %s", spike_log_path))
        end
        
        begin
            string line;
            bit [31:0] pc;
            int found = 0;
            while(!found && !$feof(spike_log_fh)) begin
                void'($fgets(line, spike_log_fh));
                if ($sscanf(line, "core   0: 3 0x%h", pc) == 1 ||
                    $sscanf(line, "core   0: 0x%h", pc) == 1) begin
                    if (pc == 32'h80000000) found = 1;
                end
            end

            if ($feof(spike_log_fh)) begin
                `uvm_fatal(get_type_name(), "Did not find PC=0x80000000 commit line in Spike log.")
            end

            process_spike_line_refactored(line);
        end
    endfunction

endclass
