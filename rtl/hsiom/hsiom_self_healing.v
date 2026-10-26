`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : hsiom_self_healing
// Description : [PATENT INNOVATION 3] Dynamic Autonomous Pin Failover Supervisor
//               Detects continuous electrical contention/shorts on active pins.
//               Autonomously migrates affected peripheral to a designated backup
//               pin without CPU intervention and raises a telemetry alarm.
//////////////////////////////////////////////////////////////////////////////////

module hsiom_self_healing
(
    input  wire        clk,
    input  wire        rst_n,

    // Primary Pin Signals to Supervise
    input  wire        primary_pad_oe,
    input  wire        primary_pad_out,
    input  wire        primary_pad_in,

    // Control Registers
    input  wire        failover_enable,
    input  wire [3:0]  backup_pin_index,
    input  wire [7:0]  fault_threshold,

    // Status & Override Outputs
    output reg         pin_fault_detected,
    output reg         failover_active,
    output reg  [3:0]  active_backup_pin,
    output reg  [15:0] contention_counter
);

    // Contention Detection: OE is asserted, but pad_in does not match pad_out
    wire contention = primary_pad_oe && (primary_pad_out != primary_pad_in);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            contention_counter <= 16'd0;
            pin_fault_detected <= 1'b0;
            failover_active    <= 1'b0;
            active_backup_pin  <= 4'd0;
        end else if (failover_enable) begin
            if (contention) begin
                if (contention_counter < 16'hFFFF)
                    contention_counter <= contention_counter + 16'd1;

                if (contention_counter >= {8'h0, fault_threshold}) begin
                    pin_fault_detected <= 1'b1;
                    failover_active    <= 1'b1;
                    active_backup_pin  <= backup_pin_index;
                end
            end else begin
                if (contention_counter > 16'd0 && !failover_active)
                    contention_counter <= contention_counter - 16'd1;
            end
        end
    end

endmodule
