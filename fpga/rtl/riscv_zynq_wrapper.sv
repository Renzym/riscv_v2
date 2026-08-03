`ifndef RISCV_ZYNQ_WRAPPER_SV
`define RISCV_ZYNQ_WRAPPER_SV

`timescale 1ns/1ps

module riscv_zynq_wrapper #(
    parameter integer ADDR_WIDTH = 10,
    parameter logic [31:0] RESET_PC = 32'h0000_0000,
    parameter logic [31:0] AXI_PERIPH_BASE = 32'h1000_0000,
    parameter logic [31:0] AXI_PERIPH_MASK = 32'hF000_0000,
    parameter integer NUM_EXT_INTERRUPTS = 32
) (
    input  logic        clk,
    input  logic        aresetn,
    input  logic [NUM_EXT_INTERRUPTS-1:0] global_interrupts,

    // AXI-Lite Slave Interface (Control/Status)
    input  logic [3:0]                           s_axi_ctrl_awaddr,
    input  logic [2:0]                           s_axi_ctrl_awprot,
    input  logic                                 s_axi_ctrl_awvalid,
    output logic                                 s_axi_ctrl_awready,
    input  logic [31:0]                          s_axi_ctrl_wdata,
    input  logic [3:0]                           s_axi_ctrl_wstrb,
    input  logic                                 s_axi_ctrl_wvalid,
    output logic                                 s_axi_ctrl_wready,
    output logic [1:0]                           s_axi_ctrl_bresp,
    output logic                                 s_axi_ctrl_bvalid,
    input  logic                                 s_axi_ctrl_bready,
    input  logic [3:0]                           s_axi_ctrl_araddr,
    input  logic [2:0]                           s_axi_ctrl_arprot,
    input  logic                                 s_axi_ctrl_arvalid,
    output logic                                 s_axi_ctrl_arready,
    output logic [31:0]                          s_axi_ctrl_rdata,
    output logic [1:0]                           s_axi_ctrl_rresp,
    output logic                                 s_axi_ctrl_rvalid,
    input  logic                                 s_axi_ctrl_rready,

    // BRAM Interface - Instruction Memory
    output logic        bram_imem_clk,
    output logic        bram_imem_rst,
    output logic        bram_imem_en,
    output logic [3:0]  bram_imem_we,
    output logic [31:0] bram_imem_addr,
    output logic [31:0] bram_imem_din,
    input  logic [31:0] bram_imem_dout,

    // BRAM Interface - Data Memory
    output logic        bram_dmem_clk,
    output logic        bram_dmem_rst,
    output logic        bram_dmem_en,
    output logic [3:0]  bram_dmem_we,
    output logic [31:0] bram_dmem_addr,
    output logic [31:0] bram_dmem_din,
    input  logic [31:0] bram_dmem_dout,

    // AXI4-Lite Master Interface - data-side peripherals
    output logic [31:0] m_axi_periph_awaddr,
    output logic [2:0]  m_axi_periph_awprot,
    output logic        m_axi_periph_awvalid,
    input  logic        m_axi_periph_awready,
    output logic [31:0] m_axi_periph_wdata,
    output logic [3:0]  m_axi_periph_wstrb,
    output logic        m_axi_periph_wvalid,
    input  logic        m_axi_periph_wready,
    input  logic [1:0]  m_axi_periph_bresp,
    input  logic        m_axi_periph_bvalid,
    output logic        m_axi_periph_bready,
    output logic [31:0] m_axi_periph_araddr,
    output logic [2:0]  m_axi_periph_arprot,
    output logic        m_axi_periph_arvalid,
    input  logic        m_axi_periph_arready,
    input  logic [31:0] m_axi_periph_rdata,
    input  logic [1:0]  m_axi_periph_rresp,
    input  logic        m_axi_periph_rvalid,
    output logic        m_axi_periph_rready
);

    logic        cpu_reset_ext;
    logic        cpu_reset;
    logic        cpu_running;

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
    logic [31:0] bram_imem_byte_addr;
    logic [31:0] bram_dmem_byte_addr;
    logic        dmem_sel_axi;
    logic        dmem_sel_bram;
    logic        bram_dmem_ready;
    logic [31:0] bram_dmem_read_data;
    logic        axi_dmem_ready;
    logic [31:0] axi_dmem_read_data;

    // BRAM has a registered (1-cycle) read output. The core expects imem_instr /
    // dmem_read_data to be valid in the same cycle that *_ready is asserted, for the
    // address it is currently driving. So we assert ready only when the address has
    // been held stable for one full cycle (i.e. the registered BRAM output now
    // corresponds to the address presently requested). This gives a correct 2-cycle
    // access and self-corrects across PC changes and pipeline stalls.
    logic [31:0] imem_addr_q;
    logic        imem_req_q;

    logic [31:0] dmem_addr_q;
    logic        dmem_acc;
    logic        dmem_acc_q;

    assign cpu_reset   = !aresetn || cpu_reset_ext;
    assign cpu_running = !cpu_reset;

    assign dmem_acc      = dmem_read_en | dmem_write_en;
    assign dmem_sel_axi  = dmem_acc &&
                           ((dmem_addr & AXI_PERIPH_MASK) ==
                            (AXI_PERIPH_BASE & AXI_PERIPH_MASK));
    assign dmem_sel_bram = dmem_acc && !dmem_sel_axi;

    always_ff @(posedge clk) begin
        if (cpu_reset) begin
            imem_addr_q <= 32'd0;
            imem_req_q  <= 1'b0;
            dmem_addr_q <= 32'd0;
            dmem_acc_q  <= 1'b0;
        end else begin
            imem_addr_q <= imem_addr;
            imem_req_q  <= imem_req;
            dmem_addr_q <= dmem_addr;
            dmem_acc_q  <= dmem_sel_bram;
        end
    end

    assign imem_ready     = imem_req_q && (imem_addr_q == imem_addr);
    assign imem_instr     = bram_imem_dout;
    assign bram_dmem_ready = dmem_acc_q && (dmem_addr_q == dmem_addr);
    assign bram_dmem_read_data = bram_dmem_dout;
    assign dmem_ready     = dmem_sel_axi ? axi_dmem_ready : bram_dmem_ready;
    assign dmem_read_data = dmem_sel_axi ? axi_dmem_read_data : bram_dmem_read_data;
    assign bram_imem_byte_addr = {
        {(32-(ADDR_WIDTH+2)){1'b0}},
        imem_addr[ADDR_WIDTH+1:2],
        2'b00
    };
    assign bram_dmem_byte_addr = {
        {(32-(ADDR_WIDTH+2)){1'b0}},
        dmem_addr[ADDR_WIDTH+1:2],
        2'b00
    };

    // AXI-Lite control/status. Memory remains direct BRAM; this only controls reset.
    axi_lite_control #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(4)
    ) ctrl_inst (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (aresetn),
        .S_AXI_AWADDR  (s_axi_ctrl_awaddr),
        .S_AXI_AWPROT  (s_axi_ctrl_awprot),
        .S_AXI_AWVALID (s_axi_ctrl_awvalid),
        .S_AXI_AWREADY (s_axi_ctrl_awready),
        .S_AXI_WDATA   (s_axi_ctrl_wdata),
        .S_AXI_WSTRB   (s_axi_ctrl_wstrb),
        .S_AXI_WVALID  (s_axi_ctrl_wvalid),
        .S_AXI_WREADY  (s_axi_ctrl_wready),
        .S_AXI_BRESP   (s_axi_ctrl_bresp),
        .S_AXI_BVALID  (s_axi_ctrl_bvalid),
        .S_AXI_BREADY  (s_axi_ctrl_bready),
        .S_AXI_ARADDR  (s_axi_ctrl_araddr),
        .S_AXI_ARPROT  (s_axi_ctrl_arprot),
        .S_AXI_ARVALID (s_axi_ctrl_arvalid),
        .S_AXI_ARREADY (s_axi_ctrl_arready),
        .S_AXI_RDATA   (s_axi_ctrl_rdata),
        .S_AXI_RRESP   (s_axi_ctrl_rresp),
        .S_AXI_RVALID  (s_axi_ctrl_rvalid),
        .S_AXI_RREADY  (s_axi_ctrl_rready),
        .cpu_reset_ext (cpu_reset_ext),
        .cpu_running   (cpu_running)
    );

    riscv_axi_lite_master #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32)
    ) dmem_axi_inst (
        .clk          (clk),
        .reset        (cpu_reset),
        .req_read     (dmem_sel_axi && dmem_read_en),
        .req_write    (dmem_sel_axi && dmem_write_en),
        .req_addr     (dmem_addr),
        .req_wdata    (dmem_write_data),
        .req_wstrb    (dmem_wstrb),
        .req_ready    (axi_dmem_ready),
        .req_rdata    (axi_dmem_read_data),
        .m_axi_awaddr (m_axi_periph_awaddr),
        .m_axi_awprot (m_axi_periph_awprot),
        .m_axi_awvalid(m_axi_periph_awvalid),
        .m_axi_awready(m_axi_periph_awready),
        .m_axi_wdata  (m_axi_periph_wdata),
        .m_axi_wstrb  (m_axi_periph_wstrb),
        .m_axi_wvalid (m_axi_periph_wvalid),
        .m_axi_wready (m_axi_periph_wready),
        .m_axi_bresp  (m_axi_periph_bresp),
        .m_axi_bvalid (m_axi_periph_bvalid),
        .m_axi_bready (m_axi_periph_bready),
        .m_axi_araddr (m_axi_periph_araddr),
        .m_axi_arprot (m_axi_periph_arprot),
        .m_axi_arvalid(m_axi_periph_arvalid),
        .m_axi_arready(m_axi_periph_arready),
        .m_axi_rdata  (m_axi_periph_rdata),
        .m_axi_rresp  (m_axi_periph_rresp),
        .m_axi_rvalid (m_axi_periph_rvalid),
        .m_axi_rready (m_axi_periph_rready)
    );

    // RISC-V core
    riscv_core #(
        .RESET_PC(RESET_PC),
        .TRAP_ACCESS_FAULTS(1'b0),
        .DMEM_BASE(32'h0000_0000),
        .DMEM_LIMIT(32'h0000_1000),
        .NUM_EXT_INTERRUPTS(NUM_EXT_INTERRUPTS)
    ) core_inst (
        .clk             (clk),
        .reset           (cpu_reset),
        .global_interrupts(global_interrupts),
        .imem_req        (imem_req),
        .imem_addr       (imem_addr),
        .imem_ready      (imem_ready),
        .imem_instr      (imem_instr),
        .imem_resp_pc    (imem_addr_q),
        .imem_resp_accept(),
        .dmem_addr       (dmem_addr),
        .dmem_write_data (dmem_write_data),
        .dmem_wstrb      (dmem_wstrb),
        .dmem_read_en    (dmem_read_en),
        .dmem_write_en   (dmem_write_en),
        .dmem_ready      (dmem_ready),
        .dmem_read_data  (dmem_read_data)
    );

    // Keep BRAM ports enabled while the CPU is running. The core still uses
    // imem_req/dmem_sel_bram for ready/write qualification, but BRAM EN no
    // longer sits on the critical core-control path into RAMB ENBWREN.
    assign bram_imem_clk  = clk;
    assign bram_imem_rst  = cpu_reset;
    assign bram_imem_en   = cpu_running;
    assign bram_imem_we   = 4'b0000;
    assign bram_imem_addr = bram_imem_byte_addr;
    assign bram_imem_din  = 32'b0;

    // Data BRAM: read/write, driven directly from core
    assign bram_dmem_clk  = clk;
    assign bram_dmem_rst  = cpu_reset;
    assign bram_dmem_en   = cpu_running;
    assign bram_dmem_we   = (dmem_sel_bram && dmem_write_en) ? dmem_wstrb : 4'b0000;
    assign bram_dmem_addr = bram_dmem_byte_addr;
    assign bram_dmem_din  = dmem_write_data;

endmodule

`endif
