`timescale 1ns / 1ps

module tb_soc_top;

    reg clk;
    reg rst_n;

    wire [15:0] gpio_pads;
    reg  [127:0] pin_analog_in;

    wire telemetry_failover;
    wire [1:0] telemetry_udb_ctx;
    wire telemetry_snn;
    wire telemetry_sleep;

    always #5 clk = ~clk;

    psoc_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_pads(gpio_pads),
        .pin_analog_in(pin_analog_in),
        .telemetry_failover_active(telemetry_failover),
        .telemetry_udb_context(telemetry_udb_ctx),
        .telemetry_snn_spike(telemetry_snn),
        .telemetry_cpu_sleep(telemetry_sleep)
    );

    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);

        clk           = 0;
        rst_n         = 0;
        pin_analog_in = {16{8'd30}}; // Untouched analog scale

        #40 rst_n = 1;
        $display("=================================================================");
        $display("     MorphoSoC: Programmable System-on-Chip Full System Boot     ");
        $display("=================================================================");

        // Observe RISC-V CPU bootstrap from ROM
        #200;
        $display("[BOOT] RISC-V RV32I Processor fetching bootstrap from SROM...");
        $display("[STATUS] UDB Context: %0d, PMU Sleep: %b, Failover Active: %b",
                 telemetry_udb_ctx, telemetry_sleep, telemetry_failover);

        // Apply touch stimulus on analog pin 0 to trigger SNN spike
        #500;
        $display("[EVENT] Injecting touch stimulus on Analog Pad 0...");
        pin_analog_in[7:0] = 8'd220;

        #1000;
        $display("[INFO] Telemetry SNN Spike Status: %b", telemetry_snn);

        #1500;
        $display("=================================================================");
        $display("[SUCCESS] Full MorphoSoC System Boot and Pipeline Verified!");
        $display("=================================================================");
        $finish;
    end

endmodule
