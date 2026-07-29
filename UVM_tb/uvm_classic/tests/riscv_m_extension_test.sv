class riscv_m_extension_test extends uvm_test;

    `uvm_component_utils(riscv_m_extension_test)

    virtual cpu_interface vif;
    bit seen[32];

    function new(string name = "riscv_m_extension_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual cpu_interface)::get(this, "*", "driver_vif", vif))
            `uvm_fatal(get_type_name(), "Virtual interface not found")
    endfunction

    function automatic bit is_expected_m_result(input logic [4:0] rd);
        return (rd >= 5'd10) && (rd <= 5'd23);
    endfunction

    function automatic logic [31:0] expected_value(input logic [4:0] rd);
        case (rd)
            5'd10: return 32'hffff_fffe; // MUL:    -1 * 2, low word
            5'd11: return 32'hffff_ffff; // MULH:   high signed(-2 * 3)
            5'd12: return 32'hffff_ffff; // MULHSU: high signed(-2) * unsigned(3)
            5'd13: return 32'h0000_0001; // MULHU:  high unsigned(0xffff_fffe * 2)
            5'd14: return 32'hffff_fffe; // DIV:    -7 / 3
            5'd15: return 32'h7fff_ffff; // DIVU:   0xffff_fffe / 2
            5'd16: return 32'hffff_ffff; // REM:    -7 % 3
            5'd17: return 32'h0000_0000; // REMU:   0xffff_fffe % 2
            5'd18: return 32'hffff_ffff; // DIV by zero
            5'd19: return 32'hffff_ffff; // DIVU by zero
            5'd20: return 32'h1234_5678; // REM by zero
            5'd21: return 32'h1234_5678; // REMU by zero
            5'd22: return 32'h8000_0000; // DIV overflow: 0x80000000 / -1
            5'd23: return 32'h0000_0000; // REM overflow: 0x80000000 % -1
            default: return 32'hxxxx_xxxx;
        endcase
    endfunction

    function automatic string result_name(input logic [4:0] rd);
        case (rd)
            5'd10: return "MUL";
            5'd11: return "MULH";
            5'd12: return "MULHSU";
            5'd13: return "MULHU";
            5'd14: return "DIV";
            5'd15: return "DIVU";
            5'd16: return "REM";
            5'd17: return "REMU";
            5'd18: return "DIV_ZERO";
            5'd19: return "DIVU_ZERO";
            5'd20: return "REM_ZERO";
            5'd21: return "REMU_ZERO";
            5'd22: return "DIV_OVERFLOW";
            5'd23: return "REM_OVERFLOW";
            default: return "UNKNOWN";
        endcase
    endfunction

    function automatic bit all_seen();
        for (int rd = 10; rd <= 23; rd++) begin
            if (!seen[rd]) return 1'b0;
        end
        return 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting directed RV32M UVM test");

        vif.external_irq = 1'b0;
        wait (!vif.rst);

        fork
            begin : monitor_writes
                forever begin
                    @(vif.monitor_cb);
                    if (!vif.rst && vif.monitor_cb.reg_write_o &&
                        is_expected_m_result(vif.monitor_cb.rd_o)) begin
                        logic [31:0] expected;
                        expected = expected_value(vif.monitor_cb.rd_o);
                        seen[vif.monitor_cb.rd_o] = 1'b1;

                        if (vif.monitor_cb.rf_rd_value_o !== expected) begin
                            `uvm_error(get_type_name(),
                                $sformatf("%s mismatch on x%0d: expected 0x%08h got 0x%08h",
                                          result_name(vif.monitor_cb.rd_o),
                                          vif.monitor_cb.rd_o,
                                          expected,
                                          vif.monitor_cb.rf_rd_value_o))
                        end else begin
                            `uvm_info(get_type_name(),
                                $sformatf("%s matched on x%0d = 0x%08h",
                                          result_name(vif.monitor_cb.rd_o),
                                          vif.monitor_cb.rd_o,
                                          vif.monitor_cb.rf_rd_value_o),
                                UVM_MEDIUM)
                        end

                        if (all_seen()) break;
                    end
                end
            end
            begin : timeout
                repeat (300) @(posedge vif.clock);
                `uvm_fatal(get_type_name(), "Timed out waiting for all RV32M result writes")
            end
        join_any
        disable fork;

        if (!all_seen())
            `uvm_fatal(get_type_name(), "Missing one or more expected RV32M result writes")

        repeat (20) @(posedge vif.clock);
        phase.drop_objection(this, "Directed RV32M UVM test complete");
    endtask

endclass
