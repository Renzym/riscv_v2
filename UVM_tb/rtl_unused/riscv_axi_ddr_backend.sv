`ifndef RISCV_AXI_DDR_BACKEND_SV
`define RISCV_AXI_DDR_BACKEND_SV

`timescale 1ns/1ps

module riscv_axi_ddr_backend #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32
) (
    input  logic                          clk,
    input  logic                          reset,

    input  logic                          imem_req,
    input  logic [31:0]                   imem_addr,
    output logic                          imem_ready,
    output logic [31:0]                   imem_rdata,

    input  logic [31:0]                   dmem_addr,
    input  logic [31:0]                   dmem_write_data,
    input  logic [3:0]                    dmem_wstrb,
    input  logic                          dmem_read_en,
    input  logic                          dmem_write_en,
    output logic                          dmem_ready,
    output logic [31:0]                   dmem_read_data,

    input  logic [31:0]                   ddr_imem_base,
    input  logic [31:0]                   ddr_dmem_base,

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

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_READ_ADDR,
        ST_READ_DATA,
        ST_WRITE_CMD,
        ST_WRITE_RESP
    } state_t;

    localparam logic [2:0] AXI_WORD_SIZE = 3'd2;

    state_t                  state;
    logic                    active_is_imem;
    logic [31:0]             active_addr;
    logic [31:0]             active_wdata;
    logic [3:0]              active_wstrb;
    logic                    aw_sent;
    logic                    w_sent;
    logic                    read_error;
    logic                    write_error;
    logic                    read_resp_fire;
    logic                    write_resp_fire;

    function automatic logic [31:0] aligned_word_addr(input logic [31:0] addr);
        aligned_word_addr = {addr[31:2], 2'b00};
    endfunction

    assign m_axi_ddr_awaddr  = active_addr[AXI_ADDR_WIDTH-1:0];
    assign m_axi_ddr_awprot  = 3'b000;
    assign m_axi_ddr_awlen   = 8'd0;
    assign m_axi_ddr_awsize  = AXI_WORD_SIZE;
    assign m_axi_ddr_awburst = 2'b01;
    assign m_axi_ddr_awvalid = (state == ST_WRITE_CMD) && !aw_sent;

    assign m_axi_ddr_wdata   = active_wdata[AXI_DATA_WIDTH-1:0];
    assign m_axi_ddr_wstrb   = active_wstrb[(AXI_DATA_WIDTH/8)-1:0];
    assign m_axi_ddr_wlast   = 1'b1;
    assign m_axi_ddr_wvalid  = (state == ST_WRITE_CMD) && !w_sent;

    assign m_axi_ddr_bready  = (state == ST_WRITE_RESP);

    assign m_axi_ddr_araddr  = active_addr[AXI_ADDR_WIDTH-1:0];
    assign m_axi_ddr_arprot  = 3'b000;
    assign m_axi_ddr_arlen   = 8'd0;
    assign m_axi_ddr_arsize  = AXI_WORD_SIZE;
    assign m_axi_ddr_arburst = 2'b01;
    assign m_axi_ddr_arvalid = (state == ST_READ_ADDR);

    assign m_axi_ddr_rready  = (state == ST_READ_DATA);

    assign read_resp_fire  = (state == ST_READ_DATA) && m_axi_ddr_rvalid;
    assign write_resp_fire = (state == ST_WRITE_RESP) && m_axi_ddr_bvalid;

    assign imem_ready = read_resp_fire && active_is_imem;
    assign imem_rdata = m_axi_ddr_rdata[31:0];

    assign dmem_ready = (read_resp_fire && !active_is_imem) || write_resp_fire;
    assign dmem_read_data = m_axi_ddr_rdata[31:0];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_IDLE;
            active_is_imem <= 1'b0;
            active_addr <= '0;
            active_wdata <= '0;
            active_wstrb <= '0;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
            read_error <= 1'b0;
            write_error <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    aw_sent <= 1'b0;
                    w_sent <= 1'b0;

                    if (dmem_write_en) begin
                        active_is_imem <= 1'b0;
                        active_addr <= ddr_dmem_base + aligned_word_addr(dmem_addr);
                        active_wdata <= dmem_write_data;
                        active_wstrb <= dmem_wstrb;
                        state <= ST_WRITE_CMD;
                    end else if (dmem_read_en) begin
                        active_is_imem <= 1'b0;
                        active_addr <= ddr_dmem_base + aligned_word_addr(dmem_addr);
                        state <= ST_READ_ADDR;
                    end else if (imem_req) begin
                        active_is_imem <= 1'b1;
                        active_addr <= ddr_imem_base + aligned_word_addr(imem_addr);
                        state <= ST_READ_ADDR;
                    end
                end

                ST_READ_ADDR: begin
                    if (m_axi_ddr_arready) begin
                        state <= ST_READ_DATA;
                    end
                end

                ST_READ_DATA: begin
                    if (m_axi_ddr_rvalid) begin
                        read_error <= (m_axi_ddr_rresp != 2'b00);
                        state <= ST_IDLE;
                    end
                end

                ST_WRITE_CMD: begin
                    if (!aw_sent && m_axi_ddr_awready)
                        aw_sent <= 1'b1;
                    if (!w_sent && m_axi_ddr_wready)
                        w_sent <= 1'b1;

                    if ((aw_sent || m_axi_ddr_awready) && (w_sent || m_axi_ddr_wready)) begin
                        state <= ST_WRITE_RESP;
                    end
                end

                ST_WRITE_RESP: begin
                    if (m_axi_ddr_bvalid) begin
                        write_error <= (m_axi_ddr_bresp != 2'b00);
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

`endif
