`timescale 1ns/1ps

module riscv_m_extension_tb;
    logic clk;
    logic reset;
    logic        imem_req;
    logic [31:0] imem_addr;
    logic        imem_ready;
    logic [31:0] imem_instr;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_write_data;
    logic [3:0]  dmem_wstrb;
    logic        dmem_read_en;
    logic        dmem_write_en;
    logic        dmem_ready;
    logic [31:0] dmem_read_data;

    logic [31:0] imem [0:63];
    integer failures;
    integer i;
    integer div_busy_cycles;
    logic   div_busy_q;

    riscv_core core (
        .clk(clk),
        .reset(reset),
        .global_interrupts(32'd0),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ready(imem_ready),
        .imem_instr(imem_instr),
        .imem_resp_pc(imem_addr),
        .imem_resp_accept(),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_write_data),
        .dmem_wstrb(dmem_wstrb),
        .dmem_read_en(dmem_read_en),
        .dmem_write_en(dmem_write_en),
        .dmem_ready(dmem_ready),
        .dmem_read_data(dmem_read_data)
    );

    assign imem_instr     = imem[imem_addr[7:2]];
    assign imem_ready     = 1'b1;
    assign dmem_ready     = 1'b1;
    assign dmem_read_data = 32'd0;

    always #5 clk = ~clk;

    // Normal divide/remainder operations must spend one cycle per quotient bit.
    // Divide-by-zero and signed-overflow never assert div_busy by design.
    always @(posedge clk) begin
        if (reset) begin
            div_busy_cycles <= 0;
            div_busy_q      <= 1'b0;
        end else begin
            if (core.div_busy)
                div_busy_cycles <= div_busy_cycles + 1;

            if (div_busy_q && !core.div_busy) begin
                if (div_busy_cycles != 32) begin
                    failures = failures + 1;
                    $display("FAIL divider latency expected=32 got=%0d", div_busy_cycles);
                end
                div_busy_cycles <= 0;
            end
            div_busy_q <= core.div_busy;
        end
    end

    task automatic expect_reg(input integer idx, input logic [31:0] expected);
        begin
            if (core.u_regfile.regs[idx] !== expected) begin
                failures = failures + 1;
                $display("FAIL x%0d expected=0x%08h got=0x%08h",
                         idx, expected, core.u_regfile.regs[idx]);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        failures = 0;

        for (i = 0; i < 64; i = i + 1)
            imem[i] = 32'h0000_0013;
        $readmemb("../UVM_tb/tb_mem/m_extension_imem.mem", imem, 0, 22);

        repeat (2) @(posedge clk);
        reset = 1'b0;
        repeat (260) @(posedge clk);

        expect_reg(10, 32'hffff_fffe);
        expect_reg(11, 32'hffff_ffff);
        expect_reg(12, 32'hffff_ffff);
        expect_reg(13, 32'h0000_0001);
        expect_reg(14, 32'hffff_fffe);
        expect_reg(15, 32'h7fff_ffff);
        expect_reg(16, 32'hffff_ffff);
        expect_reg(17, 32'h0000_0000);
        expect_reg(18, 32'hffff_ffff);
        expect_reg(19, 32'hffff_ffff);
        expect_reg(20, 32'h1234_5678);
        expect_reg(21, 32'h1234_5678);
        expect_reg(22, 32'h8000_0000);
        expect_reg(23, 32'h0000_0000);

        if (failures == 0)
            $display("PASS: RV32M multicycle regression completed without mismatches.");
        else
            $fatal(1, "RV32M regression failed with %0d mismatches.", failures);
        $finish;
    end
endmodule
