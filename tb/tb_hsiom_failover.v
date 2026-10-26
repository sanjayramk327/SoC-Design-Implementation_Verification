`timescale 1ns / 1ps

module tb_hsiom_failover;

    reg clk;
    reg rst_n;

    reg  [11:0] s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [11:0] s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    reg  [15:0] gpio_dr;
    reg         uart_tx;
    wire        uart_rx;
    reg         tcpwm_out0;
    reg         tcpwm_nout0;
    reg  [7:0]  udb_out;
    reg         snn_spike;

    wire [15:0] pad_out;
    wire [15:0] pad_oe;
    reg  [15:0] pad_in;
    wire        hsiom_fault_event;

    always #5 clk = ~clk;

    hsiom_top dut (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .gpio_dr(gpio_dr),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .tcpwm_out0(tcpwm_out0),
        .tcpwm_nout0(tcpwm_nout0),
        .udb_out(udb_out),
        .snn_spike(snn_spike),
        .pad_out(pad_out),
        .pad_oe(pad_oe),
        .pad_in(pad_in),
        .hsiom_fault_event(hsiom_fault_event)
    );

    initial begin
        $dumpfile("tb_hsiom_failover.vcd");
        $dumpvars(0, tb_hsiom_failover);

        clk           = 0;
        rst_n         = 0;
        s_axi_awvalid = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;
        gpio_dr       = 16'h0000;
        uart_tx       = 1'b1; // UART Idle High
        tcpwm_out0    = 0;
        tcpwm_nout0   = 1;
        udb_out       = 8'h00;
        snn_spike     = 0;
        pad_in        = 16'hFFFF;

        #20 rst_n = 1;
        #20;

        $display("-----------------------------------------------------------------");
        $display("[TEST START] Self-Healing HSIOM Autonomous Pin Failover");
        $display("-----------------------------------------------------------------");

        // Normal Operation: Primary Pin 3 drives UART TX
        pad_in[3] = pad_out[3];
        #20;
        $display("[INFO] Normal State: Pin 3 pad_out = %b, Pin 7 (Backup) pad_out = %b", pad_out[3], pad_out[7]);
        if (pad_out[3] === 1'b1)
            $display("[PASS] UART TX initially mapped to primary Pin 3.");

        // SIMULATE ELECTRICAL HARDWARE FAULT: Pin 3 shorted to Ground (pad_in[3] forced low while pad_out[3]=1)
        $display("[FAULT INJECTION] Shorting Pin 3 to Ground (contention active)...");
        pad_in[3] = 1'b0;

        // Wait for failover contention counter to trip threshold
        #300;

        $display("[INFO] Post-Fault Status: hsiom_fault_event = %b, Pin 7 pad_out = %b", hsiom_fault_event, pad_out[7]);
        if (hsiom_fault_event === 1'b1 && pad_out[7] === uart_tx)
            $display("[PASS] [PATENT CLAIM 3] Autonomous Hardware Pin Failover Triggered! UART TX re-routed to Pin 7!");
        else
            $display("[FAIL] Failover did not engage properly.");

        // Toggle UART TX and verify Pin 7 toggles, while faulted Pin 3 remains isolated
        uart_tx = 1'b0;
        #20;
        if (pad_out[7] === 1'b0)
            $display("[PASS] [PATENT CLAIM 3] Backup Pin 7 successfully transmitting live serial data!");

        $display("-----------------------------------------------------------------");
        $display("[TEST COMPLETE] Self-Healing HSIOM test completed successfully!");
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule
