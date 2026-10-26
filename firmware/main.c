#include "psoc_mmap.h"
#include "drivers/uart.h"

int main(void) {
    // 1. Initialize SCB UART (100 MHz clock, 115200 baud)
    uart_init(100000000, 115200);
    uart_puts("\r\n=========================================================\r\n");
    uart_puts("   MorphoSoC: Autonomous Polymorphic PSoC Initialized!   \r\n");
    uart_puts("=========================================================\r\n");

    // 2. Configure [PATENT NOVELTY 1] UDB 2.0 Shadow Contexts
    uart_puts("[INIT] Programming UDB 2.0 Single-Cycle Shadow Contexts...\r\n");
    // Context 0: Filter Accumulator
    UDB_CTX0_CFG = 0x00030000;
    // Context 1: Real-time Stream Decryptor (Key = 0xA5)
    UDB_CTX1_CFG = 0x0FFF00B5;
    // Context 2: CRC-8 Polynomial Hash Engine
    UDB_CTX2_CFG = 0x155500D6;

    // 3. Configure [PATENT NOVELTY 2] Mixed-Signal Neuromorphic Smart-Sense
    uart_puts("[INIT] Arming Neuromorphic Spiking Smart-Sense Engine...\r\n");
    AMUX_CTRL     = 0x00020001; // AMUXBUS-A mapped to Pin 0, AMUXBUS-B to Pin 1
    SNN_LEAK      = 12;         // Leak rate beta
    SNN_THRESHOLD = 500;        // Firing threshold theta
    SNN_CTRL      = 0x00000001; // Enable SNN

    // 4. Configure [PATENT NOVELTY 3] Self-Healing HSIOM Failover
    uart_puts("[INIT] Enabling Autonomous Pin Contention Failover (Backup: Pin 7)...\r\n");
    HSIOM_FAILOVER = 0x00001471; // Enable failover, backup pin = 7, threshold = 20 cycles

    // 5. Configure TCPWM (Center-aligned with Deadband)
    TCPWM_PERIOD   = 1000;
    TCPWM_COMPARE  = 500;
    TCPWM_DEADBAND = 15;
    TCPWM_CTRL     = 0x00000007; // Enable, center-aligned, deadband active

    uart_puts("[READY] System fully operational. Autonomous hardware engines active.\r\n");

    while (1) {
        // Query autonomous status registers
        uint32_t current_ctx = UDB_STATUS & 0x03;
        uint32_t gesture     = SNN_GESTURE_CLASS;
        uint32_t failover    = (HSIOM_STATUS >> 21) & 0x01;

        if (failover) {
            uart_puts("[ALERT] Hardware pin short detected! Self-healing failover active on Pin 7!\r\n");
        }

        if (gesture > 0) {
            uart_puts("[SNN] Autonomous touch/gesture classified: ID = ");
            uart_putc('0' + gesture);
            uart_puts("\r\n");
        }

        // Low power sleep waiting for reactive event triggers
        __asm__ volatile ("wfi");
    }

    return 0;
}
