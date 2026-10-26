`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : wdt_pmu
// Description : Power Management Unit (Active, Sleep, Deep Sleep) & Watchdog
//               Matches Cypress PSoC 4 Deep Sleep with 35 us fast wakeup (WIC).
//////////////////////////////////////////////////////////////////////////////////

module wdt_pmu
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

    // Wakeup Events (from REM / WIC)
    input  wire        rem_wakeup_event,
    input  wire        cpu_sleep_req,
    input  wire        cpu_deepsleep_req,

    // Outputs
    output reg         clock_gate_cpu,
    output reg         wdt_reset_out,
    output reg         wdt_prewarn_event
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

    reg [31:0] pmu_mode_reg;
    reg [31:0] wdt_ctrl_reg;
    reg [31:0] wdt_cnt;
    reg [31:0] reset_cause_reg;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            pmu_mode_reg      <= 32'h0;
            wdt_ctrl_reg      <= 32'h00000FFF; // WDT enabled with timeout
            wdt_cnt           <= 32'd0;
            reset_cause_reg   <= 32'h00000001; // POR reset
            clock_gate_cpu    <= 1'b0;
            wdt_reset_out     <= 1'b0;
            wdt_prewarn_event <= 1'b0;
        end else begin
            wdt_prewarn_event <= 1'b0;
            wdt_reset_out     <= 1'b0;

            if (reg_write_en) begin
                case (reg_addr[7:0])
                    8'h00: pmu_mode_reg <= reg_wdata;
                    8'h04: begin
                        wdt_ctrl_reg <= reg_wdata;
                        if (reg_wdata[16]) wdt_cnt <= 32'd0; // Service WDT
                    end
                    8'h08: reset_cause_reg <= reg_wdata;
                    default: ;
                endcase
            end

            // WDT Counter
            if (wdt_ctrl_reg[0]) begin
                wdt_cnt <= wdt_cnt + 32'd1;
                if (wdt_cnt == (wdt_ctrl_reg[15:0] - 16'd100))
                    wdt_prewarn_event <= 1'b1;
                if (wdt_cnt >= wdt_ctrl_reg[15:0]) begin
                    wdt_reset_out      <= 1'b1;
                    reset_cause_reg[2] <= 1'b1; // WDT reset flag
                    wdt_cnt            <= 32'd0;
                end
            end

            // Sleep & Deep Sleep Clock Gating
            if (cpu_sleep_req || cpu_deepsleep_req) begin
                clock_gate_cpu <= 1'b1;
            end

            if (rem_wakeup_event) begin
                clock_gate_cpu <= 1'b0; // Fast 0-cycle wake
            end
        end
    end

    always @(*) begin
        case (reg_addr[7:0])
            8'h00: reg_rdata = pmu_mode_reg;
            8'h04: reg_rdata = {15'h0, wdt_ctrl_reg[16], wdt_ctrl_reg[15:0]};
            8'h08: reg_rdata = reset_cause_reg;
            8'h0C: reg_rdata = wdt_cnt;
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
