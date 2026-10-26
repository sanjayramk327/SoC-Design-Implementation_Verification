`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : hsiom_top
// Description : High-Speed I/O Matrix (HSIOM) Subsystem with AXI4-Lite Slave,
//               Per-Pin Cell Routing, and Patent 3 Self-Healing Failover.
//////////////////////////////////////////////////////////////////////////////////

module hsiom_top
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

    // Internal Peripheral Source Signals
    input  wire [15:0] gpio_dr,
    input  wire        uart_tx,
    output wire        uart_rx,
    input  wire        tcpwm_out0,
    input  wire        tcpwm_nout0,
    input  wire [7:0]  udb_out,
    input  wire        snn_spike,

    // External 16 Pins (Port 0 [7:0] & Port 1 [7:0])
    output wire [15:0] pad_out,
    output wire [15:0] pad_oe,
    input  wire [15:0] pad_in,

    // Hardware Event to REM
    output wire        hsiom_fault_event
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

    // Mux Selector Registers: 3 bits per pin x 16 pins = 48 bits (2x 32-bit registers)
    reg [2:0] pin_mux [0:15];
    reg [2:0] pin_dm  [0:15];

    // Self-Healing Failover Registers
    reg        failover_en;
    reg [3:0]  backup_pin_sel;
    reg [7:0]  fault_thresh;
    wire       fault_det;
    wire       failover_active;
    wire [3:0] active_backup;
    wire [15:0] contention_cnt;

    hsiom_self_healing u_sh (
        .clk(aclk),
        .rst_n(aresetn),
        .primary_pad_oe(pad_oe[3]),       // Supervise UART TX on Pin 3
        .primary_pad_out(pad_out[3]),
        .primary_pad_in(pad_in[3]),
        .failover_enable(failover_en),
        .backup_pin_index(backup_pin_sel),
        .fault_threshold(fault_thresh),
        .pin_fault_detected(fault_det),
        .failover_active(failover_active),
        .active_backup_pin(active_backup),
        .contention_counter(contention_cnt)
    );

    assign hsiom_fault_event = fault_det;

    integer j;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (j = 0; j < 16; j = j + 1) begin
                pin_mux[j] <= 3'd0; // Default GPIO
                pin_dm[j]  <= 3'd6; // Strong Drive
            end
            // Defaults matching PSoC 4 pinout:
            pin_mux[2] <= 3'd1; // Pin 2: UART RX
            pin_mux[3] <= 3'd1; // Pin 3: UART TX
            pin_mux[5] <= 3'd2; // Pin 5: TCPWM OUT0
            pin_mux[6] <= 3'd2; // Pin 6: TCPWM nOUT0

            failover_en    <= 1'b1;
            backup_pin_sel <= 4'd7; // Backup to Pin 7
            fault_thresh   <= 8'd20; // 20 clock cycle contention = failover
        end else if (reg_write_en) begin
            case (reg_addr[7:0])
                8'h00: begin
                    pin_mux[0] <= reg_wdata[2:0];
                    pin_mux[1] <= reg_wdata[6:4];
                    pin_mux[2] <= reg_wdata[10:8];
                    pin_mux[3] <= reg_wdata[14:12];
                end
                8'h04: begin
                    pin_mux[4] <= reg_wdata[2:0];
                    pin_mux[5] <= reg_wdata[6:4];
                    pin_mux[6] <= reg_wdata[10:8];
                    pin_mux[7] <= reg_wdata[14:12];
                end
                8'h10: begin
                    failover_en    <= reg_wdata[0];
                    backup_pin_sel <= reg_wdata[7:4];
                    fault_thresh   <= reg_wdata[15:8];
                end
                default: ;
            endcase
        end
    end

    // Cell Instantiations
    wire [15:0] periph_in_bus;
    genvar p;
    generate
        for (p = 0; p < 16; p = p + 1) begin : HSIOM_PINS
            // Patent 3: If failover is active, dynamically swap signals
            wire is_faulted_primary = (p == 3) && failover_active;
            wire is_active_backup   = (p == active_backup) && failover_active;

            wire [2:0] eff_mux = is_faulted_primary ? 3'd0 : (is_active_backup ? 3'd1 : pin_mux[p]);
            wire [2:0] eff_dm  = is_faulted_primary ? 3'd1 : pin_dm[p];

            hsiom_cell u_cell (
                .mux_sel(eff_mux),
                .drive_mode(eff_dm),
                .sig_gpio(gpio_dr[p]),
                .sig_uart(uart_tx),
                .sig_tcpwm((p == 5) ? tcpwm_out0 : tcpwm_nout0),
                .sig_udb(udb_out[p % 8]),
                .sig_snn(snn_spike),
                .pad_out(pad_out[p]),
                .pad_oe(pad_oe[p]),
                .pad_in(pad_in[p]),
                .periph_in(periph_in_bus[p])
            );
        end
    endgenerate

    assign uart_rx = periph_in_bus[2];

    always @(*) begin
        case (reg_addr[7:0])
            8'h00: reg_rdata = {16'h0, pin_mux[3], 1'b0, pin_mux[2], 1'b0, pin_mux[1], 1'b0, pin_mux[0]};
            8'h04: reg_rdata = {16'h0, pin_mux[7], 1'b0, pin_mux[6], 1'b0, pin_mux[5], 1'b0, pin_mux[4]};
            8'h10: reg_rdata = {16'h0, fault_thresh, backup_pin_sel, 3'h0, failover_en};
            8'h14: reg_rdata = {10'h0, failover_active, fault_det, active_backup, contention_cnt};
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
