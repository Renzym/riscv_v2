/*
 * simple_test.c  --  Vitis (ARM PS) self-checking RV32IM instruction test.
 *
 * The DDR / cache path has been removed from the design. The RISC-V core now
 * talks directly to two BRAMs:
 *
 *      IMEM (instructions)  PS address 0x42000000   core sees PC = 0
 *      DMEM (data)          PS address 0x44000000   core sees addr = 0
 *      Control register     PS address 0x40000000   bit0 = CPU reset (1=hold)
 *
 * This program HAND-ASSEMBLES a small RV32IM machine-code program (no GCC, no
 * compiled image). The program exercises base RV32I ALU / shift / compare /
 * load / store / branch / jump instructions plus all RV32M multiply/divide
 * instructions, stores each result into DMEM, then writes a DONE marker. The
 * ARM side loads it into IMEM, releases the core, polls for DONE, and checks
 * every result against the expected value.
 *
 * Build: add this file as the application source in Vitis (bare-metal,
 * standalone BSP). Uses only xil_io / xil_printf / sleep.
 */

#include <stdint.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

/* ------------------------------------------------------------------ */
/* Address map (PS view)                                              */
/* ------------------------------------------------------------------ */
#define IMEM_BASE     0x42000000U
#define DMEM_BASE     0x44000000U
#define CTRL_BASE     0x40000000U

#define CTRL_CPU_RESET   0x00000001U   /* write 1 = hold core in reset */

/* DMEM layout (core view = PS view, same offsets) */
#define STATUS_OFF    0x10U            /* core writes DONE marker here    */
#define RESULT_OFF    0x40U            /* result[i] at RESULT_OFF + i*4   */
#define SCRATCH_OFF   0x200U           /* load/store scratch area         */

#define STATUS_DONE   0xCAFECAFEU
#define POLL_TIMEOUT  2000000U

/* ------------------------------------------------------------------ */
/* RV32IM encoders                                                    */
/* ------------------------------------------------------------------ */
/* opcodes */
#define OP_R     0x33U
#define OP_I     0x13U
#define OP_LOAD  0x03U
#define OP_STORE 0x23U
#define OP_BR    0x63U
#define OP_MISC  0x0FU
#define OP_LUI   0x37U
#define OP_AUIPC 0x17U
#define OP_JAL   0x6FU
#define OP_JALR  0x67U

/* registers */
#define ZERO 0
#define RA   1
#define T0   5
#define T1   6
#define T2   7
#define A0   10   /* result base pointer  (= RESULT_OFF) */
#define A1   11   /* value being stored                  */
#define A2   12   /* scratch base pointer (= SCRATCH_OFF)*/

static uint32_t prog[1024];
static uint32_t prog_n;

static uint32_t  exp_val[128];
static const char *exp_name[128];
static uint32_t  test_n;

static void emit(uint32_t w) { prog[prog_n++] = w; }

static uint32_t enc_r(uint32_t f7, uint32_t rs2, uint32_t rs1,
                      uint32_t f3, uint32_t rd)
{
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | OP_R;
}

static uint32_t enc_i(int32_t imm, uint32_t rs1, uint32_t f3,
                      uint32_t rd, uint32_t op)
{
    return (((uint32_t)imm & 0xFFFU) << 20) | (rs1 << 15) | (f3 << 12) |
           (rd << 7) | op;
}

static uint32_t enc_ish(uint32_t f7, uint32_t shamt, uint32_t rs1,
                        uint32_t f3, uint32_t rd)
{
    return (f7 << 25) | ((shamt & 0x1FU) << 20) | (rs1 << 15) |
           (f3 << 12) | (rd << 7) | OP_I;
}

static uint32_t enc_s(int32_t imm, uint32_t rs2, uint32_t rs1, uint32_t f3)
{
    uint32_t i = (uint32_t)imm & 0xFFFU;
    return (((i >> 5) & 0x7FU) << 25) | (rs2 << 20) | (rs1 << 15) |
           (f3 << 12) | ((i & 0x1FU) << 7) | OP_STORE;
}

