// =============================================================================
// DEMO 4: SNN Neuromorphic SmartSense — Gesture Classification
// Open in GTKWave and watch:
//   clk, rst_n, amux_voltage → pin_analog_in changes
//   snn_spike  → fires when membrane threshold crossed
//   snn_gesture_class → 0=Tap, 1=Swipe, 2=Hold, 3=Rotate
//   snn_anomaly_flag  → alert on unknown pattern
// =============================================================================
`timescale 1ns/1ps

module demo_snn_gesture;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;   // 100 MHz

    // Analog pin bus (16 channels × 8-bit = 128-bit flat)
    reg [127:0] pin_analog_in = 128'd0;

    // Outputs
    wire        snn_spike;
    wire        snn_anomaly_flag;
    // snn_class is internal — we expose via wired AXI read but keep sim simple

    analog_top dut (
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
        .pin_analog_in   (pin_analog_in),
        .comp1_event     (),
        .comp2_event     (),
        .snn_touch_spike (snn_spike),
        .snn_anomaly_flag(snn_anomaly_flag)
    );

    // Helper: set analog channel 0 voltage (connected to AMUX-A → SNN input)
    task set_voltage;
        input [7:0] v;
        begin
            pin_analog_in[7:0] = v;
            @(posedge clk);
        end
    endtask

    // Gesture patterns — ramp up then step down
    task inject_tap;   // Short fast spike
        integer k;
        begin
            $display("[%0t ns] Gesture: TAP", $time/1000);
            for (k = 0; k < 8; k = k+1) begin
                set_voltage(8'd30 + k*8'd15);   // 30..135 ramp
                repeat(2) @(posedge clk);
            end
            set_voltage(8'd10);  // drop
            repeat(10) @(posedge clk);
        end
    endtask

    task inject_swipe;  // Sustained medium ramp
        integer k;
        begin
            $display("[%0t ns] Gesture: SWIPE", $time/1000);
            for (k = 0; k < 16; k = k+1) begin
                set_voltage(8'd20 + k*8'd10);   // 20..170
                repeat(3) @(posedge clk);
            end
            for (k = 16; k > 0; k = k-1) begin
                set_voltage(8'd20 + k*8'd8);    // ramp down
                repeat(2) @(posedge clk);
            end
            set_voltage(8'd10);
            repeat(15) @(posedge clk);
        end
    endtask

    task inject_hold;   // Constant high
        integer k;
        begin
            $display("[%0t ns] Gesture: HOLD", $time/1000);
            set_voltage(8'd200);
            repeat(40) @(posedge clk);
            set_voltage(8'd10);
            repeat(10) @(posedge clk);
        end
    endtask

    task inject_rotate;  // Oscillating
        integer k;
        begin
            $display("[%0t ns] Gesture: ROTATE", $time/1000);
            for (k = 0; k < 20; k = k+1) begin
                // Triangle wave: up then down
                set_voltage((k < 10) ? (8'd80 + k*8'd12) : (8'd200 - (k-10)*8'd12));
                repeat(2) @(posedge clk);
            end
            set_voltage(8'd10);
            repeat(15) @(posedge clk);
        end
    endtask

    task inject_anomaly;   // Unknown random pattern
        begin
            $display("[%0t ns] Gesture: ANOMALY (unknown)", $time/1000);
            set_voltage(8'hFF);
            repeat(2) @(posedge clk);
            set_voltage(8'h00);
            repeat(2) @(posedge clk);
            set_voltage(8'h80);
            repeat(2) @(posedge clk);
            set_voltage(8'hFF);
            repeat(2) @(posedge clk);
            set_voltage(8'h40);
            repeat(10) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("demo_snn_gesture.vcd");
        $dumpvars(0, demo_snn_gesture);

        rst_n = 0;
        pin_analog_in = 128'd0;
        repeat(6) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        $display("[%0t ns] === SNN Gesture Classification Demo ===", $time/1000);

        inject_tap;
        inject_swipe;
        inject_hold;
        inject_rotate;
        inject_anomaly;

        // Second round — repeat
        inject_tap;
        inject_hold;

        repeat(20) @(posedge clk);
        $display("[%0t ns] spike=%b, anomaly=%b", $time/1000, snn_spike, snn_anomaly_flag);
        $display("[%0t ns] === Demo Complete ===", $time/1000);
        $finish;
    end

endmodule
