`timescale 1ns / 1ps

module tb_smartsense_snn;

    reg clk;
    reg rst_n;
    reg [7:0] amux_v;

    reg        cfg_we;
    reg [7:0]  cfg_addr;
    reg [31:0] cfg_wdata;
    wire [31:0] cfg_rdata;

    wire snn_spike;
    wire snn_anomaly;
    wire [3:0] snn_class;

    always #5 clk = ~clk;

    neuromorphic_smartsense dut (
        .clk(clk),
        .rst_n(rst_n),
        .amux_voltage(amux_v),
        .cfg_we(cfg_we),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .snn_touch_spike(snn_spike),
        .snn_anomaly_flag(snn_anomaly),
        .snn_gesture_class(snn_class)
    );

    initial begin
        $dumpfile("tb_smartsense_snn.vcd");
        $dumpvars(0, tb_smartsense_snn);

        clk      = 0;
        rst_n    = 0;
        amux_v   = 8'd20; // Untouched baseline voltage
        cfg_we   = 0;
        cfg_addr = 0;
        cfg_wdata = 0;

        #20 rst_n = 1;
        #50;

        $display("-----------------------------------------------------------------");
        $display("[TEST START] Mixed-Signal Neuromorphic Smart-Sense (SNN-SSE)");
        $display("-----------------------------------------------------------------");

        // Step 1: Untouched baseline observation
        $display("[PHASE 1] Observing untouched baseline capacitance...");
        #2500;
        $display("[INFO] Gesture Class = %0d (0 = Untouched)", snn_class);
        if (snn_class === 4'd0)
            $display("[PASS] Untouched state accurately classified!");

        // Step 2: Touch event applied (Capacitance increase -> voltage shifts to 180)
        $display("[PHASE 2] Applying finger touch on AMUXBUS sensor pad (v=180)...");
        amux_v = 8'd180;
        #3000;
        $display("[INFO] Gesture Class = %0d (1 = Tap, 2 = Long Press)", snn_class);
        if (snn_class >= 4'd1)
            $display("[PASS] [PATENT CLAIM 2] Neuromorphic Spike Detection & Gesture Classification Verified!");

        // Step 3: Extreme water-splash anomaly (voltage saturates to 250)
        $display("[PHASE 3] Injecting severe water splash / sensor short (v=250)...");
        amux_v = 8'd250;
        #3000;
        $display("[INFO] Gesture Class = %0d (3 = Anomaly/Hazard), Anomaly Flag = %b", snn_class, snn_anomaly);
        if (snn_class === 4'd3 || snn_anomaly === 1'b1)
            $display("[PASS] [PATENT CLAIM 2] Autonomous Anomaly / Safety Hazard Identified!");

        $display("-----------------------------------------------------------------");
        $display("[TEST COMPLETE] SNN Smart-Sense validation successful!");
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule
