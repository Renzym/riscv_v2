`timescale 1ns/1ps

module riscv_axi_pc_control_tb;
    localparam logic [31:0] AXI_TARGET_BASE = 32'h4200_0000;
    localparam logic [2:0] I_READ_DELAY = 3'd0;

    logic clk;
    logic aresetn;
    logic [31:0] global_interrupts;
    logic [31:0] cycle_count;

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

    logic [31:0] m_axi_iuc_araddr;
    logic [2:0]  m_axi_iuc_arprot;
    logic        m_axi_iuc_arvalid;
    logic        m_axi_iuc_arready;
    logic [31:0] m_axi_iuc_rdata;
    logic [1:0]  m_axi_iuc_rresp;
    logic        m_axi_iuc_rvalid;
    logic        m_axi_iuc_rready;

    logic [31:0] m_axi_duc_awaddr;
    logic [2:0]  m_axi_duc_awprot;
    logic        m_axi_duc_awvalid;
    logic        m_axi_duc_awready;
    logic [31:0] m_axi_duc_wdata;
    logic [3:0]  m_axi_duc_wstrb;
    logic        m_axi_duc_wvalid;
    logic        m_axi_duc_wready;
    logic [1:0]  m_axi_duc_bresp;
    logic        m_axi_duc_bvalid;
    logic        m_axi_duc_bready;
    logic [31:0] m_axi_duc_araddr;
    logic [2:0]  m_axi_duc_arprot;
    logic        m_axi_duc_arvalid;
    logic        m_axi_duc_arready;
    logic [31:0] m_axi_duc_rdata;
    logic [1:0]  m_axi_duc_rresp;
    logic        m_axi_duc_rvalid;
    logic        m_axi_duc_rready;

    logic [31:0] imem [0:63];
    logic [7:0]  dmem [0:2047];

    logic        i_read_pending;
    logic [31:0] i_read_addr;
    logic [2:0]  i_read_delay;
    logic        d_aw_captured;
    logic [31:0] d_aw_addr;
    logic        d_w_captured;
    logic [31:0] d_w_data;
    logic [3:0]  d_w_strb;

    integer i;
    integer failures;

    riscv_axi_lite_bridge dut (
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
        .m_axi_iuc_araddr(m_axi_iuc_araddr),
        .m_axi_iuc_arprot(m_axi_iuc_arprot),
        .m_axi_iuc_arvalid(m_axi_iuc_arvalid),
        .m_axi_iuc_arready(m_axi_iuc_arready),
        .m_axi_iuc_rdata(m_axi_iuc_rdata),
        .m_axi_iuc_rresp(m_axi_iuc_rresp),
        .m_axi_iuc_rvalid(m_axi_iuc_rvalid),
        .m_axi_iuc_rready(m_axi_iuc_rready),
        .m_axi_duc_awaddr(m_axi_duc_awaddr),
        .m_axi_duc_awprot(m_axi_duc_awprot),
        .m_axi_duc_awvalid(m_axi_duc_awvalid),
        .m_axi_duc_awready(m_axi_duc_awready),
        .m_axi_duc_wdata(m_axi_duc_wdata),
        .m_axi_duc_wstrb(m_axi_duc_wstrb),
        .m_axi_duc_wvalid(m_axi_duc_wvalid),
        .m_axi_duc_wready(m_axi_duc_wready),
        .m_axi_duc_bresp(m_axi_duc_bresp),
        .m_axi_duc_bvalid(m_axi_duc_bvalid),
        .m_axi_duc_bready(m_axi_duc_bready),
        .m_axi_duc_araddr(m_axi_duc_araddr),
        .m_axi_duc_arprot(m_axi_duc_arprot),
        .m_axi_duc_arvalid(m_axi_duc_arvalid),
        .m_axi_duc_arready(m_axi_duc_arready),
        .m_axi_duc_rdata(m_axi_duc_rdata),
        .m_axi_duc_rresp(m_axi_duc_rresp),
        .m_axi_duc_rvalid(m_axi_duc_rvalid),
        .m_axi_duc_rready(m_axi_duc_rready)
    );

    assign m_axi_iuc_arready = !i_read_pending && !m_axi_iuc_rvalid &&
                               (cycle_count[1:0] != 2'b00);
    assign m_axi_duc_arready = 1'b0;
    assign m_axi_duc_awready = !d_aw_captured && !m_axi_duc_bvalid &&
                               cycle_count[0];
    assign m_axi_duc_wready  = !d_w_captured && !m_axi_duc_bvalid &&
                               cycle_count[1];
    assign m_axi_iuc_rresp = 2'b00;
    assign m_axi_duc_bresp = 2'b00;
    assign m_axi_duc_rresp = 2'b00;
    assign m_axi_duc_rdata = 32'd0;
    assign m_axi_duc_rvalid = 1'b0;

    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (!aresetn)
            cycle_count <= 32'd0;
        else
            cycle_count <= cycle_count + 32'd1;
    end

    always_ff @(posedge clk) begin
        if (!aresetn) begin
            i_read_pending <= 1'b0;
            i_read_addr <= 32'd0;
            i_read_delay <= 3'd0;
            m_axi_iuc_rdata <= 32'd0;
            m_axi_iuc_rvalid <= 1'b0;
        end else begin
            if (m_axi_iuc_arvalid && m_axi_iuc_arready) begin
                i_read_pending <= 1'b1;
                i_read_addr <= m_axi_iuc_araddr;
                i_read_delay <= I_READ_DELAY;
            end
            if (i_read_pending) begin
                if (i_read_delay != 3'd0)
                    i_read_delay <= i_read_delay - 3'd1;
                else begin
                    m_axi_iuc_rdata <= imem[core_byte_addr(i_read_addr) >> 2];
                    m_axi_iuc_rvalid <= 1'b1;
                    i_read_pending <= 1'b0;
                end
            end
            if (m_axi_iuc_rvalid && m_axi_iuc_rready)
                m_axi_iuc_rvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (!aresetn) begin
            d_aw_captured <= 1'b0;
            d_aw_addr <= 32'd0;
            d_w_captured <= 1'b0;
            d_w_data <= 32'd0;
            d_w_strb <= 4'd0;
            m_axi_duc_bvalid <= 1'b0;
        end else begin
            if (m_axi_duc_awvalid && m_axi_duc_awready) begin
                d_aw_addr <= m_axi_duc_awaddr;
                d_aw_captured <= 1'b1;
            end
            if (m_axi_duc_wvalid && m_axi_duc_wready) begin
                d_w_data <= m_axi_duc_wdata;
                d_w_strb <= m_axi_duc_wstrb;
                d_w_captured <= 1'b1;
            end
            if (d_aw_captured && d_w_captured && !m_axi_duc_bvalid) begin
                if (d_w_strb[0]) dmem[core_byte_addr(d_aw_addr)]     <= d_w_data[7:0];
                if (d_w_strb[1]) dmem[core_byte_addr(d_aw_addr) + 1] <= d_w_data[15:8];
                if (d_w_strb[2]) dmem[core_byte_addr(d_aw_addr) + 2] <= d_w_data[23:16];
                if (d_w_strb[3]) dmem[core_byte_addr(d_aw_addr) + 3] <= d_w_data[31:24];
                d_aw_captured <= 1'b0;
                d_w_captured <= 1'b0;
                m_axi_duc_bvalid <= 1'b1;
            end
            if (m_axi_duc_bvalid && m_axi_duc_bready)
                m_axi_duc_bvalid <= 1'b0;
        end
    end

    function automatic integer core_byte_addr(input logic [31:0] axi_addr);
        return axi_addr - AXI_TARGET_BASE;
    endfunction

    function automatic logic [31:0] dmem_word(input integer addr);
        return {dmem[addr + 3], dmem[addr + 2], dmem[addr + 1], dmem[addr]};
    endfunction

    task automatic expect_word(input integer addr, input logic [31:0] expected);
        logic [31:0] got;
        begin
            got = dmem_word(addr);
            if (got !== expected) begin
                failures++;
                $display("FAIL dmem[0x%03x] expected=0x%08h got=0x%08h",
                         addr, expected, got);
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
        s_axi_ctrl_bready = 1'b1;
        s_axi_ctrl_araddr = '0;
        s_axi_ctrl_arprot = '0;
        s_axi_ctrl_arvalid = 1'b0;
        s_axi_ctrl_rready = 1'b1;

        for (i = 0; i < 64; i++)
            imem[i] = 32'h0000_0013;
        for (i = 0; i < 2048; i++)
            dmem[i] = 8'd0;

        imem[0]  = 32'h00001597; // auipc a1,0x1
        imem[1]  = 32'h00058413; // addi  s0,a1,0
        imem[2]  = 32'h010002ef; // jal   t0,0x18
        imem[3]  = 32'h00000493; // addi  s1,x0,0
        imem[4]  = 32'h00000663; // beq   x0,x0,0x1c
        imem[5]  = 32'h00000013; // nop
        imem[6]  = 32'h00028493; // addi  s1,t0,0
        imem[7]  = 32'h03000293; // addi  t0,x0,0x30
        imem[8]  = 32'h00028367; // jalr  t1,0(t0)
        imem[9]  = 32'h00000913; // addi  s2,x0,0
        imem[10] = 32'h00000663; // beq   x0,x0,0x34
        imem[11] = 32'h00000013; // nop
        imem[12] = 32'h00030913; // addi  s2,t1,0
        imem[13] = 32'h60802023; // sw    s0,0x600(x0)
        imem[14] = 32'h60902223; // sw    s1,0x604(x0)
        imem[15] = 32'h61202423; // sw    s2,0x608(x0)
        imem[16] = 32'h123455b7; // lui   a1,0x12345
        imem[17] = 32'h60b02623; // sw    a1,0x60c(x0)
        imem[18] = 32'h00100593; // addi  a1,x0,1
        imem[19] = 32'heb05a823; // sw    a1,0x7f0(x0)
        imem[20] = 32'h0000006f; // jal   x0,0

        repeat (5) @(posedge clk);
        aresetn = 1'b1;

        begin : wait_for_completion
            for (i = 0; i < 1000; i++) begin
                @(posedge clk);
                if (dmem_word(12'h7f0) == 32'h0000_0001)
                    disable wait_for_completion;
            end
        end

        expect_word(12'h600, 32'h0000_1000);
        expect_word(12'h604, 32'h0000_000c);
        expect_word(12'h608, 32'h0000_0024);
        expect_word(12'h60c, 32'h1234_5000);

        if (failures == 0)
            $display("PASS: AXI PC-control regression completed.");
        else
            $fatal(1, "AXI PC-control regression failed with %0d mismatches.", failures);
        $finish;
    end
endmodule
