// ============================================================================
// riscv_decode.sv  -  instruction decoder (ID stage)
//   Takes a 32-bit instruction and produces the control signals + immediate
//   for the rest of the pipeline. Pure combinational.
// ============================================================================
`ifndef RISCV_DECODE_SV
`define RISCV_DECODE_SV

`timescale 1ns/1ps

module riscv_decode (
    input  logic [31:0] instr,

    // register / field outputs
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7,
    output logic [11:0] csr_addr,
    output logic [31:0] imm,

    // control outputs
    output logic        use_rs1,
    output logic        use_rs2,
    output logic        src_a_pc,
    output logic        src_b_imm,
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  mem_size,
    output logic        mem_unsigned,
    output logic        jal,
    output logic        jalr,
    output logic [2:0]  branch_kind,
    output logic [1:0]  wb_sel,
    output logic [4:0]  alu_op,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic        is_mret,
    output logic        csr_read,
    output logic        csr_write
);
    import riscv_pkg::*;

    logic [6:0]  opcode;
    logic [11:0] system_imm12;

    assign opcode       = instr[6:0];
    assign rd           = instr[11:7];
    assign funct3       = instr[14:12];
    assign rs1          = instr[19:15];
    assign rs2          = instr[24:20];
    assign funct7       = instr[31:25];
    assign system_imm12 = instr[31:20];
    assign csr_addr     = instr[31:20];

    // immediate generators
    function automatic logic [31:0] imm_i(input logic [31:0] in);
        imm_i = {{20{in[31]}}, in[31:20]};
    endfunction
    function automatic logic [31:0] imm_s(input logic [31:0] in);
        imm_s = {{20{in[31]}}, in[31:25], in[11:7]};
    endfunction
    function automatic logic [31:0] imm_b(input logic [31:0] in);
        imm_b = {{19{in[31]}}, in[31], in[7], in[30:25], in[11:8], 1'b0};
    endfunction
    function automatic logic [31:0] imm_u(input logic [31:0] in);
        imm_u = {in[31:12], 12'b0};
    endfunction
    function automatic logic [31:0] imm_j(input logic [31:0] in);
        imm_j = {{11{in[31]}}, in[31], in[19:12], in[20], in[30:21], 1'b0};
    endfunction

    always_comb begin
        imm          = 32'd0;
        use_rs1      = 1'b0;
        use_rs2      = 1'b0;
        src_a_pc     = 1'b0;
        src_b_imm    = 1'b0;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = 2'd2;
        mem_unsigned = 1'b0;
        jal          = 1'b0;
        jalr         = 1'b0;
        branch_kind  = BR_NONE;
        wb_sel       = WB_ALU;
        alu_op       = ALU_ADD;
        is_ecall     = 1'b0;
        is_ebreak    = 1'b0;
        is_mret      = 1'b0;
        csr_read     = 1'b0;
        csr_write    = 1'b0;

        case (opcode)
            OPCODE_LUI: begin
                imm       = imm_u(instr);
                src_b_imm = 1'b1;
                reg_write = 1'b1;
                alu_op    = ALU_COPY_B;
            end
            OPCODE_AUIPC: begin
                imm       = imm_u(instr);
                src_a_pc  = 1'b1;
                src_b_imm = 1'b1;
                reg_write = 1'b1;
                alu_op    = ALU_ADD;
            end
            OPCODE_JAL: begin
                imm       = imm_j(instr);
                jal       = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_PC4;
            end
            OPCODE_JALR: begin
                imm       = imm_i(instr);
                use_rs1   = 1'b1;
                jalr      = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_PC4;
            end
            OPCODE_BRANCH: begin
                imm     = imm_b(instr);
                use_rs1 = 1'b1;
                use_rs2 = 1'b1;
                case (funct3)
                    3'b000: branch_kind = BR_EQ;
                    3'b001: branch_kind = BR_NE;
                    3'b100: branch_kind = BR_LT;
                    3'b101: branch_kind = BR_GE;
                    3'b110: branch_kind = BR_LTU;
                    3'b111: branch_kind = BR_GEU;
                    default: branch_kind = BR_NONE;
                endcase
            end
            OPCODE_LOAD: begin
                imm       = imm_i(instr);
                use_rs1   = 1'b1;
                src_b_imm = 1'b1;
                reg_write = 1'b1;
                mem_read  = 1'b1;
                wb_sel    = WB_LOAD;
                case (funct3)
                    3'b000: begin mem_size = 2'd0; mem_unsigned = 1'b0; end
                    3'b001: begin mem_size = 2'd1; mem_unsigned = 1'b0; end
                    3'b010: begin mem_size = 2'd2; mem_unsigned = 1'b0; end
                    3'b100: begin mem_size = 2'd0; mem_unsigned = 1'b1; end
                    3'b101: begin mem_size = 2'd1; mem_unsigned = 1'b1; end
                    default: begin mem_size = 2'd2; mem_unsigned = 1'b0; end
                endcase
            end
            OPCODE_STORE: begin
                imm       = imm_s(instr);
                use_rs1   = 1'b1;
                use_rs2   = 1'b1;
                src_b_imm = 1'b1;
                mem_write = 1'b1;
                case (funct3)
                    3'b000: mem_size = 2'd0;
                    3'b001: mem_size = 2'd1;
                    default: mem_size = 2'd2;
                endcase
            end
            OPCODE_OP_IMM: begin
                imm       = imm_i(instr);
                use_rs1   = 1'b1;
                src_b_imm = 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    default: alu_op = ALU_AND;
                endcase
            end
            OPCODE_OP: begin
                use_rs1   = 1'b1;
                use_rs2   = 1'b1;
                reg_write = 1'b1;
                case ({funct7, funct3})
                    10'b0000000_000: alu_op = ALU_ADD;
                    10'b0100000_000: alu_op = ALU_SUB;
                    10'b0000000_001: alu_op = ALU_SLL;
                    10'b0000000_010: alu_op = ALU_SLT;
                    10'b0000000_011: alu_op = ALU_SLTU;
                    10'b0000000_100: alu_op = ALU_XOR;
                    10'b0000000_101: alu_op = ALU_SRL;
                    10'b0100000_101: alu_op = ALU_SRA;
                    10'b0000000_110: alu_op = ALU_OR;
                    10'b0000001_000: alu_op = ALU_MUL;
                    10'b0000001_001: alu_op = ALU_MULH;
                    10'b0000001_010: alu_op = ALU_MULHSU;
                    10'b0000001_011: alu_op = ALU_MULHU;
                    10'b0000001_100: alu_op = ALU_DIV;
                    10'b0000001_101: alu_op = ALU_DIVU;
                    10'b0000001_110: alu_op = ALU_REM;
                    10'b0000001_111: alu_op = ALU_REMU;
                    default: alu_op = ALU_AND;
                endcase
            end
            // OPCODE_MISC_MEM (FENCE / FENCE.I): no caches in Core 1, so these
            // fall through to the default case and execute as a harmless NOP.
            OPCODE_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    case (system_imm12)
                        12'h000: is_ecall  = 1'b1;
                        12'h001: is_ebreak = 1'b1;
                        12'h302: is_mret   = 1'b1;
                        default: begin end
                    endcase
                end else begin
                    csr_read  = 1'b1;
                    reg_write = 1'b1;
                    wb_sel    = WB_CSR;
                    case (funct3)
                        3'b001: begin use_rs1 = 1'b1; csr_write = 1'b1;            end // CSRRW
                        3'b010: begin use_rs1 = 1'b1; csr_write = (rs1 != 5'd0);   end // CSRRS
                        3'b011: begin use_rs1 = 1'b1; csr_write = (rs1 != 5'd0);   end // CSRRC
                        3'b101: begin                 csr_write = 1'b1;            end // CSRRWI
                        3'b110: begin                 csr_write = (rs1 != 5'd0);   end // CSRRSI
                        3'b111: begin                 csr_write = (rs1 != 5'd0);   end // CSRRCI
                        default: begin csr_read = 1'b0; csr_write = 1'b0; reg_write = 1'b0; end
                    endcase
                end
            end
            default: begin end
        endcase
    end

endmodule

`endif
