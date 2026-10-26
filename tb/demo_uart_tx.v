// =============================================================================
// DEMO 3: UART TX — Transmit "MorphoSoC" over serial
// Open in GTKWave and watch:
//   clk, rst_n, uart_tx  → you will see the serial bits clearly
//   Also: baud_tick, tx_data, tx_start, tx_done, uart_irq
// =============================================================================
`timescale 1ns/1ps

module demo_uart_tx;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;   // 100 MHz

    // AXI4-Lite bus signals
    reg  [11:0] awaddr  = 0;
    reg         awvalid = 0;
    wire        awready;
    reg  [31:0] wdata   = 0;
    reg  [3:0]  wstrb   = 4'hF;
    reg         wvalid  = 0;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready  = 1;

    wire        uart_tx;
    wire        uart_tx_done;
    wire        uart_irq;
    wire        uart_rx_echo;   // loopback

    uart_top dut (
        .aclk           (clk),
        .aresetn        (rst_n),
        .s_axi_awaddr   (awaddr),
        .s_axi_awprot   (3'b0),
        .s_axi_awvalid  (awvalid),
        .s_axi_awready  (awready),
        .s_axi_wdata    (wdata),
        .s_axi_wstrb    (wstrb),
        .s_axi_wvalid   (wvalid),
        .s_axi_wready   (wready),
        .s_axi_bresp    (bresp),
        .s_axi_bvalid   (bvalid),
        .s_axi_bready   (bready),
        .s_axi_araddr   (12'h0),
        .s_axi_arprot   (3'b0),
        .s_axi_arvalid  (1'b0),
        .s_axi_arready  (),
        .s_axi_rdata    (),
        .s_axi_rresp    (),
        .s_axi_rvalid   (),
        .s_axi_rready   (1'b1),
        .uart_rx        (uart_tx),   // loopback TX→RX
        .uart_tx        (uart_tx),
        .uart_irq       (uart_irq),
        .uart_tx_done   (uart_tx_done),
        .uart_rx_done   ()
    );

    // AXI write task
    task axi_write;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            awaddr  = addr;
            awvalid = 1'b1;
            wdata   = data;
            wvalid  = 1'b1;
            @(posedge clk);
            while (!awready || !wready) @(posedge clk);
            awvalid = 1'b0;
            wvalid  = 1'b0;
            @(posedge clk);
            while (!bvalid) @(posedge clk);
            @(posedge clk);
        end
    endtask

    // Task: write one byte to UART TX FIFO (addr 0x008 = TX FIFO data register)
    task uart_send;
        input [7:0] byte_val;
        begin
            axi_write(12'h008, {24'h0, byte_val});
            $display("[%0t ns] Sending 0x%02h ('%c')", $time/1000, byte_val, byte_val);
        end
    endtask

    initial begin
        $dumpfile("demo_uart_tx.vcd");
        $dumpvars(0, demo_uart_tx);

        rst_n = 0;
        repeat(6) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);

        $display("[%0t ns] === UART TX Demo: transmitting 'MorphoSoC!' ===", $time/1000);

        // Configure baud divisor: reg 0x000 = divisor (100MHz / 115200 ≈ 868)
        axi_write(12'h000, 32'd868);

        // Transmit "MorphoSoC!"
        uart_send("M");
        uart_send("o");
        uart_send("r");
        uart_send("p");
        uart_send("h");
        uart_send("o");
        uart_send("S");
        uart_send("o");
        uart_send("C");
        uart_send("!");
        uart_send(8'h0D);   // CR
        uart_send(8'h0A);   // LF

        // Wait for all bytes to shift out
        repeat(30000) @(posedge clk);

        $display("[%0t ns] === Demo Complete ===", $time/1000);
        $finish;
    end

endmodule
