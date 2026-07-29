`timescale 1ns/1ps

module riscv_zynq_wrapper_tb;
    localparam int ADDR_WIDTH = 10;

    logic clk;
    logic aresetn;
    logic [31:0] global_interrupts;

    logic [3:0]  s_axi_ctrl_awaddr;
    logic [2:0]  s_axi_ctrl_awprot;
    logic        s_axi_ctrl_awvalid;
    logic        s_axi_ctrl_awready;
    logic [31:0] s_axi_ctrl_wdata;
    logic [3:0]  s_axi_ctrl_wstrb;
    logic        s_axi_ctrl_wvalid;
    logic        s_axi_ctrl_wready;
    logic [1:0]  s_axi_ctrl_bresp;
    logic        s_axi_ctrl_bvalid;
    logic        s_axi_ctrl_bready;
    logic [3:0]  s_axi_ctrl_araddr;
    logic [2:0]  s_axi_ctrl_arprot;
    logic        s_axi_ctrl_arvalid;
    logic        s_axi_ctrl_arready;
    logic [31:0] s_axi_ctrl_rdata;
    logic [1:0]  s_axi_ctrl_rresp;
    logic        s_axi_ctrl_rvalid;
    logic        s_axi_ctrl_rready;

    logic        bram_imem_clk;
    logic        bram_imem_rst;
    logic        bram_imem_en;
    logic [3:0]  bram_imem_we;
    logic [31:0] bram_imem_addr;
    logic [31:0] bram_imem_din;
    logic [31:0] bram_imem_dout;

    logic        bram_dmem_clk;
    logic        bram_dmem_rst;
    logic        bram_dmem_en;
    logic [3:0]  bram_dmem_we;
    logic [31:0] bram_dmem_addr;
    logic [31:0] bram_dmem_din;
    logic [31:0] bram_dmem_dout;

    logic [31:0] imem [0:(1 << ADDR_WIDTH)-1];
    logic [31:0] dmem [0:(1 << ADDR_WIDTH)-1];

    integer i;
    integer failures;

    riscv_zynq_wrapper #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .aresetn(aresetn),
        .global_interrupts(global_interrupts),
        .s_axi_ctrl_awaddr(s_axi_ctrl_awaddr),
        .s_axi_ctrl_awprot(s_axi_ctrl_awprot),
        .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
        .s_axi_ctrl_awready(s_axi_ctrl_awready),
        .s_axi_ctrl_wdata(s_axi_ctrl_wdata),
        .s_axi_ctrl_wstrb(s_axi_ctrl_wstrb),
        .s_axi_ctrl_wvalid(s_axi_ctrl_wvalid),
        .s_axi_ctrl_wready(s_axi_ctrl_wready),
        .s_axi_ctrl_bresp(s_axi_ctrl_bresp),
        .s_axi_ctrl_bvalid(s_axi_ctrl_bvalid),
        .s_axi_ctrl_bready(s_axi_ctrl_bready),
        .s_axi_ctrl_araddr(s_axi_ctrl_araddr),
        .s_axi_ctrl_arprot(s_axi_ctrl_arprot),
        .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
        .s_axi_ctrl_arready(s_axi_ctrl_arready),
        .s_axi_ctrl_rdata(s_axi_ctrl_rdata),
        .s_axi_ctrl_rresp(s_axi_ctrl_rresp),
        .s_axi_ctrl_rvalid(s_axi_ctrl_rvalid),
        .s_axi_ctrl_rready(s_axi_ctrl_rready),
        .bram_imem_clk(bram_imem_clk),
        .bram_imem_rst(bram_imem_rst),
        .bram_imem_en(bram_imem_en),
        .bram_imem_we(bram_imem_we),
        .bram_imem_addr(bram_imem_addr),
        .bram_imem_din(bram_imem_din),
        .bram_imem_dout(bram_imem_dout),
        .bram_dmem_clk(bram_dmem_clk),
        .bram_dmem_rst(bram_dmem_rst),
        .bram_dmem_en(bram_dmem_en),
        .bram_dmem_we(bram_dmem_we),
        .bram_dmem_addr(bram_dmem_addr),
        .bram_dmem_din(bram_dmem_din),
        .bram_dmem_dout(bram_dmem_dout)
    );

    always #5 clk = ~clk;

    always_ff @(posedge bram_imem_clk) begin
        if (bram_imem_rst) begin
            bram_imem_dout <= 32'd0;
        end else if (bram_imem_en) begin
            bram_imem_dout <= imem[bram_imem_addr[ADDR_WIDTH+1:2]];
        end
    end

    always_ff @(posedge bram_dmem_clk) begin
        if (bram_dmem_rst) begin
            bram_dmem_dout <= 32'd0;
        end else begin
            if (bram_dmem_en) begin
                bram_dmem_dout <= dmem[bram_dmem_addr[ADDR_WIDTH+1:2]];
            end
            if (bram_dmem_en && bram_dmem_we[0]) dmem[bram_dmem_addr[ADDR_WIDTH+1:2]][7:0]   <= bram_dmem_din[7:0];
            if (bram_dmem_en && bram_dmem_we[1]) dmem[bram_dmem_addr[ADDR_WIDTH+1:2]][15:8]  <= bram_dmem_din[15:8];
            if (bram_dmem_en && bram_dmem_we[2]) dmem[bram_dmem_addr[ADDR_WIDTH+1:2]][23:16] <= bram_dmem_din[23:16];
            if (bram_dmem_en && bram_dmem_we[3]) dmem[bram_dmem_addr[ADDR_WIDTH+1:2]][31:24] <= bram_dmem_din[31:24];
        end
    end

    task automatic ctrl_write(input logic [3:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            s_axi_ctrl_awaddr  <= addr;
            s_axi_ctrl_awprot  <= 3'b000;
            s_axi_ctrl_awvalid <= 1'b1;
            s_axi_ctrl_wdata   <= data;
            s_axi_ctrl_wstrb   <= 4'hf;
            s_axi_ctrl_wvalid  <= 1'b1;
            s_axi_ctrl_bready  <= 1'b1;

            do @(posedge clk); while (!(s_axi_ctrl_awready && s_axi_ctrl_wready));
            s_axi_ctrl_awvalid <= 1'b0;
            s_axi_ctrl_wvalid  <= 1'b0;

            do @(posedge clk); while (!s_axi_ctrl_bvalid);
            @(posedge clk);
        end
    endtask

    function automatic logic [31:0] dmem_word(input integer word_addr);
        return dmem[word_addr];
    endfunction

    task automatic expect_word(input integer word_addr, input logic [31:0] expected);
        logic [31:0] got;
        begin
            got = dmem_word(word_addr);
            if (got !== expected) begin
                failures = failures + 1;
                $display("FAIL dmem_word[0x%03x] expected=0x%08h got=0x%08h",
                         word_addr, expected, got);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        aresetn = 1'b0;
        global_interrupts = 32'd0;
        failures = 0;
        s_axi_ctrl_awaddr = '0;
        s_axi_ctrl_awprot = '0;
        s_axi_ctrl_awvalid = 1'b0;
        s_axi_ctrl_wdata = '0;
        s_axi_ctrl_wstrb = '0;
        s_axi_ctrl_wvalid = 1'b0;
        s_axi_ctrl_bready = 1'b0;
        s_axi_ctrl_araddr = '0;
        s_axi_ctrl_arprot = '0;
        s_axi_ctrl_arvalid = 1'b0;
        s_axi_ctrl_rready = 1'b0;
        bram_imem_dout = 32'd0;
        bram_dmem_dout = 32'd0;

        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            imem[i] = 32'h0000_0013;
            dmem[i] = 32'd0;
        end

        imem[0]  = 32'h0050_0093;
        imem[1]  = 32'h0070_0113;
        imem[2]  = 32'h0220_81b3;
        imem[3]  = 32'h1030_2023;
        imem[4]  = 32'h1000_2203;
        imem[5]  = 32'h0212_42b3;
        imem[6]  = 32'h1050_2223;
        imem[7]  = 32'h07f0_0313;
        imem[8]  = 32'h1060_0423;
        imem[9]  = 32'h1080_4383;
        imem[10] = 32'h1070_2623;
        imem[11] = 32'h0000_006f;

        repeat (5) @(posedge clk);
        aresetn = 1'b1;
        ctrl_write(4'h0, 32'd0);

        begin : wait_for_completion
            for (i = 0; i < 3000; i = i + 1) begin
                @(posedge clk);
                if (dmem_word('h43) == 32'h0000_007f)
                    disable wait_for_completion;
            end
        end

        expect_word('h40, 32'd35);
        expect_word('h41, 32'd7);
        expect_word('h42, 32'h0000_007f);
        expect_word('h43, 32'h0000_007f);

        if (failures == 0)
            $display("PASS: direct BRAM wrapper regression completed.");
        else
            $fatal(1, "Direct BRAM wrapper regression failed with %0d mismatches.", failures);
        $finish;
    end
endmodule
