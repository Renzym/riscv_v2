// ============================================================================
// riscv_hazard.sv  -  pipeline control: operand forwarding + load-use stalls
//   Pure combinational. Precomputes forwarding selects for the instruction in
//   decode and issues the first load-use stall/bubble. The second held decode
//   cycle is registered in riscv_core to keep EX/MEM compare logic out of the
//   high-fanout ID/EX clock-enable path.
// ============================================================================
`ifndef RISCV_HAZARD_SV
`define RISCV_HAZARD_SV

`timescale 1ns/1ps

module riscv_hazard (
    // decode-stage instruction (consumer)
    input  logic        if_id_valid,
    input  logic        id_use_rs1,
    input  logic        id_use_rs2,
    input  logic [4:0]  id_rs1,
    input  logic [4:0]  id_rs2,

    // EX-stage instruction
    input  logic        id_ex_valid,
    input  logic        id_ex_use_rs1,
    input  logic        id_ex_use_rs2,
    input  logic [4:0]  id_ex_rs1,
    input  logic [4:0]  id_ex_rs2,
    input  logic        id_ex_reg_write,
    input  logic        id_ex_mem_read,
    input  logic [4:0]  id_ex_rd,

    // MEM-stage instruction
    input  logic        ex_mem_valid,
    input  logic        ex_mem_reg_write,
    input  logic        ex_mem_mem_read,
    input  logic [4:0]  ex_mem_rd,

    // WB-stage instruction
    input  logic        mem_wb_valid,
    input  logic        mem_wb_reg_write,
    input  logic [4:0]  mem_wb_rd,

    // forwarding selects for the decode instruction's next EX cycle:
    // 00 = captured regfile data, 01 = next EX/MEM, 10 = next MEM/WB
    output logic [1:0]  forward_a_sel,
    output logic [1:0]  forward_b_sel,

    // front-end stalls
    output logic        stall_if,
    output logic        stall_id,
    output logic        bubble_ex
);
    logic load_hazard_ex;

    // ---- forwarding ----
    always_comb begin
        forward_a_sel = 2'b00;
        if (if_id_valid && id_use_rs1 && (id_rs1 != 5'd0)) begin
            if (id_ex_valid && id_ex_reg_write && !id_ex_mem_read && (id_ex_rd == id_rs1))
                forward_a_sel = 2'b01;
            else if (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd == id_rs1))
                forward_a_sel = 2'b10;
        end

        forward_b_sel = 2'b00;
        if (if_id_valid && id_use_rs2 && (id_rs2 != 5'd0)) begin
            if (id_ex_valid && id_ex_reg_write && !id_ex_mem_read && (id_ex_rd == id_rs2))
                forward_b_sel = 2'b01;
            else if (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd == id_rs2))
                forward_b_sel = 2'b10;
        end
    end

    // ---- load-use hazards ----
    assign load_hazard_ex =
        if_id_valid && id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
        ((id_use_rs1 && (id_rs1 == id_ex_rd)) ||
         (id_use_rs2 && (id_rs2 == id_ex_rd)));

    always_comb begin
        stall_if  = 1'b0;
        stall_id  = 1'b0;
        bubble_ex = 1'b0;
        if (load_hazard_ex) begin
            stall_if  = 1'b1;
            stall_id  = 1'b1;
            bubble_ex = 1'b1;
        end
    end

endmodule

`endif
