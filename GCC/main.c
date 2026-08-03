#include <stdint.h>
#include "shared_mem.h"

#define AXI_GPIO_LED      ((volatile uint32_t *)0x10000000U)
#define DIAG_WORD(offset) ((volatile uint32_t *)(MAILBOX_DIAG_BASE + (offset)))

#define TEST_A            13U
#define TEST_B            70U
#define EXPECTED_RESULT   ((TEST_A + TEST_B) + (TEST_A * TEST_B))

static void delay(void)
{
    volatile uint32_t i;

    for (i = 0U; i < 100000U; ++i) {
        __asm__ volatile ("nop");
    }
}

static void blink_once(void)
{
    *AXI_GPIO_LED = 0x1U;
    delay();
    *AXI_GPIO_LED = 0x2U;
    delay();
    *AXI_GPIO_LED = 0x4U;
    delay();
    *AXI_GPIO_LED = 0x8U;
    delay();
    *AXI_GPIO_LED = 0x0U;
    delay();
}

int main(void)
{
    uint32_t a;
    uint32_t b;
    uint32_t add_result;
    uint32_t sub_result;
    uint32_t mul_result;
    uint32_t final_result;
    uint32_t fail_count = 0U;

    *MAILBOX_INPUT0_ADDR = TEST_A;
    *MAILBOX_INPUT1_ADDR = TEST_B;

    a = *MAILBOX_INPUT0_ADDR;
    b = *MAILBOX_INPUT1_ADDR;

    add_result = a + b;
    sub_result = a - b;
    mul_result = a * b;
    final_result = add_result + mul_result;

    *DIAG_WORD(0x00U) = a;
    *DIAG_WORD(0x04U) = b;
    *DIAG_WORD(0x08U) = add_result;
    *DIAG_WORD(0x0CU) = sub_result;
    *DIAG_WORD(0x10U) = mul_result;

    if (add_result != 20U)
        fail_count++;
    if (sub_result != 6U)
        fail_count++;
    if (mul_result != 91U)
        fail_count++;

    *MAILBOX_RESULT_ADDR = final_result;
    *MAILBOX_EXPECTED_ADDR = EXPECTED_RESULT;
    *MAILBOX_FAIL_COUNT_ADDR = fail_count;
    *MAILBOX_STATUS_ADDR = STATUS_DONE;

    for (;;) {
       blink_once();
    }

    return 0;
}
