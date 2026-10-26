`timescale 1ns / 1ps

module rocket_icache (
    input  wire        clk,
    input  wire        rst_n,
    
    // Core interface
    input  wire [55:0] paddr,
    input  wire        req_valid,
    output reg         req_ready,
    output reg  [31:0] inst_out,
    output reg         inst_valid,
    
    // Memory interface
    output reg  [55:0] mem_addr,
    output reg         mem_req,
    input  wire        mem_ready,
    input  wire [63:0] mem_rdata,
    input  wire        mem_rvalid,
    
    // Flush
    input  wire        fence_i
);

    reg [2:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_ready <= 1'b1;
            inst_valid <= 1'b0;
            mem_req <= 1'b0;
            state <= 3'd0;
            inst_out <= 32'd0;
        end else begin
            if (fence_i) begin
                $display("[%0t] ICACHE: FENCE.I executed", $time);
            end
            
            // Simplified cache hit/miss logic
            if (req_valid && req_ready) begin
                // Mock a hit/miss (always hit for simplicity in stub)
                inst_valid <= 1'b1;
                inst_out <= 32'h00000013; // NOP
                $display("[%0t] ICACHE: Fetch from paddr %h", $time, paddr);
            end else begin
                inst_valid <= 1'b0;
            end
        end
    end

endmodule
