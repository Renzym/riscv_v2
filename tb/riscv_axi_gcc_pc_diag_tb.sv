`timescale 1ns/1ps

module riscv_axi_gcc_pc_diag_tb;
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
    logic [7:0]  dmem [0:4095];

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
                failures = failures + 1;
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

        for (i = 0; i < 64; i = i + 1)
            imem[i] = 32'h0000_0013;
        for (i = 0; i < 4096; i = i + 1)
            dmem[i] = 8'd0;

        imem[0]  = 32'h00001117;
        imem[1]  = 32'h00010113;
        imem[2]  = 32'h0040006f;
        imem[3]  = 32'h00000817;
        imem[4]  = 32'h00c00513;
        imem[5]  = 32'h008005ef;
        imem[6]  = 32'h00000013;
        imem[7]  = 32'h01800613;
        imem[8]  = 32'h02c00793;
        imem[9]  = 32'h00078767;
        imem[10] = 32'h00000013;
        imem[11] = 32'h02800693;
        imem[12] = 32'h40a807b3;
        imem[13] = 32'h0017b793;
        imem[14] = 32'h04c58c63;
        imem[15] = 32'h00d71463;
        imem[16] = 32'h0047e793;
        imem[17] = 32'h00001e37;
        imem[18] = 32'h830e2023;
        imem[19] = 32'h00001337;
        imem[20] = 32'h82a32223;
        imem[21] = 32'h000018b7;
        imem[22] = 32'h82b8a423;
        imem[23] = 32'h00001837;
        imem[24] = 32'h82c82623;
        imem[25] = 32'h00001537;
        imem[26] = 32'h82e52823;
        imem[27] = 32'h000015b7;
        imem[28] = 32'h82d5aa23;
        imem[29] = 32'h00001637;
        imem[30] = 32'hcafed6b7;
        imem[31] = 32'h00001737;
        imem[32] = 32'hafe68693;
        imem[33] = 32'h80f62623;
        imem[34] = 32'h80d72823;
        imem[35] = 32'h0000006f;
        imem[36] = 32'h0027e793;
        imem[37] = 32'hfa9ff06f;

        repeat (5) @(posedge clk);
        aresetn = 1'b1;

        begin : wait_for_completion
            for (i = 0; i < 1000; i = i + 1) begin
                @(posedge clk);
                if (dmem_word(12'h810) == 32'hcafe_cafe)
                    disable wait_for_completion;
            end
        end

        expect_word(12'h820, 32'h0000_000c);
        expect_word(12'h824, 32'h0000_000c);
        expect_word(12'h828, 32'h0000_0018);
        expect_word(12'h82c, 32'h0000_0018);
        expect_word(12'h830, 32'h0000_0028);
        expect_word(12'h834, 32'h0000_0028);
        expect_word(12'h80c, 32'h0000_0007);
        expect_word(12'h810, 32'hcafe_cafe);

        if (failures == 0)
            $display("PASS: GCC PC diagnostic regression completed.");
        else
            $fatal(1, "GCC PC diagnostic regression failed with %0d mismatches.", failures);
        $finish;
    end
endmodule
