#include <stdint.h>

/*
 * Simple bare-metal program for the RV32I BRAM core.
 *
 * Memory model (the core's own view):
 *   - instructions are fetched from IMEM (this program lives there, PC starts at 0)
 *   - data lives in DMEM; addresses below are DMEM byte offsets
 *
 * On the FPGA the ARM reads these DMEM offsets at 0x44000000 + offset:
 *   0x0C : result   0x10 : status (0xCAFECAFE = done)
 *
 * Use only RV32I operations here (no *, /, % - the core has no M extension).
 */
#define RESULT_ADDR  ((volatile uint32_t *)0x0000000CU)
#define STATUS_ADDR  ((volatile uint32_t *)0x00000010U)
#define STATUS_DONE  0xCAFECAFEU

int main(void)
{
    uint32_t sum = 0;
    uint32_t i;

    for (i = 1U; i <= 12U; ++i)   /* 1 + 2 + ... + 10 = 55 */
        sum += i;

    *RESULT_ADDR = sum;           /* write result to data BRAM */
    *STATUS_ADDR = STATUS_DONE;   /* tell the ARM we're done    */

    for (;;) { }                  /* halt (self-loop)           */
    return 0;
}
