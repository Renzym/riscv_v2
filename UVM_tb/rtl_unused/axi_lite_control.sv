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

    output logic                          cpu_reset_ext,
    output logic                          mem_mode_ddr,
    output logic [31:0]                   ddr_imem_base,
    output logic [31:0]                   ddr_dmem_base,
    input  logic                          cpu_running
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

    // Registers
    // 0x0: Control Register
    //      Bit 0: CPU Reset
    //      Bit 1: Memory Mode (0 = BRAM, 1 = DDR)
    // 0x4: Status Register
    //      Bit 0: CPU Running
    //      Bit 1: Active Memory Mode (0 = BRAM, 1 = DDR)
    // 0x8: DDR Instruction Memory Base Address
    // 0xC: DDR Data Memory Base Address
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    assign cpu_reset_ext = slv_reg0[0];
    assign mem_mode_ddr  = slv_reg0[1];
    assign ddr_imem_base = slv_reg2;
    assign ddr_dmem_base = slv_reg3;

    // AWREADY logic
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

    // WREADY logic
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (!axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // Register Write logic
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            slv_reg0 <= 32'h1; // Default: CPU in reset
            slv_reg1 <= '0;
            slv_reg2 <= 32'h1000_0000;
            slv_reg3 <= 32'h1001_0000;
        end else begin
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID) begin
                case (axi_awaddr[3:2])
                    2'h0: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index])
                                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    end
                    2'h1: begin
                        // slv_reg1 is read-only from AXI side
                    end
                    2'h2: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index])
                                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    end
                    2'h3: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index])
                                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    end
                endcase
            end
            slv_reg1[0] <= cpu_running;
            slv_reg1[1] <= slv_reg0[1];
        end
    end

    // Write Response logic
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

    // ARREADY logic
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

    // Read Data logic
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
                    2'h0: axi_rdata <= slv_reg0;
                    2'h1: axi_rdata <= slv_reg1;
                    2'h2: axi_rdata <= slv_reg2;
                    2'h3: axi_rdata <= slv_reg3;
                    default: axi_rdata <= 32'hDEADBEEF;
                endcase
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

`endif
