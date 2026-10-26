#ifndef PSOC_MMAP_H
#define PSOC_MMAP_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

// ==============================================================================
// MorphoSoC Memory Map (32-bit Address Space)
// ==============================================================================
#define SROM_BASE         0x00000000U // Supervisory Boot ROM (8 KB)
#define SRAM_BASE         0x20000000U // Dual-Port Tightly Coupled SRAM (32 KB)

// Peripherals MMIO
#define HSIOM_BASE        0x40000000U // High-Speed I/O Matrix
#define GPIO_BASE         0x40001000U // GPIO Ports
#define UDB_BASE          0x40002000U // UDB 2.0 Polymorphic Datapath Array
#define ANALOG_BASE       0x40003000U // Analog Frontend & SNN SmartSense
#define UART_BASE         0x40004000U // SCB UART
#define TCPWM_BASE        0x40005000U // 16-bit Timer/Counter/PWM
#define DMA_BASE          0x40006000U // 4-Channel Autonomous DMA
#define PMU_BASE          0x40007000U // Power Management & WDT
#define REM_BASE          0x40008000U // Reactive Event Matrix Crossbar

// HSIOM Registers
#define HSIOM_PORT0_SEL   REG32(HSIOM_BASE + 0x00)
#define HSIOM_PORT1_SEL   REG32(HSIOM_BASE + 0x04)
#define HSIOM_FAILOVER    REG32(HSIOM_BASE + 0x10)
#define HSIOM_STATUS      REG32(HSIOM_BASE + 0x14)

// UDB 2.0 Registers (Patent 1)
#define UDB_CTRL          REG32(UDB_BASE + 0x00)
#define UDB_STATUS        REG32(UDB_BASE + 0x04)
#define UDB_CTX0_CFG      REG32(UDB_BASE + 0x10)
#define UDB_CTX1_CFG      REG32(UDB_BASE + 0x14)
#define UDB_CTX2_CFG      REG32(UDB_BASE + 0x18)
#define UDB_CTX3_CFG      REG32(UDB_BASE + 0x1C)
#define UDB_DATA_IN       REG32(UDB_BASE + 0x30)
#define UDB_DATA_OUT      REG32(UDB_BASE + 0x34)
#define UDB_ACCUM         REG32(UDB_BASE + 0x38)

// Analog & SNN SmartSense (Patent 2)
#define AMUX_CTRL         REG32(ANALOG_BASE + 0x00)
#define IDAC_CTRL         REG32(ANALOG_BASE + 0x04)
#define COMP_CTRL         REG32(ANALOG_BASE + 0x08)
#define SNN_CTRL          REG32(ANALOG_BASE + 0x10)
#define SNN_LEAK          REG32(ANALOG_BASE + 0x14)
#define SNN_THRESHOLD     REG32(ANALOG_BASE + 0x18)
#define SNN_MEMBRANE      REG32(ANALOG_BASE + 0x1C)
#define SNN_BASELINE      REG32(ANALOG_BASE + 0x20)
#define SNN_GESTURE_CLASS REG32(ANALOG_BASE + 0x24)

// UART Registers
#define UART_CTRL         REG32(UART_BASE + 0x00)
#define UART_BAUD_DIV     REG32(UART_BASE + 0x04)
#define UART_TX_DATA      REG32(UART_BASE + 0x08)
#define UART_RX_DATA      REG32(UART_BASE + 0x0C)
#define UART_STATUS       REG32(UART_BASE + 0x10)
#define UART_FIFO_STAT    REG32(UART_BASE + 0x14)
#define UART_INTR_EN      REG32(UART_BASE + 0x18)
#define UART_INTR_STAT    REG32(UART_BASE + 0x1C)

// TCPWM Registers
#define TCPWM_CTRL        REG32(TCPWM_BASE + 0x00)
#define TCPWM_COUNTER     REG32(TCPWM_BASE + 0x04)
#define TCPWM_PERIOD      REG32(TCPWM_BASE + 0x08)
#define TCPWM_COMPARE     REG32(TCPWM_BASE + 0x0C)
#define TCPWM_DEADBAND    REG32(TCPWM_BASE + 0x10)

// PMU & Watchdog
#define PMU_MODE          REG32(PMU_BASE + 0x00)
#define WDT_CTRL          REG32(PMU_BASE + 0x04)
#define RESET_CAUSE       REG32(PMU_BASE + 0x08)

#endif // PSOC_MMAP_H
