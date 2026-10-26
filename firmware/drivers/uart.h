#ifndef DRIVER_UART_H
#define DRIVER_UART_H

#include "../psoc_mmap.h"

static inline void uart_init(uint32_t clk_hz, uint32_t baud_rate) {
    UART_BAUD_DIV = clk_hz / baud_rate;
    UART_CTRL     = 0x00000003; // Enable TX and RX
}

static inline void uart_putc(char c) {
    while (UART_STATUS & 0x08); // Wait while TX FIFO is full
    UART_TX_DATA = (uint32_t)c;
}

static inline void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

static inline int uart_getc_nonblocking(char *c) {
    if (UART_STATUS & 0x10) return 0; // RX FIFO empty
    *c = (char)(UART_RX_DATA & 0xFF);
    return 1;
}

#endif // DRIVER_UART_H
