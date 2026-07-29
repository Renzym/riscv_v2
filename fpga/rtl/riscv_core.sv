// ============================================================================
// riscv_core.sv  -  top level of the 5-stage RV32IM core
//
//   IF  -> ID -> EX -> MEM -> WB
//
//   This file holds the pipeline registers and the EX-stage control
//   (forwarding muxes, branch/redirect/trap generation). The functional
//   blocks live in their own modules:
//     riscv_decode   instruction decode + immediate
//     riscv_regfile  32x32 register file (with WB bypass)
//     riscv_alu      arithmetic/logic unit
//     riscv_csr      machine-mode CSRs + trap state
//     riscv_lsu      load/store data formatting
//     riscv_hazard   forwarding selects + load-use stalls
// ============================================================================
`ifndef RISCV_CORE_SV
`define RISCV_CORE_SV

`timescale 1ns/1ps

module riscv_core #(
    parameter logic [31:0] RESET_PC = 32'h0,   // PC value out of reset (FPGA/my_uvm use 0)
    // Load/store access-fault checking (cause 5/7). Disabled by default so
    // FPGA behavior is unchanged; the UVM testbench enables it with bounds
    // matching Spike's memory map.
    parameter logic        TRAP_ACCESS_FAULTS = 1'b0,
    parameter logic [31:0] DMEM_BASE  = 32'h8000_0000,  // valid data range [BASE, LIMIT)
    parameter logic [31:0] DMEM_LIMIT = 32'h8002_0000,
    parameter int unsigned NUM_EXT_INTERRUPTS = 32
) (
    input  logic        clk,
    input  logic        reset,
    input  logic [NUM_EXT_INTERRUPTS-1:0] global_interrupts,

    output logic        imem_req,
    output logic [31:0] imem_addr,
    input  logic        imem_ready,
    input  logic [31:0] imem_instr,
    input  logic [31:0] imem_resp_pc,
    output logic        imem_resp_accept,

    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_write_data,
    output logic [3:0]  dmem_wstrb,
    output logic        dmem_read_en,
    output logic        dmem_write_en,
    input  logic        dmem_ready,
    input  logic [31:0] dmem_read_data
);
    import riscv_pkg::*;

    // ------------------------------------------------------------------
    // Pipeline registers
    // ------------------------------------------------------------------
    logic [31:0] pc_f;
    logic        if_pending_valid;
    logic        if_discard_pending;
    logic        if_buf_valid;
    logic [31:0] if_buf_instr;
    logic [31:0] if_buf_pc;

    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instr;

    logic        id_ex_valid;
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_pc4;
    logic [31:0] id_ex_rs1_data;
    logic [31:0] id_ex_rs2_data;
    logic [31:0] id_ex_imm;
    logic [31:0] id_ex_redirect_target;
    logic [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;
    logic        id_ex_use_rs1, id_ex_use_rs2;
    logic        id_ex_src_a_pc, id_ex_src_b_imm;
    logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
    logic [1:0]  id_ex_mem_size;
    logic        id_ex_mem_unsigned;
    logic        id_ex_jal, id_ex_jalr;
    logic [2:0]  id_ex_branch_kind;
    logic [1:0]  id_ex_wb_sel;
    logic [4:0]  id_ex_alu_op;
    logic        id_ex_is_ecall, id_ex_is_ebreak, id_ex_is_mret;
    logic        id_ex_csr_read, id_ex_csr_write;
    logic [11:0] id_ex_csr_addr;
    logic [31:0] id_ex_csr_old;

    logic        ex_mem_valid;
    logic [31:0] ex_mem_pc4;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;
    logic [1:0]  ex_mem_wb_sel;
    logic        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    logic [1:0]  ex_mem_mem_size;
    logic        ex_mem_mem_unsigned;
    logic [31:0] ex_mem_csr_old;

    logic        mem_wb_valid;
    logic [31:0] mem_wb_pc4;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;
    logic [31:0] mem_wb_csr_old;
    logic [4:0]  mem_wb_rd;
    logic [1:0]  mem_wb_wb_sel;
    logic        mem_wb_reg_write;

    // ------------------------------------------------------------------
    // Decode-stage wires (from riscv_decode)
    // ------------------------------------------------------------------
    logic [4:0]  id_rs1, id_rs2, id_rd;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [11:0] id_csr_addr;
    logic [31:0] id_imm;
    logic        id_use_rs1, id_use_rs2, id_src_a_pc, id_src_b_imm;
    logic        id_reg_write, id_mem_read, id_mem_write;
    logic [1:0]  id_mem_size;
    logic        id_mem_unsigned, id_jal, id_jalr;
    logic [2:0]  id_branch_kind;
    logic [1:0]  id_wb_sel;
    logic [4:0]  id_alu_op;
    logic        id_is_ecall, id_is_ebreak, id_is_mret;
    logic        id_csr_read, id_csr_write;

    logic [31:0] id_rs1_data, id_rs2_data, id_csr_old;
    logic [31:0] id_redirect_target;

    // ------------------------------------------------------------------
    // Control / EX wires
    // ------------------------------------------------------------------
    logic        stall_if_hazard, stall_id_hazard, bubble_ex, mem_stall;
    logic        load_use_hold_q;
    logic        m_stall, mul_stall, div_stall;
    logic stall_if;
    logic stall_id;
    logic id_ex_flush_ctrl;
    logic id_ex_en_ctrl, id_ex_en_data;
    logic pc_f_en;
    logic [1:0]  id_forward_a_sel, id_forward_b_sel;
    logic [1:0]  id_ex_forward_a_sel, id_ex_forward_b_sel;
    logic [31:0] pc_f_next;
    logic        if_resp_valid;
    logic [31:0] if_resp_instr;
    logic [31:0] if_resp_pc;
    logic        if_live_resp_valid;
    logic        if_accept;
    logic [31:0] ex_forward_a_data, ex_forward_b_data;
    logic [31:0] ex_alu_src_a, ex_alu_src_b, ex_alu_base_result;
    logic [31:0] ex_alu_result, ex_store_data;
    logic [1:0]  ex_addr_lo;
    logic        ex_branch_cond;
    logic        ex_redirect;
    logic [31:0] ex_redirect_target;
    logic        ex_is_trap;
    logic [31:0] ex_trap_cause;
    logic [31:0] ex_trap_tval;
    logic        ex_misalign_load, ex_misalign_store;
    logic        ex_access_load, ex_access_store;
    logic        ex_csr_write_en;
    logic [11:0] ex_csr_write_addr;
    logic [31:0] ex_csr_write_data;
    logic [31:0] ex_mem_forward_data;

    logic [31:0] mem_load_data;
    logic [31:0] wb_data;

    logic [31:0] csr_mtvec, csr_mepc;
    logic        csr_external_irq_active;

    // Iterative RV32M divider state. One quotient bit is produced per cycle,
    // avoiding the very long combinational / and % paths inferred by Vivado.
    logic        div_is_op, div_start, div_busy, div_done;
    logic [4:0]  div_op;
    logic [5:0]  div_count;
    logic [31:0] div_dividend, div_divisor, div_quotient;
    logic [32:0] div_remainder;
    logic        div_quotient_neg, div_remainder_neg;
    logic [31:0] div_result;
    logic [32:0] div_trial_remainder, div_next_remainder;
    logic [31:0] div_next_quotient;
    logic        div_subtract;

    // MUL operands are registered before the DSP operation so Vivado can use
    // the DSP input/output pipeline registers at a 100 MHz core clock.
    logic        mul_is_op, mul_start, mul_busy, mul_done;
    logic [4:0]  mul_op;
    logic signed [32:0] mul_a_reg, mul_b_reg;
    logic signed [65:0] mul_product;
    logic [31:0] mul_result;

    // ==================================================================
    // IF stage
    // ==================================================================
    assign imem_addr  = pc_f;
    assign mem_stall  = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write) && !dmem_ready;
    assign stall_if   = stall_if_hazard || load_use_hold_q || m_stall;
    assign stall_id   = stall_id_hazard || load_use_hold_q || m_stall;
    assign id_ex_flush_ctrl = ex_redirect || (bubble_ex && !m_stall);
    assign id_ex_en_ctrl    = !stall_id;
    assign id_ex_en_data    = !stall_id;
    assign if_live_resp_valid = imem_ready && if_pending_valid &&
                                !if_discard_pending;
    assign if_resp_valid = if_buf_valid || if_live_resp_valid;
    assign if_resp_instr = if_buf_valid ? if_buf_instr : imem_instr;
    assign if_resp_pc    = if_buf_valid ? if_buf_pc    : imem_resp_pc;
    assign if_accept     = !mem_stall && !stall_if && if_resp_valid &&
                           !ex_redirect;
    assign imem_resp_accept = imem_ready &&
                              (if_pending_valid || if_discard_pending || ex_redirect);
    assign pc_f_en     = !mem_stall && (ex_redirect || if_accept);
    assign pc_f_next   = ex_redirect ? ex_redirect_target : (pc_f + 32'd4);
    // Do not launch the next IMEM read while IF is accepting a response. At
    // that clock edge pc_f advances, so a request in the same cycle would
    // capture the old address and replay the previous instruction.
    assign imem_req   = !reset && !mem_stall && !stall_if &&
                        !ex_redirect && !if_resp_valid &&
                        !if_pending_valid && !if_discard_pending;

    // ==================================================================
    // ID stage : decode + register file + CSR read
    // ==================================================================
    riscv_decode u_decode (
        .instr        (if_id_instr),
        .rs1          (id_rs1),
        .rs2          (id_rs2),
        .rd           (id_rd),
        .funct3       (id_funct3),
        .funct7       (id_funct7),
        .csr_addr     (id_csr_addr),
        .imm          (id_imm),
        .use_rs1      (id_use_rs1),
        .use_rs2      (id_use_rs2),
        .src_a_pc     (id_src_a_pc),
        .src_b_imm    (id_src_b_imm),
        .reg_write    (id_reg_write),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .mem_size     (id_mem_size),
        .mem_unsigned (id_mem_unsigned),
        .jal          (id_jal),
        .jalr         (id_jalr),
        .branch_kind  (id_branch_kind),
        .wb_sel       (id_wb_sel),
        .alu_op       (id_alu_op),
        .is_ecall     (id_is_ecall),
        .is_ebreak    (id_is_ebreak),
        .is_mret      (id_is_mret),
        .csr_read     (id_csr_read),
        .csr_write    (id_csr_write)
    );

    riscv_regfile u_regfile (
        .clk    (clk),
        .reset  (reset),
        .we     (mem_wb_valid && mem_wb_reg_write),
        .waddr  (mem_wb_rd),
        .wdata  (wb_data),
        .raddr1 (id_rs1),
        .raddr2 (id_rs2),
        .rdata1 (id_rs1_data),
        .rdata2 (id_rs2_data)
    );

    // Precompute PC-relative redirect targets one stage earlier so EX-stage
    // branch/jump resolution does not also need a wide PC+imm adder.
    assign id_redirect_target = if_id_pc + id_imm;

    riscv_csr #(
        .NUM_EXT_INTERRUPTS(NUM_EXT_INTERRUPTS)
    ) u_csr (
        .clk        (clk),
        .reset      (reset),
        .global_interrupts(global_interrupts),
        .raddr      (id_csr_addr),
        .rdata      (id_csr_old),
        .we         (id_ex_valid && ex_csr_write_en),
        .waddr      (ex_csr_write_addr),
        .wdata      (ex_csr_write_data),
        .trap_en    (id_ex_valid && ex_is_trap),
        .trap_epc   (id_ex_pc),
        .trap_cause (ex_trap_cause),
        .trap_tval  (ex_trap_tval),
        .mret_en    (id_ex_valid && !mem_stall && id_ex_is_mret),
        .mtvec      (csr_mtvec),
        .mepc       (csr_mepc),
        .external_irq_active(csr_external_irq_active)
    );

    // ==================================================================
    // Hazard / forwarding control
    // ==================================================================
    riscv_hazard u_hazard (
        .if_id_valid      (if_id_valid),
        .id_use_rs1       (id_use_rs1),
        .id_use_rs2       (id_use_rs2),
        .id_rs1           (id_rs1),
        .id_rs2           (id_rs2),
        .id_ex_valid      (id_ex_valid),
        .id_ex_use_rs1    (id_ex_use_rs1),
        .id_ex_use_rs2    (id_ex_use_rs2),
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .id_ex_reg_write  (id_ex_reg_write),
        .id_ex_mem_read   (id_ex_mem_read),
        .id_ex_rd         (id_ex_rd),
        .ex_mem_valid     (ex_mem_valid),
        .ex_mem_reg_write (ex_mem_reg_write),
        .ex_mem_mem_read  (ex_mem_mem_read),
        .ex_mem_rd        (ex_mem_rd),
        .mem_wb_valid     (mem_wb_valid),
        .mem_wb_reg_write (mem_wb_reg_write),
        .mem_wb_rd        (mem_wb_rd),
        .forward_a_sel    (id_forward_a_sel),
        .forward_b_sel    (id_forward_b_sel),
        .stall_if         (stall_if_hazard),
        .stall_id         (stall_id_hazard),
        .bubble_ex        (bubble_ex)
    );

    // ==================================================================
    // EX stage
    // ==================================================================
    always_comb begin
        case (ex_mem_wb_sel)
            WB_PC4:  ex_mem_forward_data = ex_mem_pc4;
            WB_CSR:  ex_mem_forward_data = ex_mem_csr_old;
            default: ex_mem_forward_data = ex_mem_alu_result;
        endcase
    end

    always_comb begin
        case (id_ex_forward_a_sel)
            2'b01:   ex_forward_a_data = ex_mem_forward_data;
            2'b10:   ex_forward_a_data = wb_data;
            default: ex_forward_a_data = id_ex_rs1_data;
        endcase

        case (id_ex_forward_b_sel)
            2'b01:   ex_forward_b_data = ex_mem_forward_data;
            2'b10:   ex_forward_b_data = wb_data;
            default: ex_forward_b_data = id_ex_rs2_data;
        endcase
    end

    assign ex_alu_src_a  = id_ex_src_a_pc  ? id_ex_pc  : ex_forward_a_data;
    assign ex_alu_src_b  = id_ex_src_b_imm ? id_ex_imm : ex_forward_b_data;
    assign ex_store_data = ex_forward_b_data;
    assign ex_addr_lo    = ex_alu_src_a[1:0] + ex_alu_src_b[1:0];
    assign div_is_op     = (id_ex_alu_op == ALU_DIV)  ||
                           (id_ex_alu_op == ALU_DIVU) ||
                           (id_ex_alu_op == ALU_REM)  ||
                           (id_ex_alu_op == ALU_REMU);
    assign div_start     = id_ex_valid && div_is_op && !div_busy &&
                           !div_done && !mem_stall;
    assign div_stall     = id_ex_valid && div_is_op && !div_done;
    assign mul_is_op     = (id_ex_alu_op == ALU_MUL)    ||
                           (id_ex_alu_op == ALU_MULH)   ||
                           (id_ex_alu_op == ALU_MULHSU) ||
                           (id_ex_alu_op == ALU_MULHU);
    assign mul_start     = id_ex_valid && mul_is_op && !mul_busy &&
                           !mul_done && !mem_stall;
    assign mul_stall     = id_ex_valid && mul_is_op && !mul_done;
    assign m_stall       = mul_stall || div_stall;
    assign mul_result    = (mul_op == ALU_MUL)
                         ? mul_product[31:0] : mul_product[63:32];
    assign ex_alu_result = div_is_op ? div_result :
                           mul_is_op ? mul_result : ex_alu_base_result;

    assign div_trial_remainder = {div_remainder[31:0], div_dividend[31]};
    assign div_subtract        = div_trial_remainder >= {1'b0, div_divisor};
    assign div_next_remainder  = div_subtract
                               ? div_trial_remainder - {1'b0, div_divisor}
                               : div_trial_remainder;
    assign div_next_quotient   = {div_quotient[30:0], div_subtract};

    riscv_alu u_alu (
        .alu_op (id_ex_alu_op),
        .a      (ex_alu_src_a),
        .b      (ex_alu_src_b),
        .result (ex_alu_base_result)
    );

    // branch condition
    always_comb begin
        case (id_ex_branch_kind)
            BR_EQ:  ex_branch_cond = (ex_forward_a_data == ex_forward_b_data);
            BR_NE:  ex_branch_cond = (ex_forward_a_data != ex_forward_b_data);
            BR_LT:  ex_branch_cond = ($signed(ex_forward_a_data) <  $signed(ex_forward_b_data));
            BR_GE:  ex_branch_cond = ($signed(ex_forward_a_data) >= $signed(ex_forward_b_data));
            BR_LTU: ex_branch_cond = (ex_forward_a_data <  ex_forward_b_data);
            BR_GEU: ex_branch_cond = (ex_forward_a_data >= ex_forward_b_data);
            default: ex_branch_cond = 1'b0;
        endcase
    end

    // misaligned load/store detection. Only address bits [1:0] are needed,
    // so use a small local adder instead of pulling in the full ALU carry path.
    always_comb begin
        ex_misalign_load  = 1'b0;
        ex_misalign_store = 1'b0;
        if (id_ex_mem_read || id_ex_mem_write) begin
            case (id_ex_mem_size)
                2'd1: if (ex_addr_lo[0])        begin ex_misalign_load = id_ex_mem_read; ex_misalign_store = id_ex_mem_write; end
                2'd2: if (ex_addr_lo != 2'b00)  begin ex_misalign_load = id_ex_mem_read; ex_misalign_store = id_ex_mem_write; end
                default: begin end
            endcase
        end
    end

    // load/store access-fault detection (checked after alignment, like Spike)
    always_comb begin
        ex_access_load  = 1'b0;
        ex_access_store = 1'b0;
        if (TRAP_ACCESS_FAULTS &&
            (ex_alu_result < DMEM_BASE || ex_alu_result >= DMEM_LIMIT)) begin
            ex_access_load  = id_ex_mem_read  && !ex_misalign_load;
            ex_access_store = id_ex_mem_write && !ex_misalign_store;
        end
    end

    // redirect / trap / CSR-write generation
    always_comb begin
        ex_redirect        = 1'b0;
        ex_redirect_target = 32'd0;
        ex_is_trap         = 1'b0;
        ex_trap_cause      = 32'd0;
        ex_trap_tval       = 32'd0;
        ex_csr_write_en    = 1'b0;
        ex_csr_write_addr  = id_ex_csr_addr;
        ex_csr_write_data  = 32'd0;

        if (!mem_stall && !m_stall && id_ex_valid) begin
            if (id_ex_csr_read) begin
                case (id_ex_funct3)
                    3'b001: begin ex_csr_write_en = 1'b1;               ex_csr_write_data = ex_forward_a_data; end
                    3'b010: begin ex_csr_write_en = (id_ex_rs1 != 5'd0); ex_csr_write_data = id_ex_csr_old |  ex_forward_a_data; end
                    3'b011: begin ex_csr_write_en = (id_ex_rs1 != 5'd0); ex_csr_write_data = id_ex_csr_old & ~ex_forward_a_data; end
                    3'b101: begin ex_csr_write_en = 1'b1;               ex_csr_write_data = {27'd0, id_ex_rs1}; end
                    3'b110: begin ex_csr_write_en = (id_ex_rs1 != 5'd0); ex_csr_write_data = id_ex_csr_old |  {27'd0, id_ex_rs1}; end
                    3'b111: begin ex_csr_write_en = (id_ex_rs1 != 5'd0); ex_csr_write_data = id_ex_csr_old & ~{27'd0, id_ex_rs1}; end
                    default: begin ex_csr_write_en = 1'b0;              ex_csr_write_data = 32'd0; end
                endcase
            end

            if (id_ex_is_ecall) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_ECALL_M;
                ex_trap_tval = 32'd0;
            end else if (id_ex_is_ebreak) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_BREAKPOINT;
                ex_trap_tval = id_ex_pc;   // Spike: mtval = PC of the ebreak
            end else if (ex_misalign_load) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_LOAD_MISALIGNED;
                ex_trap_tval = ex_alu_result;  // faulting address
            end else if (ex_misalign_store) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_STORE_MISALIGNED;
                ex_trap_tval = ex_alu_result;  // faulting address
            end else if (ex_access_load) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_LOAD_ACCESS;
                ex_trap_tval = ex_alu_result;  // faulting address
            end else if (ex_access_store) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_STORE_ACCESS;
                ex_trap_tval = ex_alu_result;  // faulting address
            end else if (csr_external_irq_active) begin
                ex_redirect = 1'b1; ex_redirect_target = {csr_mtvec[31:2], 2'b00}; ex_is_trap = 1'b1; ex_trap_cause = CAUSE_MACHINE_EXTERNAL_INTERRUPT;
                ex_trap_tval = 32'd0;
            end else if (id_ex_is_mret) begin
                ex_redirect = 1'b1; ex_redirect_target = csr_mepc;
            end else if (id_ex_jalr) begin
                ex_redirect = 1'b1; ex_redirect_target = (ex_forward_a_data + id_ex_imm) & 32'hffff_fffe;
            end else if (id_ex_jal) begin
                ex_redirect = 1'b1; ex_redirect_target = id_ex_redirect_target;
            end else if ((id_ex_branch_kind != BR_NONE) && ex_branch_cond) begin
                ex_redirect = 1'b1; ex_redirect_target = id_ex_redirect_target;
            end
        end
    end

    // ==================================================================
    // MEM stage : data memory access + load/store formatting
    // ==================================================================
    assign dmem_addr     = ex_mem_alu_result;
    assign dmem_read_en  = ex_mem_valid && ex_mem_mem_read;
    assign dmem_write_en = ex_mem_valid && ex_mem_mem_write;

    riscv_lsu u_lsu (
        .mem_size     (ex_mem_mem_size),
        .mem_unsigned (ex_mem_mem_unsigned),
        .addr_lo      (ex_mem_alu_result[1:0]),
        .write_en     (dmem_write_en),
        .store_data   (ex_mem_store_data),
        .read_data    (dmem_read_data),
        .write_data   (dmem_write_data),
        .wstrb        (dmem_wstrb),
        .load_data    (mem_load_data)
    );

    // ==================================================================
    // WB stage : writeback source select
    // ==================================================================
    always_comb begin
        case (mem_wb_wb_sel)
            WB_PC4:  wb_data = mem_wb_pc4;
            WB_LOAD: wb_data = mem_wb_load_data;
            WB_CSR:  wb_data = mem_wb_csr_old;
            default: wb_data = mem_wb_alu_result;
        endcase
    end

    // ==================================================================
    // Pipeline registers (sequencing, stalls, flushes)
    // ==================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            mul_busy   <= 1'b0;
            mul_done   <= 1'b0;
            mul_op     <= ALU_MUL;
            mul_a_reg  <= 33'sd0;
            mul_b_reg  <= 33'sd0;
            mul_product <= 66'sd0;
        end else begin
            if (mul_done && !mem_stall)
                mul_done <= 1'b0;

            if (mul_start) begin
                mul_op <= id_ex_alu_op;
                mul_a_reg <= ((id_ex_alu_op == ALU_MULH ||
                               id_ex_alu_op == ALU_MULHSU))
                           ? $signed({ex_alu_src_a[31], ex_alu_src_a})
                           : $signed({1'b0, ex_alu_src_a});
                mul_b_reg <= (id_ex_alu_op == ALU_MULH)
                           ? $signed({ex_alu_src_b[31], ex_alu_src_b})
                           : $signed({1'b0, ex_alu_src_b});
                mul_busy <= 1'b1;
            end else if (mul_busy) begin
                mul_product <= mul_a_reg * mul_b_reg;
                mul_busy <= 1'b0;
                mul_done <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            div_busy          <= 1'b0;
            div_done          <= 1'b0;
            div_op            <= ALU_DIVU;
            div_count         <= 6'd0;
            div_dividend      <= 32'd0;
            div_divisor       <= 32'd0;
            div_quotient      <= 32'd0;
            div_remainder     <= 33'd0;
            div_quotient_neg  <= 1'b0;
            div_remainder_neg <= 1'b0;
            div_result        <= 32'd0;
        end else begin
            if (div_done && !mem_stall)
                div_done <= 1'b0;

            if (div_start) begin
                div_op    <= id_ex_alu_op;
                div_count <= 6'd0;

                if (ex_alu_src_b == 32'd0) begin
                    div_result <= ((id_ex_alu_op == ALU_DIV) ||
                                   (id_ex_alu_op == ALU_DIVU))
                                ? 32'hffff_ffff : ex_alu_src_a;
                    div_busy <= 1'b0;
                    div_done <= 1'b1;
                end else if ((id_ex_alu_op == ALU_DIV ||
                              id_ex_alu_op == ALU_REM) &&
                             ex_alu_src_a == 32'h8000_0000 &&
                             ex_alu_src_b == 32'hffff_ffff) begin
                    div_result <= (id_ex_alu_op == ALU_DIV)
                                ? 32'h8000_0000 : 32'd0;
                    div_busy <= 1'b0;
                    div_done <= 1'b1;
                end else begin
                    div_dividend <= ((id_ex_alu_op == ALU_DIV ||
                                      id_ex_alu_op == ALU_REM) &&
                                     ex_alu_src_a[31])
                                  ? (~ex_alu_src_a + 32'd1)
                                  : ex_alu_src_a;
                    div_divisor <= ((id_ex_alu_op == ALU_DIV ||
                                     id_ex_alu_op == ALU_REM) &&
                                    ex_alu_src_b[31])
                                 ? (~ex_alu_src_b + 32'd1)
                                 : ex_alu_src_b;
                    div_quotient      <= 32'd0;
                    div_remainder     <= 33'd0;
                    div_quotient_neg  <= (id_ex_alu_op == ALU_DIV) &&
                                         (ex_alu_src_a[31] ^ ex_alu_src_b[31]);
                    div_remainder_neg <= (id_ex_alu_op == ALU_REM) &&
                                         ex_alu_src_a[31];
                    div_busy <= 1'b1;
                end
            end else if (div_busy) begin
                div_dividend  <= {div_dividend[30:0], 1'b0};
                div_quotient  <= div_next_quotient;
                div_remainder <= div_next_remainder;

                if (div_count == 6'd31) begin
                    if (div_op == ALU_DIV || div_op == ALU_DIVU)
                        div_result <= div_quotient_neg
                                    ? (~div_next_quotient + 32'd1)
                                    : div_next_quotient;
                    else
                        div_result <= div_remainder_neg
                                    ? (~div_next_remainder[31:0] + 32'd1)
                                    : div_next_remainder[31:0];
                    div_busy <= 1'b0;
                    div_done <= 1'b1;
                end else begin
                    div_count <= div_count + 6'd1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_f <= RESET_PC;
            load_use_hold_q <= 1'b0;
            if_pending_valid <= 1'b0;
            if_discard_pending <= 1'b0;
            if_buf_valid <= 1'b0;
            if_buf_instr <= 32'd0;
            if_buf_pc <= 32'd0;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'd0;

            id_ex_valid <= 1'b0;
            id_ex_forward_a_sel <= 2'b00;
            id_ex_forward_b_sel <= 2'b00;
            id_ex_pc <= 32'd0; id_ex_pc4 <= 32'd0;
            id_ex_rs1_data <= 32'd0; id_ex_rs2_data <= 32'd0; id_ex_imm <= 32'd0;
            id_ex_redirect_target <= 32'd0;
            id_ex_rs1 <= 5'd0; id_ex_rs2 <= 5'd0; id_ex_rd <= 5'd0;
            id_ex_funct3 <= 3'd0; id_ex_funct7 <= 7'd0;
            id_ex_use_rs1 <= 1'b0; id_ex_use_rs2 <= 1'b0;
            id_ex_src_a_pc <= 1'b0; id_ex_src_b_imm <= 1'b0;
            id_ex_reg_write <= 1'b0; id_ex_mem_read <= 1'b0; id_ex_mem_write <= 1'b0;
            id_ex_mem_size <= 2'd0; id_ex_mem_unsigned <= 1'b0;
            id_ex_jal <= 1'b0; id_ex_jalr <= 1'b0;
            id_ex_branch_kind <= BR_NONE; id_ex_wb_sel <= WB_ALU; id_ex_alu_op <= ALU_ADD;
            id_ex_is_ecall <= 1'b0; id_ex_is_ebreak <= 1'b0; id_ex_is_mret <= 1'b0;
            id_ex_csr_read <= 1'b0; id_ex_csr_write <= 1'b0;
            id_ex_csr_addr <= 12'd0; id_ex_csr_old <= 32'd0;

            ex_mem_valid <= 1'b0;
            ex_mem_pc4 <= 32'd0; ex_mem_alu_result <= 32'd0; ex_mem_store_data <= 32'd0;
            ex_mem_rd <= 5'd0; ex_mem_wb_sel <= WB_ALU;
            ex_mem_reg_write <= 1'b0; ex_mem_mem_read <= 1'b0; ex_mem_mem_write <= 1'b0;
            ex_mem_mem_size <= 2'd0; ex_mem_mem_unsigned <= 1'b0; ex_mem_csr_old <= 32'd0;

            mem_wb_valid <= 1'b0;
            mem_wb_pc4 <= 32'd0; mem_wb_alu_result <= 32'd0; mem_wb_load_data <= 32'd0;
            mem_wb_csr_old <= 32'd0; mem_wb_rd <= 5'd0; mem_wb_wb_sel <= WB_ALU;
            mem_wb_reg_write <= 1'b0;
        end else begin
            if (!mem_stall)
                load_use_hold_q <= !ex_redirect && bubble_ex;

            // ---- IF/ID ----
            if (ex_redirect) begin
                if_buf_valid <= 1'b0;
                if_pending_valid <= 1'b0;
                if_discard_pending <= if_pending_valid && !imem_ready;
            end else if (if_accept && if_buf_valid) begin
                if_buf_valid <= 1'b0;
            end

            if (!ex_redirect) begin
                if (imem_ready) begin
                    if (if_discard_pending) begin
                        if_discard_pending <= 1'b0;
                    end else if (if_pending_valid) begin
                        if_pending_valid <= 1'b0;
                        if (if_live_resp_valid && !if_accept && !if_buf_valid) begin
                            if_buf_valid <= 1'b1;
                            if_buf_instr <= imem_instr;
                            if_buf_pc <= imem_resp_pc;
                        end
                    end
                end

                if (imem_req) begin
                    if_pending_valid <= 1'b1;
                end
            end

            if (pc_f_en)
                pc_f <= pc_f_next;

            if (mem_stall) begin
            end else if (ex_redirect) begin
                if_id_valid <= 1'b0;
            end else if (stall_if) begin
            end else if (if_accept) begin
                if_id_valid <= 1'b1;
                if_id_pc <= if_resp_pc;
                if_id_instr <= if_resp_instr;
            end else begin
                if_id_valid <= 1'b0;
            end

            // ---- ID/EX ----
            if (mem_stall) begin
            end else begin
                if (id_ex_en_data) begin
                    id_ex_pc <= if_id_pc;
                    id_ex_pc4 <= if_id_pc + 32'd4;
                    id_ex_rs1_data <= id_rs1_data;
                    id_ex_rs2_data <= id_rs2_data;
                    id_ex_imm <= id_imm;
                    id_ex_redirect_target <= id_redirect_target;
                    id_ex_csr_old <= id_csr_old;
                end

                if (id_ex_flush_ctrl) begin
                    id_ex_valid <= 1'b0;
                    id_ex_forward_a_sel <= 2'b00;
                    id_ex_forward_b_sel <= 2'b00;
                end else if (id_ex_en_ctrl) begin
                    id_ex_valid <= if_id_valid;
                    id_ex_forward_a_sel <= id_forward_a_sel;
                    id_ex_forward_b_sel <= id_forward_b_sel;
                    id_ex_rs1 <= id_rs1;
                    id_ex_rs2 <= id_rs2;
                    id_ex_rd <= id_rd;
                    id_ex_funct3 <= id_funct3;
                    id_ex_funct7 <= id_funct7;
                    id_ex_use_rs1 <= id_use_rs1;
                    id_ex_use_rs2 <= id_use_rs2;
                    id_ex_src_a_pc <= id_src_a_pc;
                    id_ex_src_b_imm <= id_src_b_imm;
                    id_ex_reg_write <= id_reg_write;
                    id_ex_mem_read <= id_mem_read;
                    id_ex_mem_write <= id_mem_write;
                    id_ex_mem_size <= id_mem_size;
                    id_ex_mem_unsigned <= id_mem_unsigned;
                    id_ex_jal <= id_jal;
                    id_ex_jalr <= id_jalr;
                    id_ex_branch_kind <= id_branch_kind;
                    id_ex_wb_sel <= id_wb_sel;
                    id_ex_alu_op <= id_alu_op;
                    id_ex_is_ecall <= id_is_ecall;
                    id_ex_is_ebreak <= id_is_ebreak;
                    id_ex_is_mret <= id_is_mret;
                    id_ex_csr_read <= id_csr_read;
                    id_ex_csr_write <= id_csr_write;
                    id_ex_csr_addr <= id_csr_addr;
                end
            end

            // ---- EX/MEM ----
            if (!mem_stall) begin
                ex_mem_valid <= id_ex_valid && !m_stall &&
                                !ex_is_trap && !id_ex_is_mret;
                ex_mem_pc4 <= id_ex_pc4;
                ex_mem_alu_result <= ex_alu_result;
                ex_mem_store_data <= ex_store_data;
                ex_mem_rd <= id_ex_rd;
                ex_mem_wb_sel <= id_ex_wb_sel;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_mem_read <= id_ex_mem_read;
                ex_mem_mem_write <= id_ex_mem_write;
                ex_mem_mem_size <= id_ex_mem_size;
                ex_mem_mem_unsigned <= id_ex_mem_unsigned;
                ex_mem_csr_old <= id_ex_csr_old;
            end

            // ---- MEM/WB ----
            if (mem_stall) begin
                mem_wb_valid <= 1'b0;
            end else begin
                mem_wb_valid <= ex_mem_valid;
                mem_wb_pc4 <= ex_mem_pc4;
                mem_wb_alu_result <= ex_mem_alu_result;
                mem_wb_load_data <= mem_load_data;
                mem_wb_csr_old <= ex_mem_csr_old;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_wb_sel <= ex_mem_wb_sel;
                mem_wb_reg_write <= ex_mem_reg_write;
            end

        end
    end

endmodule

`endif
