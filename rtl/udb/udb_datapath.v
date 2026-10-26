`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : udb_datapath
// Description : Universal Digital Block (UDB) 8/16-bit Reconfigurable Datapath
//               Features: Dual Accumulator (A0, A1), Data Registers (D0, D1),
//               ALU with Add, Sub, AND, OR, XOR, Shift, and CRC/Crypto feedback.
//////////////////////////////////////////////////////////////////////////////////

module udb_datapath
(
    input  wire        clk,
    input  wire        rst_n,

    // Datapath Configuration & Control (from active shadow context)
    input  wire [3:0]  alu_op,
    input  wire [1:0]  src_a_sel, // 0: A0, 1: A1, 2: D0, 3: DIN
    input  wire [1:0]  src_b_sel, // 0: D0, 1: D1, 2: Imm, 3: A0
    input  wire [7:0]  imm_val,
    input  wire        acc_load,
    input  wire        shift_right,

    // Data I/O
    input  wire [7:0]  din,
    output reg  [7:0]  dout,
    output reg  [7:0]  accum_out,

    // Status Flags
    output wire        flag_zero,
    output wire        flag_carry,
    output wire        flag_sign
);

    reg [7:0] a0;
    reg [7:0] a1;
    reg [7:0] d0;
    reg [7:0] d1;

    // Source multiplexing
    reg [7:0] op_a;
    reg [7:0] op_b;

    always @(*) begin
        case (src_a_sel)
            2'd0: op_a = a0;
            2'd1: op_a = a1;
            2'd2: op_a = d0;
            2'd3: op_a = din;
        endcase

        case (src_b_sel)
            2'd0: op_b = d0;
            2'd1: op_b = d1;
            2'd2: op_b = imm_val;
            2'd3: op_b = a0;
        endcase
    end

    // ALU Calculation
    reg [8:0] alu_raw;
    always @(*) begin
        case (alu_op)
            4'd0: alu_raw = {1'b0, op_a} + {1'b0, op_b};          // ADD
            4'd1: alu_raw = {1'b0, op_a} - {1'b0, op_b};          // SUB
            4'd2: alu_raw = {1'b0, op_a & op_b};                 // AND
            4'd3: alu_raw = {1'b0, op_a | op_b};                 // OR
            4'd4: alu_raw = {1'b0, op_a ^ op_b};                 // XOR
            4'd5: alu_raw = shift_right ? {op_a[0], 1'b0, op_a[7:1]} : {op_a[7], op_a[6:0], 1'b0}; // SHIFT
            4'd6: alu_raw = {1'b0, op_a ^ {op_a[6:0], 1'b0} ^ 8'h1D}; // CRC-8 Poly
            4'd7: alu_raw = {1'b0, ~op_a};                       // NOT
            default: alu_raw = {1'b0, op_a};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a0   <= 8'h00;
            a1   <= 8'h00;
            d0   <= 8'h00;
            d1   <= 8'h00;
            dout <= 8'h00;
        end else begin
            if (acc_load) begin
                a0   <= alu_raw[7:0];
                dout <= alu_raw[7:0];
            end
        end
    end

    always @(*) begin
        accum_out = a0;
    end

    assign flag_zero  = (alu_raw[7:0] == 8'h00);
    assign flag_carry = alu_raw[8];
    assign flag_sign  = alu_raw[7];

endmodule
