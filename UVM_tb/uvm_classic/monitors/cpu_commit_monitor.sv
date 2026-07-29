class cpu_commit_monitor extends uvm_monitor;

    `uvm_component_utils(cpu_commit_monitor)

    riscv_dut_config cfg;
    virtual cpu_interface vif;

    uvm_analysis_port#(riscv_commit_transaction) item_collected_port;
    
    // Local instruction memory for robust lookup
    logic [31:0] instr_mem[bit[31:0]];
    bit mem_loaded = 0;

    function new(string name = "cpu_commit_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(riscv_dut_config)::get(this, "", "cfg", cfg))
           `uvm_fatal(get_type_name(), "Could not get configuration object");
        vif = cfg.monitor_vif;
    endfunction

    task run_phase(uvm_phase phase);
        // Load instruction memory if not already done
        if (!mem_loaded && cfg.mem_file_path != "") begin
            `uvm_info(get_type_name(), $sformatf("Loading instruction memory for lookup from: %s", cfg.mem_file_path), UVM_MEDIUM)
            $readmemb(cfg.mem_file_path, instr_mem);
            mem_loaded = 1;
        end

        forever begin
            @(vif.monitor_cb);
            
            // Only process if reset is inactive and an instruction is actually retiring
            if (!vif.rst && vif.monitor_cb.retire_valid) begin
                riscv_commit_transaction tx;
                bit [31:0] word_addr;
                
                tx = riscv_commit_transaction::type_id::create("tx");
                
                tx.pc = vif.monitor_cb.retire_pc;
                
                // Robust instruction lookup by PC
                word_addr = (tx.pc - 32'h80000000) >> 2;
                if (instr_mem.exists(word_addr)) begin
                    tx.instr = instr_mem[word_addr];
                end else begin
                    // Fallback to interface signal if not found in memory (e.g. for dynamic code)
                    tx.instr = vif.monitor_cb.retire_instruction;
                    if (tx.instr == 0) begin
                        `uvm_warning(get_type_name(), $sformatf("PC 0x%h not found in memory and retire_instruction is 0", tx.pc))
                    end
                end
                
                if (vif.monitor_cb.reg_write_o) begin
                    tx.gpr_write_enable = 1;
                    tx.rd_addr = vif.monitor_cb.rd_o;
                    tx.rd_data = vif.monitor_cb.rf_rd_value_o;
                end else begin
                    tx.gpr_write_enable = 0;
                    tx.rd_addr = 0;
                    tx.rd_data = 0;
                end
                
                if (tx.rd_addr == 0) begin
                    tx.gpr_write_enable = 0;
                    tx.rd_data = 0;
                end

                `uvm_info(get_type_name(), $sformatf("Instruction Retired: PC=0x%h, INSTR=0x%h", tx.pc, tx.instr), UVM_HIGH)
                item_collected_port.write(tx);
            end
        end
    endtask

endclass