static uint32_t enc_b(int32_t imm, uint32_t rs2, uint32_t rs1, uint32_t f3)
{
    uint32_t i = (uint32_t)imm & 0x1FFFU;          /* 13-bit, bit0 = 0 */
    uint32_t b12 = (i >> 12) & 1U;
    uint32_t b11 = (i >> 11) & 1U;
    uint32_t b10_5 = (i >> 5) & 0x3FU;
    uint32_t b4_1 = (i >> 1) & 0xFU;
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) |
           (f3 << 12) | (b4_1 << 8) | (b11 << 7) | OP_BR;
}

static uint32_t enc_u(uint32_t imm20, uint32_t rd, uint32_t op)
{
    return ((imm20 & 0xFFFFFU) << 12) | (rd << 7) | op;
}

static uint32_t enc_j(int32_t imm, uint32_t rd)
{
    uint32_t i = (uint32_t)imm & 0x1FFFFFU;        /* 21-bit, bit0 = 0 */
    uint32_t b20 = (i >> 20) & 1U;
    uint32_t b10_1 = (i >> 1) & 0x3FFU;
    uint32_t b11 = (i >> 11) & 1U;
    uint32_t b19_12 = (i >> 12) & 0xFFU;
    return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) |
           (rd << 7) | OP_JAL;
}

/* Load a 32-bit constant into rd (LUI+ADDI, or single ADDI when it fits). */
static void li(uint32_t rd, uint32_t val)
{
    int32_t lo = (int32_t)(val & 0xFFFU);
    if (lo & 0x800)
        lo -= 0x1000;                              /* sign-extend low 12 */
    uint32_t hi = (val - (uint32_t)lo) >> 12;

    if (hi == 0U) {
        emit(enc_i(lo, ZERO, 0x0, rd, OP_I));      /* addi rd, x0, lo */
    } else {
        emit(enc_u(hi, rd, OP_LUI));               /* lui  rd, hi     */
        if ((val & 0xFFFU) != 0U)
            emit(enc_i(lo, rd, 0x0, rd, OP_I));    /* addi rd, rd, lo */
    }
}

/* Store A1 into result slot, and record the expected value + name. */
static void result(const char *name, uint32_t expected)
{
    emit(enc_s((int32_t)(test_n * 4U), A1, A0, 0x2));   /* sw a1, n*4(a0) */
    exp_name[test_n] = name;
    exp_val[test_n]  = expected;
    test_n++;
}

static void rr(uint32_t lhs, uint32_t rhs, uint32_t f7, uint32_t f3)
{
    li(T0, lhs);
    li(T1, rhs);
    emit(enc_r(f7, T1, T0, f3, A1));
}

