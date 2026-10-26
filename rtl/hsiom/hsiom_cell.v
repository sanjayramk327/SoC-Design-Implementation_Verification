`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : hsiom_cell
// Description : Per-Pin HSIOM Routing and Drive Mode Logic (Matches PSoC 4)
//               Modes: 0: Analog, 1: Input, 2: Pull-Up, 3: Pull-Down,
//                      4: Open-Drain Low, 5: Open-Drain High, 6: Strong, 7: Pull-Up/Down
//////////////////////////////////////////////////////////////////////////////////

module hsiom_cell
(
    // Routing Selector (0: GPIO DR, 1: UART, 2: TCPWM, 3: UDB, 4: SNN, 5: AMUX)
    input  wire [2:0]  mux_sel,
    input  wire [2:0]  drive_mode,

    // Internal Peripheral Signal Candidates
    input  wire        sig_gpio,
    input  wire        sig_uart,
    input  wire        sig_tcpwm,
    input  wire        sig_udb,
    input  wire        sig_snn,

    // Bidirectional Pad Signals
    output reg         pad_out,
    output reg         pad_oe,
    input  wire        pad_in,

    // Feedback to Internal Peripherals
    output wire        periph_in
);

    reg selected_tx;
    always @(*) begin
        case (mux_sel)
            3'd0: selected_tx = sig_gpio;
            3'd1: selected_tx = sig_uart;
            3'd2: selected_tx = sig_tcpwm;
            3'd3: selected_tx = sig_udb;
            3'd4: selected_tx = sig_snn;
            default: selected_tx = sig_gpio;
        endcase
    end

    // Drive Mode Implementation
    always @(*) begin
        case (drive_mode)
            3'd0: begin pad_out = 1'b0; pad_oe = 1'b0; end // Analog / Hi-Z
            3'd1: begin pad_out = 1'b0; pad_oe = 1'b0; end // Digital Input Only
            3'd2: begin pad_out = 1'b1; pad_oe = ~selected_tx; end // Pull-Up (Open Drain Low)
            3'd3: begin pad_out = 1'b0; pad_oe = selected_tx;  end // Pull-Down
            3'd4: begin pad_out = 1'b0; pad_oe = ~selected_tx; end // Open Drain Low
            3'd5: begin pad_out = 1'b1; pad_oe = selected_tx;  end // Open Drain High
            3'd6: begin pad_out = selected_tx; pad_oe = 1'b1;  end // Strong CMOS Drive
            3'd7: begin pad_out = selected_tx; pad_oe = 1'b1;  end // Resistive
        endcase
    end

    assign periph_in = pad_in;

endmodule
