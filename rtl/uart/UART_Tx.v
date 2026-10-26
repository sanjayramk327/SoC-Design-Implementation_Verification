`timescale 1ns / 1ps

module uart_tx
(
    input wire clk,
    input wire rst,

    // Baud generator tick
    input wire baud_tick,

    // Control
    input wire tx_start,

    // Data
    input wire [7:0] tx_data,

    // Parity
    input wire parity_enable,
    input wire parity_type,      // 0 = Even, 1 = Odd

    // UART Output
    output reg tx,

    // Status
    output reg busy,
    output reg done
);

//////////////////////////////////////////////////////////////
// State Encoding
//////////////////////////////////////////////////////////////

localparam IDLE   = 4'd0;
localparam START  = 4'd1;
localparam DATA   = 4'd2;
localparam PARITY = 4'd3;
localparam STOP   = 4'd4;

reg [3:0] state;

//////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////

reg [7:0] data_reg;
reg [2:0] bit_index;

reg parity_bit;

//////////////////////////////////////////////////////////////
// Parity Calculation
//////////////////////////////////////////////////////////////

wire even_parity;

assign even_parity = ^data_reg;

//////////////////////////////////////////////////////////////
// Sequential Logic
//////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        state <= IDLE;

        tx <= 1'b1;

        busy <= 1'b0;

        done <= 1'b0;

        data_reg <= 8'd0;

        bit_index <= 3'd0;

        parity_bit <= 1'b0;

    end

    else
    begin

        done <= 1'b0;

        case(state)

        //////////////////////////////////////////////////////
        // IDLE
        //////////////////////////////////////////////////////

        IDLE:
        begin

            tx <= 1'b1;

            busy <= 1'b0;

            bit_index <= 3'd0;

            if(tx_start)
            begin

                busy <= 1'b1;

                data_reg <= tx_data;

                // Generate parity once
                if(parity_type == 1'b0)
                    parity_bit <= even_parity;      // Even
                else
                    parity_bit <= ~even_parity;     // Odd

                state <= START;

            end

        end

        //////////////////////////////////////////////////////
        // START BIT
        //////////////////////////////////////////////////////

        START:
        begin

            tx <= 1'b0;

            if(baud_tick)
            begin

                state <= DATA;

                bit_index <= 3'd0;

            end

        end

        //////////////////////////////////////////////////////
        // DATA BITS
        //////////////////////////////////////////////////////

        DATA:
        begin

            tx <= data_reg[bit_index];

            if(baud_tick)
            begin

                if(bit_index == 3'd7)
                begin

                    if(parity_enable)
                        state <= PARITY;
                    else
                        state <= STOP;

                end
                else
                begin

                    bit_index <= bit_index + 1'b1;

                end

            end

        end

        //////////////////////////////////////////////////////
        // PARITY
        //////////////////////////////////////////////////////

        PARITY:
        begin

            tx <= parity_bit;

            if(baud_tick)
            begin

                state <= STOP;

            end

        end

        //////////////////////////////////////////////////////
        // STOP BIT
        //////////////////////////////////////////////////////

        STOP:
        begin

            tx <= 1'b1;

            if(baud_tick)
            begin

                busy <= 1'b0;

                done <= 1'b1;

                state <= IDLE;

            end

        end

        //////////////////////////////////////////////////////
        // Default
        //////////////////////////////////////////////////////

        default:
        begin

            state <= IDLE;

        end

        endcase

    end

end

endmodule