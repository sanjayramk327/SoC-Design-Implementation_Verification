`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : rx_fifo
// Description : Robust UART Receive FIFO with Overflow/Underflow Protection
//////////////////////////////////////////////////////////////////////////////////

module rx_fifo
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4
)
(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,
    output reg                   overflow,

    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,
    output reg                   underflow,

    output reg  [ADDR_WIDTH:0]   occupancy
);

    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign empty = (occupancy == 0);
    assign full  = (occupancy == FIFO_DEPTH);

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            occupancy <= 0;
            overflow  <= 0;
            underflow <= 0;
            rd_data   <= 0;
        end else begin
            // Write handling
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end else if (wr_en && full) begin
                overflow <= 1'b1;
            end

            // Read handling
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 1'b1;
            end else if (rd_en && empty) begin
                underflow <= 1'b1;
            end

            // Occupancy update
            case ({wr_en && !full, rd_en && !empty})
                2'b10: occupancy <= occupancy + 1'b1;
                2'b01: occupancy <= occupancy - 1'b1;
                default: ;
            endcase
        end
    end

endmodule
