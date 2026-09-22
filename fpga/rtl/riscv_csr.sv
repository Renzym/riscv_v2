// SPDX-License-Identifier: MIT
//
// Copyright (c) 2026 Renzym Private limited

// ============================================================================
// riscv_csr.sv  -  machine-mode CSR file + trap state
//   Holds mstatus, mie, mtvec, mscratch, mepc, mcause, mtval. Combinational read;
//   synchronous write from EX (CSR instructions) and trap capture
//   (ECALL / EBREAK / misaligned load/store).
// ============================================================================
`ifndef RISCV_CSR_SV
`define RISCV_CSR_SV

`timescale 1ns/1ps

module riscv_csr #(
    parameter int unsigned NUM_EXT_INTERRUPTS = 32
) (
    input  logic        clk,
    input  logic        reset,
    input  logic [NUM_EXT_INTERRUPTS-1:0] global_interrupts,

    // read port (decode)
    input  logic [11:0] raddr,
    output logic [31:0] rdata,

    // write port (EX: CSR instruction)
    input  logic        we,
    input  logic [11:0] waddr,
    input  logic [31:0] wdata,

    // trap capture (EX: ECALL / EBREAK / misaligned access)
    input  logic        trap_en,
    input  logic [31:0] trap_epc,
    input  logic [31:0] trap_cause,
    input  logic [31:0] trap_tval,

    // MRET commit (EX)
    input  logic        mret_en,

    // exposed for redirect targets
    output logic [31:0] mtvec,
    output logic [31:0] mepc,
    output logic        external_irq_active
);
    import riscv_pkg::*;

    logic [31:0] csr_mtvec;
    logic [31:0] csr_mie;
    logic [31:0] csr_mscratch;
    logic [31:0] csr_mepc;
    logic [31:0] csr_mcause;
    logic [31:0] csr_mtval;
    logic [31:0] csr_meimask;
    logic [31:0] csr_meipend;
    logic [31:0] ext_irq_mask;

    // mstatus is stored as its individual implemented fields.
    // ORCA-compatible interrupt return restores MIE from MPIE and clears MPIE.
    logic        mstatus_mie;   // bit 3
    logic        mstatus_mpie;  // bit 7
    logic [1:0]  mstatus_mpp;   // bits 12:11

    logic [31:0] mstatus_rd;
    assign mstatus_rd = {19'd0, mstatus_mpp, 3'd0, mstatus_mpie, 3'd0, mstatus_mie, 3'd0};

    assign mtvec = csr_mtvec;
    assign mepc  = csr_mepc;
    assign ext_irq_mask = (NUM_EXT_INTERRUPTS >= 32) ? 32'hffff_ffff : ((32'd1 << NUM_EXT_INTERRUPTS) - 32'd1);
    assign external_irq_active = mstatus_mie && ((csr_meimask & csr_meipend) != 32'd0);

    always_comb begin
        case (raddr)
            CSR_MSTATUS:  rdata = mstatus_rd;
            CSR_MIE:      rdata = csr_mie;
            CSR_MTVEC:    rdata = csr_mtvec;
            CSR_MSCRATCH: rdata = csr_mscratch;
            CSR_MEPC:     rdata = csr_mepc;
            CSR_MCAUSE:   rdata = csr_mcause;
            CSR_MTVAL:    rdata = csr_mtval;
            CSR_MIP:      rdata = (csr_meipend != 32'd0) ? (32'd1 << MIP_MEIP_BIT) : 32'd0;
            CSR_MEIMASK:  rdata = csr_meimask;
            CSR_MEIPEND:  rdata = csr_meipend;
            default:      rdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            csr_mtvec    <= 32'd0;
            csr_mie      <= 32'd0;
            csr_mscratch <= 32'd0;
            csr_mepc     <= 32'd0;
            csr_mcause   <= 32'd0;
            csr_mtval    <= 32'd0;
            csr_meimask  <= 32'd0;
            csr_meipend  <= 32'd0;
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mstatus_mpp  <= 2'b00;
        end else begin
            csr_meipend <= 32'd0;
            for (int i = 0; i < NUM_EXT_INTERRUPTS; i++) begin
                csr_meipend[i] <= global_interrupts[i];
            end

            if (we) begin
                case (waddr)
                    CSR_MSTATUS: begin
                        mstatus_mie  <= wdata[MSTATUS_MIE_BIT];
                        mstatus_mpie <= wdata[MSTATUS_MPIE_BIT];
                        mstatus_mpp  <= wdata[12:11];
                    end
                    CSR_MIE: begin
                        csr_mie <= wdata & (32'd1 << MIE_MEIE_BIT);
                    end
                    CSR_MTVEC:    csr_mtvec    <= wdata;
                    CSR_MSCRATCH: csr_mscratch <= wdata;
                    // mepc[1:0] hardwired to 0 (IALIGN=32, matches Spike)
                    CSR_MEPC:     csr_mepc     <= wdata & 32'hffff_fffc;
                    CSR_MCAUSE:   csr_mcause   <= wdata;
                    CSR_MTVAL:    csr_mtval    <= wdata;
                    CSR_MIP:      begin end // MEIP is driven by external_irq, not writable
                    CSR_MEIMASK:  csr_meimask  <= wdata & ext_irq_mask;
                    CSR_MEIPEND:  begin end // ORCA pending bits are driven by global_interrupts
                    default: begin end
                endcase
            end
            // trap capture wins over a same-cycle CSR write
            if (trap_en) begin
                csr_mepc     <= trap_epc;
                csr_mcause   <= trap_cause;
                csr_mtval    <= trap_tval;
                mstatus_mpie <= mstatus_mie;
                mstatus_mie  <= 1'b0;
                mstatus_mpp  <= 2'b11;
            end else if (mret_en) begin
                mstatus_mie  <= mstatus_mpie;
                mstatus_mpie <= 1'b0;
                mstatus_mpp  <= 2'b00;
            end
        end
    end

endmodule

`endif
