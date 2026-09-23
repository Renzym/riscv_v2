// SPDX-License-Identifier: MIT
//
// Copyright (c) 2026 Renzym Private limited

class riscv_external_irq_test extends uvm_test;

    `uvm_component_utils(riscv_external_irq_test)

    virtual cpu_interface vif;

    function new(string name = "riscv_external_irq_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual cpu_interface)::get(this, "*", "driver_vif", vif))
            `uvm_fatal(get_type_name(), "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        bit got_mcause;
        bit got_mepc;
        bit got_meipend;
        bit got_handler_count;
        logic [31:0] mepc_seen;

        phase.raise_objection(this, "Starting directed external interrupt UVM test");

        vif.external_irq = 1'b0;
        wait (!vif.rst);

        repeat (30) @(posedge vif.clock);
        `uvm_info(get_type_name(), "Asserting external_irq", UVM_MEDIUM)
        vif.external_irq = 1'b1;

        fork
            begin : monitor_writes
                forever begin
                    @(vif.monitor_cb);
                    if (!vif.rst && vif.monitor_cb.reg_write_o) begin
                        case (vif.monitor_cb.rd_o)
                            5'd10: begin
                                got_mcause = 1'b1;
                                if (vif.monitor_cb.rf_rd_value_o !== 32'h8000_000b)
                                    `uvm_error(get_type_name(), $sformatf("mcause mismatch: got 0x%08h", vif.monitor_cb.rf_rd_value_o))
                            end
                            5'd11: begin
                                got_mepc = 1'b1;
                                mepc_seen = vif.monitor_cb.rf_rd_value_o;
                                if ((mepc_seen < 32'h8000_0020) || (mepc_seen > 32'h8000_0028) || (mepc_seen[1:0] != 2'b00))
                                    `uvm_error(get_type_name(), $sformatf("mepc not in expected loop range: got 0x%08h", mepc_seen))
                            end
                            5'd13: begin
                                got_meipend = 1'b1;
                                if (vif.monitor_cb.rf_rd_value_o !== 32'h0000_0001)
                                    `uvm_error(get_type_name(), $sformatf("meipend mismatch: got 0x%08h", vif.monitor_cb.rf_rd_value_o))
                            end
                            5'd12: begin
                                got_handler_count = 1'b1;
                                if (vif.monitor_cb.rf_rd_value_o !== 32'd1)
                                    `uvm_error(get_type_name(), $sformatf("handler count mismatch: got 0x%08h", vif.monitor_cb.rf_rd_value_o))
                                vif.external_irq = 1'b0;
                            end
                            default: begin end
                        endcase

                        if (got_mcause && got_mepc && got_meipend && got_handler_count)
                            break;
                    end
                end
            end
            begin : timeout
                repeat (300) @(posedge vif.clock);
                `uvm_fatal(get_type_name(), "Timed out waiting for external interrupt handler observations")
            end
        join_any
        disable fork;

        if (!(got_mcause && got_mepc && got_meipend && got_handler_count))
            `uvm_fatal(get_type_name(), "Missing one or more expected interrupt handler observations")

        repeat (20) @(posedge vif.clock);
        phase.drop_objection(this, "Directed external interrupt UVM test complete");
    endtask

endclass
