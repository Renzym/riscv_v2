`ifndef RISCV_CORE_SV
`define RISCV_CORE_SV

`timescale 1ns/1ps

module riscv_core (
    input  logic        clk,
    input  logic        reset,

    output logic        imem_req,
    output logic [31:0] imem_addr,
    input  logic        imem_ready,
    input  logic [31:0] imem_instr,

    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_write_data,
    output logic [3:0]  dmem_wstrb,
    output logic        dmem_read_en,
    output logic        dmem_write_en,
    input  logic        dmem_ready,
    input  logic [31:0] dmem_read_data,

    output logic        icache_invalidate,
    output logic        dcache_invalidate
);

    localparam logic [6:0] OPCODE_LUI      = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPCODE_JAL      = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR     = 7'b1100111;
    localparam logic [6:0] OPCODE_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPCODE_LOAD     = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE    = 7'b0100011;
    localparam logic [6:0] OPCODE_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPCODE_OP       = 7'b0110011;
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OPCODE_SYSTEM   = 7'b1110011;

    localparam logic [3:0] ALU_ADD    = 4'd0;
    localparam logic [3:0] ALU_SUB    = 4'd1;
    localparam logic [3:0] ALU_SLT    = 4'd2;
    localparam logic [3:0] ALU_SLTU   = 4'd3;
    localparam logic [3:0] ALU_XOR    = 4'd4;
    localparam logic [3:0] ALU_OR     = 4'd5;
    localparam logic [3:0] ALU_AND    = 4'd6;
    localparam logic [3:0] ALU_SLL    = 4'd7;
    localparam logic [3:0] ALU_SRL    = 4'd8;
    localparam logic [3:0] ALU_SRA    = 4'd9;
    localparam logic [3:0] ALU_COPY_B = 4'd10;

    localparam logic [1:0] WB_ALU  = 2'd0;
    localparam logic [1:0] WB_LOAD = 2'd1;
    localparam logic [1:0] WB_PC4  = 2'd2;
    localparam logic [1:0] WB_CSR  = 2'd3;

    localparam logic [2:0] BR_NONE = 3'd0;
    localparam logic [2:0] BR_EQ   = 3'd1;
    localparam logic [2:0] BR_NE   = 3'd2;
    localparam logic [2:0] BR_LT   = 3'd3;
    localparam logic [2:0] BR_GE   = 3'd4;
    localparam logic [2:0] BR_LTU  = 3'd5;
    localparam logic [2:0] BR_GEU  = 3'd6;

    logic [31:0] registers [0:31];
    logic [31:0] csr_mtvec;
    logic [31:0] csr_mepc;
    logic [31:0] csr_mcause;
    logic [31:0] csr_mscratch;

    logic [31:0] pc_f;

    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instr;

    logic        id_ex_valid;
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_pc4;
    logic [31:0] id_ex_rs1_data;
    logic [31:0] id_ex_rs2_data;
    logic [31:0] id_ex_imm;
    logic [4:0]  id_ex_rs1;
    logic [4:0]  id_ex_rs2;
    logic [4:0]  id_ex_rd;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;
    logic        id_ex_use_rs1;
    logic        id_ex_use_rs2;
    logic        id_ex_src_a_pc;
    logic        id_ex_src_b_imm;
    logic        id_ex_reg_write;
    logic        id_ex_mem_read;
    logic        id_ex_mem_write;
    logic [1:0]  id_ex_mem_size;
    logic        id_ex_mem_unsigned;
    logic        id_ex_jal;
    logic        id_ex_jalr;
    logic [2:0]  id_ex_branch_kind;
    logic [1:0]  id_ex_wb_sel;
    logic [3:0]  id_ex_alu_op;
    logic        id_ex_is_fence;
    logic        id_ex_is_fence_i;
    logic        id_ex_is_ecall;
    logic        id_ex_is_ebreak;
    logic        id_ex_is_mret;
    logic        id_ex_csr_read;
    logic        id_ex_csr_write;
    logic [11:0] id_ex_csr_addr;
    logic [31:0] id_ex_csr_old;

    logic        ex_mem_valid;
    logic [31:0] ex_mem_pc4;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;
    logic [1:0]  ex_mem_wb_sel;
    logic        ex_mem_reg_write;
    logic        ex_mem_mem_read;
    logic        ex_mem_mem_write;
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

    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [4:0]  id_rd;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [6:0]  id_opcode;
    logic [11:0] id_system_imm12;
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;
    logic [31:0] id_imm;
    logic        id_use_rs1;
    logic        id_use_rs2;
    logic        id_src_a_pc;
    logic        id_src_b_imm;
    logic        id_reg_write;
    logic        id_mem_read;
    logic        id_mem_write;
    logic [1:0]  id_mem_size;
    logic        id_mem_unsigned;
    logic        id_jal;
    logic        id_jalr;
    logic [2:0]  id_branch_kind;
    logic [1:0]  id_wb_sel;
    logic [3:0]  id_alu_op;
    logic        id_is_fence;
    logic        id_is_fence_i;
    logic        id_is_ecall;
    logic        id_is_ebreak;
    logic        id_is_mret;
    logic        id_csr_read;
    logic        id_csr_write;
    logic [11:0] id_csr_addr;
    logic [31:0] id_csr_old;

    logic        stall_if;
    logic        stall_id;
    logic        bubble_ex;
    logic        mem_stall;
    logic        load_hazard_ex;
    logic        load_hazard_mem;
    logic [1:0]  forward_a_sel;
    logic [1:0]  forward_b_sel;

    logic [31:0] ex_forward_a_data;
    logic [31:0] ex_forward_b_data;
    logic [31:0] ex_alu_src_a;
    logic [31:0] ex_alu_src_b;
    logic [31:0] ex_alu_result;
    logic [31:0] ex_store_data;
    logic        ex_branch_cond;
    logic        ex_redirect;
    logic [31:0] ex_redirect_target;
    logic        ex_is_trap;
    logic [31:0] ex_trap_cause;
    logic        ex_csr_write_en;
    logic [11:0] ex_csr_write_addr;
    logic [31:0] ex_csr_write_data;

    logic [31:0] mem_load_data;
    logic [31:0] wb_data;
    logic [31:0] ex_mem_forward_data;

    function automatic logic [31:0] imm_i(input logic [31:0] instr);
        imm_i = {{20{instr[31]}}, instr[31:20]};
    endfunction

    function automatic logic [31:0] imm_s(input logic [31:0] instr);
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    endfunction

    function automatic logic [31:0] imm_b(input logic [31:0] instr);
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    endfunction

    function automatic logic [31:0] imm_u(input logic [31:0] instr);
        imm_u = {instr[31:12], 12'b0};
    endfunction

    function automatic logic [31:0] imm_j(input logic [31:0] instr);
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    endfunction

    function automatic logic [31:0] read_reg(input logic [4:0] addr);
        if (addr == 5'd0)
            read_reg = 32'd0;
        else
            read_reg = registers[addr];
    endfunction

    function automatic logic [31:0] read_csr(input logic [11:0] addr);
        begin
            case (addr)
                12'h305: read_csr = csr_mtvec;
                12'h340: read_csr = csr_mscratch;
                12'h341: read_csr = csr_mepc;
                12'h342: read_csr = csr_mcause;
                default: read_csr = 32'd0;
            endcase
        end
    endfunction

    assign imem_addr = pc_f;
    assign mem_stall = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write) && !dmem_ready;
    
    // Registered imem_req to break combinatorial path and fix timing
    logic imem_req_next;
    assign imem_req_next = !reset && !mem_stall && !stall_if && !ex_redirect;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) imem_req <= 1'b0;
        else       imem_req <= imem_req_next;
    end

    assign icache_invalidate = !mem_stall && id_ex_valid && id_ex_is_fence_i;
    assign dcache_invalidate = !mem_stall && id_ex_valid && id_ex_is_fence;

    assign id_opcode       = if_id_instr[6:0];
    assign id_rd           = if_id_instr[11:7];
    assign id_funct3       = if_id_instr[14:12];
    assign id_rs1          = if_id_instr[19:15];
    assign id_rs2          = if_id_instr[24:20];
    assign id_funct7       = if_id_instr[31:25];
    assign id_system_imm12 = if_id_instr[31:20];
    assign id_csr_addr     = if_id_instr[31:20];
    assign id_csr_old      = read_csr(id_csr_addr);

    always_comb begin
        if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_rs1))
            id_rs1_data = wb_data;
        else
            id_rs1_data = read_reg(id_rs1);

        if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_rs2))
            id_rs2_data = wb_data;
        else
            id_rs2_data = read_reg(id_rs2);
    end

    always_comb begin
        id_imm          = 32'd0;
        id_use_rs1      = 1'b0;
        id_use_rs2      = 1'b0;
        id_src_a_pc     = 1'b0;
        id_src_b_imm    = 1'b0;
        id_reg_write    = 1'b0;
        id_mem_read     = 1'b0;
        id_mem_write    = 1'b0;
        id_mem_size     = 2'd2;
        id_mem_unsigned = 1'b0;
        id_jal          = 1'b0;
        id_jalr         = 1'b0;
        id_branch_kind  = BR_NONE;
        id_wb_sel       = WB_ALU;
        id_alu_op       = ALU_ADD;
        id_is_fence     = 1'b0;
        id_is_fence_i   = 1'b0;
        id_is_ecall     = 1'b0;
        id_is_ebreak    = 1'b0;
        id_is_mret      = 1'b0;
        id_csr_read     = 1'b0;
        id_csr_write    = 1'b0;

        case (id_opcode)
            OPCODE_LUI: begin
                id_imm       = imm_u(if_id_instr);
                id_src_b_imm = 1'b1;
                id_reg_write = 1'b1;
                id_alu_op    = ALU_COPY_B;
            end
            OPCODE_AUIPC: begin
                id_imm       = imm_u(if_id_instr);
                id_src_a_pc  = 1'b1;
                id_src_b_imm = 1'b1;
                id_reg_write = 1'b1;
                id_alu_op    = ALU_ADD;
            end
            OPCODE_JAL: begin
                id_imm       = imm_j(if_id_instr);
                id_jal       = 1'b1;
                id_reg_write = 1'b1;
                id_wb_sel    = WB_PC4;
            end
            OPCODE_JALR: begin
                id_imm       = imm_i(if_id_instr);
                id_use_rs1   = 1'b1;
                id_jalr      = 1'b1;
                id_reg_write = 1'b1;
                id_wb_sel    = WB_PC4;
            end
            OPCODE_BRANCH: begin
                id_imm     = imm_b(if_id_instr);
                id_use_rs1 = 1'b1;
                id_use_rs2 = 1'b1;
                case (id_funct3)
                    3'b000: id_branch_kind = BR_EQ;
                    3'b001: id_branch_kind = BR_NE;
                    3'b100: id_branch_kind = BR_LT;
                    3'b101: id_branch_kind = BR_GE;
                    3'b110: id_branch_kind = BR_LTU;
                    3'b111: id_branch_kind = BR_GEU;
                    default: id_branch_kind = BR_NONE;
                endcase
            end
            OPCODE_LOAD: begin
                id_imm       = imm_i(if_id_instr);
                id_use_rs1   = 1'b1;
                id_src_b_imm = 1'b1;
                id_reg_write = 1'b1;
                id_mem_read  = 1'b1;
                id_wb_sel    = WB_LOAD;
                case (id_funct3)
                    3'b000: begin id_mem_size = 2'd0; id_mem_unsigned = 1'b0; end
                    3'b001: begin id_mem_size = 2'd1; id_mem_unsigned = 1'b0; end
                    3'b010: begin id_mem_size = 2'd2; id_mem_unsigned = 1'b0; end
                    3'b100: begin id_mem_size = 2'd0; id_mem_unsigned = 1'b1; end
                    3'b101: begin id_mem_size = 2'd1; id_mem_unsigned = 1'b1; end
                    default: begin id_mem_size = 2'd2; id_mem_unsigned = 1'b0; end
                endcase
            end
            OPCODE_STORE: begin
                id_imm       = imm_s(if_id_instr);
                id_use_rs1   = 1'b1;
                id_use_rs2   = 1'b1;
                id_src_b_imm = 1'b1;
                id_mem_write = 1'b1;
                case (id_funct3)
                    3'b000: id_mem_size = 2'd0;
                    3'b001: id_mem_size = 2'd1;
                    default: id_mem_size = 2'd2;
                endcase
            end
            OPCODE_OP_IMM: begin
                id_imm       = imm_i(if_id_instr);
                id_use_rs1   = 1'b1;
                id_src_b_imm = 1'b1;
                id_reg_write = 1'b1;
                case (id_funct3)
                    3'b000: id_alu_op = ALU_ADD;
                    3'b001: id_alu_op = ALU_SLL;
                    3'b010: id_alu_op = ALU_SLT;
                    3'b011: id_alu_op = ALU_SLTU;
                    3'b100: id_alu_op = ALU_XOR;
                    3'b101: id_alu_op = id_funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: id_alu_op = ALU_OR;
                    default: id_alu_op = ALU_AND;
                endcase
            end
            OPCODE_OP: begin
                id_use_rs1   = 1'b1;
                id_use_rs2   = 1'b1;
                id_reg_write = 1'b1;
                case ({id_funct7, id_funct3})
                    10'b0000000_000: id_alu_op = ALU_ADD;
                    10'b0100000_000: id_alu_op = ALU_SUB;
                    10'b0000000_001: id_alu_op = ALU_SLL;
                    10'b0000000_010: id_alu_op = ALU_SLT;
                    10'b0000000_011: id_alu_op = ALU_SLTU;
                    10'b0000000_100: id_alu_op = ALU_XOR;
                    10'b0000000_101: id_alu_op = ALU_SRL;
                    10'b0100000_101: id_alu_op = ALU_SRA;
                    10'b0000000_110: id_alu_op = ALU_OR;
                    default: id_alu_op = ALU_AND;
                endcase
            end
            OPCODE_MISC_MEM: begin
                if (id_funct3 == 3'b000)
                    id_is_fence = 1'b1;
                else if (id_funct3 == 3'b001)
                    id_is_fence_i = 1'b1;
            end
            OPCODE_SYSTEM: begin
                if (id_funct3 == 3'b000) begin
                    case (id_system_imm12)
                        12'h000: id_is_ecall = 1'b1;
                        12'h001: id_is_ebreak = 1'b1;
                        12'h302: id_is_mret = 1'b1;
                        default: begin
                        end
                    endcase
                end else begin
                    id_csr_read  = 1'b1;
                    id_reg_write = 1'b1;
                    id_wb_sel    = WB_CSR;
                    case (id_funct3)
                        3'b001: begin
                            id_use_rs1    = 1'b1;
                            id_csr_write  = 1'b1;
                        end
                        3'b010: begin
                            id_use_rs1    = 1'b1;
                            id_csr_write  = (id_rs1 != 5'd0);
                        end
                        3'b011: begin
                            id_use_rs1    = 1'b1;
                            id_csr_write  = (id_rs1 != 5'd0);
                        end
                        3'b101: begin
                            id_csr_write  = 1'b1;
                        end
                        3'b110: begin
                            id_csr_write  = (id_rs1 != 5'd0);
                        end
                        3'b111: begin
                            id_csr_write  = (id_rs1 != 5'd0);
                        end
                        default: begin
                            id_csr_read   = 1'b0;
                            id_csr_write  = 1'b0;
                            id_reg_write  = 1'b0;
                        end
                    endcase
                end
            end
            default: begin
            end
        endcase
    end

    assign load_hazard_ex =
        if_id_valid &&
        id_ex_valid &&
        id_ex_mem_read &&
        (id_ex_rd != 5'd0) &&
        ((id_use_rs1 && (id_rs1 == id_ex_rd)) ||
         (id_use_rs2 && (id_rs2 == id_ex_rd)));

    assign load_hazard_mem =
        if_id_valid &&
        ex_mem_valid &&
        ex_mem_mem_read &&
        (ex_mem_rd != 5'd0) &&
        ((id_use_rs1 && (id_rs1 == ex_mem_rd)) ||
         (id_use_rs2 && (id_rs2 == ex_mem_rd)));

    always_comb begin
        stall_if  = 1'b0;
        stall_id  = 1'b0;
        bubble_ex = 1'b0;

        if (load_hazard_ex) begin
            stall_if  = 1'b1;
            stall_id  = 1'b1;
            bubble_ex = 1'b1;
        end else if (load_hazard_mem) begin
            stall_if  = 1'b1;
            stall_id  = 1'b1;
            bubble_ex = 1'b1;
        end
    end

    always_comb begin
        forward_a_sel = 2'b00;
        if (id_ex_valid && id_ex_use_rs1 && (id_ex_rs1 != 5'd0)) begin
            if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd == id_ex_rs1))
                forward_a_sel = 2'b01;
            else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd == id_ex_rs1))
                forward_a_sel = 2'b10;
        end

        forward_b_sel = 2'b00;
        if (id_ex_valid && id_ex_use_rs2 && (id_ex_rs2 != 5'd0)) begin
            if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd == id_ex_rs2))
                forward_b_sel = 2'b01;
            else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd == id_ex_rs2))
                forward_b_sel = 2'b10;
        end
    end

    always_comb begin
        case (ex_mem_wb_sel)
            WB_PC4:  ex_mem_forward_data = ex_mem_pc4;
            WB_CSR:  ex_mem_forward_data = ex_mem_csr_old;
            default: ex_mem_forward_data = ex_mem_alu_result;
        endcase
    end

    always_comb begin
        case (forward_a_sel)
            2'b01: ex_forward_a_data = ex_mem_forward_data;
            2'b10: ex_forward_a_data = wb_data;
            default: ex_forward_a_data = id_ex_rs1_data;
        endcase

        case (forward_b_sel)
            2'b01: ex_forward_b_data = ex_mem_forward_data;
            2'b10: ex_forward_b_data = wb_data;
            default: ex_forward_b_data = id_ex_rs2_data;
        endcase
    end

    assign ex_alu_src_a = id_ex_src_a_pc ? id_ex_pc : ex_forward_a_data;
    assign ex_alu_src_b = id_ex_src_b_imm ? id_ex_imm : ex_forward_b_data;
    assign ex_store_data = ex_forward_b_data;

    always_comb begin
        case (id_ex_alu_op)
            ALU_ADD:    ex_alu_result = ex_alu_src_a + ex_alu_src_b;
            ALU_SUB:    ex_alu_result = ex_alu_src_a - ex_alu_src_b;
            ALU_SLT:    ex_alu_result = ($signed(ex_alu_src_a) < $signed(ex_alu_src_b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   ex_alu_result = (ex_alu_src_a < ex_alu_src_b) ? 32'd1 : 32'd0;
            ALU_XOR:    ex_alu_result = ex_alu_src_a ^ ex_alu_src_b;
            ALU_OR:     ex_alu_result = ex_alu_src_a | ex_alu_src_b;
            ALU_AND:    ex_alu_result = ex_alu_src_a & ex_alu_src_b;
            ALU_SLL:    ex_alu_result = ex_alu_src_a << ex_alu_src_b[4:0];
            ALU_SRL:    ex_alu_result = ex_alu_src_a >> ex_alu_src_b[4:0];
            ALU_SRA:    ex_alu_result = $signed(ex_alu_src_a) >>> ex_alu_src_b[4:0];
            default:    ex_alu_result = ex_alu_src_b;
        endcase
    end

    always_comb begin
        ex_branch_cond = 1'b0;
        case (id_ex_branch_kind)
            BR_EQ:  ex_branch_cond = (ex_forward_a_data == ex_forward_b_data);
            BR_NE:  ex_branch_cond = (ex_forward_a_data != ex_forward_b_data);
            BR_LT:  ex_branch_cond = ($signed(ex_forward_a_data) <  $signed(ex_forward_b_data));
            BR_GE:  ex_branch_cond = ($signed(ex_forward_a_data) >= $signed(ex_forward_b_data));
            BR_LTU: ex_branch_cond = (ex_forward_a_data < ex_forward_b_data);
            BR_GEU: ex_branch_cond = (ex_forward_a_data >= ex_forward_b_data);
            default: ex_branch_cond = 1'b0;
        endcase
    end

    logic [31:0] spec_branch_target;
    logic [31:0] spec_jalr_target;
    assign spec_branch_target = (id_ex_pc + id_ex_imm) & 32'hffff_fffc;
    assign spec_jalr_target   = (ex_forward_a_data + id_ex_imm) & 32'hffff_fffc;

    always_comb begin
        ex_redirect = 1'b0;
        ex_redirect_target = id_ex_jalr ? spec_jalr_target : spec_branch_target;
        ex_is_trap = 1'b0;
        ex_trap_cause = 32'd0;
        ex_csr_write_en = 1'b0;
        ex_csr_write_addr = id_ex_csr_addr;
        ex_csr_write_data = 32'd0;

        if (!mem_stall && id_ex_valid) begin
            if (id_ex_csr_read || id_ex_csr_write) begin
                case (id_ex_funct3)
                    3'b001: begin
                        ex_csr_write_en = 1'b1;
                        ex_csr_write_data = ex_forward_a_data;
                    end
                    3'b010: begin
                        ex_csr_write_en = (id_ex_rs1 != 5'd0);
                        ex_csr_write_data = id_ex_csr_old | ex_forward_a_data;
                    end
                    3'b011: begin
                        ex_csr_write_en = (id_ex_rs1 != 5'd0);
                        ex_csr_write_data = id_ex_csr_old & ~ex_forward_a_data;
                    end
                    3'b101: begin
                        ex_csr_write_en = 1'b1;
                        ex_csr_write_data = {27'd0, id_ex_rs1};
                    end
                    3'b110: begin
                        ex_csr_write_en = (id_ex_rs1 != 5'd0);
                        ex_csr_write_data = id_ex_csr_old | {27'd0, id_ex_rs1};
                    end
                    3'b111: begin
                        ex_csr_write_en = (id_ex_rs1 != 5'd0);
                        ex_csr_write_data = id_ex_csr_old & ~{27'd0, id_ex_rs1};
                    end
                    default: begin
                        ex_csr_write_en = 1'b0;
                        ex_csr_write_data = 32'd0;
                    end
                endcase
            end

            if (id_ex_is_ecall) begin
                ex_redirect = 1'b1;
                ex_redirect_target = csr_mtvec & 32'hffff_fffc;
                ex_is_trap = 1'b1;
                ex_trap_cause = 32'd11;
            end else if (id_ex_is_ebreak) begin
                ex_redirect = 1'b1;
                ex_redirect_target = csr_mtvec & 32'hffff_fffc;
                ex_is_trap = 1'b1;
                ex_trap_cause = 32'd3;
            end else if (id_ex_is_mret) begin
                ex_redirect = 1'b1;
                ex_redirect_target = csr_mepc & 32'hffff_fffc;
            end else if (id_ex_jalr || id_ex_jal) begin
                ex_redirect = 1'b1;
            end else if ((id_ex_branch_kind != BR_NONE) && ex_branch_cond) begin
                ex_redirect = 1'b1;
            end
        end
    end

    assign dmem_addr = ex_mem_alu_result;
    assign dmem_read_en = ex_mem_valid && ex_mem_mem_read;
    assign dmem_write_en = ex_mem_valid && ex_mem_mem_write;

    always_comb begin
        dmem_write_data = 32'd0;
        dmem_wstrb = 4'b0000;
        case (ex_mem_mem_size)
            2'd0: begin
                dmem_write_data = {4{ex_mem_store_data[7:0]}} << (8 * ex_mem_alu_result[1:0]);
                dmem_wstrb = 4'b0001 << ex_mem_alu_result[1:0];
            end
            2'd1: begin
                dmem_write_data = {2{ex_mem_store_data[15:0]}} << (16 * ex_mem_alu_result[1]);
                dmem_wstrb = ex_mem_alu_result[1] ? 4'b1100 : 4'b0011;
            end
            default: begin
                dmem_write_data = ex_mem_store_data;
                dmem_wstrb = 4'b1111;
            end
        endcase

        if (!dmem_write_en) begin
            dmem_write_data = 32'd0;
            dmem_wstrb = 4'b0000;
        end
    end

    always_comb begin
        mem_load_data = dmem_read_data;
        case (ex_mem_mem_size)
            2'd0: begin
                case (ex_mem_alu_result[1:0])
                    2'd0: mem_load_data = ex_mem_mem_unsigned ? {24'd0, dmem_read_data[7:0]}   : {{24{dmem_read_data[7]}}, dmem_read_data[7:0]};
                    2'd1: mem_load_data = ex_mem_mem_unsigned ? {24'd0, dmem_read_data[15:8]}  : {{24{dmem_read_data[15]}}, dmem_read_data[15:8]};
                    2'd2: mem_load_data = ex_mem_mem_unsigned ? {24'd0, dmem_read_data[23:16]} : {{24{dmem_read_data[23]}}, dmem_read_data[23:16]};
                    default: mem_load_data = ex_mem_mem_unsigned ? {24'd0, dmem_read_data[31:24]} : {{24{dmem_read_data[31]}}, dmem_read_data[31:24]};
                endcase
            end
            2'd1: begin
                if (ex_mem_alu_result[1])
                    mem_load_data = ex_mem_mem_unsigned ? {16'd0, dmem_read_data[31:16]} : {{16{dmem_read_data[31]}}, dmem_read_data[31:16]};
                else
                    mem_load_data = ex_mem_mem_unsigned ? {16'd0, dmem_read_data[15:0]} : {{16{dmem_read_data[15]}}, dmem_read_data[15:0]};
            end
            default: mem_load_data = dmem_read_data;
        endcase
    end

    always_comb begin
        case (mem_wb_wb_sel)
            WB_PC4:  wb_data = mem_wb_pc4;
            WB_LOAD: wb_data = mem_wb_load_data;
            WB_CSR:  wb_data = mem_wb_csr_old;
            default: wb_data = mem_wb_alu_result;
        endcase
    end

    // Registered redirect logic to break critical path from forwarding/branch comparator
    logic        ex_redirect_q;
    logic [31:0] ex_redirect_target_q;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ex_redirect_q <= 1'b0;
            ex_redirect_target_q <= 32'd0;
        end else if (!mem_stall) begin
            ex_redirect_q <= ex_redirect;
            ex_redirect_target_q <= ex_redirect_target;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        integer i;
        if (reset) begin
            pc_f <= 32'h80000000;
            if_id_valid <= 1'b0;
            if_id_pc <= 32'd0;
            if_id_instr <= 32'd0;
            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'd0;
            id_ex_pc4 <= 32'd0;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_imm <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_rd <= 5'd0;
            id_ex_funct3 <= 3'd0;
            id_ex_funct7 <= 7'd0;
            id_ex_use_rs1 <= 1'b0;
            id_ex_use_rs2 <= 1'b0;
            id_ex_src_a_pc <= 1'b0;
            id_ex_src_b_imm <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_size <= 2'd0;
            id_ex_mem_unsigned <= 1'b0;
            id_ex_jal <= 1'b0;
            id_ex_jalr <= 1'b0;
            id_ex_branch_kind <= BR_NONE;
            id_ex_wb_sel <= WB_ALU;
            id_ex_alu_op <= ALU_ADD;
            id_ex_is_fence <= 1'b0;
            id_ex_is_fence_i <= 1'b0;
            id_ex_is_ecall <= 1'b0;
            id_ex_is_ebreak <= 1'b0;
            id_ex_is_mret <= 1'b0;
            id_ex_csr_read <= 1'b0;
            id_ex_csr_write <= 1'b0;
            id_ex_csr_addr <= 12'd0;
            id_ex_csr_old <= 32'd0;
            ex_mem_valid <= 1'b0;
            ex_mem_pc4 <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_store_data <= 32'd0;
            ex_mem_rd <= 5'd0;
            ex_mem_wb_sel <= WB_ALU;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_size <= 2'd0;
            ex_mem_mem_unsigned <= 1'b0;
            ex_mem_csr_old <= 32'd0;
            mem_wb_valid <= 1'b0;
            mem_wb_pc4 <= 32'd0;
            mem_wb_alu_result <= 32'd0;
            mem_wb_load_data <= 32'd0;
            mem_wb_csr_old <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_wb_sel <= WB_ALU;
            mem_wb_reg_write <= 1'b0;
            csr_mtvec <= 32'd0;
            csr_mepc <= 32'd0;
            csr_mcause <= 32'd0;
            csr_mscratch <= 32'd0;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end else begin
            if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0))
                registers[mem_wb_rd] <= wb_data;
            registers[0] <= 32'd0;

            if (id_ex_valid && ex_csr_write_en) begin
                case (ex_csr_write_addr)
                    12'h305: csr_mtvec <= ex_csr_write_data;
                    12'h340: csr_mscratch <= ex_csr_write_data;
                    12'h341: csr_mepc <= ex_csr_write_data & 32'hffff_fffc;
                    12'h342: csr_mcause <= ex_csr_write_data;
                    default: begin
                    end
                endcase
            end

            if (id_ex_valid && ex_is_trap) begin
                csr_mepc <= id_ex_pc & 32'hffff_fffc;
                csr_mcause <= ex_trap_cause;
            end

            if (mem_stall) begin
            end else if (ex_redirect) begin
                pc_f <= ex_redirect_target;
                if_id_valid <= 1'b0;
                if_id_pc <= 32'd0;
                if_id_instr <= 32'd0;
            end else if (stall_if) begin
            end else if (imem_ready) begin
                if_id_valid <= 1'b1;
                if_id_pc <= pc_f;
                if_id_instr <= imem_instr;
                pc_f <= pc_f + 32'd4;
            end else begin
                if_id_valid <= 1'b0;
                if_id_pc <= 32'd0;
                if_id_instr <= 32'd0;
            end

            if (mem_stall) begin
            end else if (ex_redirect || bubble_ex) begin
                id_ex_valid <= 1'b0;
                id_ex_pc <= 32'd0;
                id_ex_pc4 <= 32'd0;
                id_ex_rs1_data <= 32'd0;
                id_ex_rs2_data <= 32'd0;
                id_ex_imm <= 32'd0;
                id_ex_rs1 <= 5'd0;
                id_ex_rs2 <= 5'd0;
                id_ex_rd <= 5'd0;
                id_ex_funct3 <= 3'd0;
                id_ex_funct7 <= 7'd0;
                id_ex_use_rs1 <= 1'b0;
                id_ex_use_rs2 <= 1'b0;
                id_ex_src_a_pc <= 1'b0;
                id_ex_src_b_imm <= 1'b0;
                id_ex_reg_write <= 1'b0;
                id_ex_mem_read <= 1'b0;
                id_ex_mem_write <= 1'b0;
                id_ex_mem_size <= 2'd0;
                id_ex_mem_unsigned <= 1'b0;
                id_ex_jal <= 1'b0;
                id_ex_jalr <= 1'b0;
                id_ex_branch_kind <= BR_NONE;
                id_ex_wb_sel <= WB_ALU;
                id_ex_alu_op <= ALU_ADD;
                id_ex_is_fence <= 1'b0;
                id_ex_is_fence_i <= 1'b0;
                id_ex_is_ecall <= 1'b0;
                id_ex_is_ebreak <= 1'b0;
                id_ex_is_mret <= 1'b0;
                id_ex_csr_read <= 1'b0;
                id_ex_csr_write <= 1'b0;
                id_ex_csr_addr <= 12'd0;
                id_ex_csr_old <= 32'd0;
            end else if (!stall_id) begin
                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc + 32'd4;
                id_ex_rs1_data <= id_rs1_data;
                id_ex_rs2_data <= id_rs2_data;
                id_ex_imm <= id_imm;
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
                id_ex_is_fence <= id_is_fence;
                id_ex_is_fence_i <= id_is_fence_i;
                id_ex_is_ecall <= id_is_ecall;
                id_ex_is_ebreak <= id_is_ebreak;
                id_ex_is_mret <= id_is_mret;
                id_ex_csr_read <= id_csr_read;
                id_ex_csr_write <= id_csr_write;
                id_ex_csr_addr <= id_csr_addr;
                id_ex_csr_old <= id_csr_old;
            end

            if (!mem_stall) begin
                ex_mem_valid <= id_ex_valid;
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

            if (mem_stall) begin
                mem_wb_valid <= 1'b0;
                mem_wb_pc4 <= 32'd0;
                mem_wb_alu_result <= 32'd0;
                mem_wb_load_data <= 32'd0;
                mem_wb_csr_old <= 32'd0;
                mem_wb_rd <= 5'd0;
                mem_wb_wb_sel <= WB_ALU;
                mem_wb_reg_write <= 1'b0;
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
