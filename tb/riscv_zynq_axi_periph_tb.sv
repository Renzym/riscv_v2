`timescale 1ns/1ps

module riscv_zynq_axi_periph_tb;
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

    logic [31:0] m_axi_periph_awaddr;
    logic [2:0]  m_axi_periph_awprot;
    logic        m_axi_periph_awvalid;
    logic        m_axi_periph_awready;
    logic [31:0] m_axi_periph_wdata;
    logic [3:0]  m_axi_periph_wstrb;
    logic        m_axi_periph_wvalid;
    logic        m_axi_periph_wready;
    logic [1:0]  m_axi_periph_bresp;
    logic        m_axi_periph_bvalid;
    logic        m_axi_periph_bready;
    logic [31:0] m_axi_periph_araddr;
    logic [2:0]  m_axi_periph_arprot;
    logic        m_axi_periph_arvalid;
    logic        m_axi_periph_arready;
    logic [31:0] m_axi_periph_rdata;
    logic [1:0]  m_axi_periph_rresp;
    logic        m_axi_periph_rvalid;
    logic        m_axi_periph_rready;

    logic [31:0] imem [0:63];
    logic [31:0] dmem [0:255];
    logic [31:0] periph_reg0;
    logic        aw_seen;
    logic        w_seen;
    logic [31:0] aw_addr_q;
    logic [31:0] w_data_q;
    logic [3:0]  w_strb_q;
    logic [1:0]  b_delay;
    logic [1:0]  r_delay;
    integer      i;

    riscv_zynq_wrapper dut (
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
        .bram_dmem_dout(bram_dmem_dout),
        .m_axi_periph_awaddr(m_axi_periph_awaddr),
        .m_axi_periph_awprot(m_axi_periph_awprot),
        .m_axi_periph_awvalid(m_axi_periph_awvalid),
        .m_axi_periph_awready(m_axi_periph_awready),
        .m_axi_periph_wdata(m_axi_periph_wdata),
        .m_axi_periph_wstrb(m_axi_periph_wstrb),
        .m_axi_periph_wvalid(m_axi_periph_wvalid),
        .m_axi_periph_wready(m_axi_periph_wready),
        .m_axi_periph_bresp(m_axi_periph_bresp),
        .m_axi_periph_bvalid(m_axi_periph_bvalid),
        .m_axi_periph_bready(m_axi_periph_bready),
        .m_axi_periph_araddr(m_axi_periph_araddr),
        .m_axi_periph_arprot(m_axi_periph_arprot),
        .m_axi_periph_arvalid(m_axi_periph_arvalid),
        .m_axi_periph_arready(m_axi_periph_arready),
        .m_axi_periph_rdata(m_axi_periph_rdata),
        .m_axi_periph_rresp(m_axi_periph_rresp),
        .m_axi_periph_rvalid(m_axi_periph_rvalid),
        .m_axi_periph_rready(m_axi_periph_rready)
    );

    assign m_axi_periph_awready = !aw_seen && !m_axi_periph_bvalid;
    assign m_axi_periph_wready  = !w_seen && !m_axi_periph_bvalid;
    assign m_axi_periph_arready = !m_axi_periph_rvalid && (r_delay == 2'd0);
    assign m_axi_periph_bresp   = 2'b00;
    assign m_axi_periph_rresp   = 2'b00;

    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (bram_imem_en)
            bram_imem_dout <= imem[bram_imem_addr[31:2]];
    end

    always_ff @(posedge clk) begin
        if (bram_dmem_en) begin
            if (bram_dmem_we[0]) dmem[bram_dmem_addr[31:2]][7:0]   <= bram_dmem_din[7:0];
            if (bram_dmem_we[1]) dmem[bram_dmem_addr[31:2]][15:8]  <= bram_dmem_din[15:8];
            if (bram_dmem_we[2]) dmem[bram_dmem_addr[31:2]][23:16] <= bram_dmem_din[23:16];
            if (bram_dmem_we[3]) dmem[bram_dmem_addr[31:2]][31:24] <= bram_dmem_din[31:24];
            bram_dmem_dout <= dmem[bram_dmem_addr[31:2]];
        end
    end

    always_ff @(posedge clk) begin
        if (!aresetn) begin
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            aw_addr_q <= 32'd0;
            w_data_q <= 32'd0;
            w_strb_q <= 4'd0;
            b_delay <= 2'd0;
            r_delay <= 2'd0;
            periph_reg0 <= 32'd0;
            m_axi_periph_bvalid <= 1'b0;
            m_axi_periph_rvalid <= 1'b0;
            m_axi_periph_rdata <= 32'd0;
        end else begin
            if (m_axi_periph_awvalid && m_axi_periph_awready) begin
                aw_seen <= 1'b1;
                aw_addr_q <= m_axi_periph_awaddr;
            end
            if (m_axi_periph_wvalid && m_axi_periph_wready) begin
                w_seen <= 1'b1;
                w_data_q <= m_axi_periph_wdata;
                w_strb_q <= m_axi_periph_wstrb;
            end
            if (aw_seen && w_seen && !m_axi_periph_bvalid && b_delay == 2'd0) begin
                b_delay <= 2'd2;
            end else if (b_delay != 2'd0) begin
                b_delay <= b_delay - 2'd1;
                if (b_delay == 2'd1) begin
                    if (aw_addr_q == 32'h1000_0000) begin
                        if (w_strb_q[0]) periph_reg0[7:0]   <= w_data_q[7:0];
                        if (w_strb_q[1]) periph_reg0[15:8]  <= w_data_q[15:8];
                        if (w_strb_q[2]) periph_reg0[23:16] <= w_data_q[23:16];
                        if (w_strb_q[3]) periph_reg0[31:24] <= w_data_q[31:24];
                    end
                    m_axi_periph_bvalid <= 1'b1;
                    aw_seen <= 1'b0;
                    w_seen <= 1'b0;
                end
            end
            if (m_axi_periph_bvalid && m_axi_periph_bready)
                m_axi_periph_bvalid <= 1'b0;

            if (m_axi_periph_arvalid && m_axi_periph_arready) begin
                r_delay <= 2'd2;
            end else if (r_delay != 2'd0) begin
                r_delay <= r_delay - 2'd1;
                if (r_delay == 2'd1) begin
                    m_axi_periph_rdata <= (m_axi_periph_araddr == 32'h1000_0004)
                                        ? 32'hABCD_EF01 : 32'd0;
                    m_axi_periph_rvalid <= 1'b1;
                end
            end
            if (m_axi_periph_rvalid && m_axi_periph_rready)
                m_axi_periph_rvalid <= 1'b0;
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
            s_axi_ctrl_bready <= 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        aresetn = 1'b0;
        global_interrupts = 32'd0;
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

        for (i = 0; i < 64; i = i + 1)
            imem[i] = 32'h0000_0013;
        for (i = 0; i < 256; i = i + 1)
            dmem[i] = 32'd0;

        imem[0] = 32'h1000_00b7; // lui  x1,0x10000
        imem[1] = 32'h0550_0113; // addi x2,x0,0x55
        imem[2] = 32'h0020_a023; // sw   x2,0(x1)
        imem[3] = 32'h0040_a183; // lw   x3,4(x1)
        imem[4] = 32'h1030_2023; // sw   x3,0x100(x0)
        imem[5] = 32'h0000_006f; // jal  x0,0

        repeat (5) @(posedge clk);
        aresetn = 1'b1;
        ctrl_write(4'h0, 32'h0000_0000);

        begin : wait_for_axi_completion
            for (i = 0; i < 300; i = i + 1) begin
                @(posedge clk);
                if (dmem[12'h100 >> 2] == 32'hABCD_EF01)
                    disable wait_for_axi_completion;
            end
        end

        if (periph_reg0 !== 32'h0000_0055)
            $fatal(1, "AXI write failed: periph_reg0=0x%08h", periph_reg0);
        if (dmem[12'h100 >> 2] !== 32'hABCD_EF01)
            $fatal(1, "AXI read result was not written back to BRAM: 0x%08h", dmem[12'h100 >> 2]);

        $display("PASS: native BRAM plus AXI-Lite peripheral access completed.");
        $finish;
    end
endmodule
