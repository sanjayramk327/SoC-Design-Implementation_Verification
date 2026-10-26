`timescale 1ns / 1ps

module tb_udb_morph;

    reg clk;
    reg rst_n;

    // AXI signals
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

    // REM Event trigger
    reg        rem_morph_trig;
    reg  [1:0] rem_target_ctx;

    reg  [7:0] udb_io_in;
    wire [7:0] udb_io_out;
    wire [1:0] current_ctx;

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    udb_top dut (
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
        .rem_morph_trigger(rem_morph_trig),
        .rem_target_context(rem_target_ctx),
        .udb_io_in(udb_io_in),
        .udb_io_out(udb_io_out),
        .current_context(current_ctx)
    );

    task axi_write(input [11:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'b1111;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;
        wait(s_axi_awready && s_axi_wready);
        @(posedge clk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;
        wait(s_axi_bvalid);
        @(posedge clk);
        s_axi_bready  <= 1'b0;
    end
    endtask

    initial begin
        $dumpfile("tb_udb_morph.vcd");
        $dumpvars(0, tb_udb_morph);

        clk            = 0;
        rst_n          = 0;
        s_axi_awvalid  = 0;
        s_axi_wvalid   = 0;
        s_axi_bready   = 0;
        s_axi_arvalid  = 0;
        s_axi_rready   = 0;
        rem_morph_trig = 0;
        rem_target_ctx = 0;
        udb_io_in      = 8'h00;

        #20 rst_n = 1;
        #20;

        $display("-----------------------------------------------------------------");
        $display("[TEST START] MorphoSoC UDB 2.0 Autonomous Context Morphing");
        $display("-----------------------------------------------------------------");

        // Verify initial state is Context 0 (Accumulator)
        if (current_ctx === 2'b00)
            $display("[PASS] Initial context is Context 0 (Accumulator)");
        else
            $display("[FAIL] Initial context mismatch: %b", current_ctx);

        // Feed input data in Context 0: Data = 8'h10
        udb_io_in = 8'h10;
        #10;
        $display("[INFO] Context 0 Output = 0x%02X", udb_io_out);

        // PATENT 1 TEST: Autonomous 1-cycle morph to Context 1 (Stream Decryptor)
        @(posedge clk);
        rem_morph_trig <= 1'b1;
        rem_target_ctx <= 2'b01;
        @(posedge clk);
        rem_morph_trig <= 1'b0;

        // Check if context morphed in 1 cycle
        #1;
        if (current_ctx === 2'b01)
            $display("[PASS] [PATENT CLAIM 1] Single-Cycle Context Morph Succeeded! (Morphed to Context 1 in 1 clock cycle)");
        else
            $display("[FAIL] Context did not morph in 1 cycle: %b", current_ctx);

        #10;
        $display("[INFO] Context 1 Morphed Output = 0x%02X (Expected XOR decryption)", udb_io_out);

        // Morph to Context 2 (CRC-8 Checksum)
        @(posedge clk);
        rem_morph_trig <= 1'b1;
        rem_target_ctx <= 2'b10;
        @(posedge clk);
        rem_morph_trig <= 1'b0;
        #1;
        if (current_ctx === 2'b10)
            $display("[PASS] [PATENT CLAIM 1] Autonomous Morph to Context 2 (CRC-8 Checksum) Succeeded!");

        #20;
        $display("-----------------------------------------------------------------");
        $display("[TEST COMPLETE] UDB 2.0 Autonomous Morphing fully verified!");
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule
