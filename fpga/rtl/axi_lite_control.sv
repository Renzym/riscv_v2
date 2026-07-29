`ifndef AXI_LITE_CONTROL_SV
`define AXI_LITE_CONTROL_SV

`timescale 1ns/1ps

module axi_lite_control #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
) (
    input  logic                          S_AXI_ACLK,
    input  logic                          S_AXI_ARESETN,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic [2:0]                    S_AXI_AWPROT,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,
    input  logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  logic                          S_AXI_WVALID,
    output logic                          S_AXI_WREADY,
    output logic [1:0]                    S_AXI_BRESP,
    output logic                          S_AXI_BVALID,
    input  logic                          S_AXI_BREADY,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic [2:0]                    S_AXI_ARPROT,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,
    output logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY,

    output logic cpu_reset_ext,
    input  logic cpu_running
);

    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic                          axi_awready;
    logic                          axi_wready;
    logic [1:0]                    axi_bresp;
    logic                          axi_bvalid;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic                          axi_arready;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    logic [1:0]                    axi_rresp;
    logic                          axi_rvalid;

    // Register map:
    // 0x0 (Control) : bit 0 = CPU Reset (1 = held in reset)
    // 0x4 (Status)  : bit 0 = CPU Running (read-only)
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    assign cpu_reset_ext = slv_reg0[0];

    // AWREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= '0;
        end else begin
            if (!axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= S_AXI_AWADDR;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // WREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (!axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
                axi_wready <= 1'b1;
            else
                axi_wready <= 1'b0;
        end
    end

    // Register write
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            slv_reg0 <= 32'h1; // CPU starts in reset
            slv_reg1 <= '0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID) begin
                if (axi_awaddr[3:2] == 2'h0) begin
                    for (int i = 0; i <= (C_S_AXI_DATA_WIDTH/8)-1; i++)
                        if (S_AXI_WSTRB[i])
                            slv_reg0[(i*8) +: 8] <= S_AXI_WDATA[(i*8) +: 8];
                end
                // writes to 0x4, 0x8, 0xC are silently ignored
            end
            slv_reg1[0] <= cpu_running;
        end
    end

    // Write response
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID && !axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // ARREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= '0;
        end else begin
            if (!axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Read data
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b0;
            axi_rdata  <= '0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && !axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0;
                case (axi_araddr[3:2])
                    2'h0:    axi_rdata <= slv_reg0;
                    2'h1:    axi_rdata <= slv_reg1;
                    default: axi_rdata <= 32'h0;
                endcase
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

`endif
