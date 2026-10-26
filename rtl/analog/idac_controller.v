`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : idac_controller
// Description : Dual Current DACs (8-bit IDAC1 and 7-bit IDAC2)
//               Matches Cypress PSoC 4 specs (Source / Sink, Low / High ranges).
//////////////////////////////////////////////////////////////////////////////////

module idac_controller
(
    input  wire        clk,
    input  wire        rst_n,

    // IDAC1 (8-bit) Configuration
    input  wire [7:0]  idac1_val,
    input  wire        idac1_en,
    input  wire        idac1_range, // 0 = Low (306 uA), 1 = High (612 uA)
    input  wire        idac1_polarity, // 0 = Source, 1 = Sink

    // IDAC2 (7-bit) Configuration
    input  wire [6:0]  idac2_val,
    input  wire        idac2_en,
    input  wire        idac2_range, // 0 = Low (152 uA), 1 = High (304 uA)
    input  wire        idac2_polarity,

    // Emulated Output Current Value (mA scaled to 8-bit integer)
    output reg  [7:0]  idac1_out_ma,
    output reg  [7:0]  idac2_out_ma
);

    always @(*) begin
        if (!idac1_en)
            idac1_out_ma = 8'd0;
        else
            idac1_out_ma = idac1_range ? idac1_val : (idac1_val >> 1);

        if (!idac2_en)
            idac2_out_ma = 8'd0;
        else
            idac2_out_ma = idac2_range ? {1'b0, idac2_val} : {2'b0, idac2_val[6:1]};
    end

endmodule
