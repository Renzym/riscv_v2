`timescale 1ns/1ps

module riscv_alu_m_tb;
    import riscv_pkg::*;

    logic [4:0]  alu_op;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] result;
    integer failures;

    riscv_alu dut (
        .alu_op(alu_op),
        .a(a),
        .b(b),
        .result(result)
    );

    task automatic expect_alu(
        input [4:0] op,
        input [31:0] lhs,
        input [31:0] rhs,
        input [31:0] expected,
        input [127:0] name
    );
        begin
            alu_op = op;
            a = lhs;
            b = rhs;
            #1;
            if (result !== expected) begin
                failures = failures + 1;
                $display("FAIL %0s a=0x%08h b=0x%08h expected=0x%08h got=0x%08h",
                         name, lhs, rhs, expected, result);
            end
        end
    endtask

    initial begin
        failures = 0;

        expect_alu(ALU_MUL,    32'hffff_ffff, 32'd2,         32'hffff_fffe, "MUL");
        expect_alu(ALU_MULH,   32'hffff_fffe, 32'd3,         32'hffff_ffff, "MULH");
        expect_alu(ALU_MULHSU, 32'hffff_fffe, 32'd3,         32'hffff_ffff, "MULHSU");
        expect_alu(ALU_MULHU,  32'hffff_fffe, 32'd2,         32'h0000_0001, "MULHU");
        expect_alu(ALU_DIV,    32'hffff_fff9, 32'd3,         32'hffff_fffe, "DIV");
        expect_alu(ALU_DIVU,   32'hffff_fffe, 32'd2,         32'h7fff_ffff, "DIVU");
        expect_alu(ALU_REM,    32'hffff_fff9, 32'd3,         32'hffff_ffff, "REM");
        expect_alu(ALU_REMU,   32'hffff_fffe, 32'd2,         32'h0000_0000, "REMU");

        expect_alu(ALU_DIV,    32'h1234_5678, 32'd0,         32'hffff_ffff, "DIV_ZERO");
        expect_alu(ALU_DIVU,   32'h1234_5678, 32'd0,         32'hffff_ffff, "DIVU_ZERO");
        expect_alu(ALU_REM,    32'h1234_5678, 32'd0,         32'h1234_5678, "REM_ZERO");
        expect_alu(ALU_REMU,   32'h1234_5678, 32'd0,         32'h1234_5678, "REMU_ZERO");
        expect_alu(ALU_DIV,    32'h8000_0000, 32'hffff_ffff, 32'h8000_0000, "DIV_OVERFLOW");
        expect_alu(ALU_REM,    32'h8000_0000, 32'hffff_ffff, 32'h0000_0000, "REM_OVERFLOW");

        if (failures == 0)
            $display("PASS: RV32M ALU operations completed without mismatches.");
        else
            $fatal(1, "RV32M ALU operations failed with %0d mismatches.", failures);

        $finish;
    end
endmodule
