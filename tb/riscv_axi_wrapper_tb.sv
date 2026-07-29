`timescale 1ns/1ps

module riscv_axi_wrapper_tb;
    localparam logic [31:0] AXI_TARGET_BASE = 32'h4200_0000;
    logic clk;
    logic aresetn;
    logic [31:0] global_interrupts;
    logic [31:0] cycle_count;
    logic        saw_if_resp_during_mem_stall;
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
    logic        m_axi_iuc_arvalid;
    logic        m_axi_iuc_arready;
    logic [31:0] m_axi_iuc_rdata;
    logic [1:0]  m_axi_iuc_rresp;
    logic        m_axi_iuc_rvalid;
    logic        m_axi_iuc_rready;
    logic [2:0]  m_axi_iuc_arprot;

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
    logic [7:0]  dmem [0:1023];

    logic        i_read_pending;
    logic [31:0] i_read_addr;
    logic [2:0]  i_read_delay;
    logic        d_read_pending;
    logic [31:0] d_read_addr;
    logic [2:0]  d_read_delay;
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
    assign m_axi_duc_arready = !d_read_pending && !m_axi_duc_rvalid &&
                               (cycle_count[1:0] != 2'b01);
    assign m_axi_duc_awready = !d_aw_captured && !m_axi_duc_bvalid &&
                               cycle_count[0];
    assign m_axi_duc_wready  = !d_w_captured && !m_axi_duc_bvalid &&
                               cycle_count[1];

    assign m_axi_iuc_rresp = 2'b00;
    assign m_axi_duc_bresp = 2'b00;
    assign m_axi_duc_rresp = 2'b00;

    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (!aresetn)
            cycle_count <= 32'd0;
        else
            cycle_count <= cycle_count + 32'd1;
    end

    always_ff @(posedge clk) begin
        if (!aresetn)
            saw_if_resp_during_mem_stall <= 1'b0;
        else if (dut.sv_inst.imem_ready && dut.sv_inst.core_inst.mem_stall)
            saw_if_resp_during_mem_stall <= 1'b1;
    end

    // Delayed AXI instruction read responder.
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
                i_read_delay <= 3'd2;
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

    // Delayed AXI data read responder and independent AW/W write responder.
    always_ff @(posedge clk) begin
        if (!aresetn) begin
            d_read_pending <= 1'b0;
            d_read_addr <= 32'd0;
            d_read_delay <= 3'd0;
            m_axi_duc_rdata <= 32'd0;
            m_axi_duc_rvalid <= 1'b0;
            d_aw_captured <= 1'b0;
            d_aw_addr <= 32'd0;
            d_w_captured <= 1'b0;
            d_w_data <= 32'd0;
            d_w_strb <= 4'd0;
            m_axi_duc_bvalid <= 1'b0;
        end else begin
            if (m_axi_duc_arvalid && m_axi_duc_arready) begin
                d_read_pending <= 1'b1;
                d_read_addr <= m_axi_duc_araddr;
                d_read_delay <= 3'd3;
            end
            if (d_read_pending) begin
                if (d_read_delay != 3'd0)
                    d_read_delay <= d_read_delay - 3'd1;
                else begin
                    m_axi_duc_rdata <= {
                        dmem[core_byte_addr(d_read_addr) + 3],
                        dmem[core_byte_addr(d_read_addr) + 2],
                        dmem[core_byte_addr(d_read_addr) + 1],
                        dmem[core_byte_addr(d_read_addr)]
                    };
                    m_axi_duc_rvalid <= 1'b1;
                    d_read_pending <= 1'b0;
                end
            end
            if (m_axi_duc_rvalid && m_axi_duc_rready)
                m_axi_duc_rvalid <= 1'b0;

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

    function automatic logic [31:0] dmem_word(input integer addr);
        return {dmem[addr + 3], dmem[addr + 2], dmem[addr + 1], dmem[addr]};
    endfunction

    function automatic integer core_byte_addr(input logic [31:0] axi_addr);
        return axi_addr - AXI_TARGET_BASE;
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
        for (i = 0; i < 1024; i = i + 1)
            dmem[i] = 8'd0;

        imem[0]  = 32'h0050_0093; // addi x1,x0,5
        imem[1]  = 32'h0070_0113; // addi x2,x0,7
        imem[2]  = 32'h0220_81b3; // mul  x3,x1,x2
        imem[3]  = 32'h1030_2023; // sw   x3,0x100(x0)
        imem[4]  = 32'h1000_2203; // lw   x4,0x100(x0)
        imem[5]  = 32'h0212_42b3; // div  x5,x4,x1
        imem[6]  = 32'h1050_2223; // sw   x5,0x104(x0)
        imem[7]  = 32'h07f0_0313; // addi x6,x0,0x7f
        imem[8]  = 32'h1060_0423; // sb   x6,0x108(x0)
        imem[9]  = 32'h1080_4383; // lbu  x7,0x108(x0)
        imem[10] = 32'h1070_2623; // sw   x7,0x10c(x0)
        // Match the Vitis hardware-smoke instruction spacing: ALU operation,
        // store through M_AXI_DUC, then another dependent ALU operation.
        imem[11] = 32'h0320_0293; // addi x5,x0,50
        imem[12] = 32'h01e0_0313; // addi x6,x0,30
        imem[13] = 32'h4062_83b3; // sub  x7,x5,x6
        imem[14] = 32'h1070_2823; // sw   x7,0x110(x0)
        imem[15] = 32'h0070_0293; // addi x5,x0,7
        imem[16] = 32'h0060_0313; // addi x6,x0,6
        imem[17] = 32'h0262_83b3; // mul  x7,x5,x6
        imem[18] = 32'h1070_2a23; // sw   x7,0x114(x0)
        imem[19] = 32'h0540_0293; // addi x5,x0,84
        imem[20] = 32'h0070_0313; // addi x6,x0,7
        imem[21] = 32'h0262_c3b3; // div  x7,x5,x6
        imem[22] = 32'h1070_2c23; // sw   x7,0x118(x0)
        imem[23] = 32'h0010_0393; // addi x7,x0,1
        imem[24] = 32'h1070_2e23; // sw   x7,0x11c(x0)
        imem[25] = 32'h0000_006f; // jal  x0,0

        repeat (5) @(posedge clk);
        aresetn = 1'b1;

        begin : wait_for_completion
            for (i = 0; i < 3000; i = i + 1) begin
                @(posedge clk);
                if (dmem_word(12'h11c) == 32'h0000_0001)
                    disable wait_for_completion;
            end
        end

        expect_word(12'h100, 32'd35);
        expect_word(12'h104, 32'd7);
        expect_word(12'h108, 32'h0000_007f);
        expect_word(12'h10c, 32'h0000_007f);
        expect_word(12'h110, 32'd20);
        expect_word(12'h114, 32'd42);
        expect_word(12'h118, 32'd12);
        expect_word(12'h11c, 32'd1);
        if (!saw_if_resp_during_mem_stall) begin
            failures = failures + 1;
            $display("FAIL did not cover IF response during MEM stall.");
        end

        if (failures == 0)
            $display("PASS: AXI4-Lite bridge regression completed.");
        else
            $fatal(1, "AXI4-Lite bridge regression failed with %0d mismatches.", failures);
        $finish;
    end
endmodule
