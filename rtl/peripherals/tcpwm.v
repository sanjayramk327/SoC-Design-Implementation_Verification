`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : tcpwm
// Description : 16-bit Timer / Counter / PWM matching Cypress PSoC 4 specs
//               Features: Center-aligned, Edge-aligned, Dead-band Insertion,
//               Complementary outputs (OUT0, nOUT0), Hardware Kill Input.
//////////////////////////////////////////////////////////////////////////////////

module tcpwm
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave
    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Hardware Kill / Trigger Inputs (from REM)
    input  wire        hw_kill_trig,
    input  wire        hw_reload_trig,

    // PWM Complementary Physical Outputs
    output reg         pwm_out0,
    output reg         pwm_nout0,

    // Event Outputs to REM
    output reg         event_overflow,
    output reg         event_underflow,
    output reg         event_compare_match
);

    wire [11:0] reg_addr;
    wire [31:0] reg_wdata;
    wire [3:0]  reg_wstrb;
    wire        reg_write_en;
    wire        reg_read_en;
    reg  [31:0] reg_rdata;

    axi4lite_slave #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) u_axislave (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb),
        .reg_write_en(reg_write_en),
        .reg_read_en(reg_read_en),
        .reg_rdata(reg_rdata),
        .reg_ack(1'b1)
    );

    reg [31:0] ctrl_reg;     // [0] enable, [1] up/down, [2] deadband en, [3] kill_en
    reg [15:0] counter_reg;
    reg [15:0] period_reg;
    reg [15:0] compare_reg;
    reg [7:0]  deadband_reg;
    reg        count_dir; // 0 = up, 1 = down
    reg        killed;

    reg raw_pwm;
    reg [7:0] db_cnt_rise;
    reg [7:0] db_cnt_fall;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ctrl_reg            <= 32'h00000001; // Enabled by default
            counter_reg         <= 16'd0;
            period_reg          <= 16'd1000;
            compare_reg         <= 16'd500;
            deadband_reg        <= 8'd10;
            count_dir           <= 1'b0;
            killed              <= 1'b0;
            pwm_out0            <= 1'b0;
            pwm_nout0           <= 1'b0;
            event_overflow      <= 1'b0;
            event_underflow     <= 1'b0;
            event_compare_match <= 1'b0;
            db_cnt_rise         <= 8'd0;
            db_cnt_fall         <= 8'd0;
        end else begin
            event_overflow      <= 1'b0;
            event_underflow     <= 1'b0;
            event_compare_match <= 1'b0;

            // Hardware Kill
            if (ctrl_reg[3] && hw_kill_trig)
                killed <= 1'b1;

            if (reg_write_en) begin
                case (reg_addr[7:0])
                    8'h00: begin
                        ctrl_reg <= reg_wdata;
                        if (reg_wdata[4]) killed <= 1'b0; // Clear kill
                    end
                    8'h04: counter_reg  <= reg_wdata[15:0];
                    8'h08: period_reg   <= reg_wdata[15:0];
                    8'h0C: compare_reg  <= reg_wdata[15:0];
                    8'h10: deadband_reg <= reg_wdata[7:0];
                    default: ;
                endcase
            end

            // Counter Operation
            if (ctrl_reg[0] && !killed) begin
                if (counter_reg == compare_reg)
                    event_compare_match <= 1'b1;

                if (!ctrl_reg[1]) begin
                    // Up-counter mode
                    if (counter_reg >= period_reg) begin
                        counter_reg    <= 16'd0;
                        event_overflow <= 1'b1;
                    end else begin
                        counter_reg <= counter_reg + 16'd1;
                    end
                    raw_pwm <= (counter_reg < compare_reg);
                end else begin
                    // Center-aligned mode
                    if (!count_dir) begin
                        if (counter_reg >= period_reg) begin
                            count_dir      <= 1'b1;
                            event_overflow <= 1'b1;
                        end else begin
                            counter_reg <= counter_reg + 16'd1;
                        end
                    end else begin
                        if (counter_reg == 16'd0) begin
                            count_dir       <= 1'b0;
                            event_underflow <= 1'b1;
                        end else begin
                            counter_reg <= counter_reg - 16'd1;
                        end
                    end
                    raw_pwm <= (counter_reg < compare_reg);
                end

                // Dead-band insertion generator
                if (ctrl_reg[2]) begin
                    if (raw_pwm) begin
                        pwm_nout0 <= 1'b0;
                        if (db_cnt_rise < deadband_reg) begin
                            db_cnt_rise <= db_cnt_rise + 8'd1;
                            pwm_out0    <= 1'b0;
                        end else begin
                            pwm_out0 <= 1'b1;
                        end
                        db_cnt_fall <= 8'd0;
                    end else begin
                        pwm_out0 <= 1'b0;
                        if (db_cnt_fall < deadband_reg) begin
                            db_cnt_fall <= db_cnt_fall + 8'd1;
                            pwm_nout0   <= 1'b0;
                        end else begin
                            pwm_nout0 <= 1'b1;
                        end
                        db_cnt_rise <= 8'd0;
                    end
                end else begin
                    pwm_out0  <= raw_pwm;
                    pwm_nout0 <= ~raw_pwm;
                end
            end else if (killed) begin
                // Safe state shutoff
                pwm_out0  <= 1'b0;
                pwm_nout0 <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (reg_addr[7:0])
            8'h00: reg_rdata = {27'h0, killed, ctrl_reg[3:0]};
            8'h04: reg_rdata = {16'h0, counter_reg};
            8'h08: reg_rdata = {16'h0, period_reg};
            8'h0C: reg_rdata = {16'h0, compare_reg};
            8'h10: reg_rdata = {24'h0, deadband_reg};
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
