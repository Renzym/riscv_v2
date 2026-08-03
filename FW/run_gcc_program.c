/*
 * run_gcc_program.c  -  Vitis (ARM) loader for a GCC-compiled RV32IM program.
 *
 * Flow:
 *   1. write your C in  GCC/main.c
 *   2. build it:        cd GCC && make           (produces rv32i_program_image.h)
 *   3. copy rv32i_program_image.h next to this file (or add GCC/ to the include path)
 *   4. build & run this app in Vitis on the Zynq
 *
 * What this does on the board:
 *   - holds the RISC-V core in reset
 *   - loads the compiled program into instruction BRAM (0x42000000)
 *   - releases the core; it executes from BRAM and writes its result to data BRAM
 *   - reads the result back from data BRAM (0x44000000) and prints it
 */
#include <stdint.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"
#include "rv32i_program_image.h"   /* riscv_code[], RISCV_CODE_WORD_COUNT */

#define IMEM_BASE     0x42000000U  /* instruction BRAM (ARM view) */
#define DMEM_BASE     0x44000000U  /* data BRAM        (ARM view) */
#define CTRL_BASE     0x40000000U  /* control register            */
#define CTRL_RESET    0x00000001U  /* bit0 = hold core in reset   */

#define RESULT_OFF    0x0CU        /* final result */
#define STATUS_OFF    0x10U        /* done word */
#define FAIL_OFF      0x14U        /* failing checks */
#define EXPECTED_OFF  0x18U        /* expected final result */
#define DIAG_OFF      0x20U        /* diagnostic/result words */
#define STATUS_DONE   0xCAFECAFEU
#define DIAG_WORDS    3U
#define POLL_TIMEOUT  2000000U

int main(void)
{
    uint32_t i, poll, status, result, expected, fail_count;

    xil_printf("\r\n=== Run GCC-compiled RV32IM program ===\r\n");
    xil_printf("Image : %s\r\n", RV32IM_IMAGE_TAG);
    xil_printf("Words : %u\r\n", RISCV_CODE_WORD_COUNT);

    /* 1. hold core in reset */
    Xil_Out32(CTRL_BASE, CTRL_RESET);

    /* 2. clear the low data-BRAM region (mailbox + a bit of scratch) */
    for (i = 0U; i < 0x400U; i += 4U)
        Xil_Out32(DMEM_BASE + i, 0U);

    /* 3. load the program into instruction BRAM and verify */
    for (i = 0U; i < RISCV_CODE_WORD_COUNT; ++i)
        Xil_Out32(IMEM_BASE + i * 4U, riscv_code[i]);

    for (i = 0U; i < RISCV_CODE_WORD_COUNT; ++i) {
        if (Xil_In32(IMEM_BASE + i * 4U) != riscv_code[i]) {
            xil_printf("IMEM verify FAIL @%u\r\n", i);
            return -1;
        }
    }
    xil_printf("IMEM loaded & verified.\r\n");

    /* 4. release the core */
    Xil_Out32(CTRL_BASE, 0U);
    xil_printf("Core released, running...\r\n");

    /* 5. wait for the program to signal DONE */
    for (poll = 0U; poll < POLL_TIMEOUT; ++poll) {
        status = Xil_In32(DMEM_BASE + STATUS_OFF);
        if (status == STATUS_DONE)
            break;
        usleep(1U);
    }
    if (poll >= POLL_TIMEOUT) {
        xil_printf("TIMEOUT: core never wrote DONE (status=0x%08x)\r\n", status);
        return -1;
    }

    /* 6. read the result the core wrote into data BRAM */
    result = Xil_In32(DMEM_BASE + RESULT_OFF);
    expected = Xil_In32(DMEM_BASE + EXPECTED_OFF);
    fail_count = Xil_In32(DMEM_BASE + FAIL_OFF);

    xil_printf("DONE after %u polls.\r\n", poll);
    xil_printf("Result = 0x%08x expected=0x%08x fail_count=%u\r\n",
               result, expected, fail_count);

    for (i = 0U; i < DIAG_WORDS; ++i) {
        uint32_t value = Xil_In32(DMEM_BASE + DIAG_OFF + (i * 4U));
        xil_printf("DMEM[0x%02x] = %u (0x%08x)\r\n",
                   DIAG_OFF + (i * 4U), value, value);
    }

    if ((result != expected) || (fail_count != 0U)) {
        xil_printf("GCC-loaded RISC-V program FAIL\r\n");
        return -1;
    }

    xil_printf("GCC-loaded RISC-V program PASS\r\n");

    return 0;
}
