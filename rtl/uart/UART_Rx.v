`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_rx
// Description : Robust UART Receiver for MorphoSoC
//////////////////////////////////////////////////////////////////////////////////

module uart_rx
(
    input  wire       clk,
    input  wire       rst,

    // Baud Tick Generator (1x baud tick)
    input  wire       baud_tick,

    // UART RX Input
    input  wire       rx,

    // UART Configuration
    input  wire       parity_enable,
    input  wire       parity_type,      // 0 = Even, 1 = Odd

    // UART Outputs
    output reg [7:0]  rx_data,
    output reg        rx_done,
    output reg        parity_error,
    output reg        framing_error
);

    reg rx_sync1;
    reg rx_sync2;
    reg rx_prev;

    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
            rx_prev  <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            rx_prev  <= rx_sync2;
        end
    end

    wire start_edge = (rx_prev == 1'b1) && (rx_sync2 == 1'b0);

    localparam IDLE   = 3'd0;
    localparam START  = 3'd1;
    localparam DATA   = 3'd2;
    localparam PARITY = 3'd3;
    localparam STOP   = 3'd4;

    reg [2:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg       calc_parity;

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            bit_idx       <= 3'd0;
            shift_reg     <= 8'd0;
            rx_data       <= 8'd0;
            rx_done       <= 1'b0;
            parity_error  <= 1'b0;
            framing_error <= 1'b0;
            calc_parity   <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    bit_idx       <= 3'd0;
                    parity_error  <= 1'b0;
                    framing_error <= 1'b0;
                    if (start_edge) begin
                        state <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        if (rx_sync2 == 1'b0) begin
                            state       <= DATA;
                            bit_idx     <= 3'd0;
                            calc_parity <= 1'b0;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        shift_reg[bit_idx] <= rx_sync2;
                        calc_parity        <= calc_parity ^ rx_sync2;
                        if (bit_idx == 3'd7) begin
                            if (parity_enable)
                                state <= PARITY;
                            else
                                state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end
                end

                PARITY: begin
                    if (baud_tick) begin
                        if (rx_sync2 != (parity_type ? ~calc_parity : calc_parity))
                            parity_error <= 1'b1;
                        state <= STOP;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (rx_sync2 == 1'b0)
                            framing_error <= 1'b1;
                        rx_data <= shift_reg;
                        rx_done <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
