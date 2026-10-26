`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : analog_mux_bus
// Description : Concentric Dual Analog Multiplexed Buses (AMUXBUS-A and AMUXBUS-B)
//               Replicates Cypress PSoC 4 amux concentric topology.
//               Allows any of the 16 port pins to connect to internal analog blocks.
//////////////////////////////////////////////////////////////////////////////////

module analog_mux_bus
(
    input  wire         clk,
    input  wire         rst_n,

    // Firmware Switch Control Registers
    input  wire [15:0]  switch_a_mask, // 16 pins connected to AMUXBUS-A
    input  wire [15:0]  switch_b_mask, // 16 pins connected to AMUXBUS-B

    // Pin Analog Input Voltages (16x 8-bit values flattened to 128 bits)
    input  wire [127:0] pin_analog_in,

    // Connected Bus Output Levels
    output reg  [7:0]   amuxbus_a_voltage,
    output reg  [7:0]   amuxbus_b_voltage
);

    integer i;
    always @(*) begin
        amuxbus_a_voltage = 8'd0;
        amuxbus_b_voltage = 8'd0;

        for (i = 0; i < 16; i = i + 1) begin
            if (switch_a_mask[i])
                amuxbus_a_voltage = pin_analog_in[i*8 +: 8];
            if (switch_b_mask[i])
                amuxbus_b_voltage = pin_analog_in[i*8 +: 8];
        end
    end

endmodule
