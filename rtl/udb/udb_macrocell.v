`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : udb_macrocell
// Description : 12-Macrocell Programmable Logic Array (PLD Matrix)
//               Combines product terms and registers for sequential state machines.
//////////////////////////////////////////////////////////////////////////////////

module udb_macrocell
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] pld_inputs,
    input  wire [23:0] pld_lut_config, // 2 bits per macrocell: 0: Direct, 1: Invert, 2: Registered, 3: Toggle
    output reg  [11:0] pld_outputs
);

    reg [11:0] mc_ff;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mc_ff <= 12'h0;
        end else begin
            for (i = 0; i < 12; i = i + 1) begin
                case (pld_lut_config[i*2 +: 2])
                    2'b00: mc_ff[i] <= pld_inputs[i];
                    2'b01: mc_ff[i] <= ~pld_inputs[i];
                    2'b10: mc_ff[i] <= pld_inputs[i] ^ mc_ff[i];
                    2'b11: mc_ff[i] <= (pld_inputs[i] & ~mc_ff[i]) | (~pld_inputs[i] & mc_ff[i]);
                endcase
            end
        end
    end

    always @(*) begin
        for (i = 0; i < 12; i = i + 1) begin
            pld_outputs[i] = pld_lut_config[i*2] ? mc_ff[i] : pld_inputs[i];
        end
    end

endmodule
