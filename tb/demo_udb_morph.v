// =============================================================================
// DEMO 1: UDB 2.0 — Single-Cycle Autonomous Context Morphing
// Open in GTKWave and watch:
//   clk, rst_n, morph_trigger, rem_target_ctx, current_ctx,
//   udb_io_in, udb_io_out, morph_done
// =============================================================================
`timescale 1ns/1ps

module demo_udb_morph;

    // Clock & reset
    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;   // 100 MHz

    // UDB top ports
    reg  [7:0]  udb_io_in       = 8'hA5;
    wire [7:0]  udb_io_out;
    wire [1:0]  current_ctx;

    // REM hardware event trigger
    reg         morph_trigger   = 0;
    reg  [1:0]  rem_target_ctx  = 2'd0;

    // AXI – tie unused to 0
    wire s_axi_awready, s_axi_wready, s_axi_bvalid,
         s_axi_arready, s_axi_rvalid;
    wire [1:0] s_axi_bresp, s_axi_rresp;
    wire [31:0] s_axi_rdata;
    wire morph_done;

    // Observe morph_done via output context change detection
    reg [1:0] prev_ctx = 0;
    assign morph_done = (current_ctx !== prev_ctx) ? 1'b1 : 1'b0;

    udb_top dut (
        .aclk              (clk),
        .aresetn           (rst_n),
        .s_axi_awaddr      (12'h0),
        .s_axi_awprot      (3'b0),
        .s_axi_awvalid     (1'b0),
        .s_axi_awready     (s_axi_awready),
        .s_axi_wdata       (32'h0),
        .s_axi_wstrb       (4'hF),
        .s_axi_wvalid      (1'b0),
        .s_axi_wready      (s_axi_wready),
        .s_axi_bresp       (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (1'b1),
        .s_axi_araddr      (12'h0),
        .s_axi_arprot      (3'b0),
        .s_axi_arvalid     (1'b0),
        .s_axi_arready     (s_axi_arready),
        .s_axi_rdata       (s_axi_rdata),
        .s_axi_rresp       (s_axi_rresp),
        .s_axi_rvalid      (s_axi_rvalid),
        .s_axi_rready      (1'b1),
        .rem_morph_trigger (morph_trigger),
        .rem_target_context(rem_target_ctx),
        .udb_io_in         (udb_io_in),
        .udb_io_out        (udb_io_out),
        .current_context   (current_ctx)
    );

    // Track previous context for done pulse
    always @(posedge clk) prev_ctx <= current_ctx;

    integer i;
    initial begin
        $dumpfile("demo_udb_morph.vcd");
        $dumpvars(0, demo_udb_morph);

        // ----- Reset -----
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("[%0t ns] === UDB Context Morph Demo Start ===", $time/1000);
        $display("[%0t ns] Context = %0d, IO_IN=0x%02h, IO_OUT=0x%02h",
                  $time/1000, current_ctx, udb_io_in, udb_io_out);

        // ---- Phase 1: Let accumulator work (Context 0 = Accumulator) ----
        $display("[%0t ns] Phase 1: Context 0 (Accumulator) — IO_IN cycles 0x11..0x55", $time/1000);
        udb_io_in = 8'h11; repeat(3) @(posedge clk);
        udb_io_in = 8'h22; repeat(3) @(posedge clk);
        udb_io_in = 8'h44; repeat(3) @(posedge clk);
        udb_io_in = 8'h55; repeat(3) @(posedge clk);

        // ---- MORPH to Context 1 (XOR Cipher) ----
        $display("[%0t ns] >>> MORPH TRIGGER → Context 1 (XOR Cipher)", $time/1000);
        udb_io_in      = 8'hA5;   // plaintext byte
        rem_target_ctx = 2'd1;
        morph_trigger  = 1'b1;
        @(posedge clk);
        morph_trigger  = 1'b0;    // single-cycle pulse
        @(posedge clk);
        $display("[%0t ns] Context = %0d (expect 1), IO_OUT=0x%02h (XOR cipher)",
                  $time/1000, current_ctx, udb_io_out);
        repeat(5) @(posedge clk);

        // Feed more plaintext to XOR engine
        $display("[%0t ns] Feeding more bytes to XOR context...", $time/1000);
        udb_io_in = 8'hDE; repeat(3) @(posedge clk);
        udb_io_in = 8'hAD; repeat(3) @(posedge clk);
        udb_io_in = 8'hBE; repeat(3) @(posedge clk);
        udb_io_in = 8'hEF; repeat(3) @(posedge clk);

        // ---- MORPH to Context 2 (CRC-8) ----
        $display("[%0t ns] >>> MORPH TRIGGER → Context 2 (CRC-8 Checksum)", $time/1000);
        udb_io_in      = 8'h4D;
        rem_target_ctx = 2'd2;
        morph_trigger  = 1'b1;
        @(posedge clk);
        morph_trigger  = 1'b0;
        @(posedge clk);
        $display("[%0t ns] Context = %0d (expect 2), IO_OUT=0x%02h (CRC)",
                  $time/1000, current_ctx, udb_io_out);
        repeat(5) @(posedge clk);

        // Feed data bytes for CRC
        for (i = 0; i < 8; i = i+1) begin
            udb_io_in = i * 8'h13 + 8'h01;
            @(posedge clk);
        end
        repeat(3) @(posedge clk);
        $display("[%0t ns] CRC-8 result = 0x%02h", $time/1000, udb_io_out);

        // ---- MORPH to Context 3 (LFSR / Bit Shifter) ----
        $display("[%0t ns] >>> MORPH TRIGGER → Context 3 (LFSR Shift)", $time/1000);
        rem_target_ctx = 2'd3;
        morph_trigger  = 1'b1;
        @(posedge clk);
        morph_trigger  = 1'b0;
        @(posedge clk);
        $display("[%0t ns] Context = %0d (expect 3), IO_OUT=0x%02h (LFSR)",
                  $time/1000, current_ctx, udb_io_out);
        repeat(10) @(posedge clk);

        // ---- MORPH back to Context 0 ----
        $display("[%0t ns] >>> MORPH back → Context 0 (Accumulator)", $time/1000);
        rem_target_ctx = 2'd0;
        morph_trigger  = 1'b1;
        @(posedge clk);
        morph_trigger  = 1'b0;
        @(posedge clk);
        $display("[%0t ns] Context = %0d (expect 0)", $time/1000, current_ctx);
        repeat(5) @(posedge clk);

        $display("[%0t ns] === Demo Complete ===", $time/1000);
        $finish;
    end

endmodule
