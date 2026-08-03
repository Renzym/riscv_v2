`ifndef RISCV_DMEM_AXI_LITE_MASTER_SV
`define RISCV_DMEM_AXI_LITE_MASTER_SV

`timescale 1ns/1ps

module riscv_axi_lite_master #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32
) (
    input  logic                          clk,
    input  logic                          reset,

    input  logic                          req_read,
    input  logic                          req_write,
    input  logic [31:0]                   req_addr,
    input  logic [31:0]                   req_wdata,
    input  logic [3:0]                    req_wstrb,
    output logic                          req_ready,
    output logic [31:0]                   req_rdata,

    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_awaddr,
    output logic [2:0]                    m_axi_awprot,
    output logic                          m_axi_awvalid,
    input  logic                          m_axi_awready,
    output logic [AXI_DATA_WIDTH-1:0]     m_axi_wdata,
    output logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic                          m_axi_wvalid,
    input  logic                          m_axi_wready,
    input  logic [1:0]                    m_axi_bresp,
    input  logic                          m_axi_bvalid,
    output logic                          m_axi_bready,
    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_araddr,
    output logic [2:0]                    m_axi_arprot,
    output logic                          m_axi_arvalid,
    input  logic                          m_axi_arready,
    input  logic [AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    input  logic [1:0]                    m_axi_rresp,
    input  logic                          m_axi_rvalid,
    output logic                          m_axi_rready
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_WRITE_CMD,
        ST_WRITE_RESP,
        ST_READ_ADDR,
        ST_READ_DATA
    } state_t;

    state_t      state;
    logic [31:0] active_addr;
    logic [31:0] active_wdata;
    logic [3:0]  active_wstrb;
    logic        aw_done;
    logic        w_done;

    function automatic logic [31:0] aligned_word_addr(input logic [31:0] addr);
        aligned_word_addr = {addr[31:2], 2'b00};
    endfunction

    assign m_axi_awaddr  = active_addr[AXI_ADDR_WIDTH-1:0];
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awvalid = (state == ST_WRITE_CMD) && !aw_done;
    assign m_axi_wdata   = active_wdata[AXI_DATA_WIDTH-1:0];
    assign m_axi_wstrb   = active_wstrb[(AXI_DATA_WIDTH/8)-1:0];
    assign m_axi_wvalid  = (state == ST_WRITE_CMD) && !w_done;
    assign m_axi_bready  = (state == ST_WRITE_RESP);

    assign m_axi_araddr  = active_addr[AXI_ADDR_WIDTH-1:0];
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arvalid = (state == ST_READ_ADDR);
    assign m_axi_rready  = (state == ST_READ_DATA);

    assign req_ready = ((state == ST_WRITE_RESP) && m_axi_bvalid) ||
                       ((state == ST_READ_DATA)  && m_axi_rvalid);
    assign req_rdata = m_axi_rdata[31:0];

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= ST_IDLE;
            active_addr  <= 32'd0;
            active_wdata <= 32'd0;
            active_wstrb <= 4'd0;
            aw_done      <= 1'b0;
            w_done       <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;

                    if (req_write) begin
                        active_addr  <= aligned_word_addr(req_addr);
                        active_wdata <= req_wdata;
                        active_wstrb <= req_wstrb;
                        state        <= ST_WRITE_CMD;
                    end else if (req_read) begin
                        active_addr <= aligned_word_addr(req_addr);
                        state       <= ST_READ_ADDR;
                    end
                end

                ST_WRITE_CMD: begin
                    if (!aw_done && m_axi_awready)
                        aw_done <= 1'b1;
                    if (!w_done && m_axi_wready)
                        w_done <= 1'b1;
                    if ((aw_done || m_axi_awready) && (w_done || m_axi_wready))
                        state <= ST_WRITE_RESP;
                end

                ST_WRITE_RESP: begin
                    if (m_axi_bvalid)
                        state <= ST_IDLE;
                end

                ST_READ_ADDR: begin
                    if (m_axi_arready)
                        state <= ST_READ_DATA;
                end

                ST_READ_DATA: begin
                    if (m_axi_rvalid)
                        state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

`endif
