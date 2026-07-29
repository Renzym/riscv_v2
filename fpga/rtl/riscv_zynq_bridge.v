// riscv_zynq_bridge.v
// Plain Verilog-2001 wrapper to allow SystemVerilog module in Vivado Block Design

module riscv_zynq_bridge #(
    parameter ADDR_WIDTH         = 10,
    parameter RESET_PC = 32'h0000_0000,
    parameter NUM_EXT_INTERRUPTS = 32
) (
    input  wire        clk,
    input  wire        aresetn,
    input  wire [NUM_EXT_INTERRUPTS-1:0] global_interrupts,

    // AXI-Lite (Control/Status)
    input  wire [3:0]                           s_axi_ctrl_awaddr,
    input  wire [2:0]                           s_axi_ctrl_awprot,
    input  wire                                 s_axi_ctrl_awvalid,
    output wire                                 s_axi_ctrl_awready,
    input  wire [31:0]                          s_axi_ctrl_wdata,
    input  wire [3:0]                           s_axi_ctrl_wstrb,
    input  wire                                 s_axi_ctrl_wvalid,
    output wire                                 s_axi_ctrl_wready,
    output wire [1:0]                           s_axi_ctrl_bresp,
    output wire                                 s_axi_ctrl_bvalid,
    input  wire                                 s_axi_ctrl_bready,
    input  wire [3:0]                           s_axi_ctrl_araddr,
    input  wire [2:0]                           s_axi_ctrl_arprot,
    input  wire                                 s_axi_ctrl_arvalid,
    output wire                                 s_axi_ctrl_arready,
    output wire [31:0]                          s_axi_ctrl_rdata,
    output wire [1:0]                           s_axi_ctrl_rresp,
    output wire                                 s_axi_ctrl_rvalid,
    input  wire                                 s_axi_ctrl_rready,

    // BRAM - Instruction Memory
    output wire        bram_imem_clk,
    output wire        bram_imem_rst,
    output wire        bram_imem_en,
    output wire [3:0]  bram_imem_we,
    output wire [31:0] bram_imem_addr,
    output wire [31:0] bram_imem_din,
    input  wire [31:0] bram_imem_dout,

    // BRAM - Data Memory
    output wire        bram_dmem_clk,
    output wire        bram_dmem_rst,
    output wire        bram_dmem_en,
    output wire [3:0]  bram_dmem_we,
    output wire [31:0] bram_dmem_addr,
    output wire [31:0] bram_dmem_din,
    input  wire [31:0] bram_dmem_dout
);

    riscv_zynq_wrapper #(
        .ADDR_WIDTH        (ADDR_WIDTH),
        .RESET_PC          (RESET_PC),
        .NUM_EXT_INTERRUPTS(NUM_EXT_INTERRUPTS)
    ) sv_inst (
        .clk               (clk),
        .aresetn           (aresetn),
        .global_interrupts (global_interrupts),
        .s_axi_ctrl_awaddr (s_axi_ctrl_awaddr),
        .s_axi_ctrl_awprot (s_axi_ctrl_awprot),
        .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
        .s_axi_ctrl_awready(s_axi_ctrl_awready),
        .s_axi_ctrl_wdata  (s_axi_ctrl_wdata),
        .s_axi_ctrl_wstrb  (s_axi_ctrl_wstrb),
        .s_axi_ctrl_wvalid (s_axi_ctrl_wvalid),
        .s_axi_ctrl_wready (s_axi_ctrl_wready),
        .s_axi_ctrl_bresp  (s_axi_ctrl_bresp),
        .s_axi_ctrl_bvalid (s_axi_ctrl_bvalid),
        .s_axi_ctrl_bready (s_axi_ctrl_bready),
        .s_axi_ctrl_araddr (s_axi_ctrl_araddr),
        .s_axi_ctrl_arprot (s_axi_ctrl_arprot),
        .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
        .s_axi_ctrl_arready(s_axi_ctrl_arready),
        .s_axi_ctrl_rdata  (s_axi_ctrl_rdata),
        .s_axi_ctrl_rresp  (s_axi_ctrl_rresp),
        .s_axi_ctrl_rvalid (s_axi_ctrl_rvalid),
        .s_axi_ctrl_rready (s_axi_ctrl_rready),
        .bram_imem_clk     (bram_imem_clk),
        .bram_imem_rst     (bram_imem_rst),
        .bram_imem_en      (bram_imem_en),
        .bram_imem_we      (bram_imem_we),
        .bram_imem_addr    (bram_imem_addr),
        .bram_imem_din     (bram_imem_din),
        .bram_imem_dout    (bram_imem_dout),
        .bram_dmem_clk     (bram_dmem_clk),
        .bram_dmem_rst     (bram_dmem_rst),
        .bram_dmem_en      (bram_dmem_en),
        .bram_dmem_we      (bram_dmem_we),
        .bram_dmem_addr    (bram_dmem_addr),
        .bram_dmem_din     (bram_dmem_din),
        .bram_dmem_dout    (bram_dmem_dout)
    );

endmodule
