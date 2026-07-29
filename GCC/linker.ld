ENTRY(_start)

/*
 * RV32IM direct-BRAM memory map (core's view).
 *   0x0000..0x07ff : code / rodata
 *   0x0000..0x00ff : DMEM mailbox reserved for PS <-> core exchange
 *   0x0900..0x0bff : data / bss
 *   0x0c00..0x0fff : stack
 *
 * IMEM and DMEM are separate BRAM ports. The matching physical addresses from
 * the ARM/PS side are 0x42000000 for IMEM and 0x44000000 for DMEM.
 */
MEMORY
{
    CODE_MEM  (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00000800
    DATA_MEM  (rwx) : ORIGIN = 0x00000900, LENGTH = 0x00000300
    STACK_MEM (rw)  : ORIGIN = 0x00000C00, LENGTH = 0x00000400
}

_stack_size = 0x400;   /* 1 KB stack */

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.startup))
        KEEP(*(.text.startup.*))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
    } > CODE_MEM

    /* No runtime .data copy is done (crt0 is minimal), so keep programs free of
       initialized globals - use locals/computed values as in main.c. */
    .data :
    {
        . = ALIGN(4);
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
    } > DATA_MEM AT > CODE_MEM

    .bss :
    {
        . = ALIGN(4);
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
    } > DATA_MEM

    .stack ORIGIN(STACK_MEM) :
    {
        . = ALIGN(16);
        _stack_bottom = .;
        . += _stack_size;
        _stack_top = .;
    } > STACK_MEM

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame)
    }
}

ASSERT(_stack_top <= ORIGIN(STACK_MEM) + LENGTH(STACK_MEM), "stack overflow")
