`timescale 1ns/1ps

module riscv_external_irq_tb;
    logic clk;
    logic reset;
    logic external_irq;
    logic [31:0] global_interrupts;

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

    integer failures;
    integer i;

    assign global_interrupts = {31'd0, external_irq};

    riscv_core core (
        .clk(clk),
        .reset(reset),
        .global_interrupts(global_interrupts),
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

    localparam integer IMEM_WORDS = 64;
    logic [31:0] imem [0:IMEM_WORDS-1];

    assign imem_instr     = imem[imem_addr[7:2]];
    assign imem_ready     = 1'b1;
    assign dmem_read_data = 32'd0;
    assign dmem_ready     = 1'b1;

    always #5 clk = ~clk;

    task automatic expect_reg(input integer idx, input [31:0] expected);
        begin
            if (core.u_regfile.regs[idx] !== expected) begin
                failures = failures + 1;
                $display("FAIL reg x%0d expected=0x%08h got=0x%08h",
                         idx, expected, core.u_regfile.regs[idx]);
            end
        end
    endtask

    task automatic expect_mepc_range(input [31:0] actual);
        begin
            if ((actual < 32'h0000_001c) || (actual > 32'h0000_0024) || (actual[1:0] != 2'b00)) begin
                failures = failures + 1;
                $display("FAIL mepc expected aligned PC in [0x1c,0x24], got=0x%08h", actual);
            end
        end
    endtask

    initial begin
        $dumpfile("riscv_external_irq.vcd");
        $dumpvars(0, riscv_external_irq_tb);

        failures = 0;
        clk = 0;
        reset = 1;
        external_irq = 1'b0;

        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'h00000013;

        imem[0]  = 32'h04000093; // addi x1,x0,0x40
        imem[1]  = 32'h30509073; // csrw mtvec,x1
        imem[2]  = 32'h00100113; // addi x2,x0,1 -> enable global_interrupts[0]
        imem[3]  = 32'h00000013; // nop
        imem[4]  = 32'h7c011073; // csrw meimask,x2
        imem[5]  = 32'h00800193; // addi x3,x0,8 (MIE)
        imem[6]  = 32'h30019073; // csrw mstatus,x3
        imem[7]  = 32'h00128293; // addi x5,x5,1
        imem[8]  = 32'h00100313; // addi x6,x0,1
        imem[9]  = 32'hfe000ce3; // beq x0,x0,-8
        imem[16] = 32'h34202573; // csrr x10,mcause
        imem[17] = 32'h341025f3; // csrr x11,mepc
        imem[18] = 32'hfc0026f3; // csrr x13,meipend
        imem[19] = 32'h00160613; // addi x12,x12,1
        imem[20] = 32'h30200073; // mret

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (18) @(posedge clk);
        external_irq = 1'b1;

        wait (core.u_regfile.regs[12] == 32'd1);
        external_irq = 1'b0;

        repeat (40) @(posedge clk);

        expect_reg(10, 32'h8000_000b);
        expect_mepc_range(core.u_regfile.regs[11]);
        expect_reg(12, 32'd1);
        expect_reg(13, 32'h0000_0001);

        if (failures == 0)
            $display("PASS: External interrupt regression completed without mismatches.");
        else
            $fatal(1, "External interrupt regression failed with %0d mismatches.", failures);

        $finish;
    end
endmodule
