`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : comparator_block
// Description : Dual Ultra-Low-Power Analog Comparators with Internal Reference
//               Includes programmable hysteresis and internal 1.2V bandgap DAC reference.
//////////////////////////////////////////////////////////////////////////////////

module comparator_block
(
    input  wire        clk,
    input  wire        rst_n,

    // Analog Inputs (8-bit scale: 0 = 0V, 255 = 3.3V, 1.2V ~ 93)
    input  wire [7:0]  v_in1,
    input  wire [7:0]  v_in2,

    // Configuration
    input  wire        comp1_en,
    input  wire        comp2_en,
    input  wire [7:0]  vref_dac,       // Internal reference voltage (default 93 = 1.2V)
    input  wire [3:0]  hysteresis_val, // Hysteresis band

    // Outputs
    output reg         comp1_out,
    output reg         comp2_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comp1_out <= 1'b0;
            comp2_out <= 1'b0;
        end else begin
            // Comparator 1 with hysteresis
            if (comp1_en) begin
                if (v_in1 > (vref_dac + hysteresis_val))
                    comp1_out <= 1'b1;
                else if (v_in1 < (vref_dac - hysteresis_val))
                    comp1_out <= 1'b0;
            end else begin
                comp1_out <= 1'b0;
            end

            // Comparator 2
            if (comp2_en) begin
                if (v_in2 > (vref_dac + hysteresis_val))
                    comp2_out <= 1'b1;
                else if (v_in2 < (vref_dac - hysteresis_val))
                    comp2_out <= 1'b0;
            end else begin
                comp2_out <= 1'b0;
            end
        end
    end

endmodule
