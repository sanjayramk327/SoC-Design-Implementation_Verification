`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : udb_morph_controller
// Description : [PATENT INNOVATION 1] Single-Cycle Autonomous Context Morpher
//               Holds 4 shadow contexts (Context 0..3) representing completely
//               distinct hardware personalities (Filter, Decryptor, Modulator, etc.).
//               Upon receiving a trigger pulse from the REM (or software), the
//               active personality morphs in EXACTLY 1 CLOCK CYCLE with zero CPU overhead.
//////////////////////////////////////////////////////////////////////////////////

module udb_morph_controller
(
    input  wire        clk,
    input  wire        rst_n,

    // Autonomous REM Event Trigger (Single-cycle pulse from event matrix)
    input  wire        event_morph_trigger,
    input  wire [1:0]  event_target_context,

    // MMIO Configuration Interface
    input  wire        reg_we,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    output reg  [31:0] reg_rdata,

    // Active Context Controls Driven to Datapath & Macrocell
    output reg  [3:0]  active_alu_op,
    output reg  [1:0]  active_src_a_sel,
    output reg  [1:0]  active_src_b_sel,
    output reg  [7:0]  active_imm_val,
    output reg         active_acc_load,
    output reg         active_shift_right,
    output reg  [23:0] active_pld_lut_config,
    output wire [1:0]  current_context_id,
    output reg  [31:0] morph_cycle_counter
);

    // Quad Shadow Context Storage (32 bits per context)
    // Bits [3:0]   : alu_op
    // Bits [5:4]   : src_a_sel
    // Bits [7:6]   : src_b_sel
    // Bits [15:8]  : imm_val
    // Bit  [16]    : acc_load
    // Bit  [17]    : shift_right
    // Bits [31:18] : pld_lut_config slice
    reg [31:0] shadow_context [0:3];
    reg [1:0]  active_idx;
    reg        auto_morph_en;

    assign current_context_id = active_idx;

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Default Context Personalities:
            // Context 0: Digital FIR Accumulator (ADD, A0 + D0)
            shadow_context[0] <= {14'h0000, 1'b1, 1'b1, 8'h00, 2'd0, 2'd0, 4'd0};
            // Context 1: Real-time Stream Decryptor/Scrambler (XOR with imm key 0xA5)
            shadow_context[1] <= {14'h0FFF, 1'b0, 1'b1, 8'hA5, 2'd2, 2'd3, 4'd4};
            // Context 2: CRC-8 Checksum / Polynomial Hash Generator
            shadow_context[2] <= {14'h1555, 1'b0, 1'b1, 8'h1D, 2'd0, 2'd3, 4'd6};
            // Context 3: Pulse Modulator / Shifter
            shadow_context[3] <= {14'h2AAA, 1'b1, 1'b1, 8'h01, 2'd0, 2'd0, 4'd5};

            active_idx          <= 2'b00;
            auto_morph_en       <= 1'b1;
            morph_cycle_counter <= 32'd0;
        end else begin
            morph_cycle_counter <= morph_cycle_counter + 32'd1;

            // PATENT NOVELTY: Autonomous 1-cycle hardware morphing triggered by REM
            if (auto_morph_en && event_morph_trigger) begin
                active_idx <= event_target_context;
            end else if (reg_we) begin
                case (reg_addr)
                    8'h00: begin // Control / Active Context Select
                        active_idx    <= reg_wdata[1:0];
                        auto_morph_en <= reg_wdata[2];
                    end
                    8'h10: shadow_context[0] <= reg_wdata;
                    8'h14: shadow_context[1] <= reg_wdata;
                    8'h18: shadow_context[2] <= reg_wdata;
                    8'h1C: shadow_context[3] <= reg_wdata;
                    default: ;
                endcase
            end
        end
    end

    // Single-Cycle Combinational Demultiplexing of Active Personality
    always @(*) begin
        active_alu_op         = shadow_context[active_idx][3:0];
        active_src_a_sel      = shadow_context[active_idx][5:4];
        active_src_b_sel      = shadow_context[active_idx][7:6];
        active_imm_val        = shadow_context[active_idx][15:8];
        active_acc_load       = shadow_context[active_idx][16];
        active_shift_right    = shadow_context[active_idx][17];
        active_pld_lut_config = {10'h0, shadow_context[active_idx][31:18]};
    end

    // MMIO Readout
    always @(*) begin
        case (reg_addr)
            8'h00: reg_rdata = {29'h0, auto_morph_en, active_idx};
            8'h04: reg_rdata = morph_cycle_counter;
            8'h10: reg_rdata = shadow_context[0];
            8'h14: reg_rdata = shadow_context[1];
            8'h18: reg_rdata = shadow_context[2];
            8'h1C: reg_rdata = shadow_context[3];
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
