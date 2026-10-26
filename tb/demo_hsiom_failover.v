// =============================================================================
// DEMO 2: HSIOM Self-Healing — Autonomous Pin Failover
// Open in GTKWave and watch:
//   clk, rst_n, pad_in, pad_out, uart_tx, hsiom_fault_event
//   HSIOM_PINS[0].u_cell.sig_uart  → goes LOW when fault
//   HSIOM_PINS[1].u_cell.sig_uart  → goes HIGH (backup takes over)
// =============================================================================
`timescale 1ns/1ps

module demo_hsiom_failover;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;   // 100 MHz

    // HSIOM ports
    wire [15:0] pad_out;
    wire [15:0] pad_oe;
    reg  [15:0] pad_in         = 16'h0000;
    reg         uart_tx_src    = 1'b1;   // UART idle = HIGH
    wire        uart_rx_out;
    wire        hsiom_fault_event;

    // Peripheral sources (UART on pin 3 by default, see hsiom_top reset logic)
    hsiom_top dut (
        .aclk            (clk),
        .aresetn         (rst_n),
        .s_axi_awaddr    (12'h0),
        .s_axi_awprot    (3'b0),
        .s_axi_awvalid   (1'b0),
        .s_axi_awready   (),
        .s_axi_wdata     (32'h0),
        .s_axi_wstrb     (4'hF),
        .s_axi_wvalid    (1'b0),
        .s_axi_wready    (),
        .s_axi_bresp     (),
        .s_axi_bvalid    (),
        .s_axi_bready    (1'b1),
        .s_axi_araddr    (12'h0),
        .s_axi_arprot    (3'b0),
        .s_axi_arvalid   (1'b0),
        .s_axi_arready   (),
        .s_axi_rdata     (),
        .s_axi_rresp     (),
        .s_axi_rvalid    (),
        .s_axi_rready    (1'b1),
        .gpio_dr         (16'h5A5A),
        .uart_tx         (uart_tx_src),
        .uart_rx         (uart_rx_out),
        .tcpwm_out0      (1'b0),
        .tcpwm_nout0     (1'b1),
        .udb_out         (8'hAA),
        .snn_spike       (1'b0),
        .pad_out         (pad_out),
        .pad_oe          (pad_oe),
        .pad_in          (pad_in),
        .hsiom_fault_event(hsiom_fault_event)
    );

    // Simple task: send a UART byte pattern on uart_tx_src
    task send_uart_byte;
        input [7:0] data;
        integer k;
        begin
            // START bit
            uart_tx_src = 0;
            repeat(8) @(posedge clk);   // 1 bit = 8 cycles (simulated baud)
            for (k = 0; k < 8; k = k+1) begin
                uart_tx_src = data[k];
                repeat(8) @(posedge clk);
            end
            // STOP bit
            uart_tx_src = 1;
            repeat(8) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("demo_hsiom_failover.vcd");
        $dumpvars(0, demo_hsiom_failover);

        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);

        $display("[%0t ns] === HSIOM Self-Healing Demo ===", $time/1000);
        $display("[%0t ns] Sending UART bytes normally (no fault)...", $time/1000);

        // Normal operation — transmit 3 bytes
        send_uart_byte(8'h48);   // 'H'
        send_uart_byte(8'h49);   // 'I'
        $display("[%0t ns] pad_out=0x%04h, fault=%b", $time/1000, pad_out, hsiom_fault_event);

        // ---- Inject FAULT: drive pad_in stuck at 0 (simulates shorted pin) ----
        $display("[%0t ns] >>> FAULT INJECTED on pad_in[3] (stuck-at-0)...", $time/1000);
        pad_in = 16'h0000;     // All pins pulled low — triggers fault detector
        repeat(20) @(posedge clk);
        $display("[%0t ns] hsiom_fault_event = %b  (expect 1)", $time/1000, hsiom_fault_event);

        // HSIOM should autonomously reroute UART to backup pin
        repeat(10) @(posedge clk);
        $display("[%0t ns] pad_out=0x%04h (UART now on backup pin)", $time/1000, pad_out);

        // Transmission resumes after failover — with no software intervention
        $display("[%0t ns] Sending UART bytes after autonomous failover...", $time/1000);
        send_uart_byte(8'h4F);   // 'O'
        send_uart_byte(8'h4B);   // 'K'

        // ---- Clear fault ----
        $display("[%0t ns] Clearing fault (pad_in driven HIGH)...", $time/1000);
        pad_in = 16'hFFFF;
        repeat(20) @(posedge clk);
        $display("[%0t ns] hsiom_fault_event = %b  (expect 0)", $time/1000, hsiom_fault_event);

        send_uart_byte(8'h2E);   // '.'
        repeat(10) @(posedge clk);

        $display("[%0t ns] === Demo Complete ===", $time/1000);
        $finish;
    end

endmodule
