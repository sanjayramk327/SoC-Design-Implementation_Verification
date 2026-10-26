`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : reactive_event_matrix
// Description : Low-Latency Dual-Plane Reactive Event Matrix (REM)
//               Cross-connects 16 event sources to 8 action targets.
//////////////////////////////////////////////////////////////////////////////////

module reactive_event_matrix
(
    input  wire        clk,
    input  wire        rst_n,

    // Configuration Interface
    input  wire        cfg_we,
    input  wire [7:0]  cfg_addr,
    input  wire [31:0] cfg_wdata,
    output reg  [31:0] cfg_rdata,

    // 16 Event Inputs
    input  wire [15:0] event_sources,

    // 8 Hardware Action Outputs
    output wire [7:0]  action_triggers
);

    reg [3:0] act_sel [0:7];
    reg [7:0] act_en;
    reg [7:0] act_inv;
    reg [15:0] sw_events;

    wire [15:0] total_events = event_sources | sw_events;

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 8; k = k + 1)
                act_sel[k] <= k[3:0];
            act_en    <= 8'hFF;
            act_inv   <= 8'h00;
            sw_events <= 16'h0000;
        end else begin
            sw_events <= 16'h0000;
            if (cfg_we) begin
                case (cfg_addr[7:0])
                    8'h00: begin
                        act_sel[0] <= cfg_wdata[3:0];
                        act_sel[1] <= cfg_wdata[7:4];
                        act_sel[2] <= cfg_wdata[11:8];
                        act_sel[3] <= cfg_wdata[15:12];
                    end
                    8'h04: begin
                        act_sel[4] <= cfg_wdata[3:0];
                        act_sel[5] <= cfg_wdata[7:4];
                        act_sel[6] <= cfg_wdata[11:8];
                        act_sel[7] <= cfg_wdata[15:12];
                    end
                    8'h08: act_en    <= cfg_wdata[7:0];
                    8'h0C: act_inv   <= cfg_wdata[7:0];
                    8'h10: sw_events <= cfg_wdata[15:0];
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (cfg_addr[7:0])
            8'h00: cfg_rdata = {16'h0, act_sel[3], act_sel[2], act_sel[1], act_sel[0]};
            8'h04: cfg_rdata = {16'h0, act_sel[7], act_sel[6], act_sel[5], act_sel[4]};
            8'h08: cfg_rdata = {24'h0, act_en};
            8'h0C: cfg_rdata = {24'h0, act_inv};
            8'h10: cfg_rdata = {16'h0, total_events};
            default: cfg_rdata = 32'h0;
        endcase
    end

    genvar a;
    generate
        for (a = 0; a < 8; a = a + 1) begin : REM_ACTION_GEN
            wire raw_event = total_events[act_sel[a]];
            wire pol_event = act_inv[a] ? ~raw_event : raw_event;
            assign action_triggers[a] = act_en[a] & pol_event;
        end
    endgenerate

endmodule
