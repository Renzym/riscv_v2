`timescale 1ns/1ps
//
// Standalone Icarus-Verilog testbench for the modular RV32I core (no caches).
//
// The core is connected directly to simple zero-latency instruction/data
// memories (Harvard, 4 KB each). It loads regression_imem.hex / regression_dmem.hex,
// runs the program, then checks the architectural state (registers, data
// memory, CSRs).
//
// The RTL files are passed on the iverilog command line (package first) by
// run_sim.sh / run_sim.ps1 - do NOT `include them here.
//
module riscv_tb;
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

    integer failures;
    integer i;

    // ---- DUT ----
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

    // ---- simple memories (4 KB each, zero-latency) ----
    localparam integer IMEM_WORDS = 1024;
    localparam integer DMEM_WORDS = 1024;
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] dmem [0:DMEM_WORDS-1];

    assign imem_instr     = imem[imem_addr[11:2]];
    assign imem_ready     = 1'b1;
    assign dmem_read_data = dmem[dmem_addr[11:2]];
    assign dmem_ready     = 1'b1;

    always @(posedge clk) begin
        if (dmem_write_en) begin
            if (dmem_wstrb[0]) dmem[dmem_addr[11:2]][7:0]   <= dmem_write_data[7:0];
            if (dmem_wstrb[1]) dmem[dmem_addr[11:2]][15:8]  <= dmem_write_data[15:8];
            if (dmem_wstrb[2]) dmem[dmem_addr[11:2]][23:16] <= dmem_write_data[23:16];
            if (dmem_wstrb[3]) dmem[dmem_addr[11:2]][31:24] <= dmem_write_data[31:24];
        end
    end

    // ---- checks (hierarchical access into the modular core) ----
    task automatic expect_reg(input integer idx, input [31:0] expected);
        begin
            if (core.u_regfile.regs[idx] !== expected) begin
                failures = failures + 1;
                $display("FAIL reg x%0d expected=0x%08h got=0x%08h",
                         idx, expected, core.u_regfile.regs[idx]);
            end
        end
    endtask

    task automatic expect_mem(input integer idx, input [31:0] expected);
        begin
            if (dmem[idx] !== expected) begin
                failures = failures + 1;
                $display("FAIL mem[%0d] expected=0x%08h got=0x%08h",
                         idx, expected, dmem[idx]);
            end
        end
    endtask

    task automatic expect_csr(input [127:0] name, input [31:0] actual, input [31:0] expected);
        begin
            if (actual !== expected) begin
                failures = failures + 1;
                $display("FAIL CSR %0s expected=0x%08h got=0x%08h", name, expected, actual);
            end
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        $dumpfile("riscv_core.vcd");
        $dumpvars(0, riscv_tb);

        failures = 0;
        clk      = 0;
        reset    = 1;

        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h00000013; // NOP fill
        for (i = 0; i < DMEM_WORDS; i = i + 1) dmem[i] = 32'h0;
        $readmemh("regression_imem.hex", imem);
        $readmemh("regression_dmem.hex", dmem);

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (700) @(posedge clk);

        expect_reg(1,  32'h12345000);
        expect_reg(2,  32'h00001004);
        expect_reg(3,  32'd40);
        expect_reg(4,  32'd10);
        expect_reg(5,  32'd320);
        expect_reg(6,  32'd512);
        expect_reg(7,  32'h11223344);
        expect_reg(8,  32'd68);
        expect_reg(9,  32'd51);
        expect_reg(10, 32'd13124);
        expect_reg(11, 32'd4386);
        expect_reg(12, 32'h11223344);
        expect_reg(13, 32'hffffff80);
        expect_reg(14, 32'd128);
        expect_reg(15, 32'hffffff80);
        expect_reg(16, 32'hffffffff);
        expect_reg(17, 32'd65535);
        expect_reg(18, 32'hffffffff);
        expect_reg(19, 32'hffff8044);
        expect_reg(20, 32'd1);
        expect_reg(21, 32'd47);
        expect_reg(22, 32'd9);
        expect_reg(23, 32'd3);
        expect_reg(24, 32'd276);
        expect_reg(25, 32'hffffffff);
        expect_reg(26, 32'd3);
        expect_reg(27, 32'd3);
        expect_reg(28, 32'd1);
        expect_reg(29, 32'd268);
        expect_reg(30, 32'd1);
        expect_reg(31, 32'd276);

        expect_mem(128, 32'hffff8044);
        expect_csr("mtvec",  core.u_csr.csr_mtvec,  32'd320);
        expect_csr("mepc",   core.u_csr.csr_mepc,   32'd276);
        expect_csr("mcause", core.u_csr.csr_mcause, 32'd3);

        if (failures == 0)
            $display("PASS: RV32I regression completed without mismatches.");
        else
            $fatal(1, "RV32I regression failed with %0d mismatches.", failures);

        $finish;
    end

endmodule