/* ------------------------------------------------------------------ */
/* Build the RV32IM test program                                      */
/* ------------------------------------------------------------------ */
static void build_program(void)
{
    prog_n = 0;
    test_n = 0;

    li(A0, RESULT_OFF);     /* a0 -> results base  */
    li(A2, SCRATCH_OFF);    /* a2 -> scratch base  */

    /* ---------- R-type ---------- */
    li(T0, 10); li(T1, 20); emit(enc_r(0x00, T1, T0, 0x0, A1)); result("ADD",  30);
    li(T0, 50); li(T1, 30); emit(enc_r(0x20, T1, T0, 0x0, A1)); result("SUB",  20);
    li(T0, 0xFF); li(T1, 0x0F); emit(enc_r(0x00, T1, T0, 0x7, A1)); result("AND", 0x0F);
    li(T0, 0xF0); li(T1, 0x0F); emit(enc_r(0x00, T1, T0, 0x6, A1)); result("OR",  0xFF);
    li(T0, 0xFF); li(T1, 0x0F); emit(enc_r(0x00, T1, T0, 0x4, A1)); result("XOR", 0xF0);
    li(T0, 1);  li(T1, 4);  emit(enc_r(0x00, T1, T0, 0x1, A1)); result("SLL", 16);
    li(T0, 0x80000000U); li(T1, 1); emit(enc_r(0x00, T1, T0, 0x5, A1)); result("SRL", 0x40000000U);
    li(T0, (uint32_t)-8); li(T1, 1); emit(enc_r(0x20, T1, T0, 0x5, A1)); result("SRA", (uint32_t)-4);
    li(T0, (uint32_t)-1); li(T1, 1); emit(enc_r(0x00, T1, T0, 0x2, A1)); result("SLT",  1);
    li(T0, 1); li(T1, 2);   emit(enc_r(0x00, T1, T0, 0x3, A1)); result("SLTU", 1);
    li(T0, (uint32_t)-1); li(T1, 1); emit(enc_r(0x00, T1, T0, 0x3, A1)); result("SLTU(big)", 0);

    /* ---------- RV32M ---------- */
    rr(0xFFFFFFFDU, 7U,          0x01, 0x0); result("MUL",      0xFFFFFFEBU);
    rr(0x80000000U, 2U,          0x01, 0x1); result("MULH",     0xFFFFFFFFU);
    rr(0xFFFFFFFEU, 3U,          0x01, 0x2); result("MULHSU",   0xFFFFFFFFU);
    rr(0xFFFFFFFFU, 2U,          0x01, 0x3); result("MULHU",    0x00000001U);
    rr(0xFFFFFFACU, 7U,          0x01, 0x4); result("DIV",      0xFFFFFFF4U);
    rr(84U,         7U,          0x01, 0x5); result("DIVU",     0x0000000CU);
    rr(0xFFFFFFABU, 7U,          0x01, 0x6); result("REM",      0xFFFFFFFFU);
    rr(85U,         7U,          0x01, 0x7); result("REMU",     0x00000001U);
    rr(123U,        0U,          0x01, 0x4); result("DIV_ZERO", 0xFFFFFFFFU);
    rr(123U,        0U,          0x01, 0x6); result("REM_ZERO", 0x0000007BU);
    rr(0x80000000U, 0xFFFFFFFFU, 0x01, 0x4); result("DIV_OVF",  0x80000000U);
    rr(0x80000000U, 0xFFFFFFFFU, 0x01, 0x6); result("REM_OVF",  0x00000000U);

    /* ---------- I-type ALU ---------- */
    li(T0, 100); emit(enc_i(23, T0, 0x0, A1, OP_I)); result("ADDI", 123);
    li(T0, 0xFF); emit(enc_i(0x0F, T0, 0x7, A1, OP_I)); result("ANDI", 0x0F);
    li(T0, 0xF0); emit(enc_i(0x0F, T0, 0x6, A1, OP_I)); result("ORI",  0xFF);
    li(T0, 0xFF); emit(enc_i(0x0F, T0, 0x4, A1, OP_I)); result("XORI", 0xF0);
    li(T0, 1);  emit(enc_ish(0x00, 3, T0, 0x1, A1)); result("SLLI", 8);
    li(T0, 64); emit(enc_ish(0x00, 2, T0, 0x5, A1)); result("SRLI", 16);
    li(T0, (uint32_t)-8); emit(enc_ish(0x20, 1, T0, 0x5, A1)); result("SRAI", (uint32_t)-4);
    li(T0, (uint32_t)-5); emit(enc_i(0, T0, 0x2, A1, OP_I)); result("SLTI",  1);
    li(T0, 0); emit(enc_i(5, T0, 0x3, A1, OP_I)); result("SLTIU", 1);

    /* ---------- FENCE / FENCE.I: uncached core treats these as NOPs ---------- */
    emit(0x0FF0000FU);                         /* fence */
    li(A1, 1);
    result("FENCE", 1);

    emit(0x0000100FU);                         /* fence.i */
    li(A1, 1);
    result("FENCE.I", 1);

    /* ---------- U-type ---------- */
    emit(enc_u(0xABCDE, A1, OP_LUI)); result("LUI", 0xABCDE000U);

    /* AUIPC: difference between two consecutive auipc must be 4 */
    emit(enc_u(0, T0, OP_AUIPC));            /* auipc t0, 0 -> pc      */
    emit(enc_u(0, T1, OP_AUIPC));            /* auipc t1, 0 -> pc+4    */
    emit(enc_r(0x20, T0, T1, 0x0, A1));      /* sub a1, t1, t0  = 4    */
    result("AUIPC(diff)", 4);

    /* ---------- Load / Store ---------- */
    li(T0, 0x12345678U);
    emit(enc_s(0, T0, A2, 0x2));             /* sw  t0, 0(a2)          */
    emit(enc_i(0, A2, 0x2, A1, OP_LOAD));    /* lw  a1, 0(a2)          */
    result("SW/LW", 0x12345678U);

    li(T0, 0x8000U);
    emit(enc_s(4, T0, A2, 0x1));             /* sh  t0, 4(a2)          */
    emit(enc_i(4, A2, 0x1, A1, OP_LOAD));    /* lh  a1, 4(a2)  signed  */
    result("SH/LH", 0xFFFF8000U);
    emit(enc_i(4, A2, 0x5, A1, OP_LOAD));    /* lhu a1, 4(a2)          */
    result("LHU", 0x00008000U);

    li(T0, 0x80U);
    emit(enc_s(8, T0, A2, 0x0));             /* sb  t0, 8(a2)          */
    emit(enc_i(8, A2, 0x0, A1, OP_LOAD));    /* lb  a1, 8(a2)  signed  */
    result("SB/LB", 0xFFFFFF80U);
    emit(enc_i(8, A2, 0x4, A1, OP_LOAD));    /* lbu a1, 8(a2)          */
    result("LBU", 0x00000080U);

    /* ---------- Branches (taken path keeps a1 = 1) ---------- */
    /* pattern: addi a1,x0,1 ; B rs1,rs2,+8 ; addi a1,x0,0(fail) ; sw */
    #define BR_TAKEN(NAME, F3, V0, V1, EXP)                              \
        do {                                                            \
            li(T0, (V0)); li(T1, (V1));                                 \
            emit(enc_i(1, ZERO, 0x0, A1, OP_I));                        \
            emit(enc_b(8, T1, T0, (F3)));                              \
            emit(enc_i(0, ZERO, 0x0, A1, OP_I));                       \
            result((NAME), (EXP));                                     \
        } while (0)

    BR_TAKEN("BEQ",  0x0, 7, 7, 1);
    BR_TAKEN("BNE",  0x1, 7, 8, 1);
    BR_TAKEN("BLT",  0x4, (uint32_t)-1, 1, 1);
    BR_TAKEN("BGE",  0x5, 5, 3, 1);
    BR_TAKEN("BLTU", 0x6, 1, 2, 1);
    BR_TAKEN("BGEU", 0x7, 2, 1, 1);

    /* BNE not-taken: a1 starts 0, branch NOT taken, fall-through sets 1 */
    li(T0, 7);
    emit(enc_i(0, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,0           */
    emit(enc_b(8, T0, T0, 0x1));             /* bne t0,t0,+8 (not taken)*/
    emit(enc_i(1, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,1 (runs)     */
    result("BNE(not taken)", 1);

    /* ---------- JAL ---------- */
    /* a1 = 0 ; jal ra,+8 ; (skipped fail) ; addi a1,x0,1 ; sw          */
    emit(enc_i(0, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,0            */
    emit(enc_j(8, RA));                      /* jal ra,+8               */
    emit(enc_i(0, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,0 (skipped)  */
    emit(enc_i(1, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,1 (target)   */
    result("JAL", 1);

    /* ---------- JALR ---------- */
    /* auipc t2,0 ; addi a1,0 ; jalr x0,16(t2) ; (skipped) ; addi a1,1 ; sw */
    emit(enc_u(0, T2, OP_AUIPC));            /* t2 = pc                 */
    emit(enc_i(0, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,0            */
    emit(enc_i(16, T2, 0x0, ZERO, OP_JALR)); /* jalr x0,16(t2)-> pc+16  */
    emit(enc_i(0, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,0 (skipped)  */
    emit(enc_i(1, ZERO, 0x0, A1, OP_I));     /* addi a1,x0,1 (target)   */
    result("JALR", 1);

    /* ---------- Done marker + halt ---------- */
    li(A1, STATUS_DONE);
    emit(enc_s((int32_t)STATUS_OFF - (int32_t)RESULT_OFF, A1, A0, 0x2)); /* sw a1, status(a0) */
    emit(enc_j(0, ZERO));                    /* jal x0,0  (self loop)   */
}

/* ------------------------------------------------------------------ */
/* Main                                                               */
/* ------------------------------------------------------------------ */
int main(void)
{
    uint32_t i;
    uint32_t poll;
    uint32_t status;
    uint32_t pass = 0;
    uint32_t fail = 0;

    xil_printf("\r\n==========================================\r\n");
    xil_printf("RV32IM instruction self-test (BRAM only)\r\n");
    xil_printf("==========================================\r\n");

    build_program();
    xil_printf("Program  : %u instructions\r\n", prog_n);
    xil_printf("Tests    : %u\r\n", test_n);

    /* 1. Hold core in reset */
    Xil_Out32(CTRL_BASE, CTRL_CPU_RESET);

    /* 2. Clear DMEM result/status/scratch region */
    for (i = 0U; i < 0x400U; i += 4U)
        Xil_Out32(DMEM_BASE + i, 0U);

    /* 3. Load instruction memory and verify */
    for (i = 0U; i < prog_n; ++i)
        Xil_Out32(IMEM_BASE + i * 4U, prog[i]);

    for (i = 0U; i < prog_n; ++i) {
        uint32_t rb = Xil_In32(IMEM_BASE + i * 4U);
        if (rb != prog[i]) {
            xil_printf("IMEM verify FAIL @%u exp=0x%08x got=0x%08x\r\n",
                       i, prog[i], rb);
            return -1;
        }
    }
    xil_printf("IMEM     : loaded & verified\r\n");

    /* 4. Release core */
    Xil_Out32(CTRL_BASE, 0U);
    xil_printf("Core     : released, running...\r\n\r\n");

    /* 5. Wait for DONE */
    for (poll = 0U; poll < POLL_TIMEOUT; ++poll) {
        status = Xil_In32(DMEM_BASE + STATUS_OFF);
        if (status == STATUS_DONE)
            break;
        usleep(1U);
    }

    if (poll >= POLL_TIMEOUT)
        xil_printf("TIMEOUT: core never wrote DONE (status=0x%08x) -- "
                   "dumping partial results\r\n", status);
    else
        xil_printf("Core wrote DONE after %u polls.\r\n", poll);

    /* 6. Check every result */
    xil_printf("%-18s %-12s %-12s %s\r\n", "INSTRUCTION", "EXPECTED", "GOT", "RESULT");
    xil_printf("------------------------------------------------------------\r\n");
    for (i = 0U; i < test_n; ++i) {
        uint32_t got = Xil_In32(DMEM_BASE + RESULT_OFF + i * 4U);
        int ok = (got == exp_val[i]);
        xil_printf("%-18s 0x%08x   0x%08x   %s\r\n",
                   exp_name[i], exp_val[i], got, ok ? "PASS" : "FAIL");
        if (ok) pass++; else fail++;
    }

    xil_printf("------------------------------------------------------------\r\n");
    xil_printf("TOTAL: %u   PASS: %u   FAIL: %u\r\n", test_n, pass, fail);
    xil_printf("%s\r\n", (fail == 0U && poll < POLL_TIMEOUT)
                             ? ">>> ALL TESTS PASSED <<<"
                             : ">>> SOME TESTS FAILED <<<");

    return (fail == 0U && poll < POLL_TIMEOUT) ? 0 : -1;
}
