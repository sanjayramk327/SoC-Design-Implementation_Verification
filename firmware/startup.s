.section .text.init
.globl _start

_start:
    # Initialize integer register file
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0

    # Set stack pointer to top of 32KB SRAM
    li sp, 0x20008000

    # Set trap vector
    la t0, trap_handler
    csrw mtvec, t0

    # Enable global interrupts
    li t0, 0x888
    csrw mie, t0
    csrsi mstatus, 0x8

    # Jump to main application
    jal ra, main

dead_loop:
    wfi
    j dead_loop

.globl trap_handler
.align 4
trap_handler:
    # Save context, handle event, and return
    csrr t0, mcause
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
    mret
