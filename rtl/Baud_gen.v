`timescale 1ns / 1ps

module baud_generator
#(
    parameter CLK_FREQ = 100000000
)
(
    input  wire        clk,
    input  wire        rst,

    // Desired UART baud rate
    input  wire [31:0] baud_rate,

    // 1x baud tick (TX)
    output reg         baud_tick,

    // 16x baud tick (RX)
    output reg         baud16_tick
);

//////////////////////////////////////////////////////////////
// Divider Calculations
//////////////////////////////////////////////////////////////

wire [31:0] baud_div;
wire [31:0] baud16_div;

assign baud_div   = CLK_FREQ / baud_rate;
assign baud16_div = CLK_FREQ / (baud_rate * 16);

//////////////////////////////////////////////////////////////
// Counters
//////////////////////////////////////////////////////////////

reg [31:0] baud_counter;
reg [31:0] baud16_counter;

//////////////////////////////////////////////////////////////
// Baud Tick Generator
//////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        baud_counter   <= 32'd0;
        baud16_counter <= 32'd0;

        baud_tick      <= 1'b0;
        baud16_tick    <= 1'b0;

    end

    else
    begin

        //------------------------------------------------------
        // Default Outputs
        //------------------------------------------------------

        baud_tick   <= 1'b0;
        baud16_tick <= 1'b0;

        //------------------------------------------------------
        // 1x Baud Tick
        //------------------------------------------------------

        if(baud_counter == baud_div - 1)
        begin
            baud_counter <= 32'd0;
            baud_tick <= 1'b1;
        end
        else
        begin
            baud_counter <= baud_counter + 1'b1;
        end

        //------------------------------------------------------
        // 16x Baud Tick
        //------------------------------------------------------

        if(baud16_counter == baud16_div - 1)
        begin
            baud16_counter <= 32'd0;
            baud16_tick <= 1'b1;
        end
        else
        begin
            baud16_counter <= baud16_counter + 1'b1;
        end

    end

end

endmodule