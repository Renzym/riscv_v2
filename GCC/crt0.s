    .section .text.startup, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    la sp, _stack_top
    j main

    .size _start, . - _start
