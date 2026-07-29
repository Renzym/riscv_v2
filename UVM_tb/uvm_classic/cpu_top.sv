// cpu_top.sv
// Adapted for the Core1_BRAM riscv_core (modular RTL, no caches, BRAM-only)
// Synchronized shadow pipeline for instruction bits

`ifndef FORMAL_VERIFICATION
    `include "uvm_macros.svh"
`endif

module cpu_top(
    input clock,
    input rst,
    input [31:0] instruction,
    output [31:0] current_PC,
    input external_irq,

    output mem_read,
    output mem_write,
    output [31:0]  address,

    output [3:0] mem_wstrb,
    output [31:0] mem_write_data,
    input [31:0] mem_read_data,

    // Expose verification signals
    output wire reg_write_o,
    output wire [4:0] rd_o,
    output [31:0] rf_rd_value_o,

    // Retirement signals for pipelined monitor
    output [31:0] retired_pc,
    output [31:0] retired_instr,
    output        retired_valid
);

    wire imem_req;
    wire [31:0] imem_addr;
    wire [31:0] imem_resp_pc;
    wire [31:0] global_interrupts;

    // The driver expects current_PC to be the fetch address
    assign current_PC = imem_addr;
    assign imem_resp_pc = imem_addr;
    assign global_interrupts = {31'd0, external_irq};

    // RESET_PC must match the riscv-dv link address / Spike (core default is 0).
    // Access-fault checking enabled with bounds matching Spike's memory map
    // (spike -m0x80000000:0x20000).
    riscv_core #(
        .RESET_PC          (32'h8000_0000),
        .TRAP_ACCESS_FAULTS(1'b1),
        .DMEM_BASE         (32'h8000_0000),
        .DMEM_LIMIT        (32'h8002_0000)
    ) core_inst (
        .clk(clock),
        .reset(rst),
        .global_interrupts(global_interrupts),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ready(1'b1),
        .imem_instr(instruction),
        .imem_resp_pc(imem_resp_pc),
        .imem_resp_accept(),

        .dmem_addr(address),
        .dmem_write_data(mem_write_data),
        .dmem_wstrb(mem_wstrb),
        .dmem_read_en(mem_read),
        .dmem_write_en(mem_write),
        .dmem_ready(1'b1),
        .dmem_read_data(mem_read_data)
    );

    // Hierarchical connections for verification
    assign reg_write_o = core_inst.mem_wb_valid && core_inst.mem_wb_reg_write;
    assign rd_o = core_inst.mem_wb_rd;
    assign rf_rd_value_o = core_inst.wb_data;

    // Shadow pipeline for instruction bits, plus a TB-side valid bit.
    // This core kills wrong-path slots in hardware (redirect clears the
    // if_id/id_ex valid bits), so no branch-shadow masking is needed here.
    // However, the core also drops ECALL/EBREAK/MRET from ex_mem_valid; the
    // scoreboards need to see those retire (end-of-test detection and Spike
    // comparison), so the shadow valid propagates id_ex_valid without that
    // exclusion.
    reg [31:0] id_ex_instr, ex_mem_instr, mem_wb_instr;
    reg ex_mem_v, mem_wb_v;

    always @(posedge clock) begin
        if (rst) begin
            id_ex_instr <= 0; ex_mem_instr <= 0; mem_wb_instr <= 0;
            ex_mem_v <= 0; mem_wb_v <= 0;
        end else if (!core_inst.mem_stall) begin
            // From ID to EX (mirrors the core's ID/EX register controls)
            if (core_inst.ex_redirect || core_inst.bubble_ex)
                id_ex_instr <= 32'h00000013; // NOP on flush/bubble
            else if (!core_inst.stall_id)
                id_ex_instr <= core_inst.if_id_instr;

            // From EX to MEM
            ex_mem_instr <= id_ex_instr;
            ex_mem_v <= core_inst.id_ex_valid;

            // From MEM to WB
            mem_wb_instr <= ex_mem_instr;
            mem_wb_v <= ex_mem_v;
        end else begin
            // The core inserts a bubble into MEM/WB while mem_stall holds
            mem_wb_v <= 1'b0;
        end
    end

    assign retired_pc = (core_inst.mem_wb_pc4 - 4);
    assign retired_instr = mem_wb_instr;
    assign retired_valid = mem_wb_v;

endmodule
