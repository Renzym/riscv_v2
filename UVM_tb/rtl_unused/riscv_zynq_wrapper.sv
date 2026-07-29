`ifndef RISCV_ZYNQ_WRAPPER_SV
`define RISCV_ZYNQ_WRAPPER_SV

`timescale 1ns/1ps

module riscv_zynq_wrapper #(
    parameter integer ADDR_WIDTH = 10, // 4KB by default
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
) (
    // Global signals
    input  logic        clk,
    input  logic        aresetn,

    // AXI-Lite Slave Interface (Control/Status)
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_ctrl_awaddr,
    input  logic [2:0]                    s_axi_ctrl_awprot,
    input  logic                          s_axi_ctrl_awvalid,
    output logic                          s_axi_ctrl_awready,
    input  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_ctrl_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_ctrl_wstrb,
    input  logic                          s_axi_ctrl_wvalid,
    output logic                          s_axi_ctrl_wready,
    output logic [1:0]                    s_axi_ctrl_bresp,
    output logic                          s_axi_ctrl_bvalid,
    input  logic                          s_axi_ctrl_bready,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_ctrl_araddr,
    input  logic [2:0]                    s_axi_ctrl_arprot,
    input  logic                          s_axi_ctrl_arvalid,
    output logic                          s_axi_ctrl_arready,
    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_ctrl_rdata,
    output logic [1:0]                    s_axi_ctrl_rresp,
    output logic                          s_axi_ctrl_rvalid,
    input  logic                          s_axi_ctrl_rready,

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

    // AXI4 Master Interface to PS DDR
    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_ddr_awaddr,
    output logic [2:0]                    m_axi_ddr_awprot,
    output logic [7:0]                    m_axi_ddr_awlen,
    output logic [2:0]                    m_axi_ddr_awsize,
    output logic [1:0]                    m_axi_ddr_awburst,
    output logic                          m_axi_ddr_awvalid,
    input  logic                          m_axi_ddr_awready,
    output logic [AXI_DATA_WIDTH-1:0]     m_axi_ddr_wdata,
    output logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_ddr_wstrb,
    output logic                          m_axi_ddr_wlast,
    output logic                          m_axi_ddr_wvalid,
    input  logic                          m_axi_ddr_wready,
    input  logic [1:0]                    m_axi_ddr_bresp,
    input  logic                          m_axi_ddr_bvalid,
    output logic                          m_axi_ddr_bready,
    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_ddr_araddr,
    output logic [2:0]                    m_axi_ddr_arprot,
    output logic [7:0]                    m_axi_ddr_arlen,
    output logic [2:0]                    m_axi_ddr_arsize,
    output logic [1:0]                    m_axi_ddr_arburst,
    output logic                          m_axi_ddr_arvalid,
    input  logic                          m_axi_ddr_arready,
    input  logic [AXI_DATA_WIDTH-1:0]     m_axi_ddr_rdata,
    input  logic [1:0]                    m_axi_ddr_rresp,
    input  logic                          m_axi_ddr_rlast,
    input  logic                          m_axi_ddr_rvalid,
    output logic                          m_axi_ddr_rready
);

    // Internal signals
    logic cpu_reset_ext;
    logic cpu_reset;
    logic cpu_running;
    logic mem_mode_ddr;
    logic [31:0] ddr_imem_base;
    logic [31:0] ddr_dmem_base;
    
    // Core memory interface
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

    logic        icache_invalidate;
    logic        dcache_invalidate;

    // Cache to Memory signals
    logic [ADDR_WIDTH-1:0] icache_mem_addr;
    logic                  bram_imem_ready;
    logic [31:0]           bram_imem_instr;
    logic [31:0]           icache_mem_rdata;

    logic [ADDR_WIDTH-1:0] dcache_mem_addr;
    logic [31:0]           dcache_mem_write_data;
    logic [3:0]            dcache_mem_wstrb;
    logic                  dcache_mem_read_en;
    logic                  dcache_mem_write_en;
    logic                  bram_dmem_ready;
    logic [31:0]           bram_dmem_read_data;
    logic [31:0]           dcache_mem_read_data;

    logic                  ddr_imem_ready;
    logic [31:0]           ddr_imem_instr;
    logic                  ddr_dmem_ready;
    logic [31:0]           ddr_dmem_read_data;

    // Reset logic
    assign cpu_reset = !aresetn || cpu_reset_ext;
    assign cpu_running = !cpu_reset;

    // Instantiate AXI-Lite Control
    axi_lite_control #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) ctrl_inst (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(aresetn),
        .S_AXI_AWADDR(s_axi_ctrl_awaddr),
        .S_AXI_AWPROT(s_axi_ctrl_awprot),
        .S_AXI_AWVALID(s_axi_ctrl_awvalid),
        .S_AXI_AWREADY(s_axi_ctrl_awready),
        .S_AXI_WDATA(s_axi_ctrl_wdata),
        .S_AXI_WSTRB(s_axi_ctrl_wstrb),
        .S_AXI_WVALID(s_axi_ctrl_wvalid),
        .S_AXI_WREADY(s_axi_ctrl_wready),
        .S_AXI_BRESP(s_axi_ctrl_bresp),
        .S_AXI_BVALID(s_axi_ctrl_bvalid),
        .S_AXI_BREADY(s_axi_ctrl_bready),
        .S_AXI_ARADDR(s_axi_ctrl_araddr),
        .S_AXI_ARPROT(s_axi_ctrl_arprot),
        .S_AXI_ARVALID(s_axi_ctrl_arvalid),
        .S_AXI_ARREADY(s_axi_ctrl_arready),
        .S_AXI_RDATA(s_axi_ctrl_rdata),
        .S_AXI_RRESP(s_axi_ctrl_rresp),
        .S_AXI_RVALID(s_axi_ctrl_rvalid),
        .S_AXI_RREADY(s_axi_ctrl_rready),
        .cpu_reset_ext(cpu_reset_ext),
        .mem_mode_ddr(mem_mode_ddr),
        .ddr_imem_base(ddr_imem_base),
        .ddr_dmem_base(ddr_dmem_base),
        .cpu_running(cpu_running)
    );

    assign imem_ready = mem_mode_ddr ? ddr_imem_ready : bram_imem_ready;
    assign imem_instr = mem_mode_ddr ? ddr_imem_instr : bram_imem_instr;
    assign dmem_ready = mem_mode_ddr ? ddr_dmem_ready : bram_dmem_ready;
    assign dmem_read_data = mem_mode_ddr ? ddr_dmem_read_data : bram_dmem_read_data;

    // Instantiate RISC-V Core
    riscv_core core_inst (
        .clk(clk),
        .reset(cpu_reset),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ready(imem_ready),
        .imem_instr(imem_instr),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_write_data),
        .dmem_wstrb(dmem_wstrb),
        .dmem_read_en(dmem_read_en),
        .dmem_write_en(dmem_write_en),
        .dmem_ready(dmem_ready),
        .dmem_read_data(dmem_read_data),
        .icache_invalidate(icache_invalidate),
        .dcache_invalidate(dcache_invalidate)
    );

    // Instantiate Instruction Cache (MISS_LATENCY=2 for BRAM)
    simple_icache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_LINES(32),
        .MISS_LATENCY(2)
    ) icache_inst (
        .clk(clk),
        .reset(cpu_reset),
        .cpu_req(!mem_mode_ddr && imem_req),
        .cpu_addr(imem_addr),
        .cpu_ready(bram_imem_ready),
        .cpu_rdata(bram_imem_instr),
        .invalidate(icache_invalidate),
        .mem_addr(icache_mem_addr),
        .mem_rdata(icache_mem_rdata)
    );

    // Instantiate Data Cache (MISS_LATENCY=2 for BRAM)
    simple_dcache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_LINES(16),
        .MISS_LATENCY(2)
    ) dcache_inst (
        .clk(clk),
        .reset(cpu_reset),
        .cpu_read_en(!mem_mode_ddr && dmem_read_en),
        .cpu_write_en(!mem_mode_ddr && dmem_write_en),
        .cpu_addr(dmem_addr),
        .cpu_write_data(dmem_write_data),
        .cpu_wstrb(dmem_wstrb),
        .cpu_ready(bram_dmem_ready),
        .cpu_read_data(bram_dmem_read_data),
        .invalidate(dcache_invalidate),
        .mem_addr(dcache_mem_addr),
        .mem_write_data(dcache_mem_write_data),
        .mem_wstrb(dcache_mem_wstrb),
        .mem_read_en(dcache_mem_read_en),
        .mem_write_en(dcache_mem_write_en),
        .mem_read_data(dcache_mem_read_data)
    );

    riscv_axi_ddr_backend #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) ddr_backend_inst (
        .clk(clk),
        .reset(cpu_reset),
        .imem_req(mem_mode_ddr && imem_req),
        .imem_addr(imem_addr),
        .imem_ready(ddr_imem_ready),
        .imem_rdata(ddr_imem_instr),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_write_data),
        .dmem_wstrb(dmem_wstrb),
        .dmem_read_en(mem_mode_ddr && dmem_read_en),
        .dmem_write_en(mem_mode_ddr && dmem_write_en),
        .dmem_ready(ddr_dmem_ready),
        .dmem_read_data(ddr_dmem_read_data),
        .ddr_imem_base(ddr_imem_base),
        .ddr_dmem_base(ddr_dmem_base),
        .m_axi_ddr_awaddr(m_axi_ddr_awaddr),
        .m_axi_ddr_awprot(m_axi_ddr_awprot),
        .m_axi_ddr_awlen(m_axi_ddr_awlen),
        .m_axi_ddr_awsize(m_axi_ddr_awsize),
        .m_axi_ddr_awburst(m_axi_ddr_awburst),
        .m_axi_ddr_awvalid(m_axi_ddr_awvalid),
        .m_axi_ddr_awready(m_axi_ddr_awready),
        .m_axi_ddr_wdata(m_axi_ddr_wdata),
        .m_axi_ddr_wstrb(m_axi_ddr_wstrb),
        .m_axi_ddr_wlast(m_axi_ddr_wlast),
        .m_axi_ddr_wvalid(m_axi_ddr_wvalid),
        .m_axi_ddr_wready(m_axi_ddr_wready),
        .m_axi_ddr_bresp(m_axi_ddr_bresp),
        .m_axi_ddr_bvalid(m_axi_ddr_bvalid),
        .m_axi_ddr_bready(m_axi_ddr_bready),
        .m_axi_ddr_araddr(m_axi_ddr_araddr),
        .m_axi_ddr_arprot(m_axi_ddr_arprot),
        .m_axi_ddr_arlen(m_axi_ddr_arlen),
        .m_axi_ddr_arsize(m_axi_ddr_arsize),
        .m_axi_ddr_arburst(m_axi_ddr_arburst),
        .m_axi_ddr_arvalid(m_axi_ddr_arvalid),
        .m_axi_ddr_arready(m_axi_ddr_arready),
        .m_axi_ddr_rdata(m_axi_ddr_rdata),
        .m_axi_ddr_rresp(m_axi_ddr_rresp),
        .m_axi_ddr_rlast(m_axi_ddr_rlast),
        .m_axi_ddr_rvalid(m_axi_ddr_rvalid),
        .m_axi_ddr_rready(m_axi_ddr_rready)
    );

    // Map I-Cache to BRAM
    assign bram_imem_clk  = clk;
    assign bram_imem_rst  = cpu_reset;
    assign bram_imem_en   = !mem_mode_ddr;
    assign bram_imem_we   = 4'b0000;
    assign bram_imem_addr = mem_mode_ddr ? 32'd0 : { {(32-ADDR_WIDTH-2){1'b0}}, icache_mem_addr, 2'b00 };
    assign bram_imem_din  = 32'b0;
    assign icache_mem_rdata = bram_imem_dout;

    // Map D-Cache to BRAM
    assign bram_dmem_clk  = clk;
    assign bram_dmem_rst  = cpu_reset;
    assign bram_dmem_en   = !mem_mode_ddr && (dcache_mem_read_en || dcache_mem_write_en);
    assign bram_dmem_we   = (!mem_mode_ddr && dcache_mem_write_en) ? dcache_mem_wstrb : 4'b0000;
    assign bram_dmem_addr = mem_mode_ddr ? 32'd0 : { {(32-ADDR_WIDTH-2){1'b0}}, dcache_mem_addr, 2'b00 };
    assign bram_dmem_din  = mem_mode_ddr ? 32'd0 : dcache_mem_write_data;
    assign dcache_mem_read_data = bram_dmem_dout;

endmodule

`endif
