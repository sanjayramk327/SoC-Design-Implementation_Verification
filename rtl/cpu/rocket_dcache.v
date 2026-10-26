`timescale 1ns / 1ps

module rocket_dcache (
    input  wire        clk,
    input  wire        rst_n,
    
    // Core interface
    input  wire [55:0] paddr,
    input  wire [63:0] wdata,
    input  wire [7:0]  wstrb,
    input  wire        ren,
    input  wire        wen,
    input  wire [4:0]  amo_op,    // Atomic Memory Operations
    output reg         req_ready,
    
    output reg  [63:0] rdata,
    output reg         rvalid,
    
    // Memory interface
    output reg  [55:0] mem_addr,
    output reg         mem_ren,
    output reg         mem_wen,
    output reg  [63:0] mem_wdata,
    input  wire        mem_ready,
    input  wire [63:0] mem_rdata,
    input  wire        mem_rvalid
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_ready <= 1'b1;
            rvalid <= 1'b0;
            rdata <= 64'd0;
            mem_ren <= 1'b0;
            mem_wen <= 1'b0;
        end else begin
            if ((ren || wen) && req_ready) begin
                req_ready <= 1'b0;
                mem_addr <= paddr;
                mem_ren <= ren;
                mem_wen <= wen;
                mem_wdata <= wdata;
                if (amo_op != 5'd0) begin
                    $display("[%0t] DCACHE: AMO op %h at paddr %h", $time, amo_op, paddr);
                end
            end else if (!req_ready && mem_ready) begin
                // Mock memory response handling
                mem_ren <= 1'b0;
                mem_wen <= 1'b0;
                
                if (mem_rvalid) begin
                    rdata <= mem_rdata;
                    rvalid <= 1'b1;
                    req_ready <= 1'b1;
                    $display("[%0t] DCACHE: Read data ready", $time);
                end else if (wen) begin
                    rvalid <= 1'b1; // Write ack
                    req_ready <= 1'b1;
                    $display("[%0t] DCACHE: Write complete", $time);
                end
            end else begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
